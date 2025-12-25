import "package:jolt/src/core/reactive.dart";
import "package:jolt/src/utils/finalizer.dart";
import "package:meta/meta.dart";
import "package:shared_interfaces/shared_interfaces.dart";

/// Marker interface for mutable collection types.
///
/// Used internally to identify reactive collections that need special
/// change detection handling.
///
/// Example:
/// ```dart
/// class MutableListSignal<T> extends ListSignal<T>
///     implements IMutableCollection<T> {}
/// ```
abstract interface class IMutableCollection<T> {
  /// Returns a skip function if target is a mutable collection.
  ///
  /// Parameters:
  /// - [target]: The object to check
  ///
  /// Returns: A function that always returns true (skip change detection),
  /// or null if target is not a mutable collection
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static bool Function(dynamic, dynamic)? skipNode(dynamic target) =>
      target is IMutableCollection ? _skip : null;

  static bool _skip(dynamic newValue, dynamic oldValue) {
    return true;
  }
}

/// Interface for readonly reactive nodes.
///
/// Represents a reactive value that can be read and tracked as a dependency,
/// but cannot be modified. Provides lifecycle management through disposal.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// ReadableNode<int> doubled = Computed(() => count.value * 2);
/// print(doubled.value); // OK
/// // doubled.value = 6; // Compile error
/// ```
abstract interface class ReadableNode<T>
    implements Readable<T>, Notifiable, DisposableNode {}

/// Interface for writable reactive nodes.
///
/// Extends [ReadableNode] to provide write access, allowing values to be
/// both read and modified reactively.
///
/// Example:
/// ```dart
/// WritableNode<int> count = Signal(0);
/// count.value = 42; // Can modify
/// print(count.value); // Can read
/// ```
abstract interface class WritableNode<T>
    implements Writable<T>, ReadableNode<T> {}

/// Interface for effect nodes (Effect, EffectScope, Watcher).
///
/// Represents reactive side effects that can be disposed. Used internally
/// to identify effect-related nodes in the reactive system.
abstract interface class EffectNode implements DisposableNode {}

abstract interface class DisposableNode implements Disposable {
  /// Whether this node has been disposed.
  bool get isDisposed;

  /// Disposes this node and cleans up resources.
  ///
  /// Marks the node as disposed, invokes [onDispose] for custom cleanup,
  /// and notifies the finalizer system for chained disposers.
  ///
  /// Example:
  /// ```dart
  /// final node = MyDisposableNode();
  /// node.dispose(); // Cleanup happens automatically
  /// ```
  @mustCallSuper
  @override
  void dispose();
}

/// Mixin providing base disposal functionality for reactive nodes.
///
/// Implements common disposal logic and state management. Automatically
/// tracks disposal state and calls [onDispose] for custom cleanup.
///
/// Example:
/// ```dart
/// class MyNode<T> with DisposableNodeMixin implements DisposableNode {
///   @override
///   void onDispose() {
///     // Custom cleanup logic
///   }
/// }
/// ```
mixin DisposableNodeMixin implements DisposableNode, ChainedDisposable {
  /// Whether this node has been disposed.
  @override
  bool get isDisposed => _isDisposed;

  @protected
  bool _isDisposed = false;

  @override
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    // allow unawaited futures
    // ignore: discarded_futures
    onDispose();

    JFinalizer.disposeObject(this);
  }

  /// Called when the node is being disposed.
  ///
  /// Override to provide custom cleanup logic. Called automatically by [dispose].
  ///
  /// Example:
  /// ```dart
  /// class MyNode<T> with DisposableNodeMixin implements DisposableNode {
  ///   @override
  ///   void onDispose() {
  ///     // Clean up resources
  ///   }
  /// }
  /// ```
  @override
  @protected
  void onDispose() {}
}
