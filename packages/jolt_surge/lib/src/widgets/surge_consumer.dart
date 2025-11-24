import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart';
import 'package:provider/provider.dart';

import '../surge.dart';

/// A unified widget that provides both builder and listener functionality.
///
/// SurgeConsumer provides fine-grained control over when to rebuild the UI
/// and when to execute side effects (listeners). It supports conditional
/// rebuilding and listening through [buildWhen] and [listenWhen] callbacks.
///
/// **Key Features:**
/// - **builder**: Builds the UI, default behavior is untracked (doesn't create
///   reactive dependencies), only rebuilds when [buildWhen] returns true
/// - **listener**: Handles side effects (like showing SnackBar, sending analytics
///   events, etc.), default behavior is untracked, only executes when [listenWhen]
///   returns true
/// - **buildWhen**: Controls whether to rebuild, default is tracked (can depend
///   on external signals)
/// - **listenWhen**: Controls whether to execute the listener, default is tracked
///   (can depend on external signals)
///
/// Example:
/// ```dart
/// SurgeConsumer<CounterSurge, int>(
///   buildWhen: (prev, next, s) => next.isEven, // Only rebuild when even
///   listenWhen: (prev, next, s) => next > prev, // Only listen when increasing
///   builder: (context, state, s) => Text('count: $state'),
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
class SurgeConsumer<T extends Surge<S>, S> extends StatefulWidget {
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
  State<StatefulWidget> createState() {
    return SurgeConsumerState<T, S>();
  }
}

class SurgeConsumerState<T extends Surge<S>, S>
    extends State<SurgeConsumer<T, S>> {
  SurgeConsumerState();

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
  void didUpdateWidget(SurgeConsumer<T, S> oldWidget) {
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
        (widget.listenWhen == null || widget.listener == null) &&
            widget.buildWhen == null;
    bool firstEffect = true;
    _effect = Effect(() {
      if (!mounted) return;

      final state = _surge.state;
      final listenerTriggable = widget.listener != null &&
          (widget.listenWhen?.call(_state, state, _surge) ?? true);
      final builderTriggable =
          widget.buildWhen?.call(_state, state, _surge) ?? true;

      if ((_state == state && allowNullSkip) || firstEffect) {
        firstEffect = false;
        return;
      }

      if (listenerTriggable) {
        untracked(() {
          widget.listener!(context, state, _surge);
        });
      }
      if (builderTriggable) {
        (context as StatefulElement).markNeedsBuild();
      }

      _state = state;
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
    return widget.builder(context, _state, _surge);
  }
}
