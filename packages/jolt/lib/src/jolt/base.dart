import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:meta/meta.dart';

import '../core/system.dart';
import 'utils.dart';

/// Marker interface for mutable collection types.
///
/// This interface is used internally to identify reactive collections
/// that can be modified and need special handling for change detection.
abstract interface class IMutableCollection<T> {}

/// Base class for all readable reactive values.
///
/// JReadonlyValue provides the foundation for reactive values that can
/// be read and tracked as dependencies. It handles disposal, dependency
/// tracking, and notification of subscribers.
abstract class JReadonlyValue<T> extends ReactiveNode
    implements ChainedDisposable {
  /// Creates a readable reactive value.
  ///
  /// Parameters:
  /// - [flags]: Reactive flags for this node
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  /// - [pendingValue]: Initial internal value storage
  JReadonlyValue({required super.flags, this.pendingValue});

  /// Internal storage for the node's value.
  Object? pendingValue;

  /// Returns the current value without establishing a reactive dependency.
  T get peek;

  /// Returns the current value and establishes a reactive dependency.
  T get value;

  /// Returns the current value and establishes a reactive dependency.
  T get();

  /// Whether this reactive value has been disposed.
  bool isDisposed = false;

  /// Disposes this reactive value and cleans up resources.
  @override
  @mustCallSuper
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    onDispose();
    manuallyDisposeJoltAttachments(this);
    pendingValue = null;
  }

  /// Notifies all subscribers that this value has changed.
  @mustCallSuper
  void notify() {
    assert(!isDisposed);
  }

  @visibleForTesting
  bool testNoSubscribers() {
    return subs == null && subsTail == null;
  }
}

/// Interface for writable reactive values.
///
/// JWritableValue extends JReadonlyValue to provide write access,
/// allowing values to be both read and modified reactively.
abstract interface class JWritableValue<T> implements JReadonlyValue<T> {
  /// Sets a new value for this reactive value.
  set value(T value);

  /// Sets a new value for this reactive value.
  void set(T value);
}
