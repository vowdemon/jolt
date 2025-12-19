import "package:jolt/src/core/reactive.dart";
import "package:jolt/src/jolt/shared.dart";
import "package:meta/meta.dart";
import "package:shared_interfaces/shared_interfaces.dart";

/// Marker interface for mutable collection types.
///
/// This interface is used internally to identify reactive collections
/// that can be modified and need special handling for change detection.
///
/// Example:
/// ```dart
/// class MutableListSignal<T> extends ListSignal<T>
///     implements IMutableCollection<T> {}
/// ```
abstract interface class IMutableCollection<T> {
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static bool Function(dynamic, dynamic)? skipNode(dynamic target) =>
      target is IMutableCollection ? _skip : null;

  static bool _skip(dynamic newValue, dynamic oldValue) {
    return true;
  }
}

/// Mixin that provides base functionality for readonly reactive nodes.
///
/// This mixin implements common disposal logic and state management for
/// reactive nodes that can only be read, not modified.
///
/// Example:
/// ```dart
/// class MyReadonlyNode<T> with ReadonlyNodeMixin<T> implements ReadonlyNode<T> {
///   @override
///   T get value => throw UnimplementedError();
///
///   @override
///   FutureOr<void> onDispose() async {
///     // Custom cleanup logic
///   }
/// }
/// ```
mixin ReadableNodeMixin<T> implements ReadableNode<T>, ChainedDisposable {
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
  /// Override this method to provide custom cleanup logic. This method
  /// is called automatically by [dispose].
  ///
  /// Example:
  /// ```dart
  /// class MyNode<T> extends ReadonlyNode<T> {
  ///   @override
  ///   FutureOr<void> onDispose() {
  ///     // Clean up resources
  ///   }
  /// }
  /// ```
  @override
  @protected
  void onDispose();

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  String toString() => value.toString();
}

@Deprecated("use ReadableNodeMixin<T> instead")
mixin ReadonlyNodeMixin<T> implements ReadableNodeMixin<T>, ReadonlyNode<T> {
  /// Whether this node has been disposed.
  @override
  bool get isDisposed => _isDisposed;

  @override
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
  /// Override this method to provide custom cleanup logic. This method
  /// is called automatically by [dispose].
  ///
  /// Example:
  /// ```dart
  /// class MyNode<T> extends ReadonlyNode<T> {
  ///   @override
  ///   FutureOr<void> onDispose() {
  ///     // Clean up resources
  ///   }
  /// }
  /// ```
  @override
  @protected
  void onDispose();

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  String toString() => value.toString();
}

/// Interface for readonly reactive nodes.
///
/// ReadonlyNode represents a reactive value that can be read and tracked
/// as a dependency, but cannot be modified. It provides lifecycle management
/// through disposal.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// ReadonlyNode<int> doubled = Computed(() => count.value * 2);
/// print(doubled.value); // OK
/// // doubled.value = 6; // Compile error
/// ```
abstract interface class ReadableNode<T> implements Readable<T>, Disposable {
  /// Whether this node has been disposed.
  bool get isDisposed;

  /// {@template jolt_dispose_node}
  /// Disposes this node and cleans up resources.
  ///
  /// This method marks the node as disposed, invokes [onDispose] for custom
  /// cleanup, and notifies the finalizer system so chained disposers can run.
  ///
  /// Example:
  /// ```dart
  /// final disposable = MyDisposableNode();
  /// disposable.dispose(); // Cleanup happens automatically
  /// ```
  /// {@endtemplate}
  ///
  /// {@macro jolt_dispose_node}
  @mustCallSuper
  @override
  void dispose();
}

/// Interface for readonly reactive nodes.
///
/// ReadonlyNode represents a reactive value that can be read and tracked
/// as a dependency, but cannot be modified. It provides lifecycle management
/// through disposal.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// ReadonlyNode<int> doubled = Computed(() => count.value * 2);
/// print(doubled.value); // OK
/// // doubled.value = 6; // Compile error
/// ```
@Deprecated("use ReadableNode<T> instead")
abstract interface class ReadonlyNode<T>
    implements ReadableNode<T>, Readonly<T> {}

/// Interface for writable reactive nodes.
///
/// WritableNode extends ReadonlyNode to provide write access, allowing
/// values to be both read and modified reactively.
///
/// Example:
/// ```dart
/// WritableNode<int> count = Signal(0);
/// count.value = 42; // Can modify
/// print(count.value); // Can read
/// ```
abstract interface class WritableNode<T>
    implements Writable<T>, ReadableNode<T>, ReadonlyNode<T> {}

/// Mixin that provides base functionality for effect nodes.
///
/// This mixin implements common disposal logic for effect-related nodes
/// such as Effect, Watcher, and EffectScope.
///
/// Example:
/// ```dart
/// class CustomEffectNode with EffectNode implements ChainedDisposable {
///   @override
///   FutureOr<void> onDispose() async {
///     // Custom cleanup logic
///   }
/// }
/// ```
mixin EffectNodeMixin implements EffectNode, ChainedDisposable {
  @override
  bool get isDisposed => _isDisposed;
  @protected
  bool _isDisposed = false;

  @override
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    onDispose();

    JFinalizer.disposeObject(this);
  }

  @override
  @protected
  void onDispose();
}

abstract interface class EffectNode implements Disposable {
  /// Whether this node has been disposed.
  bool get isDisposed;

  /// {@macro jolt_dispose_node}
  @mustCallSuper
  @override
  void dispose();
}
