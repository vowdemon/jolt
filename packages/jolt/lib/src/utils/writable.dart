import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

extension JoltUtilsWritableExtension<T> on Writable<T> {
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
  T update(T Function(T value) updater) => value = updater(peek);

  /// Sets the value.
  ///
  /// Same as assigning to [value] property.
  ///
  /// Parameters:
  /// - [value]: The new value to set
  ///
  /// Returns: The value that was set
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(5);
  /// count.set(10); // Same as count.value = 10
  /// ```
  T set(T value) => this.value = value;
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
  Computed<T> readonly() {
    return _ComputedWrapperImpl(this);
  }
}

class _ComputedWrapperImpl<T> implements Computed<T> {
  _ComputedWrapperImpl(this.root);

  final WritableComputed<T> root;

  @override
  T get peek => root.peek;

  @override
  T get value => root.value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _ComputedWrapperImpl<T> && root == other.root);
  }

  @override
  int get hashCode => Object.hashAll(['computedView', root.hashCode]);

  @override
  void dispose() => root.dispose();

  @override
  bool get isDisposed => root.isDisposed;

  @override
  void notify() => root.notify();

  @override
  T get peekCached => root.peekCached;
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
  ReadonlySignal<T> readonly() {
    return _ReadonlySignalWrapperImpl(this);
  }
}

class _ReadonlySignalWrapperImpl<T> implements ReadonlySignal<T> {
  _ReadonlySignalWrapperImpl(this.root);

  final Signal<T> root;

  @override
  T get peek => root.peek;

  @override
  T get value => root.value;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _ReadonlySignalWrapperImpl<T> && root == other.root);
  }

  @override
  int get hashCode => Object.hashAll(['readonlySignalView', root.hashCode]);

  @override
  void dispose() => root.dispose();

  @override
  bool get isDisposed => root.isDisposed;

  @override
  void notify() => root.notify();
}
