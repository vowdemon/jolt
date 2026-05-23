import 'package:jolt/core.dart';
export 'package:jolt/core.dart'
    show JoltSignalReadonlyExtension, JoltComputedReadonlyExtension;

/// A read-only reactive view that exposes values without write APIs.
///
/// Use [Readonly] when callers should observe state owned elsewhere without
/// being able to assign to it directly.
///
/// Example:
/// ```dart
/// class Counter {
///   final _count = Signal(0);
///
///   Readonly<int> get count => _count.readonly();
///
///   void increment() => _count.value++;
/// }
/// ```
/// {@category Advanced Techniques}
abstract interface class Readonly<T> implements Readable<T> {
  /// Creates a constant read-only value.
  ///
  /// The returned [Readonly] always exposes [value] and never changes unless a
  /// new instance is created.
  const factory Readonly(T value) = ConstantImpl<T>;

  /// The current value without establishing a reactive dependency.
  @override
  T get peek;

  /// The current value using this view's normal read semantics.
  ///
  /// When this view wraps a reactive source, reading [value] still participates
  /// in dependency tracking.
  @override
  T get value;
}
