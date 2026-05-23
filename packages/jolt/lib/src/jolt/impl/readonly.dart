import 'package:jolt/jolt.dart';

class ReadonlyImpl<T> implements Readonly<T>, Readable<T> {
  final Readable<T> raw;

  const ReadonlyImpl(this.raw);

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get peek => raw.peek;

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

/// [Readonly] views for writable [Signal] values.
extension JoltSignalReadonlyExtension<T> on Signal<T> {
  /// Returns a cached read-only view of this signal.
  ///
  /// The returned [Readonly] still tracks reads reactively, but it does not
  /// expose write APIs such as [Writable.value].
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

/// [Readonly] views for [Computed] values.
extension JoltComputedReadonlyExtension<T> on Computed<T> {
  /// Returns a cached read-only view of this computed value.
  ///
  /// Use this when callers should read the derived value without depending on
  /// the richer [Computed] interface.
  ///
  /// Example:
  /// ```dart
  /// final first = Signal('Ada');
  /// final last = Signal('Lovelace');
  /// final fullName = Computed(() => '${first.value} ${last.value}');
  /// final readonly = fullName.readonly();
  /// ```
  Readonly<T> readonly() {
    if (this is Readonly<T>) return this as Readonly<T>;
    return (_readonlys[this] ??= ReadonlyImpl(this)) as Readonly<T>;
  }
}

/// [Readonly] views for [WritableComputed] values.
extension JoltWritableComputedReadonlyExtension<T> on WritableComputed<T> {
  /// Returns a cached read-only view of this writable computed value.
  ///
  /// Use this when callers should observe the derived value but should not be
  /// able to assign through it.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final writableComputed = WritableComputed(
  ///   () => counter.value,
  ///   (value) => counter.value = value,
  /// );
  /// final readonly = writableComputed.readonly();
  /// ```
  Readonly<T> readonly() {
    if (this is Readonly<T>) return this as Readonly<T>;
    return (_readonlys[this] ??= ReadonlyImpl(this)) as Readonly<T>;
  }
}
