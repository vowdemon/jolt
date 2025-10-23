import 'base.dart';

/// Global configuration for the Jolt reactive system.
///
/// Provides access to system-wide settings and observers for monitoring
/// reactive value lifecycle events.
class JoltConfig {
  JoltConfig._();

  /// Global observer for monitoring reactive value events.
  ///
  /// Set this to an IJoltObserver implementation to receive notifications
  /// about reactive value creation, updates, disposal, and notifications.
  ///
  /// Example:
  /// ```dart
  /// JConfig.observer = MyCustomObserver();
  /// ```
  static IJoltObserver? observer;
}
