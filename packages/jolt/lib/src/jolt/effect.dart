import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/src/jolt/base.dart";
import "package:jolt/src/jolt/track.dart";
import "package:meta/meta.dart";
import "package:shared_interfaces/shared_interfaces.dart";

/// Base interface for all effect nodes in the reactive system.
///
/// EffectBase is a marker interface that identifies nodes that represent
/// side effects in the reactive system, such as Effect, Watcher, and EffectScope.
///
/// Example:
/// ```dart
/// EffectBase effect = Effect(() => print('Hello'));
/// effect.dispose();
/// ```
abstract interface class EffectBase implements Disposable {}

@protected
mixin EffectCleanupMixin {
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
    with EffectNode, EffectCleanupMixin
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
  FutureOr<void> onDispose() {
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
abstract class EffectScope implements EffectNode, EffectBase {
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
    with EffectNode, EffectCleanupMixin
    implements Effect {
  /// Creates a new effect with the given function.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [immediately]: Whether to run the effect immediately upon creation
  ///
  /// The effect function will be called immediately (if [immediately] is true)
  /// and then whenever any of its reactive dependencies change.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  ///
  /// final effect = Effect(() {
  ///   print('Signal value: ${signal.value}');
  /// }, immediately: false); // Don't run immediately
  ///
  /// effect.run(); // Manually run the effect
  /// ```
  EffectImpl(this.fn, {bool immediately = true, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck) {
    JoltDebug.create(this, onDebug);

    final prevSub = getActiveSub();
    if (prevSub != null) {
      link(this, prevSub, 0);
    }

    if (immediately) {
      final prevSub = setActiveSub(this);
      try {
        effectFn();
      } finally {
        setActiveSub(prevSub);
        flags &= ~ReactiveFlags.recursedCheck;
      }
    } else {
      flags &= ~ReactiveFlags.recursedCheck;
    }
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override

  /// Do not call this method directly
  void effectFn() {
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
  /// final effect = Effect(() => print('Hello'), immediately: false);
  /// effect.run(); // Prints: "Hello"
  /// ```
  @override
  void run() {
    flags |= ReactiveFlags.dirty;
    runEffect(this);
  }

  @override
  @protected
  FutureOr<void> onDispose() {
    doCleanup();
    disposeNode(this);
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
abstract class Effect implements EffectNode, EffectBase {
  /// Creates a new effect with the given function.
  ///
  /// Parameters:
  /// - [fn]: The effect function to execute
  /// - [immediately]: Whether to run the effect immediately upon creation
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final effect = Effect(() => print('Hello'), immediately: false);
  /// ```
  factory Effect(void Function() fn, {bool immediately, JoltDebugFn? onDebug}) =
      EffectImpl;

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
    with EffectNode, EffectCleanupMixin
    implements Watcher<T> {
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
          fn(prevSources, null);
          Watcher.activeWatcher = prevWatcher;
        });
        JoltDebug.effect(this);
      }
    } finally {
      setActiveSub(prevSub);
    }
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

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void effectFn() {
    doCleanup();
    final sources = sourcesFn();
    final shouldTrigger =
        when == null ? sources != prevSources : when!(sources, prevSources);

    if (shouldTrigger) {
      untracked(() {
        final prevWatcher = Watcher.activeWatcher;
        Watcher.activeWatcher = this;
        fn(sources, prevSources);
        Watcher.activeWatcher = prevWatcher;
      });
    }

    prevSources = sources;

    JoltDebug.effect(this);
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void run() {
    effectFn();
  }

  @override
  @protected
  FutureOr<void> onDispose() {
    doCleanup();
    disposeNode(this);
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
abstract class Watcher<T> implements EffectNode, EffectBase {
  /// Creates a new watcher with the given sources and callback.
  ///
  /// Parameters:
  /// - [sourcesFn]: Function that returns the values to watch
  /// - [fn]: Callback function executed when sources change
  /// - [immediately]: Whether to execute the callback immediately
  /// - [when]: Optional condition function for custom trigger logic
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final watcher = Watcher(
  ///   () => signal.value,
  ///   (newValue, oldValue) => print('Changed'),
  ///   when: (newValue, oldValue) => newValue > oldValue,
  /// );
  /// ```
  factory Watcher(SourcesFn<T> sourcesFn, WatcherFn<T> fn,
      {bool immediately,
      WhenFn<T>? when,
      JoltDebugFn? onDebug}) = WatcherImpl<T>;

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
