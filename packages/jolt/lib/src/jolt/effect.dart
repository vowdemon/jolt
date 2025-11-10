import 'dart:async';

import 'package:jolt/src/core/debug.dart';
import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:meta/meta.dart';

import '../core/reactive.dart';
import '../core/system.dart';
import 'untracked.dart';

/// Interface for reactive nodes that can execute effect functions.
abstract interface class EffectBase implements ReactiveNode {
  /// Executes the effect function.
  void effectFn();

  void runEffect(GlobalReactiveSystem system);
}

/// Base class for all effect nodes in the reactive system.
abstract class JEffect extends ReactiveNode implements ChainedDisposable {
  /// Create an effect base node.
  ///
  /// Parameters:
  /// - [flags]: Reactive flags for this node
  /// - [subs]: Subscribers list
  /// - [subsTail]: Tail of subscribers list
  /// - [deps]: Dependencies list
  /// - [depsTail]: Tail of dependencies list
  JEffect({
    required super.flags,
    super.subs,
    super.subsTail,
    super.deps,
    super.depsTail,
  });

  /// Whether this effect has been disposed.
  bool _isDisposed = false;

  /// List of cleanup functions to be executed when this effect is disposed or re-run.
  late final List<Disposer> _cleanups = [];

  /// Whether this effect has been disposed.
  ///
  /// Returns true if the effect has been disposed, false otherwise.
  /// Once disposed, the effect will no longer track dependencies or execute.
  bool get isDisposed => _isDisposed;

  /// Disposes this effect and cleans up all resources.
  ///
  /// This method executes all registered cleanup functions and removes
  /// the effect from the reactive system. After disposal, the effect
  /// will no longer track dependencies or execute.
  ///
  /// This method is idempotent - calling it multiple times has no effect.
  @override
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    doCleanup();
    onDispose();
  }

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
  void doCleanup() {
    if (_cleanups.isEmpty) return;
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
  }

  /// Called when this effect is being disposed.
  ///
  /// This method is called by [dispose] to perform cleanup operations.
  /// Subclasses can override this method to add custom disposal logic,
  /// but must call `super.onDispose()`.
  ///
  /// This method removes the effect from the reactive system and cleans
  /// up its dependencies.
  @override
  @mustCallSuper
  @protected
  void onDispose() {
    globalReactiveSystem.nodeDispose(this);
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
class EffectScope extends JEffect {
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
  EffectScope({bool? detach, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.none) {
    JoltDebug.create(this, onDebug);
    if (!(detach ?? false)) {
      final prevSub = globalReactiveSystem.getActiveSub();
      if (prevSub != null) {
        globalReactiveSystem.link(this, prevSub, 0);
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
  T run<T>(T Function() fn) {
    final prevSub = globalReactiveSystem.setActiveSub(this);
    final prevScope = globalReactiveSystem.setActiveScope(this);
    try {
      final result = fn();

      JoltDebug.effect(this);

      return result;
    } finally {
      globalReactiveSystem.setActiveScope(prevScope);
      globalReactiveSystem.setActiveSub(prevSub);
    }
  }
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
class Effect extends JEffect implements EffectBase {
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
  Effect(this.fn, {bool immediately = true, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck) {
    JoltDebug.create(this, onDebug);

    final prevSub = globalReactiveSystem.getActiveSub();
    if (prevSub != null) {
      globalReactiveSystem.link(this, prevSub, 0);
    }

    if (immediately) {
      final prevSub = globalReactiveSystem.setActiveSub(this);
      try {
        effectFn();
      } finally {
        globalReactiveSystem.setActiveSub(prevSub);
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
  @override
  void runEffect(GlobalReactiveSystem system) {
    system.runEffect(this);
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
  void run() {
    flags |= ReactiveFlags.dirty;
    globalReactiveSystem.run(this);
  }
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
class Watcher<T> extends JEffect implements EffectBase {
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
  Watcher(this.sourcesFn, this.fn,
      {bool immediately = false, this.when, JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.watching) {
    JoltDebug.create(this, onDebug);

    final prevSub = globalReactiveSystem.setActiveSub(this);
    if (prevSub != null) {
      globalReactiveSystem.link(this, prevSub, 0);
    }
    try {
      prevSources = sourcesFn();
      if (immediately) {
        untracked(() {
          final prevWatcher = activeWatcher;
          activeWatcher = this;
          fn(prevSources, null);
          activeWatcher = prevWatcher;
        });
        assert(() {
          untracked(() {
            getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);
          });
          return true;
        }());
      }
    } finally {
      globalReactiveSystem.setActiveSub(prevSub);
    }
  }

  /// The currently active watcher instance.
  ///
  /// This static field tracks the active watcher when its callback is executed
  /// within an untracked context. This allows [onEffectCleanup] to automatically
  /// detect the active watcher even when called within [untracked] blocks.
  ///
  /// This field is set before calling the watcher's callback function and
  /// restored afterwards to maintain the previous watcher context.
  static Watcher? activeWatcher;

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
        final prevWatcher = activeWatcher;
        activeWatcher = this;
        fn(sources, prevSources);
        activeWatcher = prevWatcher;
      });
    }

    prevSources = sources;

    JoltDebug.effect(this);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  void runEffect(GlobalReactiveSystem system) {
    system.runEffect(this);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void run() {
    effectFn();
  }
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
void onEffectCleanup(Disposer fn, {JEffect? owner}) {
  assert(
      owner != null ||
          globalReactiveSystem.getActiveSub() is JEffect ||
          Watcher.activeWatcher != null,
      'onCleanup can only be used within an effect');

  (owner ??
          Watcher.activeWatcher ??
          globalReactiveSystem.getActiveSub()! as JEffect)
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
  assert(owner != null || globalReactiveSystem.getActiveScope() != null,
      'onScopeDispose can only be used within an effect scope');

  (owner ?? globalReactiveSystem.getActiveScope()!).onCleanUp(fn);
}
