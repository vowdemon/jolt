import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

/// Implementation of [Effect] that automatically runs when its dependencies change.
///
/// This is the concrete implementation of the [Effect] interface. Effects are
/// side-effect functions that run in response to reactive state changes. They
/// automatically track their dependencies and re-run when any dependency changes.
///
/// See [Effect] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final count = Signal(0);
///
/// // Effect runs immediately and whenever count changes
/// final effect = Effect(() {
///   print('Count is: ${count.value}');
/// });
///
/// count.value = 1; // Prints: "Count is: 1"
/// count.value = 2; // Prints: "Count is: 2"
///
/// effect.dispose(); // Stop the effect
/// ```
class EffectImpl implements Effect {
  final EffectNode raw;

  /// {@template jolt_effect_impl}
  /// Creates a new effect with the given function.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [lazy]: Whether to defer running the effect on creation.
  ///   If `true`, the effect will NOT run immediately and will not track
  ///   dependencies until you call [run]. If `false` (default), the effect
  ///   runs immediately on creation and then automatically re-runs whenever
  ///   its reactive dependencies change.
  /// - [detach]: If true, the effect will not be bound to the current scope
  ///   and will not be disposed when the scope is disposed.
  /// - [debug]: Optional debug options
  ///
  /// The effect function will be called immediately upon creation (if [lazy] is false)
  /// and then automatically whenever any of its reactive dependencies change.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  ///
  /// // Effect runs immediately and whenever signal changes
  /// final effect = Effect(() {
  ///   print('Signal value: ${signal.value}');
  /// }, lazy: false);
  ///
  /// // Effect does not run until manually triggered
  /// final delayedEffect = Effect(() {
  ///   print('Signal value: ${signal.value}');
  /// }, lazy: true);
  ///
  /// signal.value = 1; // Only the immediate effect runs
  /// ```
  /// {@endtemplate}
  EffectImpl(this.fn,
      {bool lazy = false, bool detach = false, JoltDebugOption? debug})
      : raw = EffectNode(fn, lazy: lazy, detach: detach, debug: debug);

  EffectImpl.custom(this.fn, {required EffectNode node}) : raw = node;

  /// {@template jolt_effect_impl.lazy}
  /// Creates a new effect that does not run automatically upon creation.
  ///
  /// This factory method is a convenience constructor for creating an effect
  /// with [lazy] set to `true`. The effect will not execute until you call
  /// [run]. After the first manual run, it will track dependencies and re-run
  /// when they change.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [detach]: If true, the effect will not be bound to the current scope
  /// - [debug]: Optional debug options
  ///
  /// Returns: A new [Effect] instance that starts in deferred mode
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(10);
  /// final values = <int>[];
  ///
  /// Effect.lazy(() {
  ///   values.add(signal.value);
  /// });
  ///
  /// // Effect has not run yet
  /// expect(values, isEmpty);
  ///
  /// effect.run(); // Start tracking and run once
  /// expect(values, equals([10]));
  ///
  /// signal.value = 20; // Effect runs again after tracking starts
  /// expect(values, equals([10, 20]));
  /// ```
  /// {@endtemplate}
  factory EffectImpl.lazy(void Function() fn,
      {bool detach = false, JoltDebugOption? debug}) {
    return EffectImpl(fn, lazy: true, detach: detach, debug: debug);
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")

  /// The function that defines the effect's behavior.
  @protected
  final void Function() fn;

  /// Manually runs the effect function.
  ///
  /// This establishes the effect as the current reactive context,
  /// allowing it to track dependencies accessed during execution.
  ///
  /// Example:
  /// ```dart
  /// final effect = Effect(() => print('Hello'), lazy: false);
  /// effect.run(); // Prints: "Hello"
  /// ```
  @override
  void run() {
    assert(
      raw.flags != ReactiveFlags.none,
      'Cannot call run() on a disposed $runtimeType',
    );
    if (raw.flags != ReactiveFlags.none) {
      raw.flags |= ReactiveFlags.dirty;
    }
    raw.run();
  }

  @override
  void dispose() => raw.dispose();

  @override
  void onCleanup(Disposer fn) => raw.onCleanup(fn);

  @override
  bool get isDisposed => raw.isDisposed;

  T track<T>(T Function() fn, [bool purge = true]) => raw.track(fn, purge);
}

/// Registers a cleanup function to be executed when the current effect is disposed or re-run.
///
/// Parameters:
/// - [fn]: The cleanup function to register
/// - [owner]: Optional effect owner. If not provided, automatically detects the current
///   active effect from the reactive context or the active watcher.
///
/// This function can only be called within an effect or watcher context. The cleanup
/// function will be executed before the effect re-runs or when the effect is disposed.
///
/// Example:
/// ```dart
/// Effect(() {
///   final timer = Timer.periodic(Duration(seconds: 1), (_) {});
///   onEffectCleanup(() => timer.cancel());
/// });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void onEffectCleanup(Disposer fn, {Object? owner}) {
  final e = owner ?? Watcher.activeWatcher ?? getActiveSub();
  assert(e is Effect || e is Watcher || e is EffectNode,
      "Cannot add cleanup on a non-effect or non-watcher");
  if (e is EffectNode) {
    e.onCleanup(fn);
  } else if (e is Watcher) {
    e.onCleanup(fn);
  } else if (e is Effect) {
    e.onCleanup(fn);
  }
}
