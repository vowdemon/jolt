import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

class WatcherImpl<T> implements Watcher<T> {
  late final EffectNode raw;

  WatcherImpl(this.sourcesFn, this.fn,
      {bool immediately = false,
      this.when,
      bool detach = false,
      JoltDebugOption? debug}) {
    raw = EffectNode(_effectFn, lazy: true, detach: detach, debug: debug);

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

  factory WatcherImpl.immediately(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, bool detach = false, JoltDebugOption? debug}) {
    return WatcherImpl(sourcesFn, fn,
        immediately: true, when: when, detach: detach, debug: debug);
  }

  factory WatcherImpl.once(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, bool detach = false, JoltDebugOption? debug}) {
    late WatcherImpl<T> watcher;

    watcher = WatcherImpl(sourcesFn, (newValue, oldValue) {
      fn(newValue, oldValue);
      watcher.dispose();
    }, when: when, immediately: false, detach: detach, debug: debug);

    return watcher;
  }

  /// The callback that returns the value or snapshot watched by this watcher.
  late SourcesFn<T> sourcesFn;

  /// The callback that runs when this watcher reports a visible change.
  late WatcherFn<T> fn;

  /// The optional predicate that decides whether this watcher should trigger.
  late WhenFn<T>? when;

  /// The latest source value snapshot cached by this watcher.
  late T currentValues;

  /// The previous source value snapshot used for comparisons.
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
        assert(() {
          JoltDevTools.effect(raw);
          return true;
        }());
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
