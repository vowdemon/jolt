import 'package:jolt/jolt.dart';

extension JoltWritableExtension<T> on WritableNode<T> {
  /// Updates the value using an updater function based on the current value.
  ///
  /// This method reads the current value using [peek] (without establishing
  /// a reactive dependency), passes it to the [updater] function, and then
  /// sets the new value using [set]. This is useful for updating values
  /// based on their current state without needing to manually read and write.
  ///
  /// **Implementation note:** This method internally calls [set] with the
  /// result of applying the [updater] function to the current value obtained
  /// via [peek].
  ///
  /// Parameters:
  /// - [updater]: A function that takes the current value and returns a new value
  ///
  /// Returns: The new value that was set
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(5);
  /// count.update((value) => value + 1); // count.value is now 6
  /// count.update((value) => value * 2); // count.value is now 12
  /// ```
  ///
  /// This is equivalent to:
  /// ```dart
  /// count.set(count.peek + 1);
  /// count.set(count.peek * 2);
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  T update(T Function(T value) updater) => set(updater(peek));
}

/// Extension methods for WritableComputed to provide additional functionality.
extension JoltWritableComputedExtension<T> on WritableComputed<T> {
  /// Returns a read-only view of this writable computed.
  ///
  /// The returned Computed cannot be used to modify the value,
  /// but still provides reactive access to the computed value.
  ///
  /// Returns: A read-only interface to this writable computed
  ///
  /// Example:
  /// ```dart
  /// final writableComputed = WritableComputed(getter, setter);
  /// final readonlyComputed = writableComputed.readonly();
  ///
  /// print(readonlyComputed.value); // OK
  /// // readonlyComputed.value = 1; // Compile error
  /// ```
  Computed<T> readonly() => this;
}

/// Extension methods for Signal to provide additional functionality.
extension JoltSignalExtension<T> on Signal<T> {
  /// Returns a read-only view of this signal.
  ///
  /// The returned ReadonlySignal cannot be used to modify the value,
  /// but still provides reactive access to the current value.
  ///
  /// Returns: A read-only interface to this signal
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final readonlyCounter = counter.readonly();
  ///
  /// print(readonlyCounter.value); // OK
  /// // readonlyCounter.value = 1; // Compile error
  /// ```
  ReadonlySignal<T> readonly() => this;
}
