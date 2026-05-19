import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

class _ConvertComputedImpl<T, U> extends WritableComputedImpl<T>
    implements ConvertComputed<T, U> {
  _ConvertComputedImpl(
    this.source, {
    required this.decode,
    required this.encode,
    super.equals,
    super.debug,
  }) : super(
          () => decode(source.value),
          (value) => source.value = encode(value),
        );

  final Writable<U> source;

  final T Function(U value) decode;

  final U Function(T value) encode;
}

/// A writable computed value that converts through another writable source.
///
/// [ConvertComputed] reads from [source] through [decode] and writes back
/// through [encode]. Use it to expose one representation of state while storing
/// another.
abstract interface class ConvertComputed<T, U> implements WritableComputed<T> {
  /// Creates a writable computed value backed by [source].
  ///
  /// The [decode] callback converts values read from [source] into this
  /// computed value's type. The [encode] callback converts assigned values back
  /// into [source]'s type. Errors thrown by [decode] surface on reads, and
  /// errors thrown by [encode] surface on writes.
  ///
  /// ```dart
  /// final cents = Signal(1250);
  /// final dollars = ConvertComputed<String, int>(
  ///   cents,
  ///   decode: (value) => (value / 100).toStringAsFixed(2),
  ///   encode: (value) => (double.parse(value) * 100).round(),
  /// );
  ///
  /// dollars.value = '20.00';
  /// print(cents.value); // 2000
  /// ```
  factory ConvertComputed(
    Writable<U> source, {
    required T Function(U value) decode,
    required U Function(T value) encode,
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) = _ConvertComputedImpl<T, U>;
}
