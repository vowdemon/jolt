import 'dart:async';

import 'package:jolt/core.dart';
import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:meta/meta.dart';

import 'base.dart';
import 'track.dart';

/// Base class for all effect nodes in the reactive system.

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
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @protected
  void doCleanup() {
    if (_cleanups.isEmpty) return;
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
  }
}

/// A scope for managing the lifecycle of effects and other reactive nodes.
///
/// EffectScope allows you to group related effects together and dispose
/// them all at once. It's useful for component-based architectures where
/// you want to clean up all effects when a component is destroyed.
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

abstract class EffectScope implements EffectNode {
  T run<T>(T Function() fn);

  void onCleanUp(Disposer fn);

  factory EffectScope({bool? detach, JoltDebugFn? onDebug}) = EffectScopeImpl;
}

/// A reactive effect that automatically runs when its dependencies change.
///
/// Effects are side-effect functions that run in response to reactive state
/// changes. They automatically track their dependencies and re-run when
/// any dependency changes.
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
        flags &= ~(ReactiveFlags.recursedCheck);
      }
    } else {
      flags &= ~(ReactiveFlags.recursedCheck);
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override

  /// Do not call this method directly
  void effectFn() {
    doCleanup();
    wrappedFn();
    JoltDebug.effect(this);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
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

abstract class Effect implements EffectNode {
  factory Effect(void Function() fn, {bool immediately, JoltDebugFn? onDebug}) =
      EffectImpl;

  void run();
  void onCleanUp(Disposer fn);
}

/// Function type for providing source values to a watcher.
typedef SourcesFn<T> = T Function();

/// Function type for handling watcher value changes.
typedef WatcherFn<T> = FutureOr<void> Function(T newValue, T? oldValue);

/// Function type for determining when a watcher should trigger.
typedef WhenFn<T> = bool Function(T newValue, T oldValue);

/// A watcher that observes changes to reactive sources and executes a callback.
///
/// Watchers are similar to effects but provide more control over when they
/// trigger. They compare old and new values and only execute when values
/// actually change (or when a custom condition is met).
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

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
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

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
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

abstract class Watcher<T> implements EffectNode {
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

  void run();
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
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void onEffectCleanup(Disposer fn, {EffectCleanupMixin? owner}) {
  assert(
      owner != null ||
          getActiveSub() is EffectCleanupMixin ||
          Watcher.activeWatcher != null,
      'onCleanup can only be used within an effect');

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
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void onScopeDispose(Disposer fn, {EffectScope? owner}) {
  assert(owner != null || getActiveScope() != null,
      'onScopeDispose can only be used within an effect scope');

  ((owner ?? getActiveScope()!) as EffectCleanupMixin).onCleanUp(fn);
}
