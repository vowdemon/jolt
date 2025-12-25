import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

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
class FlutterEffectImpl extends EffectReactiveNode
    with DisposableNodeMixin, EffectCleanupMixin
    implements FlutterEffect, EffectScheduler {
  /// {@template flutter_effect_impl}
  /// Creates a new Flutter effect with the given function.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [lazy]: Whether to run the effect immediately upon creation.
  ///   If `true`, the effect will execute once immediately when created,
  ///   then automatically re-run whenever its reactive dependencies change.
  ///   If `false` (default), the effect will only run when dependencies change,
  ///   not immediately upon creation.
  /// - [onDebug]: Optional debug callback for reactive system debugging
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
  FlutterEffectImpl(this.fn, {bool lazy = false, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck) {
    JoltDebug.create(this, onDebug);

    final prevSub = getActiveSub();
    if (prevSub != null) {
      link(this, prevSub, 0);
    }

    if (!lazy) {
      final prevSub = setActiveSub(this);
      try {
        _effectFn();
      } finally {
        setActiveSub(prevSub);
        flags &= ~ReactiveFlags.recursedCheck;
      }
    } else {
      flags &= ~ReactiveFlags.recursedCheck;
    }
  }

  /// {@template flutter_effect_impl.lazy}
  /// Creates a new Flutter effect that runs immediately upon creation.
  ///
  /// This factory method is a convenience constructor for creating an effect
  /// with [lazy] set to `true`. The effect will execute once immediately when
  /// created, then automatically re-run at the end of frames whenever its
  /// reactive dependencies change.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A new [FlutterEffect] instance that executes immediately
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
  /// // Effect executed immediately with value 10
  /// expect(values, equals([10]));
  ///
  /// signal.value = 20; // Effect schedules for end of frame
  /// ```
  /// {@endtemplate}
  factory FlutterEffectImpl.lazy(void Function() fn, {JoltDebugFn? onDebug}) {
    return FlutterEffectImpl(fn, lazy: true, onDebug: onDebug);
  }

  /// The function that defines the effect's behavior.
  @protected
  final void Function() fn;

  /// Whether a frame-end schedule is pending.
  bool _isScheduled = false;

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  void _effectFn() {
    doCleanup();
    wrappedFn();
    JoltDebug.effect(this);
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @protected
  void wrappedFn() => fn();

  /// Schedules this effect to run at the end of the current Flutter frame.
  ///
  /// This method implements the [EffectScheduler] interface, allowing custom
  /// scheduling behavior. Multiple calls within the same frame will only
  /// result in a single execution at frame end (batch processing).
  ///
  /// Returns: `true` to indicate custom scheduling was handled
  @override
  bool schedule() {
    // If already scheduled for this frame, skip
    if (_isScheduled) {
      return true;
    }

    // Mark as scheduled
    _isScheduled = true;

    // Schedule for end of frame
    SchedulerBinding.instance.endOfFrame.then((_) {
      _isScheduled = false;
      _executeEffect();
    });

    return true;
  }

  /// Executes the effect function.
  ///
  /// This is called at the end of the frame after scheduling.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  void _executeEffect() {
    if (isDisposed) return;

    // Mark as dirty to trigger execution
    flags |= ReactiveFlags.dirty;
    runEffect();
  }

  /// Manually runs the effect function immediately, bypassing frame scheduling.
  ///
  /// This establishes the effect as the current reactive context,
  /// allowing it to track dependencies accessed during execution.
  ///
  /// Example:
  /// ```dart
  /// final effect = FlutterEffect(() => print('Hello'), lazy: false);
  /// effect.run(); // Prints: "Hello" immediately
  /// ```
  @override
  void run() {
    assert(!isDisposed, "FlutterEffect is disposed");
    flags |= ReactiveFlags.dirty;
    runEffect();
  }

  @override
  @protected
  void onDispose() {
    _isScheduled = true;
    doCleanup();
    disposeNode(this);
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  @protected
  void runEffect() {
    // Clear the scheduled flag when effect runs
    _isScheduled = false;
    defaultRunEffect(this, _effectFn);
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
abstract class FlutterEffect implements EffectNode {
  /// {@macro flutter_effect_impl}
  factory FlutterEffect(
    void Function() fn, {
    bool lazy,
    JoltDebugFn? onDebug,
  }) = FlutterEffectImpl;

  /// {@macro flutter_effect_impl.lazy}
  factory FlutterEffect.lazy(void Function() fn, {JoltDebugFn? onDebug}) =
      FlutterEffectImpl.lazy;

  /// Manually runs the effect function immediately, bypassing frame scheduling.
  ///
  /// This establishes the effect as the current reactive context,
  /// allowing it to track dependencies accessed during execution.
  ///
  /// Example:
  /// ```dart
  /// effect.run(); // Triggers the effect immediately
  /// ```
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
  void onCleanUp(Disposer fn);
}
