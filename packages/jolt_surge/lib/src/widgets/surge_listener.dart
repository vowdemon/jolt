import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

import '../surge.dart';
import 'surge_consumer.dart';

/// A widget that listens to Surge state changes for side effects.
///
/// SurgeListener is a [StatefulWidget] that executes side effects when the
/// Surge state changes, without rebuilding its child widget. It uses an
/// [Effect] internally to track state changes.
///
/// **Key Implementation Details:**
/// - Uses [Effect] (not FlutterEffect) to track state changes
/// - The [listener] is executed within an [untracked] context to avoid creating
///   reactive dependencies
/// - [listenWhen] is called within the effect and is tracked by default
/// - First effect execution is skipped to avoid unnecessary initial listener call
/// - If state hasn't changed and [listenWhen] is null and [listener] is null,
///   the listener execution is skipped
/// - Even though the child doesn't rebuild, `markNeedsBuild()` is called to
///   update internal state tracking
/// - When [surge] is null, uses `context.select` to ensure updates when the
///   Provider instance changes
///
/// Example:
/// ```dart
/// SurgeListener<CounterSurge, int>(
///   listenWhen: (prev, next, s) => next > prev, // Only listen when increasing
///   listener: (context, state, surge) {
///     // Only handle side effects, doesn't build UI
///     print('Count increased to: $state');
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(content: Text('Count is now: $state')),
///     );
///   },
///   child: const SizedBox.shrink(),
/// );
/// ```
///
/// See also:
/// - [SurgeConsumer] for both builder and listener functionality
/// - [SurgeBuilder] for builder-only functionality
/// - [SurgeSelector] for fine-grained rebuild control with selector
class SurgeListener<T extends Surge<S>, S> extends StatefulWidget {
  /// Creates a SurgeListener widget with full access to the Surge instance.
  ///
  /// This is the full-featured constructor that provides access to the Surge
  /// instance in the listener and listenWhen callbacks.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [child]: The child widget to display (not rebuilt by this widget)
  /// - [listener]: The listener function for side effects.
  ///   Receives `(context, state, surge)` parameters.
  ///   Executed within an [untracked] context.
  /// - [listenWhen]: Optional condition function to control when to execute listener.
  ///   Receives `(prevState, newState, surge)` parameters.
  ///   Returns true to execute, false to skip. Defaults to always executing.
  ///   This function is tracked by default (can depend on external signals).
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from
  ///   context using `context.read<T>()`
  ///
  /// The [listenWhen] function is tracked by default, meaning it can depend on
  /// external signals. If you need to use external signals without tracking them,
  /// wrap the access in [untracked]:
  ///
  /// ```dart
  /// SurgeListener<CounterSurge, int>.full(
  ///   listenWhen: (prev, next, s) => untracked(() => shouldListenSignal.value),
  ///   listener: (context, state, surge) { /* ... */ },
  ///   child: const SizedBox.shrink(),
  /// );
  /// ```
  const SurgeListener.full({
    super.key,
    required this.child,
    required this.listener,
    this.listenWhen,
    this.surge,
  });

  /// Creates a SurgeListener widget with Cubit-compatible API.
  ///
  /// This factory constructor provides a 100% compatible API with `BlocListener`
  /// from the `flutter_bloc` package, making it easy to migrate from Bloc/Cubit
  /// to Surge. The listener and listenWhen functions do not receive the Surge
  /// instance, matching the Cubit API exactly.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [child]: The child widget to display (not rebuilt by this widget)
  /// - [listener]: The listener function for side effects.
  ///   Receives `(context, state)` parameters (no Surge instance).
  ///   Executed within an [untracked] context.
  /// - [surge]: Optional Surge instance. If not provided, will be obtained from
  ///   context using `context.read<T>()`
  /// - [listenWhen]: Optional condition function to control when to execute listener.
  ///   Receives `(prevState, newState)` parameters (no Surge instance).
  ///   Returns true to execute, false to skip. Defaults to always executing.
  ///
  /// Example:
  /// ```dart
  /// // Cubit-compatible usage (same as BlocListener)
  /// SurgeListener<CounterSurge, int>(
  ///   listenWhen: (prev, next) => next > prev, // Only listen when increasing
  ///   listener: (context, state) {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       SnackBar(content: Text('Count is now: $state')),
  ///     );
  ///   },
  ///   child: const SizedBox.shrink(),
  /// );
  /// ```
  ///
  /// See also:
  /// - [SurgeListener.full] for access to the Surge instance in callbacks
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

  /// The child widget to display.
  ///
  /// This widget is not rebuilt by SurgeListener. It is simply passed through
  /// and returned as-is. The listener executes side effects when state changes,
  /// but does not affect the child widget's rebuild cycle.
  final Widget child;

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
    return widget.child;
  }
}
