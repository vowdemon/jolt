import "package:jolt/core.dart";

/// Interface for computed reactive values.
///
/// Computed values are derived from other reactive values and automatically
/// update when their dependencies change. They are cached and only recompute
/// when necessary.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// Computed<int> doubled = Computed(() => count.value * 2);
/// print(doubled.value); // 0
/// count.value = 5;
/// print(doubled.value); // 10
/// ```
abstract interface class Computed<T>
    implements Readable<T>, Notifiable, DisposableNode {
  /// {@macro jolt_computed_impl}
  factory Computed(
    T Function() getter, {
    EqualFn? equals,
    JoltDebugOption? debug,
  }) = ComputedImpl;

  /// {@macro jolt_computed_impl_with_previous}
  factory Computed.withPrevious(
    T Function(T?) getter, {
    EqualFn? equals,
    JoltDebugOption? debug,
  }) = ComputedImpl.withPrevious;

  /// Recomputes this value and notifies subscribers only if the value changed.
  void notifySoft();
}

/// Interface for writable computed reactive values.
///
/// WritableComputed allows you to create computed values that can also be
/// set directly. When set, the setter function is called to update the
/// underlying dependencies.
///
/// Example:
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
///
/// WritableComputed<String> fullName = WritableComputed(
///   () => '${firstName.value} ${lastName.value}',
///   (value) {
///     final parts = value.split(' ');
///     firstName.value = parts[0];
///     lastName.value = parts[1];
///   },
/// );
/// ```
abstract interface class WritableComputed<T>
    implements Computed<T>, Writable<T> {
  /// {@macro jolt_writable_computed_impl}
  factory WritableComputed(
    T Function() getter,
    void Function(T) setter, {
    EqualFn? equals,
    JoltDebugOption? debug,
  }) = WritableComputedImpl<T>;

  /// {@macro jolt_writable_computed_impl_with_previous}
  factory WritableComputed.withPrevious(
    T Function(T?) getter,
    void Function(T) setter, {
    EqualFn? equals,
    JoltDebugOption? debug,
  }) = WritableComputedImpl.withPrevious;
}
