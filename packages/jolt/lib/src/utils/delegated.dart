import 'package:jolt/jolt.dart';
import 'package:jolt/src/utils/finalizer.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

/// Helper class for managing reference-counted shared resources.
///
/// Tracks how many times a resource is acquired and automatically disposes
/// it when the reference count reaches zero.
///
/// Parameters:
/// - [source]: The resource to manage
/// - [onCreate]: Optional callback when helper is created
/// - [onDispose]: Optional callback when resource is disposed
/// - [autoDispose]: Whether to automatically dispose the source (default: true)
///
/// Example:
/// ```dart
/// final source = Signal(42);
/// final helper = DelegatedRefCountHelper<Signal<int>>(
///   source,
///   onDispose: (signal) => print('Disposed'),
/// );
///
/// final delegated1 = DelegatedSignal(helper);
/// final delegated2 = DelegatedSignal(helper);
/// // Both share the same source
///
/// delegated1.dispose();
/// delegated2.dispose(); // Source is disposed here
/// ```
class DelegatedRefCountHelper<T> {
  DelegatedRefCountHelper(this.source,
      {void Function(T source)? onCreate,
      this.onDispose,
      this.autoDispose = true}) {
    onCreate?.call(source);
  }

  late final T source;
  void Function(T source)? onDispose;
  final bool autoDispose;

  int _refCount = 0;

  /// Current reference count.
  int get count => _refCount;

  /// Increments reference count and returns the source.
  ///
  /// Returns: The source resource
  T acquire() {
    _refCount++;
    return source;
  }

  /// Decrements reference count and disposes if count reaches zero.
  ///
  /// Returns: `true` if resource was disposed, `false` otherwise
  bool release() {
    _refCount--;
    if (_refCount == 0) {
      dispose();
      return true;
    }
    return false;
  }

  void dispose() {
    if (onDispose != null) {
      onDispose!(source);
      onDispose = null;
    }
    if (autoDispose && source is Disposable) {
      (source as Disposable).dispose();
    }
    JFinalizer.disposeObject(this);
  }
}

/// A read-only signal that shares a source with reference counting.
///
/// When disposed, decrements the reference count. The source is automatically
/// disposed when all delegated signals are disposed.
///
/// Parameters:
/// - [delegated]: The reference-counted helper managing the source
///
/// Example:
/// ```dart
/// final helper = DelegatedRefCountHelper<ReadonlySignal<int>>(source);
/// final delegated = DelegatedReadonlySignal(helper);
/// print(delegated.value); // Accesses shared source
/// ```
class DelegatedReadonlySignal<T> implements ReadonlySignal<T> {
  DelegatedReadonlySignal(this.delegated) {
    delegated.acquire();
    _releaseDisposer =
        JFinalizer.attachToJoltAttachments(this, delegated.release);
  }

  final DelegatedRefCountHelper<ReadonlySignal<T>> delegated;
  Disposer? _releaseDisposer;

  @override
  T get peek => delegated.source.peek;

  @override
  T get value {
    return delegated.source.value;
  }

  @override
  void notify([bool force = false]) {
    delegated.source.notify(force);
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    delegated.release();

    _releaseDisposer?.call();
    _releaseDisposer = null;

    JFinalizer.disposeObject(this);
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  String toString() => value.toString();
}

/// A writable signal that shares a source with reference counting.
///
/// When disposed, decrements the reference count. The source is automatically
/// disposed when all delegated signals are disposed.
///
/// Parameters:
/// - [delegated]: The reference-counted helper managing the source
///
/// Example:
/// ```dart
/// final helper = DelegatedRefCountHelper<Signal<int>>(source);
/// final delegated = DelegatedSignal(helper);
/// delegated.value = 10; // Updates shared source
/// ```
class DelegatedSignal<T> implements Signal<T> {
  DelegatedSignal(this.delegated) {
    delegated.acquire();
    _releaseDisposer =
        JFinalizer.attachToJoltAttachments(this, delegated.release);
  }

  final DelegatedRefCountHelper<Signal<T>> delegated;
  Disposer? _releaseDisposer;

  @override
  set value(T value) {
    assert(!isDisposed, "$runtimeType is disposed");
    if (!isDisposed) {
      delegated.source.value = value;
    }
  }

  @override
  T get peek => delegated.source.peek;

  @override
  T get value {
    return delegated.source.value;
  }

  @override
  void notify([bool force = false]) {
    delegated.source.notify(force);
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    delegated.release();

    _releaseDisposer?.call();
    _releaseDisposer = null;

    JFinalizer.disposeObject(this);
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  String toString() => value.toString();
}
