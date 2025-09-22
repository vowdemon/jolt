import 'package:free_disposer/free_disposer.dart' as fd;

import 'base.dart';

/// Interface for disposable resources.
///
/// Extends the free_disposer Disposable interface to provide
/// additional lifecycle hooks for cleanup operations.
abstract interface class Disposable implements fd.Disposable {
  /// Called when this resource is being disposed. Override to perform cleanup.
  void onDispose();
}

/// Extension for bitwise operations on integers.
///
/// Provides convenient methods for working with bit flags in the reactive system.
extension BitExtension on int {
  /// Checks if any of the specified flags are set.
  ///
  /// Parameters:
  /// - [flag]: The flag bits to check
  ///
  /// Returns: true if any of the flag bits are set in this integer
  ///
  /// Example:
  /// ```dart
  /// final flags = 0b1010;
  /// print(flags.hasAny(0b0010)); // true (bit 2 is set)
  /// print(flags.hasAny(0b0001)); // false (bit 1 is not set)
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool hasAny(int flag) => (this & flag) != 0;

  /// Checks if none of the specified flags are set.
  ///
  /// Parameters:
  /// - [flag]: The flag bits to check
  ///
  /// Returns: true if none of the flag bits are set in this integer
  ///
  /// Example:
  /// ```dart
  /// final flags = 0b1010;
  /// print(flags.notHasAny(0b0001)); // true (bit 1 is not set)
  /// print(flags.notHasAny(0b0010)); // false (bit 2 is set)
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool notHasAny(int flag) => (this & flag) == 0;

  /// Checks if all of the specified flags are set.
  ///
  /// Parameters:
  /// - [flag]: The flag bits to check
  ///
  /// Returns: true if all of the flag bits are set in this integer
  ///
  /// Example:
  /// ```dart
  /// final flags = 0b1010;
  /// print(flags.hasAll(0b1010)); // true (both bits 2 and 4 are set)
  /// print(flags.hasAll(0b1011)); // false (bit 1 is not set)
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool hasAll(int flag) => (this & flag) == flag;
}

/// Global configuration for the Jolt reactive system.
///
/// Provides access to system-wide settings and observers for monitoring
/// reactive value lifecycle events.
class JConfig {
  JConfig._();

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
