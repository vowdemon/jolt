import 'shared.dart';
import 'surge.dart';

/// Observes [Surge] lifecycle events for debugging, logging, or analytics.
///
/// Assign a subclass to [observer] to receive callbacks for every surge in the
/// process.
///
/// ```dart
/// class LoggingObserver extends SurgeObserver {
///   @override
///   void onChange(Surge surge, Change change) {
///     debugPrint(
///       '${change.currentState} -> ${change.nextState}',
///     );
///   }
/// }
///
/// SurgeObserver.observer = LoggingObserver();
/// ```
abstract class SurgeObserver {
  /// Creates an observer instance.
  const SurgeObserver();

  /// Called when a [Surge] is created.
  void onCreate(Surge<dynamic> surge) {}

  /// Called before [Surge.emit] applies a new state.
  void onChange(Surge<dynamic> surge, Change<dynamic> change) {}

  /// Called when a [Surge] is disposed.
  void onDispose(Surge<dynamic> surge) {}

  /// The global observer notified for all surge lifecycle events.
  static SurgeObserver? observer;
}
