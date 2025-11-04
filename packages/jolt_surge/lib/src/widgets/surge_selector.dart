import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

/// A widget that provides fine-grained rebuild control using a selector function.
///
/// SurgeSelector only rebuilds when the value returned by the [selector] function
/// changes (determined by `==` comparison). This allows you to optimize rebuilds
/// by selecting only the specific part of the state that your widget needs.
///
/// The [selector] function is tracked by default, meaning it can depend on
/// external signals. If you need to use external signals without tracking them,
/// wrap the access in [untracked].
///
/// Example:
/// ```dart
/// SurgeSelector<CounterSurge, int, String>(
///   selector: (state, s) => state.isEven ? 'even' : 'odd', // Default tracked
///   builder: (context, selected, s) => Text(selected),
/// );
/// ```
///
/// With untracked external signals:
/// ```dart
/// SurgeSelector<CounterSurge, int, String>(
///   selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
///   builder: (context, selected, s) => Text(selected),
/// );
/// ```
///
/// See also:
/// - [SurgeConsumer] for both builder and listener functionality
/// - [SurgeBuilder] for builder-only functionality
/// - [SurgeListener] for listener-only functionality
class SurgeSelector<T extends Surge<S>, S, C> extends StatefulWidget {
  /// Creates a SurgeSelector widget.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on selected value
  /// - [selector]: The selector function that extracts a value from the state.
  ///   This function is tracked by default (can depend on external signals)
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  ///
  /// The widget only rebuilds when the value returned by [selector] changes
  /// (determined by `==` comparison). This allows fine-grained control over
  /// when to rebuild.
  ///
  /// The [selector] function is tracked by default, meaning it can depend on
  /// external signals. If you need to use external signals without tracking them,
  /// wrap the access in [untracked]:
  ///
  /// ```dart
  /// SurgeSelector<CounterSurge, int, String>(
  ///   selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  ///   builder: (context, selected, s) => Text(selected),
  /// );
  /// ```
  ///
  /// Example:
  /// ```dart
  /// SurgeSelector<CounterSurge, int, String>(
  ///   selector: (state, s) => state.isEven ? 'even' : 'odd',
  ///   builder: (context, selected, s) => Text('Number is $selected'),
  /// );
  /// // Only rebuilds when the state changes between even and odd
  /// ```
  const SurgeSelector({
    super.key,
    required this.builder,
    required this.selector,
    this.surge,
  });

  /// The builder function that builds the UI based on the selected value.
  ///
  /// Parameters:
  /// - [context]: The build context
  /// - [state]: The selected value (result of [selector])
  /// - [surge]: The Surge instance
  ///
  /// Returns: The widget to build
  ///
  /// This function is called whenever the value returned by [selector] changes
  /// (determined by `==` comparison).
  final Widget Function(BuildContext context, C state, T surge) builder;

  /// The selector function that extracts a value from the state.
  ///
  /// Parameters:
  /// - [state]: The current state value
  /// - [surge]: The Surge instance
  ///
  /// Returns: The selected value to use for rebuilding
  ///
  /// This function is tracked by default, meaning it can depend on external signals.
  /// The widget only rebuilds when the returned value changes (determined by `==`).
  ///
  /// If you need to use external signals without tracking them, wrap the access
  /// in [untracked]:
  ///
  /// ```dart
  /// selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  /// ```
  final C Function(S state, T surge) selector;

  /// Optional Surge instance.
  ///
  /// If not provided, the Surge will be obtained from the widget tree using
  /// `context.read<T>()`. If provided, this specific instance will be used.
  final T? surge;

  @override
  State<StatefulWidget> createState() {
    return SurgeSelectorState<T, S, C>();
  }
}

class SurgeSelectorState<T extends Surge<S>, S, C>
    extends State<SurgeSelector<T, S, C>> {
  SurgeSelectorState();

  late T _surge;
  late C _selectorValue;

  Effect? _effect;

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
    _effect = Effect(() {
      if (!mounted) return;
      final state = _surge.state;

      final newSelectorValue = widget.selector(state, _surge);
      if (_selectorValue == newSelectorValue) return;

      _selectorValue = newSelectorValue;

      (context as StatefulElement).markNeedsBuild();
    });
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
    return widget.builder(context, _selectorValue, _surge);
  }
}
