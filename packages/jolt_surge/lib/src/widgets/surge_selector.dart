import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

/// A widget that provides fine-grained rebuild control using a selector function.
///
/// SurgeSelector is a [StatefulWidget] that only rebuilds when the value returned
/// by the [selector] function changes (determined by `==` comparison). It uses a
/// [FlutterEffect] internally to track Surge state changes and compare selector results.
///
/// **Key Implementation Details:**
/// - Uses [FlutterEffect] to track Surge state changes (executes at frame end)
/// - [selector] is called within the effect and is tracked by default
/// - Only rebuilds when the selector result changes (using `==` comparison)
/// - When [surge] is null, uses `context.select` to ensure rebuilds when the
///   Provider instance changes
/// - If the selector function itself changes (in didUpdateWidget), the selector
///   value is recalculated immediately
/// - **Builder function dependency tracking**: The [builder] function is wrapped
///   in a [JoltBuilder], allowing it to automatically track external signals,
///   computed values, and other reactive dependencies accessed within the builder.
///   This provides the same dependency tracking capabilities as [JoltBuilder].
///
/// Example:
/// ```dart
/// final externalSignal = Signal<String>('initial');
///
/// SurgeSelector<CounterSurge, int, String>(
///   selector: (state, s) => state.isEven ? 'even' : 'odd', // Default tracked
///   builder: (context, selected, s) {
///     // Can access external signals - automatically tracked!
///     final external = externalSignal.value;
///     return Text('$selected, external: $external');
///   },
/// );
/// ```
///
/// With untracked external signals in selector:
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
/// - [JoltBuilder] for the underlying dependency tracking mechanism
class SurgeSelector<T extends Surge<S>, S, C> extends StatefulWidget {
  /// Creates a SurgeSelector widget with full access to the Surge instance.
  ///
  /// This is the full-featured constructor that provides access to the Surge
  /// instance in callbacks. Use this when you need to access the Surge instance
  /// in your selector or builder functions.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on selected value.
  ///   Receives `(context, selected, surge)` parameters.
  /// - [selector]: The selector function that extracts a value from the state.
  ///   Receives `(state, surge)` parameters.
  ///   This function is tracked by default (can depend on external signals).
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
  /// SurgeSelector<CounterSurge, int, String>.full(
  ///   selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  ///   builder: (context, selected, s) => Text(selected),
  /// );
  /// ```
  ///
  /// Example:
  /// ```dart
  /// SurgeSelector<CounterSurge, int, String>.full(
  ///   selector: (state, s) => state.isEven ? 'even' : 'odd',
  ///   builder: (context, selected, s) => Text('Number is $selected'),
  /// );
  /// // Only rebuilds when the state changes between even and odd
  /// ```
  const SurgeSelector.full({
    super.key,
    required this.builder,
    required this.selector,
    this.surge,
  });

  /// Creates a SurgeSelector widget with Cubit-compatible API.
  ///
  /// This factory constructor provides a 100% compatible API with `BlocSelector`
  /// from the `flutter_bloc` package, making it easy to migrate from Bloc/Cubit
  /// to Surge. The builder and selector functions do not receive the Surge instance,
  /// matching the Cubit API exactly.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on selected value.
  ///   Receives `(context, selected)` parameters (no Surge instance).
  /// - [selector]: The selector function that extracts a value from the state.
  ///   Receives `(state)` parameter (no Surge instance).
  ///   This function is tracked by default (can depend on external signals).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  ///
  /// The widget only rebuilds when the value returned by [selector] changes
  /// (determined by `==` comparison). This allows fine-grained control over
  /// when to rebuild.
  ///
  /// Example:
  /// ```dart
  /// // Cubit-compatible usage (same as BlocSelector)
  /// SurgeSelector<CounterSurge, int, String>(
  ///   selector: (state) => state.isEven ? 'even' : 'odd',
  ///   builder: (context, selected) => Text('Number is $selected'),
  /// );
  /// // Only rebuilds when the state changes between even and odd
  /// ```
  ///
  /// See also:
  /// - [SurgeSelector.full] for access to the Surge instance in callbacks
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
  ///
  /// **Dependency Tracking:**
  /// The builder function is wrapped in a [JoltBuilder], which means any external
  /// signals, computed values, or reactive collections accessed within this builder
  /// will be automatically tracked. When these tracked dependencies change, the
  /// widget will automatically rebuild, just like [JoltBuilder].
  ///
  /// Example:
  /// ```dart
  /// final multiplier = Signal<int>(2);
  /// final computed = Computed(() => multiplier.value * 10);
  ///
  /// SurgeSelector<CounterSurge, int, String>(
  ///   selector: (state, s) => state.isEven ? 'even' : 'odd',
  ///   builder: (context, selected, surge) {
  ///     // These are automatically tracked:
  ///     final mult = multiplier.value;
  ///     final comp = computed.value;
  ///     return Text('Selected: $selected, Mult: $mult, Computed: $comp');
  ///   },
  /// );
  /// // Widget rebuilds when selector result changes OR when multiplier/computed changes
  /// ```
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
    }, debug: JoltDebugOption.type('SurgeSelector<$T,$C>'));
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
