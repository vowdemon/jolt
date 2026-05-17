import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';

import 'package:shared_interfaces/shared_interfaces.dart';

/// Interface for watchers that observe changes to reactive sources.
///
/// Watchers are similar to effects but provide more control over when they
/// trigger. They compare old and new values and only execute when values
/// actually change (or when a custom condition is met).
///
/// Example:
/// ```dart
/// Watcher<List<int>> watcher = Watcher(
///   () => [count.value, name.value],
///   (newValues, oldValues) => print('Changed'),
/// );
/// ```
abstract class Watcher<T> implements DisposableNode {
  /// {@macro jolt_watcher_impl}
  factory Watcher(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    bool immediately,
    WhenFn<T>? when,
    bool detach,
    JoltDebugOption? debug,
  }) = WatcherImpl<T>;

  /// {@macro jolt_watcher_impl.immediately}
  factory Watcher.immediately(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    bool detach,
    JoltDebugOption? debug,
  }) = WatcherImpl.immediately;

  /// {@macro jolt_watcher_impl.once}
  factory Watcher.once(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    bool detach,
    JoltDebugOption? debug,
  }) = WatcherImpl.once;

  @protected
  EffectNode get effect;

  /// The currently active watcher instance.
  ///
  /// This static field tracks the active watcher when its callback is executed
  /// within an untracked context. This allows [onEffectCleanup] to automatically
  /// detect the active watcher even when called within [untracked] blocks.
  ///
  /// This field is set before calling the watcher's callback function and
  /// restored afterwards to maintain the previous watcher context.
  static Watcher? activeWatcher;

  /// Manually runs the watcher function.
  ///
  /// This checks the sources and executes the callback if the condition is met.
  ///
  /// Example:
  /// ```dart
  /// watcher.trigger(); // Manually trigger check
  /// ```
  void trigger();

  /// Registers a cleanup function to be called when the watcher is disposed or re-run.
  ///
  /// Parameters:
  /// - [fn]: The cleanup function to register
  ///
  /// Example:
  /// ```dart
  /// watcher.onCleanup(() => subscription.cancel());
  /// ```
  void onCleanup(Disposer fn);

  /// Whether this watcher is currently paused.
  ///
  /// When a watcher is paused, it will not respond to changes in its watched
  /// sources. The watcher's dependencies are cleared when paused, and will be
  /// re-collected when resumed.
  ///
  /// Returns: `true` if the watcher is paused, `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// final watcher = Watcher(...);
  /// expect(watcher.isPaused, isFalse);
  ///
  /// watcher.pause();
  /// expect(watcher.isPaused, isTrue);
  ///
  /// watcher.resume();
  /// expect(watcher.isPaused, isFalse);
  /// ```
  bool get isPaused;

  /// Pauses the watcher, preventing it from responding to changes.
  ///
  /// When paused, the watcher will:
  /// - Stop responding to changes in watched sources
  /// - Clear its dependencies
  /// - Maintain its paused state until [resume] is called
  ///
  /// You can call [pause] multiple times; it is idempotent. After pausing,
  /// use [resume] to re-enable the watcher and re-collect dependencies.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(1);
  /// final values = <int>[];
  /// final watcher = Watcher(
  ///   () => signal.value,
  ///   (newValue, _) => values.add(newValue),
  /// );
  ///
  /// signal.value = 2; // Triggers
  /// expect(values, equals([2]));
  ///
  /// watcher.pause();
  /// signal.value = 3; // Does not trigger
  /// expect(values, equals([2]));
  ///
  /// watcher.resume();
  /// signal.value = 4; // Triggers again
  /// expect(values, equals([2, 4]));
  /// ```
  void pause();

  void resume();

  /// Temporarily ignores updates from the reactive sources during function execution.
  ///
  /// This method executes the given function while preventing the watcher's
  /// callback from being triggered by any changes that occur during execution.
  /// The reactive sources will still update normally, but the watcher's callback
  /// will not be executed for changes during the ignored period.
  ///
  /// **Behavior:**
  /// - Only prevents callback execution; ref changes and listener updates still occur
  /// - Does not update `prevValue` during the ignored period
  /// - Changes during ignore are treated as "never happened" for `oldValue` purposes,
  ///   but `newValue` will always reflect the latest state
  /// - Works correctly even when nested inside batches
  ///
  /// **Implementation note:** This method uses [batch] to delay side effects
  /// and restores flags to prevent new changes during ignore from triggering
  /// callbacks. If the previous flags required execution (e.g., had `dirty`),
  /// it will still execute after restore (preserves existing pending tasks).
  ///
  /// Parameters:
  /// - [fn]: The function to execute while ignoring updates
  ///
  /// Returns: The result of executing [fn]
  ///
  /// Type parameter:
  /// - [U]: The return type of [fn]
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(1);
  /// final values = <int>[];
  /// final watcher = Watcher(
  ///   () => signal.value,
  ///   (newValue, _) => values.add(newValue),
  /// );
  ///
  /// signal.value = 2; // Triggers
  /// expect(values, equals([2]));
  ///
  /// watcher.ignoreUpdates(() {
  ///   signal.value = 3; // Does not trigger callback
  /// });
  /// expect(values, equals([2]));
  /// expect(signal.value, equals(3)); // Value still updated
  ///
  /// signal.value = 4; // Triggers again
  /// expect(values, equals([2, 4]));
  /// ```
  ///
  /// Example with nested batch:
  /// ```dart
  /// batch(() {
  ///   signal.value = 5;
  ///   watcher.ignoreUpdates(() {
  ///     signal.value = 6;
  ///   });
  ///   signal.value = 7;
  /// });
  /// // Only the final value (7) triggers the callback
  /// ```
  U ignoreUpdates<U>(U Function() fn);

  @override
  bool get isDisposed;
}

/// Function type for providing source values to a watcher.
typedef SourcesFn<T> = T Function();

/// Function type for handling watcher value changes.
typedef WatcherFn<T> = void Function(T newValue, T? oldValue);

/// Function type for determining when a watcher should trigger.
typedef WhenFn<T> = bool Function(T newValue, T oldValue);
