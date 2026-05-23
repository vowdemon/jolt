import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

/// Rebuilds only when [selector] returns a new value.
///
/// Selector results are compared with `==`. Wrap reads that should not create
/// dependencies in [untracked]. The [builder] is wrapped in a [JoltBuilder] for
/// external signal tracking. When [surge] is omitted, the nearest
/// [SurgeProvider] is used.
///
/// ```dart
/// SurgeSelector<CounterSurge, int, String>(
///   selector: (state, _) => state.isEven ? 'even' : 'odd',
///   builder: (context, label, _) => Text(label),
/// );
/// ```
///
/// See also: [SurgeConsumer], [SurgeBuilder], and [SurgeListener].
class SurgeSelector<T extends Surge<S>, S, C> extends StatefulWidget {
  /// Creates a selector that receives the [Surge] instance in callbacks.
  ///
  /// [selector] is tracked by default unless wrapped in [untracked].
  const SurgeSelector.full({
    super.key,
    required this.builder,
    required this.selector,
    this.surge,
  });

  /// Creates a Cubit-style selector without exposing the [Surge] in callbacks.
  ///
  /// See [SurgeSelector.full] when callbacks need the surge instance.
  factory SurgeSelector({
    Key? key,
    required Widget Function(BuildContext context, C state) builder,
    required C Function(S state) selector,
    T? surge,
  }) =>
      SurgeSelector.full(
        key: key,
        builder: (context, state, _) => builder(context, state),
        selector: (state, _) => selector(state),
        surge: surge,
      );

  /// Builds UI from the value selected by [selector].
  final Widget Function(BuildContext context, C state, T surge) builder;

  /// Derives the value that controls rebuilds.
  ///
  /// Tracked by default unless wrapped in [untracked].
  final C Function(S state, T surge) selector;

  /// The surge to observe, or `null` to read from [SurgeProvider].
  final T? surge;

  @override
  State<StatefulWidget> createState() {
    return _SurgeSelectorState<T, S, C>();
  }
}

class _SurgeSelectorState<T extends Surge<S>, S, C>
    extends State<SurgeSelector<T, S, C>> {
  _SurgeSelectorState();

  late T _surge;
  late C _selectorValue;

  FlutterEffect? _effect;

  @override
  void initState() {
    super.initState();
    _surge = widget.surge ?? context.read<T>();
    _selectorValue = widget.selector(_surge.state, _surge);
    _startEffect();
  }

  @override
  void dispose() {
    super.dispose();
    _stopEffect();
  }

  @override
  void didUpdateWidget(SurgeSelector<T, S, C> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSurge = oldWidget.surge ?? context.read<T>();
    final currentSurge = widget.surge ?? oldSurge;
    if (!identical(oldSurge, currentSurge)) {
      _surge = currentSurge;
      _selectorValue = widget.selector(_surge.state, _surge);
      _restartEffect();
    } else if (widget.selector != oldWidget.selector) {
      _selectorValue = widget.selector(_surge.state, _surge);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final surge = widget.surge ?? context.read<T>();
    if (!identical(_surge, surge)) {
      _surge = surge;
      _selectorValue = widget.selector(_surge.state, _surge);
      _restartEffect();
    }
  }

  void _startEffect() {
    _effect = FlutterEffect(() {
      if (!mounted) return;
      final state = _surge.state;

      final newSelectorValue = widget.selector(state, _surge);
      if (_selectorValue == newSelectorValue) return;

      _selectorValue = newSelectorValue;

      (context as StatefulElement).markNeedsBuild();
    }, detach: true, debug: JoltDebugOption.type('SurgeSelector<$T,$C>'));
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
    return widget.builder(context, _selectorValue, _surge);
  }
}
