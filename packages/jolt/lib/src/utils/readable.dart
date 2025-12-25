import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

/// Extension methods for [Readable] values.
extension JoltUtilsReadableExtension<T> on Readable<T> {
  /// Gets the current value (callable syntax).
  ///
  /// Same as accessing [value] property.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(5);
  /// final v = count(); // Same as count.value
  /// ```
  T call() => value;

  /// Gets the current value.
  ///
  /// Same as accessing [value] property.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(5);
  /// final v = count.get(); // Same as count.value
  /// ```
  T get() => value;

  /// Creates a computed value derived from this readable.
  ///
  /// Parameters:
  /// - [computed]: Function that transforms the value
  ///
  /// Returns: A [Computed] that updates when this value changes
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(5);
  /// final doubled = count.derived((value) => value * 2);
  /// print(doubled.value); // 10
  /// ```
  Computed<U> derived<U>(U Function(T value) computed) =>
      Computed(() => computed(value));
}
