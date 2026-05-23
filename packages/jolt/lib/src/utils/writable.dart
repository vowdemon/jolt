import 'package:jolt/core.dart';

/// Extension methods for [Writable] values.
extension JoltUtilsWritableExtension<T> on Writable<T> {
  /// Sets a new value derived from the current value.
  ///
  /// The [updater] callback receives [peek], not [Readable.value], so this read
  /// does not establish a dependency in the current reactive context. Returns
  /// the value that was assigned.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  T update(T Function(T value) updater) => value = updater(peek);

  /// Sets [value] and returns it.
  ///
  /// This is method syntax for assigning through [Writable.value].
  T set(T value) => this.value = value;
}
