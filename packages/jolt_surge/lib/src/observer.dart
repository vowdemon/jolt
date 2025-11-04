import 'shared.dart';
import 'surge.dart';

/// Abstract observer class for monitoring Surge lifecycle events.
///
/// SurgeObserver provides a way to observe and react to Surge lifecycle events,
/// including creation, state changes, and disposal. This is useful for debugging,
/// logging, or implementing cross-cutting concerns.
///
/// To use an observer, create a subclass and override the methods you're interested in,
/// then set it as the global observer:
///
/// Example:
/// ```dart
/// class MyObserver extends SurgeObserver {
///   @override
///   void onCreate(Surge surge) {
///     print('Surge created: $surge');
///   }
///
///   @override
///   void onChange(Surge surge, Change change) {
///     print('State changed: ${change.currentState} -> ${change.nextState}');
///   }
///
///   @override
///   void onDispose(Surge surge) {
///     print('Surge disposed: $surge');
///   }
/// }
///
/// SurgeObserver.observer = MyObserver();
/// ```
abstract class SurgeObserver {
  /// Creates a new observer instance.
  const SurgeObserver();

  /// Called when a Surge is created.
  ///
  /// Parameters:
  /// - [surge]: The Surge instance that was created
  ///
  /// This method is called immediately after a Surge is constructed.
  /// Subclasses can override this method to perform actions when a Surge is created,
  /// such as logging or initialization.
  ///
  /// Example:
  /// ```dart
  /// class LoggingObserver extends SurgeObserver {
  ///   @override
  ///   void onCreate(Surge surge) {
  ///     print('Created Surge with initial state: ${surge.state}');
  ///   }
  /// }
  /// ```
  void onCreate(Surge<dynamic> surge) {}

  /// Called when a Surge's state changes.
  ///
  /// Parameters:
  /// - [surge]: The Surge instance whose state changed
  /// - [change]: The change object containing the current and next state
  ///
  /// This method is called before the state is updated when [Surge.emit] is called.
  /// Subclasses can override this method to perform actions when a Surge's state changes,
  /// such as logging, validation, or side effects.
  ///
  /// Example:
  /// ```dart
  /// class ChangeObserver extends SurgeObserver {
  ///   @override
  ///   void onChange(Surge surge, Change change) {
  ///     print('State change: ${change.currentState} -> ${change.nextState}');
  ///   }
  /// }
  /// ```
  void onChange(Surge<dynamic> surge, Change<dynamic> change) {}

  /// Called when a Surge is disposed.
  ///
  /// Parameters:
  /// - [surge]: The Surge instance that was disposed
  ///
  /// This method is called when [Surge.dispose] is called.
  /// Subclasses can override this method to perform actions when a Surge is disposed,
  /// such as logging or cleanup.
  ///
  /// Example:
  /// ```dart
  /// class DisposeObserver extends SurgeObserver {
  ///   @override
  ///   void onDispose(Surge surge) {
  ///     print('Surge disposed with final state: ${surge.state}');
  ///   }
  /// }
  /// ```
  void onDispose(Surge<dynamic> surge) {}

  /// The global observer instance for all Surge lifecycle events.
  ///
  /// This static field holds the observer that will be notified of all Surge
  /// lifecycle events. Set this to a custom observer to monitor all Surge instances.
  ///
  /// Example:
  /// ```dart
  /// SurgeObserver.observer = MyObserver();
  ///
  /// // Now all Surge lifecycle events will be observed
  /// final surge = MySurge(42);
  /// // onCreate is called
  /// surge.emit(43);
  /// // onChange is called
  /// surge.dispose();
  /// // onDispose is called
  /// ```
  static SurgeObserver? observer;
}
