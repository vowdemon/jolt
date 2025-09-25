import 'computed.dart';
import 'effect.dart';
import 'signal.dart';

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
  void onSignalCreated(Signal source) {}
  void onSignalUpdated(Signal source, Object? newValue, Object? oldValue) {}
  void onSignalNotified(Signal source) {}
  void onSignalDisposed(Signal source) {}

  void onComputedCreated(Computed source) {}
  void onComputedUpdated(Computed source, Object? newValue, Object? oldValue) {}
  void onComputedNotified(Computed source) {}
  void onComputedDisposed(Computed source) {}

  void onEffectCreated(Effect source) {}
  void onEffectTriggered(Effect source) {}
  void onEffectDisposed(Effect source) {}

  void onWatcherCreated(Watcher source) {}
  void onWatcherTriggered(Watcher source) {}
  void onWatcherDisposed(Watcher source) {}

  void onEffectScopeCreated(EffectScope source) {}
  void onEffectScopeDisposed(EffectScope source) {}
}
