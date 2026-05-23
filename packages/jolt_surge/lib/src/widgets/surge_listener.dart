import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

import '../surge.dart';
import 'surge_consumer.dart';

/// Runs side effects when a [Surge] state changes without rebuilding [child].
///
/// The [listener] runs in an [untracked] context so it does not create reactive
/// dependencies. Use [listenWhen] to filter which transitions invoke
/// [listener]. When [surge] is omitted, the nearest [SurgeProvider] is used.
///
/// ```dart
/// SurgeListener<CounterSurge, int>(
///   listenWhen: (previous, current, _) => current > previous,
///   listener: (context, state, surge) {
///     debugPrint('Count increased to: $state');
///   },
///   child: const SizedBox.shrink(),
/// );
/// ```
///
/// See also: [SurgeConsumer], [SurgeBuilder], and [SurgeSelector].
class SurgeListener<T extends Surge<S>, S> extends StatefulWidget {
  /// Creates a listener that receives the [Surge] instance in callbacks.
  ///
  /// [listenWhen] is tracked by default unless wrapped in [untracked].
  const SurgeListener.full({
    super.key,
    required this.child,
    required this.listener,
    this.listenWhen,
    this.surge,
  });

  /// Creates a Cubit-style listener without exposing the [Surge] in callbacks.
  ///
  /// See [SurgeListener.full] when callbacks need the surge instance.
  factory SurgeListener({
    Key? key,
    required Widget child,
    required void Function(BuildContext context, S state) listener,
    T? surge,
    bool Function(S prevState, S newState)? listenWhen,
  }) =>
      SurgeListener.full(
        key: key,
        listener: (context, state, _) => listener(context, state),
        surge: surge,
        listenWhen: listenWhen != null
            ? (prevState, newState, _) => listenWhen(prevState, newState)
            : null,
        child: child,
      );

  /// The subtree that is not rebuilt by this listener.
  final Widget child;

  /// Runs side effects in an [untracked] context when [listenWhen] allows it.
  final void Function(BuildContext context, S state, T surge)? listener;

  /// Whether to run [listener] for a given state transition.
  final bool Function(S prevState, S newState, T surge)? listenWhen;

  /// The surge to observe, or `null` to read from [SurgeProvider].
  final T? surge;

  @override
  State<StatefulWidget> createState() {
    return _SurgeListenerState<T, S>();
  }
}

class _SurgeListenerState<T extends Surge<S>, S>
    extends State<SurgeListener<T, S>> {
  _SurgeListenerState();

  late T _surge;
  late S _state;

  Effect? _effect;

  @override
  void initState() {
    super.initState();
    _surge = widget.surge ?? context.read<T>();
    _state = _surge.state;
    _startEffect();
  }

  @override
  void dispose() {
    super.dispose();
    _stopEffect();
  }

  @override
  void didUpdateWidget(SurgeListener<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSurge = oldWidget.surge ?? context.read<T>();
    final currentSurge = widget.surge ?? oldSurge;
    if (!identical(oldSurge, currentSurge)) {
      _surge = currentSurge;
      _state = _surge.state;
      _restartEffect();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final surge = widget.surge ?? context.read<T>();
    if (!identical(_surge, surge)) {
      _surge = surge;
      _state = _surge.state;
      _restartEffect();
    }
  }

  void _startEffect() {
    final allowNullSkip =
        (widget.listenWhen == null || widget.listener == null);
    bool firstEffect = true;
    _effect = Effect(() {
      if (!mounted) return;

      final state = _surge.state;
      final listenerTriggable = widget.listener != null &&
          (widget.listenWhen?.call(_state, state, _surge) ?? true);

      if ((_state == state && allowNullSkip) || firstEffect) {
        firstEffect = false;
        return;
      }

      if (listenerTriggable) {
        untracked(() {
          widget.listener!(context, state, _surge);
        });
      }

      (context as StatefulElement).markNeedsBuild();

      _state = state;
    }, detach: true, debug: JoltDebugOption.type('SurgeListener<$T>'));
  }

  void _stopEffect() {
    _effect?.dispose();
    _effect = null;
  }

  void _restartEffect() {
    _stopEffect();
    _startEffect();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.surge == null) {
      context.select<T, bool>((surge) => identical(_surge, surge));
    }
    return widget.child;
  }
}
