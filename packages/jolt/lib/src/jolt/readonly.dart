import 'package:jolt/core.dart';
export 'package:jolt/core.dart'
    show JoltSignalReadonlyExtension, JoltComputedReadonlyExtension;

/// A read-only interface for signals that prevents modification.
///
/// This is useful for exposing signals publicly while maintaining
/// write access control internally.
///
/// Example:
/// ```dart
/// class Counter {
///   final _count = Signal(0);
///
///   ReadonlySignal<int> get count => _count.readonly();
///
///   void increment() => _count.value++;
/// }
/// ```
abstract interface class Readonly<T> implements Readable<T> {
  /// Creates a constant read-only signal with a fixed value.
  ///
  /// The returned signal will always return the same value and cannot be modified.
  /// This is useful for creating immutable signals that don't change over time.
  ///
  /// Parameters:
  /// - [value]: The constant value for the signal
  ///
  /// Example:
  /// ```dart
  /// final constant = ReadonlySignal(42);
  /// print(constant.value); // Always 42
  /// ```
  const factory Readonly(T value) = ConstantImpl<T>;
}
