import 'package:free_disposer/free_disposer.dart';
import 'package:meta/meta.dart';

import '../core/system.dart';
import 'computed.dart';
import 'effect.dart';
import 'signal.dart';

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
  JReadonlyValue(
      {required super.flags, this.autoDispose = false, this.pendingValue});

  /// Internal storage for the node's value.
  Object? pendingValue;

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

  /// Disposes this reactive value and cleans up resources.
  @override
  @mustCallSuper
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    onDispose();
    disposeAttached();
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
  /// Called when a new Signal is created.
  ///
  /// This callback is triggered immediately after a Signal instance
  /// is constructed and initialized.
  void onSignalCreated(Signal source);

  /// Called when a Signal's value is updated.
  ///
  /// Parameters:
  /// - [source]: The Signal that was updated
  /// - [newValue]: The new value that was set
  /// - [oldValue]: The previous value before the update
  void onSignalUpdated(Signal source, Object? newValue, Object? oldValue);

  /// Called when a Signal notifies its subscribers.
  ///
  /// This is triggered when the Signal's value changes and it needs
  /// to notify all dependent reactive values and effects.
  void onSignalNotified(Signal source);

  /// Called when a Signal is disposed.
  ///
  /// This callback is triggered when the Signal is no longer needed
  /// and its resources are being cleaned up.
  void onSignalDisposed(Signal source);

  /// Called when a new Computed is created.
  ///
  /// This callback is triggered immediately after a Computed instance
  /// is constructed and initialized.
  void onComputedCreated(Computed source);

  /// Called when a Computed's value is recalculated.
  ///
  /// Parameters:
  /// - [source]: The Computed that was updated
  /// - [newValue]: The newly calculated value
  /// - [oldValue]: The previous calculated value
  void onComputedUpdated(Computed source, Object? newValue, Object? oldValue);

  /// Called when a Computed notifies its subscribers.
  ///
  /// This is triggered when the Computed's value changes and it needs
  /// to notify all dependent reactive values and effects.
  void onComputedNotified(Computed source);

  /// Called when a Computed is disposed.
  ///
  /// This callback is triggered when the Computed is no longer needed
  /// and its resources are being cleaned up.
  void onComputedDisposed(Computed source);

  /// Called when a new Effect is created.
  ///
  /// This callback is triggered immediately after an Effect instance
  /// is constructed and initialized.
  void onEffectCreated(Effect source);

  /// Called when an Effect is triggered for execution.
  ///
  /// This is triggered when the Effect's dependencies change and
  /// the effect function needs to be re-executed.
  void onEffectTriggered(Effect source);

  /// Called when an Effect is disposed.
  ///
  /// This callback is triggered when the Effect is no longer needed
  /// and its resources are being cleaned up.
  void onEffectDisposed(Effect source);

  /// Called when a new Watcher is created.
  ///
  /// This callback is triggered immediately after a Watcher instance
  /// is constructed and initialized.
  void onWatcherCreated(Watcher source);

  /// Called when a Watcher is triggered for execution.
  ///
  /// This is triggered when the Watcher's dependencies change and
  /// the watcher function needs to be re-executed.
  void onWatcherTriggered(Watcher source);

  /// Called when a Watcher is disposed.
  ///
  /// This callback is triggered when the Watcher is no longer needed
  /// and its resources are being cleaned up.
  void onWatcherDisposed(Watcher source);

  /// Called when a new EffectScope is created.
  ///
  /// This callback is triggered immediately after an EffectScope instance
  /// is constructed and initialized.
  void onEffectScopeCreated(EffectScope source);

  /// Called when an EffectScope is disposed.
  ///
  /// This callback is triggered when the EffectScope is no longer needed
  /// and all effects within the scope are being cleaned up.
  void onEffectScopeDisposed(EffectScope source);
}
