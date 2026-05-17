import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

/// Implementation of [Watcher] that observes changes to reactive sources and executes a callback.
///
/// This is the concrete implementation of the [Watcher] interface. Watchers are
/// similar to effects but provide more control over when they trigger. They compare
/// old and new values and only execute when values actually change (or when a
/// custom condition is met).
///
/// See [Watcher] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// final name = Signal('Alice');
///
/// final watcher = Watcher(
///   () => [count.value, name.value], // Sources to watch
///   (newValues, oldValues) {
///     print('Count: ${newValues[0]}, Name: ${newValues[1]}');
///   },
/// );
///
/// count.value = 1; // Triggers watcher
/// name.value = 'Bob'; // Triggers watcher
/// ```
class WatcherImpl<T> implements Watcher<T> {
  late final EffectNode raw;

  /// {@template jolt_watcher_impl}
  /// Creates a new watcher with the given sources and callback.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [immediately]: Whether to execute the callback immediately
  /// - [when]: Optional condition function for custom trigger logic
  /// - [detach]: Whether to detach this watcher from the current effect scope.
  ///   If true, the watcher will not be automatically disposed when its parent
  ///   scope is disposed.
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  ///
  /// final watcher = Watcher(
  ///   () => signal.value,
  ///   (newValue, oldValue) => print('Changed: $oldValue -> $newValue'),
  ///   immediately: true,
  ///   when: (newValue, oldValue) => newValue > oldValue, // Only when increasing
  /// );
  /// ```
  /// {@endtemplate}
  WatcherImpl(this.sourcesFn, this.fn,
      {bool immediately = false,
      this.when,
      bool detach = false,
      JoltDebugOption? debug}) {
    raw = EffectNode(_effectFn, lazy: true, detach: detach);
    // assert(() {
    //   JoltDebug.create(this, debug);
    //   return true;
    // }());

    previosValues = currentValues = raw.track(sourcesFn);
    if (immediately) {
      untracked(() {
        final prevWatcher = Watcher.activeWatcher;
        Watcher.activeWatcher = this;
        try {
          fn(currentValues, null);
        } finally {
          Watcher.activeWatcher = prevWatcher;
        }
      });
    }
  }

  /// {@template jolt_watcher_impl.immediately}
  /// Creates a watcher that executes the callback immediately upon creation.
  ///
  /// This factory method is a convenience constructor for creating a watcher
  /// with [immediately] set to `true`. The callback will be executed once
  /// immediately with the current source values, and then whenever the sources
  /// change and the condition (if provided) is met.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [when]: Optional condition function for custom trigger logic
  /// - [detach]: Whether to detach this watcher from the current effect scope
  /// - [debug]: Optional debug options
  ///
  /// Returns: A new [Watcher] instance that executes immediately
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(10);
  /// final values = <int>[];
  ///
  /// Watcher.immediately(
  ///   () => signal.value,
  ///   (newValue, oldValue) {
  ///     values.add(newValue);
  ///   },
  /// );
  ///
  /// // Callback executed immediately with value 10
  /// expect(values, equals([10]));
  ///
  /// signal.value = 20; // Triggers callback again
  /// expect(values, equals([10, 20]));
  /// ```
  /// {@endtemplate}
  factory WatcherImpl.immediately(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, bool detach = false, JoltDebugOption? debug}) {
    return WatcherImpl(sourcesFn, fn,
        immediately: true, when: when, detach: detach, debug: debug);
  }

  /// {@template jolt_watcher_impl.once}
  /// Creates a watcher that executes once and then automatically disposes itself.
  ///
  /// This factory method creates a watcher that will execute its callback
  /// on the first change after creation, and then automatically dispose itself.
  /// The watcher will not respond to changes before the first trigger, and
  /// will not respond to any changes after disposal.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed on first change
  /// - [when]: Optional condition function for custom trigger logic
  /// - [detach]: Whether to detach this watcher from the current effect scope
  /// - [debug]: Optional debug options
  ///
  /// Returns: A new [Watcher] instance that auto-disposes after first execution
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(1);
  /// final values = <int>[];
  ///
  /// final watcher = Watcher.once(
  ///   () => signal.value,
  ///   (newValue, _) {
  ///     values.add(newValue);
  ///   },
  /// );
  ///
  /// expect(values, isEmpty);
  /// expect(watcher.isDisposed, isFalse);
  ///
  /// signal.value = 2; // Triggers and disposes
  /// expect(values, equals([2]));
  /// expect(watcher.isDisposed, isTrue);
  ///
  /// signal.value = 3; // No longer responds
  /// expect(values, equals([2]));
  /// ```
  /// {@endtemplate}
  factory WatcherImpl.once(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, bool detach = false, JoltDebugOption? debug}) {
    late WatcherImpl<T> watcher;

    watcher = WatcherImpl(sourcesFn, (newValue, oldValue) {
      fn(newValue, oldValue);
      watcher.dispose();
    }, when: when, immediately: false, detach: detach, debug: debug);

    return watcher;
  }

  /// Function that provides the source values to watch.
  late SourcesFn<T> sourcesFn;

  /// Callback function executed when sources change.
  late WatcherFn<T> fn;

  /// Optional condition function for custom trigger logic.
  late WhenFn<T>? when;

  /// The previous source values for comparison.
  late T currentValues;

  late T previosValues;

  @visibleForTesting
  T get testCachedSources => currentValues;

  void _effectFn() {
    previosValues = currentValues;
    currentValues = sourcesFn();

    if (_isPaused) {
      return;
    }

    final shouldTrigger = when == null
        ? currentValues != previosValues
        : when!(currentValues, previosValues);

    if (shouldTrigger) {
      trigger();
    }
  }

  @override
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  void trigger() {
    untracked(() {
      final prevWatcher = Watcher.activeWatcher;
      Watcher.activeWatcher = this;
      try {
        fn(currentValues, previosValues);
      } finally {
        Watcher.activeWatcher = prevWatcher;
      }
    });
  }

  @override
  void dispose() => raw.dispose();

  bool _isPaused = false;
  @override
  bool get isPaused => _isPaused;

  @override
  void pause() {
    _isPaused = true;
    cycle++;
    raw.depsTail = null;
    purgeDeps(raw);
    raw.flags = ReactiveFlags.watching;
  }

  @override
  void resume() {
    _isPaused = false;

    raw.track(_effectFn);
  }

  @override
  U ignoreUpdates<U>(U Function() fn) {
    return batch(() {
      int prevFlags = raw.flags;
      try {
        return fn();
      } finally {
        raw.flags = prevFlags;
      }
    });
  }

  @override
  void onCleanup(Disposer fn) => raw.onCleanup(fn);

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  EffectNode get effect => raw;
}
