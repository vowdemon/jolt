import 'package:flutter/scheduler.dart';
import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

class _FlutterEffectNode extends EffectNode {
  _FlutterEffectNode(super.fn, {super.lazy, super.detach, super.debug});

  bool _isScheduled = false;

  @override
  void notifyEffect() {
    // If already scheduled for this frame, skip
    if (_isScheduled) {
      return;
    }

    // Mark as scheduled
    _isScheduled = true;

    // Schedule for end of frame
    SchedulerBinding.instance.endOfFrame.then((_) {
      _isScheduled = false;
      run();
    });
  }
}

/// Implementation of [FlutterEffect] that schedules execution at the end of the current Flutter frame.
///
/// This effect batches multiple triggers within the same frame and executes only once
/// at the end of the frame, avoiding unnecessary repeated executions during frame rendering.
///
/// Example:
/// ```dart
/// final count = Signal(0);
///
/// // Effect runs once at end of frame, even if count changes multiple times
/// final effect = FlutterEffect(() {
///   print('Count is: ${count.value}');
/// });
///
/// count.value = 1;
/// count.value = 2;
/// count.value = 3;
/// // Effect executes once at end of frame with count.value = 3
/// ```
class FlutterEffectImpl extends EffectImpl implements FlutterEffect {
  /// {@template flutter_effect_impl}
  /// Creates a new Flutter effect with the given function.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [lazy]: Whether to defer running the effect on creation.
  ///   If `true`, the effect will NOT run immediately and will not track
  ///   dependencies until you call [run]. If `false` (default), the effect
  ///   runs immediately on creation and then re-runs at frame end whenever
  ///   its reactive dependencies change.
  /// - [detach]: Whether to detach this effect from the current effect scope.
  ///   If true, the effect will not be automatically disposed when its parent
  ///   scope is disposed.
  /// - [debug]: Optional debug options
  ///
  /// The effect function will be called at the end of the current Flutter frame,
  /// batching multiple triggers within the same frame into a single execution.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  ///
  /// // Effect runs at end of frame when signal changes
  /// final effect = FlutterEffect(() {
  ///   print('Signal value: ${signal.value}');
  /// });
  ///
  /// signal.value = 1;
  /// signal.value = 2;
  /// // Effect executes once at end of frame with signal.value = 2
  /// ```
  /// {@endtemplate}
  FlutterEffectImpl(super.fn,
      {bool lazy = false, bool detach = false, JoltDebugOption? debug})
      : super.custom(
            node: _FlutterEffectNode(fn,
                lazy: lazy, detach: detach, debug: debug));

  /// {@template flutter_effect_impl.lazy}
  /// Creates a new Flutter effect that does not run automatically upon creation.
  ///
  /// This factory method is a convenience constructor for creating an effect
  /// with [lazy] set to `true`. The effect will not execute until you call
  /// [run]. After the first manual run, it will track dependencies and re-run
  /// at the end of frames whenever those dependencies change.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [detach]: Whether to detach this effect from the current effect scope
  /// - [debug]: Optional debug options
  ///
  /// Returns: A new [FlutterEffect] instance that starts in deferred mode
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(10);
  /// final values = <int>[];
  ///
  /// FlutterEffect.lazy(() {
  ///   values.add(signal.value);
  /// });
  ///
  /// // Effect has not run yet
  /// expect(values, isEmpty);
  ///
  /// effect.run(); // Start tracking and run once
  /// expect(values, equals([10]));
  ///
  /// signal.value = 20; // Effect schedules for end of frame
  /// ```
  /// {@endtemplate}
  factory FlutterEffectImpl.lazy(void Function() fn,
      {bool detach = false, JoltDebugOption? debug}) {
    return FlutterEffectImpl(fn, lazy: true, detach: detach, debug: debug);
  }
}

/// Interface for Flutter effects that schedule execution at frame end.
///
/// FlutterEffect is similar to [Effect] but schedules execution at the end of
/// the current Flutter frame, batching multiple triggers within the same frame
/// into a single execution. This is useful for UI-related side effects that
/// should not interfere with frame rendering.
///
/// Example:
/// ```dart
/// FlutterEffect effect = FlutterEffect(() {
///   print('Count: ${count.value}');
/// });
/// effect.run(); // Manually trigger
/// effect.dispose(); // Stop the effect
/// ```
abstract class FlutterEffect implements Effect {
  /// {@macro flutter_effect_impl}
  factory FlutterEffect(
    void Function() fn, {
    bool lazy,
    bool detach,
    JoltDebugOption? debug,
  }) = FlutterEffectImpl;

  /// {@macro flutter_effect_impl.lazy}
  factory FlutterEffect.lazy(void Function() fn,
      {bool detach, JoltDebugOption? debug}) = FlutterEffectImpl.lazy;

  /// Manually runs the effect function immediately, bypassing frame scheduling.
  ///
  /// This establishes the effect as the current reactive context,
  /// allowing it to track dependencies accessed during execution.
  ///
  /// Example:
  /// ```dart
  /// effect.run(); // Triggers the effect immediately
  /// ```
  @override
  void run();

  /// Registers a cleanup function to be called when the effect is disposed or re-run.
  ///
  /// Parameters:
  /// - [fn]: The cleanup function to register
  ///
  /// Example:
  /// ```dart
  /// effect.onCleanUp(() => subscription.cancel());
  /// ```
  @override
  void onCleanup(Disposer fn);
}
