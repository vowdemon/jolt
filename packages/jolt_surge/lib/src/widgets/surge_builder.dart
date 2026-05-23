import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

import '../surge.dart';
import 'surge_consumer.dart';

/// Rebuilds UI when a [Surge] state changes.
///
/// The [builder] is wrapped in a [JoltBuilder], so external Jolt signals read
/// inside it are tracked as well. Use [buildWhen] to skip rebuilds for specific
/// transitions. When [surge] is omitted, the nearest [SurgeProvider] is used.
///
/// ```dart
/// SurgeBuilder<CounterSurge, int>(
///   builder: (context, state, surge) => Text('Count: $state'),
///   buildWhen: (previous, current, _) => current.isEven,
/// );
/// ```
///
/// See also: [SurgeConsumer], [SurgeListener], and [SurgeSelector].
class SurgeBuilder<T extends Surge<S>, S> extends StatefulWidget {
  /// Creates a builder that receives the [Surge] instance in callbacks.
  ///
  /// [buildWhen] is tracked by default. Wrap external reads in [untracked]
  /// when they should not schedule rebuilds.
  const SurgeBuilder.full({
    super.key,
    required this.builder,
    this.buildWhen,
    this.surge,
  });

  /// Creates a Cubit-style builder without exposing the [Surge] in callbacks.
  ///
  /// See [SurgeBuilder.full] when callbacks need the surge instance.
  factory SurgeBuilder({
    Key? key,
    required Widget Function(BuildContext context, S state) builder,
    T? surge,
    bool Function(S prevState, S newState)? buildWhen,
  }) =>
      SurgeBuilder.full(
        key: key,
        builder: (context, state, _) => builder(context, state),
        surge: surge,
        buildWhen: buildWhen != null
            ? (prevState, newState, _) => buildWhen(prevState, newState)
            : null,
      );

  /// Builds UI from the current [state] and [surge].
  final Widget Function(BuildContext context, S state, T surge) builder;

  /// Whether to rebuild for a given state transition.
  ///
  /// Tracked by default unless wrapped in [untracked].
  final bool Function(S prevState, S newState, T surge)? buildWhen;

  /// The surge to observe, or `null` to read from [SurgeProvider].
  ///
  /// If not provided, the Surge will be obtained from the widget tree using
  /// `context.read<T>()`. If provided, this specific instance will be used.
  final T? surge;

  @override
  State<StatefulWidget> createState() {
    return _SurgeBuilderState<T, S>();
  }
}

class _SurgeBuilderState<T extends Surge<S>, S>
    extends State<SurgeBuilder<T, S>> {
  _SurgeBuilderState();

  late T _surge;
  late S _state;

  FlutterEffect? _effect;

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
  void didUpdateWidget(SurgeBuilder<T, S> oldWidget) {
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
    final allowNullSkip = widget.buildWhen == null;
    bool firstEffect = true;
    _effect = FlutterEffect(() {
      if (!mounted) return;

      final state = _surge.state;

      final builderTriggable =
          widget.buildWhen?.call(_state, state, _surge) ?? true;

      if ((_state == state && allowNullSkip) || firstEffect) {
        firstEffect = false;
        return;
      }

      if (builderTriggable) {
        (context as StatefulElement).markNeedsBuild();
      }

      _state = state;
    }, detach: true, debug: JoltDebugOption.type('SurgeBuilder<$T>'));
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
    return JoltBuilder(builder: _builder);
  }

  Widget _builder(BuildContext context) {
    return widget.builder(context, _state, _surge);
  }
}
