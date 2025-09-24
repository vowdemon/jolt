import 'package:free_disposer/free_disposer.dart';
import 'package:meta/meta.dart';

import '../core/system.dart';
import 'utils.dart' show JoltConfig;

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
abstract class JReadonlyValue<T> extends ReactiveNode implements Disposable {
  /// Creates a readable reactive value.
  ///
  /// Parameters:
  /// - [flags]: Reactive flags for this node
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  /// - [nodeValue]: Initial internal value storage
  JReadonlyValue(
      {required super.flags, this.autoDispose = false, this.nodeValue}) {
    JoltConfig.observer?.onCreated(this);
  }

  /// Internal storage for the node's value.
  Object? nodeValue;

  /// Returns the current value without establishing a reactive dependency.
  T get peek;

  /// Returns the current value and establishes a reactive dependency.
  T get value;

  /// Returns the current value and establishes a reactive dependency.
  T get();

  /// Attempts to dispose this value if auto-dispose is enabled.
  void tryDispose();

  /// Whether this reactive value has been disposed.
  bool isDisposed = false;

  /// Whether this value should be automatically disposed when no longer referenced.
  final bool autoDispose;

  /// Called when this value is being disposed. Override to perform cleanup.
  @mustCallSuper
  void onDispose() {
    JoltConfig.observer?.onDisposed(this);
  }

  /// Disposes this reactive value and cleans up resources.
  @override
  @mustCallSuper
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    onDispose();
    disposeAttached();
    nodeValue = null;
  }

  /// Notifies all subscribers that this value has changed.
  @mustCallSuper
  void notify() {
    assert(!isDisposed);
    JoltConfig.observer?.onNotify(this);
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

/// Observer interface for monitoring reactive value lifecycle events.
///
/// IJoltObserver allows you to hook into the creation, update, disposal,
/// and notification events of reactive values for debugging or analytics.
///
/// Example:
/// ```dart
/// class LoggingObserver implements IJoltObserver {
///   @override
///   void onCreated(JReadonlyValue source) {
///     print('Created: ${source.runtimeType}');
///   }
///
///   @override
///   void onUpdated(JReadonlyValue source, Object? newValue, Object? oldValue) {
///     print('Updated: $oldValue -> $newValue');
///   }
/// }
///
/// JConfig.observer = LoggingObserver();
/// ```
abstract interface class IJoltObserver {
  /// Called when a reactive value is created.
  void onCreated(JReadonlyValue source) {}

  /// Called when a reactive value is updated.
  void onUpdated(JReadonlyValue source, Object? newValue, Object? oldValue) {}

  /// Called when a reactive value is disposed.
  void onDisposed(JReadonlyValue source) {}

  /// Called when a reactive value notifies its subscribers.
  void onNotify(JReadonlyValue source) {}
}
