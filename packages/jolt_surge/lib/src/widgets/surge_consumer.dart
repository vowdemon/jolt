import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../surge.dart';
import 'surge_listener.dart';
import 'surge_builder.dart';

/// A unified widget that provides both builder and listener functionality.
///
/// SurgeConsumer is a [StatelessWidget] that combines [SurgeBuilder] and
/// [SurgeListener] to provide both UI building and side effect handling
/// capabilities in a single widget.
///
/// **Implementation:**
/// - Internally wraps a [SurgeListener] around a [SurgeBuilder]
/// - The listener handles side effects (executed in untracked context)
/// - The builder handles UI rebuilding (using FlutterEffect)
/// - Both [buildWhen] and [listenWhen] are tracked by default
/// - **Builder function dependency tracking**: The [builder] function is wrapped
///   in a [JoltBuilder] (via [SurgeBuilder]), allowing it to automatically track
///   external signals, computed values, and other reactive dependencies accessed
///   within the builder. This provides the same dependency tracking capabilities
///   as [JoltBuilder].
///
/// Example:
/// ```dart
/// final externalSignal = Signal<String>('initial');
///
/// SurgeConsumer<CounterSurge, int>(
///   buildWhen: (prev, next, s) => next.isEven, // Only rebuild when even
///   listenWhen: (prev, next, s) => next > prev, // Only listen when increasing
///   builder: (context, state, s) {
///     // Can access external signals - automatically tracked!
///     final external = externalSignal.value;
///     return Text('count: $state, external: $external');
///   },
///   listener: (context, state, s) {
///     // Side effects: show SnackBar or send analytics events
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Count is now: $state')),
///     );
///   },
/// );
/// ```
///
/// See also:
/// - [SurgeBuilder] for builder-only functionality
/// - [SurgeListener] for listener-only functionality
/// - [SurgeSelector] for fine-grained rebuild control with selector
/// - [JoltBuilder] for the underlying dependency tracking mechanism
class SurgeConsumer<T extends Surge<S>, S> extends StatelessWidget {
  /// Creates a SurgeConsumer widget with full access to the Surge instance.
  ///
  /// This is the full-featured constructor that provides access to the Surge
  /// instance in all callbacks. Use this when you need to access the Surge instance
  /// in your builder, listener, buildWhen, or listenWhen functions.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state.
  ///   Receives `(context, state, surge)` parameters.
  /// - [listener]: Optional listener function for side effects.
  ///   Receives `(context, state, surge)` parameters.
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Receives `(prevState, newState, surge)` parameters.
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  ///   This function is tracked by default (can depend on external signals).
  /// - [listenWhen]: Optional condition function to control when to execute listener.
  ///   Receives `(prevState, newState, surge)` parameters.
  ///   Returns true to execute, false to skip. Defaults to always executing.
  ///   This function is tracked by default (can depend on external signals).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  ///
  /// Both [buildWhen] and [listenWhen] are tracked by default, meaning they can
  /// depend on external signals. If you need to use external signals without
  /// tracking them, use [untracked]:
  ///
  /// ```dart
  /// SurgeConsumer<CounterSurge, int>.full(
  ///   buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
  ///   // ...
  /// );
  /// ```
  const SurgeConsumer.full({
    super.key,
    required this.builder,
    this.listener,
    this.buildWhen,
    this.listenWhen,
    this.surge,
  });

