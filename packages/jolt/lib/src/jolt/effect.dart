import 'dart:async';

import 'package:jolt/src/core/debug.dart';
import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:meta/meta.dart';

import '../core/reactive.dart';
import '../core/system.dart';
import 'untracked.dart';

/// Interface for reactive nodes that can execute effect functions.
abstract interface class JEffectNode implements ReactiveNode {
  /// Executes the effect function.
  void effectFn();
}

/// Base class for all effect nodes in the reactive system.
abstract class EffectBaseNode extends ReactiveNode
    implements ChainedDisposable {
  /// Create an effect base node.
  ///
  /// Parameters:
  /// - [flags]: Reactive flags for this node
  /// - [subs]: Subscribers list
  /// - [subsTail]: Tail of subscribers list
  /// - [deps]: Dependencies list
  /// - [depsTail]: Tail of dependencies list
  EffectBaseNode({
    required super.flags,
    super.subs,
    super.subsTail,
    super.deps,
    super.depsTail,
  });

  bool isDisposed = false;

  @override
  @mustCallSuper
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    onDispose();
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
/// final scope = EffectScope((scope) {
///   final signal = Signal(0);
///   Effect(() => print('Value: ${signal.value}'));
///
///   // Both signal and effect will be disposed when scope is disposed
/// });
///
/// // Later, dispose all effects in the scope
/// scope.dispose();
/// ```
class EffectScope extends EffectBaseNode {
  /// Creates a new effect scope and runs the provided function.
  ///
  /// Parameters:
  /// - [fn]: Function to execute within the scope context
  ///
  /// The function receives the scope instance as a parameter, allowing
  /// you to manually add disposers or access scope functionality.
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope((scope) {
  ///   final signal = Signal(0);
  ///   Effect(() => print(signal.value));
  ///
  ///   // Manually add a disposer
  ///   scope.add(() => print('Scope disposed'));
  /// });
  /// ```
  EffectScope(void Function(EffectScope scope)? fn, {JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.none) {
    assert(() {
      if (onDebug != null) {
        setJoltDebugFn(this, onDebug);
        onDebug(DebugNodeOperationType.create, this);
      }
      return true;
    }());
    final prevSub = globalReactiveSystem.setActiveSub(this);
    if (prevSub != null) {
      globalReactiveSystem.link(this, prevSub, 0);
    }

    try {
      if (fn != null) {
        fn(this);
      }
    } finally {
      globalReactiveSystem.setActiveSub(prevSub);
    }
    assert(() {
      untracked(() {
        getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);
      });
      return true;
    }());
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
  /// final scope = EffectScope((scope) {});
  ///
  /// final result = scope.run((scope) {
  ///   final signal = Signal(42);
  ///   return signal.value;
  /// });
  /// ```
  T run<T>(
    T Function(EffectScope scope) fn,
  ) {
    final prevSub = globalReactiveSystem.setActiveSub(this);

    try {
      final result = fn(this);

      assert(() {
        untracked(() {
          getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);
        });
        return true;
      }());

      return result;
    } finally {
      globalReactiveSystem.setActiveSub(prevSub);
    }
  }

  @override
  void onDispose() {
    globalReactiveSystem.nodeDispose(this);
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
class Effect extends EffectBaseNode implements JEffectNode {
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
      : super(flags: ReactiveFlags.watching) {
    assert(() {
      if (onDebug != null) {
        setJoltDebugFn(this, onDebug);
        onDebug(DebugNodeOperationType.create, this);
      }
      return true;
    }());

    final prevSub = globalReactiveSystem.getActiveSub();
    if (prevSub != null) {
      globalReactiveSystem.link(this, prevSub, 0);
    }

    if (immediately) {
      run();
    }
  }

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void effectFn() {
    fn();
    assert(() {
      untracked(() {
        getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);
      });
      return true;
    }());
  }

  /// The function that defines the effect's behavior.
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
    final prevSub = globalReactiveSystem.setActiveSub(this);
    try {
      fn();
    } finally {
      globalReactiveSystem.setActiveSub(prevSub);
    }
    assert(() {
      getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);

      return true;
    }());
  }

  @override
  void onDispose() {
    globalReactiveSystem.nodeDispose(this);
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
class Watcher<T> extends EffectBaseNode implements JEffectNode {
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
    assert(() {
      if (onDebug != null) {
        setJoltDebugFn(this, onDebug);
        onDebug(DebugNodeOperationType.create, this);
      }
      return true;
    }());
    final prevSub = globalReactiveSystem.setActiveSub(this);
    if (prevSub != null) {
      globalReactiveSystem.link(this, prevSub, 0);
    }
    try {
      prevSources = sourcesFn();
      if (immediately) {
        fn(prevSources, null);

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

  /// Function that provides the source values to watch.
  final SourcesFn<T> sourcesFn;

  /// Callback function executed when sources change.
  final WatcherFn<T> fn;

  /// Optional condition function for custom trigger logic.
  final WhenFn<T>? when;

  /// The previous source values for comparison.
  late T prevSources;

  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void effectFn() {
    run();
  }

  @override
  void onDispose() {
    globalReactiveSystem.nodeDispose(this);
  }

  /// Triggers the watcher to check for changes and potentially execute.
  ///
  /// Returns: true if the watcher callback was executed, false otherwise
  ///
  /// This method compares current source values with previous values and
  /// executes the callback if they differ (or if the custom condition is met).
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool run() {
    final sources = sourcesFn();
    if (((when == null && sources == prevSources) ||
        (when != null && !when!(sources, prevSources)))) {
      assert(() {
        untracked(() {
          getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);
        });
        return true;
      }());

      return false;
    }
    untracked(() {
      fn(sources, prevSources);
    });
    prevSources = sources;

    assert(() {
      untracked(() {
        getJoltDebugFn(this)?.call(DebugNodeOperationType.effect, this);
      });
      return true;
    }());

    return true;
  }
}
