import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';

import 'package:shared_interfaces/shared_interfaces.dart';

/// Observes source values and runs a callback when their visible result changes.
///
/// Use [Watcher] when you need both the new and previous values, custom
/// triggering rules, or lifecycle controls such as pause and resume.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// final name = Signal('Alice');
///
/// final watcher = Watcher<List<int>>(
///   () => [count.value, name.value],
///   (newValues, oldValues) => print('$oldValues -> $newValues'),
/// );
/// ```
abstract class Watcher<T> implements DisposableNode {
  /// Creates a watcher from [sourcesFn] and [fn].
  ///
  /// The [sourcesFn] callback returns the snapshot compared between runs. The
  /// [fn] callback runs when this watcher decides that a visible change
  /// occurred. Set [immediately] to invoke [fn] once right after construction.
  /// The optional [when] predicate replaces the default `!=` comparison. Set
  /// [detach] to keep this watcher out of the current [EffectScope].
  factory Watcher(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    bool immediately,
    WhenFn<T>? when,
    bool detach,
    JoltDebugOption? debug,
  }) = WatcherImpl<T>;

  /// Creates a watcher that invokes [fn] immediately after construction.
  ///
  /// The [sourcesFn] callback returns the snapshot compared between runs. After
  /// the immediate call, [fn] runs again only for later qualifying
  /// transitions. The optional [when] predicate replaces the default `!=`
  /// comparison. Set [detach] to keep this watcher out of the current
  /// [EffectScope].
  factory Watcher.immediately(
    SourcesFn<T> sourcesFn,
    WatcherFn<T> fn, {
    WhenFn<T>? when,
    bool detach,
    JoltDebugOption? debug,
  }) = WatcherImpl.immediately;

  /// Creates a watcher that disposes itself after the first callback run.
  ///
  /// The [sourcesFn] callback returns the snapshot compared between runs. The
  /// [fn] callback runs for the first qualifying transition before this
  /// watcher disposes itself. The optional [when] predicate replaces the
  /// default `!=` comparison. Set [detach] to keep this watcher out of the
  /// current [EffectScope].
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

  /// Re-runs the watcher callback with the current cached values.
  ///
  /// Example:
  /// ```dart
  /// watcher.trigger(); // Manually trigger check
  /// ```
  void trigger();

  /// Registers a cleanup callback for this watcher.
  ///
  /// The [fn] callback runs before this watcher re-runs and when this watcher
  /// disposes.
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
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  /// final watcher = Watcher(() => signal.value, (_, __) {});
  /// expect(watcher.isPaused, isFalse);
  ///
  /// watcher.pause();
  /// expect(watcher.isPaused, isTrue);
  ///
  /// watcher.resume();
  /// expect(watcher.isPaused, isFalse);
  /// ```
  bool get isPaused;

  /// Pauses the watcher and clears its current dependency list.
  ///
  /// Changes that happen while paused do not invoke the callback. The next call
  /// to [resume] re-collects dependencies and can replay the latest source value.
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

  /// Resumes the watcher and immediately re-collects its dependencies.
  ///
  /// If the watched source changed while paused, resuming can invoke the
  /// callback once with the latest visible value.
  ///
  /// Example:
  /// ```dart
  /// watcher.pause();
  /// signal.value = 2;
  /// watcher.resume();
  /// ```
  void resume();

  /// Runs [fn] while suppressing watcher callbacks caused by its updates.
  ///
  /// Source values still change normally, but the watcher keeps the previous
  /// visible state for the next callback. This is useful when applying internal
  /// writes that should not count as observable watcher transitions.
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
  U ignoreUpdates<U>(U Function() fn);

  @override
  bool get isDisposed;
}

/// Returns the source value snapshot tracked by a [Watcher].
///
/// The returned value is compared between runs and passed to the watcher
/// callback when the watcher triggers.
typedef SourcesFn<T> = T Function();

/// A change callback for [Watcher].
///
/// The [newValue] argument is the latest value returned by the source
/// function. The [oldValue] argument is the previous visible value, or `null`
/// for the immediate first callback from [Watcher.immediately].
typedef WatcherFn<T> = void Function(T newValue, T? oldValue);

/// A predicate that decides whether a [Watcher] should notify.
///
/// The [newValue] and [oldValue] arguments describe the candidate transition.
typedef WhenFn<T> = bool Function(T newValue, T oldValue);
