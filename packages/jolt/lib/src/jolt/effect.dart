import "package:meta/meta.dart";
import "package:shared_interfaces/shared_interfaces.dart";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

@protected
mixin EffectCleanupMixin {
  bool get isDisposed;

  @protected
  late final List<Disposer> _cleanups = [];

  /// Registers a cleanup function to be called when this effect is disposed or re-run.
  ///
  /// Parameters:
  /// - [fn]: The cleanup function to register
  ///
  /// Cleanup functions are executed in the order they were registered, either
  /// when the effect is disposed or before the effect function is re-run.
  ///
  /// Example:
  /// ```dart
  /// final effect = Effect(() {
  ///   final subscription = someStream.listen((data) {});
  ///   onEffectCleanup(() => subscription.cancel());
  /// });
  /// ```
  void onCleanUp(Disposer fn) {
    assert(!isDisposed, "$runtimeType is disposed");

    _cleanups.add(fn);
  }

  /// Executes all registered cleanup functions and clears the cleanup list.
  ///
  /// This method is called automatically when the effect is disposed or
  /// before the effect function is re-run. Cleanup functions are executed
  /// in the order they were registered.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @protected
  void doCleanup() {
    if (_cleanups.isEmpty) return;
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
  }
}

/// Implementation of [EffectScope] for managing the lifecycle of effects and other reactive nodes.
///
/// This is the concrete implementation of the [EffectScope] interface. EffectScope
/// allows you to group related effects together and dispose them all at once.
/// It's useful for component-based architectures where you want to clean up
/// all effects when a component is destroyed.
///
/// See [EffectScope] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final scope = EffectScope()
///   ..run(() {
///     final signal = Signal(0);
///     Effect(() => print('Value: ${signal.value}'));
///
///     // Both signal and effect will be disposed when scope is disposed
///   });
///
/// // Later, dispose all effects in the scope
/// scope.dispose();
/// ```
class EffectScopeImpl extends EffectScopeReactiveNode
    with DisposableNodeMixin, EffectCleanupMixin
    implements EffectScope {
  /// Creates a new effect scope.
  ///
  /// Parameters:
  /// - [detach]: Whether to detach this scope from its parent scope. If true,
  ///   the scope will not be automatically disposed when its parent is disposed.
  ///   Defaults to false.
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// The scope is automatically linked to its parent scope (if any) unless
  /// [detach] is true. Use [run] to execute code within the scope context.
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope()
  ///   ..run(() {
  ///     final signal = Signal(0);
  ///     Effect(() => print(signal.value));
  ///
  ///     // Register cleanup function
  ///     onScopeDispose(() => print('Scope disposed'));
  ///   });
  /// ```
  EffectScopeImpl({bool? detach, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.none) {
    JoltDebug.create(this, onDebug);
    if (!(detach ?? false)) {
      final prevSub = getActiveSub();
      if (prevSub != null) {
        link(this, prevSub, 0);
      }
    }
  }

  /// Runs a function within this scope's context.
  ///
  /// Parameters:
  /// - [fn]: Function to execute within the scope
  ///
  /// Returns: The result of the function execution
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope();
  ///
  /// final result = scope.run(() {
  ///   final signal = Signal(42);
  ///   return signal.value;
  /// });
  /// ```
  @override
  T run<T>(T Function() fn) {
    final prevSub = setActiveSub(this);
    final prevScope = setActiveScope(this);
    try {
      final result = fn();

      JoltDebug.effect(this);

      return result;
    } finally {
      setActiveScope(prevScope);
      setActiveSub(prevSub);
    }
  }

  @override
  @protected
  void onDispose() {
    doCleanup();
    disposeNode(this);
  }
}

/// Interface for effect scopes that manage the lifecycle of effects.
///
/// EffectScope allows you to group related effects together and dispose
/// them all at once. It's useful for component-based architectures.
///
/// Example:
/// ```dart
/// EffectScope scope = EffectScope()
///   ..run(() {
///     final signal = Signal(0);
///     Effect(() => print(signal.value));
///   });
/// scope.dispose(); // Disposes all effects in scope
/// ```
abstract class EffectScope implements EffectNode {
  /// Creates a new effect scope.
  ///
  /// Parameters:
  /// - [detach]: Whether to detach this scope from its parent scope
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope(detach: true);
  /// ```
  factory EffectScope({bool? detach, JoltDebugFn? onDebug}) = EffectScopeImpl;

  /// Runs a function within this scope's context.
  ///
  /// Parameters:
  /// - [fn]: Function to execute within the scope
  ///
  /// Returns: The result of the function execution
  ///
  /// Example:
  /// ```dart
  /// final result = scope.run(() => 42);
  /// ```
  T run<T>(T Function() fn);

  /// Registers a cleanup function to be called when the scope is disposed.
  ///
  /// Parameters:
  /// - [fn]: The cleanup function to register
  ///
  /// Example:
  /// ```dart
  /// scope.onCleanUp(() => print('Scope disposed'));
  /// ```
  void onCleanUp(Disposer fn);
}

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
class EffectImpl extends EffectReactiveNode
    with DisposableNodeMixin, EffectCleanupMixin
    implements Effect {
  /// {@template jolt_effect_impl}
  /// Creates a new effect with the given function.
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
  /// The effect function will be called immediately upon creation (if [lazy] is true)
  /// and then automatically whenever any of its reactive dependencies change.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  ///
  /// // Effect runs immediately and whenever signal changes
  /// final effect = Effect(() {
  ///   print('Signal value: ${signal.value}');
  /// }, lazy: true);
  ///
  /// // Effect only runs when signal changes (not immediately)
  /// final delayedEffect = Effect(() {
  ///   print('Signal value: ${signal.value}');
  /// }, lazy: false);
  ///
  /// signal.value = 1; // Both effects run
  /// ```
  /// {@endtemplate}
  EffectImpl(this.fn, {bool lazy = false, JoltDebugFn? onDebug})
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

  /// {@template jolt_effect_impl.lazy}
  /// Creates a new effect that runs immediately upon creation.
  ///
  /// This factory method is a convenience constructor for creating an effect
  /// with [lazy] set to `true`. The effect will execute once immediately when
  /// created, then automatically re-run whenever its reactive dependencies change.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Returns: A new [Effect] instance that executes immediately
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
  /// // Effect executed immediately with value 10
  /// expect(values, equals([10]));
  ///
  /// signal.value = 20; // Effect runs again
  /// expect(values, equals([10, 20]));
  /// ```
  /// {@endtemplate}
  factory EffectImpl.lazy(void Function() fn, {JoltDebugFn? onDebug}) {
    return EffectImpl(fn, lazy: true, onDebug: onDebug);
  }

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
    assert(!isDisposed, "Watcher is disposed");
    flags |= ReactiveFlags.dirty;
    runEffect();
  }

  @override
  @protected
  void onDispose() {
    doCleanup();
    disposeNode(this);
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  @protected
  void runEffect() {
    defaultRunEffect(this, _effectFn);
  }
}

/// Interface for reactive effects that run when dependencies change.
///
/// Effects are side-effect functions that run in response to reactive state
/// changes. They automatically track their dependencies and re-run when
/// any dependency changes.
///
/// Example:
/// ```dart
/// Effect effect = Effect(() {
///   print('Count: ${count.value}');
/// });
/// effect.run(); // Manually trigger
/// effect.dispose(); // Stop the effect
/// ```
abstract class Effect implements EffectNode {
  /// {@macro jolt_effect_impl}
  factory Effect(
    void Function() fn, {
    bool lazy,
    JoltDebugFn? onDebug,
  }) = EffectImpl;

  /// {@macro jolt_effect_impl.lazy}
  factory Effect.lazy(void Function() fn, {JoltDebugFn? onDebug}) =
      EffectImpl.lazy;

  /// Manually runs the effect function.
  ///
  /// This establishes the effect as the current reactive context,
  /// allowing it to track dependencies accessed during execution.
  ///
  /// Example:
  /// ```dart
  /// effect.run(); // Triggers the effect
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

/// Function type for providing source values to a watcher.
typedef SourcesFn<T> = T Function();

/// Function type for handling watcher value changes.
typedef WatcherFn<T> = void Function(T newValue, T? oldValue);

/// Function type for determining when a watcher should trigger.
typedef WhenFn<T> = bool Function(T newValue, T oldValue);

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
class WatcherImpl<T> extends EffectReactiveNode
    with DisposableNodeMixin, EffectCleanupMixin
    implements Watcher<T> {
  /// {@template jolt_watcher_impl}
  /// Creates a new watcher with the given sources and callback.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [immediately]: Whether to execute the callback immediately
  /// - [when]: Optional condition function for custom trigger logic
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
      {bool immediately = false, this.when, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.watching) {
    JoltDebug.create(this, onDebug);

    final prevSub = setActiveSub(this);
    if (prevSub != null) {
      link(this, prevSub, 0);
    }
    try {
      prevSources = sourcesFn();
      if (immediately) {
        untracked(() {
          final prevWatcher = Watcher.activeWatcher;
          Watcher.activeWatcher = this;
          try {
            fn(prevSources, null);
          } finally {
            Watcher.activeWatcher = prevWatcher;
          }
        });
        JoltDebug.effect(this);
      }
    } finally {
      setActiveSub(prevSub);
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
  /// - [onDebug]: Optional debug callback for reactive system debugging
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
      {WhenFn<T>? when, JoltDebugFn? onDebug}) {
    return WatcherImpl(sourcesFn, fn,
        immediately: true, when: when, onDebug: onDebug);
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
  /// - [onDebug]: Optional debug callback for reactive system debugging
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
      {WhenFn<T>? when, JoltDebugFn? onDebug}) {
    late WatcherImpl<T> watcher;

    watcher = WatcherImpl(sourcesFn, (newValue, oldValue) {
      fn(newValue, oldValue);
      watcher.dispose();
    }, when: when, immediately: false, onDebug: onDebug);

    return watcher;
  }

  /// Function that provides the source values to watch.
  @protected
  final SourcesFn<T> sourcesFn;

  /// Callback function executed when sources change.
  @protected
  final WatcherFn<T> fn;

  /// Optional condition function for custom trigger logic.
  @protected
  final WhenFn<T>? when;

  /// The previous source values for comparison.
  @protected
  late T prevSources;

  @visibleForTesting
  T get testCachedSources => prevSources;

  void _effectFn() {
    if (_isPaused) {
      return;
    }

    doCleanup();
    final sources = sourcesFn();
    final shouldTrigger =
        when == null ? sources != prevSources : when!(sources, prevSources);

    if (shouldTrigger) {
      trigger(sources: sources);
    } else {
      prevSources = sources;
      JoltDebug.effect(this);
    }
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @protected
  void trigger({required T? sources}) {
    if (sources == null) {
      doCleanup();
    }

    untracked(() {
      final current = sources ?? sourcesFn();
      final prevWatcher = Watcher.activeWatcher;
      Watcher.activeWatcher = this;
      try {
        fn(current, prevSources);
      } finally {
        Watcher.activeWatcher = prevWatcher;
        prevSources = current;
      }
    });
    JoltDebug.effect(this);
  }

  @override
  void run() {
    assert(!isDisposed, "Watcher is disposed");
    trigger(sources: null);
  }

  @override
  @protected
  void onDispose() {
    doCleanup();
    disposeNode(this);
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  @protected
  void runEffect() {
    defaultRunEffect(this, _effectFn);
  }

  bool _isPaused = false;
  @override
  bool get isPaused => _isPaused;

  @override
  void pause() {
    assert(!isDisposed, "Watcher is disposed");
    _isPaused = true;
    cycle++;
    depsTail = null;
    purgeDeps(this);
    flags = ReactiveFlags.watching;
  }

  @override
  void resume([bool tryRun = false]) {
    assert(!isDisposed, "Watcher is disposed");
    _isPaused = false;

    if (!tryRun) {
      trackWithEffect(sourcesFn, this);
    } else {
      trackWithEffect(_effectFn, this);
    }
  }

  @override
  U ignoreUpdates<U>(U Function() fn) {
    assert(!isDisposed, "Watcher is disposed");

    return batch(() {
      int prevFlags = flags;
      try {
        return fn();
      } finally {
        flags = prevFlags;
      }
    });
  }
}

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
abstract class Watcher<T> implements EffectNode {
  /// {@macro jolt_watcher_impl}
  factory Watcher(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {bool immediately,
      WhenFn<T>? when,
      JoltDebugFn? onDebug}) = WatcherImpl<T>;

  /// {@macro jolt_watcher_impl.immediately}
  factory Watcher.immediately(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, JoltDebugFn? onDebug}) = WatcherImpl.immediately;

  /// {@macro jolt_watcher_impl.once}
  factory Watcher.once(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {WhenFn<T>? when, JoltDebugFn? onDebug}) = WatcherImpl.once;

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
  /// watcher.run(); // Manually trigger check
  /// ```
  void run();

  /// Registers a cleanup function to be called when the watcher is disposed or re-run.
  ///
  /// Parameters:
  /// - [fn]: The cleanup function to register
  ///
  /// Example:
  /// ```dart
  /// watcher.onCleanUp(() => subscription.cancel());
  /// ```
  void onCleanUp(Disposer fn);

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

  /// Resumes the watcher, re-enabling it to respond to changes.
  ///
  /// When resumed, the watcher will:
  /// - Re-collect dependencies by tracking the watched sources
  /// - Start responding to changes in watched sources again
  ///
  /// Parameters:
  /// - [tryRun]: If `true`, attempts to run the watcher immediately after
  ///   re-collecting dependencies. If `false`, only re-collects dependencies
  ///   without executing the callback.
  ///
  /// Example:
  /// ```dart
  /// final watcher = Watcher(...);
  /// watcher.pause();
  ///
  /// // Resume without executing
  /// watcher.resume();
  ///
  /// // Resume and try to run immediately
  /// watcher.resume(tryRun: true);
  /// ```
  void resume([bool tryRun = false]);

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
void onEffectCleanup(Disposer fn, {EffectCleanupMixin? owner}) {
  assert(
      owner != null ||
          getActiveSub() is EffectCleanupMixin ||
          Watcher.activeWatcher != null,
      "onCleanup can only be used within an effect or watcher");

  ((owner ?? Watcher.activeWatcher ?? getActiveSub()!) as EffectCleanupMixin)
      .onCleanUp(fn);
}

/// Registers a cleanup function to be executed when the current effect scope is disposed.
///
/// Parameters:
/// - [fn]: The cleanup function to register
/// - [owner]: Optional effect scope owner. If not provided, automatically detects
///   the current active effect scope from the reactive context.
///
/// This function can only be called within an effect scope context. The cleanup
/// function will be executed when the effect scope is disposed.
///
/// Example:
/// ```dart
/// final scope = EffectScope()
///   ..run(() {
///     final subscription = someStream.listen((data) {});
///     onScopeDispose(() => subscription.cancel());
///   });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void onScopeDispose(Disposer fn, {EffectScope? owner}) {
  assert(owner != null || getActiveScope() != null,
      "onScopeDispose can only be used within an effect scope");

  ((owner ?? getActiveScope()!) as EffectCleanupMixin).onCleanUp(fn);
}
