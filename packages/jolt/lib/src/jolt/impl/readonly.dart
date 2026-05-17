import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

/// Implementation of [Signal] that holds a value and notifies subscribers when it changes.
/// Base implementation of read-only signal for storing state and tracking dependencies.
class ReadonlyImpl<T> implements Readonly<T>, Readable<T> {
  final Readable<T> raw;

  /// Creates a new signal with the given initial value.
  ///
  /// Parameters:
  /// - [value]: The initial value of the signal
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final name = Signal('Alice');
  /// final counter = Signal(0);
  /// ```
  const ReadonlyImpl(this.raw);

  /// Returns the current value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity,
  /// such as in event handlers or side effects.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// print(counter.peek); // Doesn't create dependency
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get peek => raw.peek;

  /// Returns the current value and establishes a reactive dependency.
  ///
  /// When accessed within a reactive context (like a Computed or Effect),
  /// the context will be notified when this signal changes.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final doubled = Computed(() => counter.value * 2); // Creates dependency
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get value => raw.value;

  @override
  String toString() => value.toString();
}

class ConstantImpl<T> implements ReadonlyImpl<T> {
  final T _value;
  const ConstantImpl(T value) : _value = value;

  @override
  T get peek => _value;

  @override
  T get value => _value;

  @override
  String toString() => _value.toString();

  @override
  Readable<T> get raw => this;
}

final _readonlys = Expando<Object>();

/// Extension methods for Signal to provide additional functionality.
extension JoltSignalReadonlyExtension<T> on Signal<T> {
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
  Readonly<T> readonly() {
    if (this is Readonly<T>) return this as Readonly<T>;
    return (_readonlys[this] ??= ReadonlyImpl(this)) as Readonly<T>;
  }
}

extension JoltComputedReadonlyExtension<T> on Computed<T> {
  Readonly<T> readonly() {
    if (this is Readonly<T>) return this as Readonly<T>;
    return (_readonlys[this] ??= ReadonlyImpl(this)) as Readonly<T>;
  }
}

/// Extension methods for WritableComputed to provide additional functionality.
extension JoltWritableComputedReadonlyExtension<T> on WritableComputed<T> {
  Readonly<T> readonly() {
    if (this is Readonly<T>) return this as Readonly<T>;
    return (_readonlys[this] ??= ReadonlyImpl(this)) as Readonly<T>;
  }
}