  /// Creates a SurgeConsumer widget with Cubit-compatible API.
  ///
  /// This factory constructor provides a 100% compatible API with `BlocConsumer`
  /// from the `flutter_bloc` package, making it easy to migrate from Bloc/Cubit
  /// to Surge. The builder, listener, buildWhen, and listenWhen functions do not
  /// receive the Surge instance, matching the Cubit API exactly.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [builder]: The builder function that builds the UI based on state.
  ///   Receives `(context, state)` parameters (no Surge instance).
  /// - [listener]: Optional listener function for side effects.
  ///   Receives `(context, state)` parameters (no Surge instance).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from context
  /// - [buildWhen]: Optional condition function to control when to rebuild.
  ///   Receives `(prevState, newState)` parameters (no Surge instance).
  ///   Returns true to rebuild, false to skip. Defaults to always rebuilding.
  /// - [listenWhen]: Optional condition function to control when to execute listener.
  ///   Receives `(prevState, newState)` parameters (no Surge instance).
  ///   Returns true to execute, false to skip. Defaults to always executing.
  ///
  /// Example:
  /// ```dart
  /// // Cubit-compatible usage (same as BlocConsumer)
  /// SurgeConsumer<CounterSurge, int>(
  ///   buildWhen: (prev, next) => next.isEven, // Only rebuild when even
  ///   listenWhen: (prev, next) => next > prev, // Only listen when increasing
  ///   builder: (context, state) => Text('count: $state'),
  ///   listener: (context, state) {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       SnackBar(content: Text('Count is now: $state')),
  ///     );
  ///   },
  /// );
  /// ```
  ///
  /// See also:
  /// - [SurgeConsumer.full] for access to the Surge instance in callbacks
  factory SurgeConsumer({
    Key? key,
    required Widget Function(BuildContext context, S state) builder,
    void Function(BuildContext context, S state)? listener,
    T? surge,
    bool Function(S prevState, S newState)? buildWhen,
    bool Function(S prevState, S newState)? listenWhen,
  }) =>
      SurgeConsumer.full(
        key: key,
        builder: (context, state, _) => builder(context, state),
        listener: listener != null
            ? (context, state, _) => listener(context, state)
            : null,
        surge: surge,
        buildWhen: buildWhen != null
            ? (prevState, newState, _) => buildWhen(prevState, newState)
            : null,
        listenWhen: listenWhen != null
            ? (prevState, newState, _) => listenWhen(prevState, newState)
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
  /// The builder function is wrapped in a [JoltBuilder] (via [SurgeBuilder]), which
  /// means any external signals, computed values, or reactive collections accessed
  /// within this builder will be automatically tracked. When these tracked dependencies
  /// change, the widget will automatically rebuild, just like [JoltBuilder].
  ///
  /// Example:
  /// ```dart
  /// final multiplier = Signal<int>(2);
  /// final computed = Computed(() => multiplier.value * 10);
  ///
  /// SurgeConsumer<CounterSurge, int>(
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

  /// Optional listener function for handling side effects.
  ///
  /// Parameters:
  /// - [context]: The build context
  /// - [state]: The current state value
  /// - [surge]: The Surge instance
  ///
  /// This function is called whenever the state changes and [listenWhen] returns true.
  /// It is executed within an [untracked] context to avoid creating reactive dependencies.
  ///
  /// Use this for side effects like showing SnackBars, sending analytics events,
  /// or navigating to other screens.
  final void Function(BuildContext context, S state, T surge)? listener;

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

  /// Optional condition function to control when to execute the listener.
  ///
  /// Parameters:
  /// - [prevState]: The previous state value
  /// - [newState]: The new state value
  /// - [surge]: The Surge instance
  ///
  /// Returns: true to execute listener, false to skip
  ///
  /// This function is tracked by default, meaning it can depend on external signals.
  /// If you need to use external signals without tracking them, wrap the access
  /// in [untracked].
  ///
  /// If not provided, the listener will execute on every state change.
  final bool Function(S prevState, S newState, T surge)? listenWhen;

  /// Optional Surge instance.
  ///
  /// If not provided, the Surge will be obtained from the widget tree using
  /// `context.read<T>()`. If provided, this specific instance will be used.
  final T? surge;

  @override
  Widget build(BuildContext context) {
    return SurgeListener.full(
      listener: listener,
      listenWhen: listenWhen,
      surge: surge,
      child: SurgeBuilder.full(
          builder: builder, buildWhen: buildWhen, surge: surge),
    );
  }
}
