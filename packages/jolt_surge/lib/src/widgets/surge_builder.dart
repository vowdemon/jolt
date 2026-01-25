import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

import '../surge.dart';
import 'surge_consumer.dart';

/// A widget that builds UI based on Surge state changes.
///
/// SurgeBuilder is a [StatefulWidget] that automatically rebuilds when the Surge
/// state changes. It uses a [FlutterEffect] internally to track Surge state changes
/// and conditionally rebuilds based on the [buildWhen] callback.
///
/// **Key Implementation Details:**
/// - Uses [FlutterEffect] to track Surge state changes (executes at frame end)
/// - [buildWhen] is called within the effect and is tracked by default
/// - First effect execution is skipped to avoid unnecessary initial rebuild
/// - If state hasn't changed and [buildWhen] is null, the rebuild is skipped
/// - When [surge] is null, uses `context.select` to ensure rebuilds when
///   the Provider instance changes
/// - **Builder function dependency tracking**: The [builder] function is wrapped
///   in a [JoltBuilder], allowing it to automatically track external signals,
///   computed values, and other reactive dependencies accessed within the builder.
///   This provides the same dependency tracking capabilities as [JoltBuilder].
///
/// Example:
/// ```dart
/// final externalSignal = Signal<String>('initial');
///
/// SurgeBuilder<CounterSurge, int>(
///   builder: (context, state, surge) {
///     // Can access external signals - automatically tracked!
///     final external = externalSignal.value;
///     return Text('count: $state, external: $external');
///   },
///   buildWhen: (prev, next, s) => next.isEven, // Optional: only rebuild when even
/// );
/// ```
///
/// See also:
/// - [SurgeConsumer] for both builder and listener functionality
/// - [SurgeListener] for listener-only functionality
/// - [SurgeSelector] for fine-grained rebuild control with selector
/// - [JoltBuilder] for the underlying dependency tracking mechanism
class SurgeBuilder<T extends Surge<S>, S> extends StatefulWidget {
  /// Creates a SurgeBuilder widget with full access to the Surge instance.
  ///
  /// This is the full-featured constructor that provides access to the Surge
  /// instance in the builder and buildWhen callbacks.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state.
  ///   Receives `(context, state, surge)` parameters.
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Receives `(prevState, newState, surge)` parameters.
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  ///   This function is tracked by default (can depend on external signals).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from
  ///   context using `context.read<T>()`
  ///
  /// The [buildWhen] function is tracked by default, meaning it can depend on
  /// external signals. If you need to use external signals without tracking
  /// them, wrap the access in [untracked]:
  ///
  /// ```dart
  /// SurgeBuilder<CounterSurge, int>.full(
  ///   buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
  ///   builder: (context, state, surge) => Text('count: $state'),
  /// );
  /// ```
  const SurgeBuilder.full({
    super.key,
    required this.builder,
    this.buildWhen,
    this.surge,
  });

  /// Creates a SurgeBuilder widget with Cubit-compatible API.
  ///
  /// This factory constructor provides a 100% compatible API with `BlocBuilder`
  /// from the `flutter_bloc` package, making it easy to migrate from Bloc/Cubit
  /// to Surge. The builder and buildWhen functions do not receive the Surge
  /// instance, matching the Cubit API exactly.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state.
  ///   Receives `(context, state)` parameters (no Surge instance).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from
  ///   context using `context.read<T>()`
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Receives `(prevState, newState)` parameters (no Surge instance).
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  ///
  /// Example:
  /// ```dart
  /// // Cubit-compatible usage (same as BlocBuilder)
  /// SurgeBuilder<CounterSurge, int>(
  ///   buildWhen: (prev, next) => next.isEven, // Only rebuild when even
  ///   builder: (context, state) => Text('count: $state'),
  /// );
  /// ```
  ///
  /// See also:
  /// - [SurgeBuilder.full] for access to the Surge instance in callbacks
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

  /// The builder function that builds the UI based on state.
  ///
  /// Parameters:
  /// - [context]: The build context
  /// - [state]: The current state value
  /// - [surge]: The Surge instance
  ///
  /// Returns: The widget to build
  ///
  /// This function is called whenever the state changes and [buildWhen] returns true.
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
  /// SurgeBuilder<CounterSurge, int>(
  ///   builder: (context, state, surge) {
  ///     // These are automatically tracked:
  ///     final mult = multiplier.value;
  ///     final comp = computed.value;
  ///     return Text('State: $state, Mult: $mult, Computed: $comp');
  ///   },
  /// );
  /// // Widget rebuilds when state changes OR when multiplier/computed changes
  /// ```
  final Widget Function(BuildContext context, S state, T surge) builder;

  /// Optional condition function to control when to rebuild.
  ///
  /// Parameters:
  /// - [prevState]: The previous state value
  /// - [newState]: The new state value
  /// - [surge]: The Surge instance
  ///
  /// Returns: true to rebuild, false to skip
  ///
  /// This function is tracked by default, meaning it can depend on external signals.
  /// If you need to use external signals without tracking them, wrap the access
  /// in [untracked].
  ///
  /// If not provided, the widget will rebuild on every state change.
  final bool Function(S prevState, S newState, T surge)? buildWhen;

  /// Optional Surge instance.
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
    }, debug: JoltDebugOption.type('SurgeBuilder<$T>'));
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
