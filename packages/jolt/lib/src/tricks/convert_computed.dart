import 'package:jolt/jolt.dart';

/// A computed signal that converts between different types.
///
/// ConvertComputed provides a way to create a computed signal that converts
/// between different types while maintaining reactivity. It acts as a bridge
/// between signals of different types, automatically handling the conversion
/// in both directions.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// final textCount = ConvertComputed(
///   count,
///   decode: (int value) => value.toString(),
///   encode: (String value) => int.parse(value),
/// );
///
/// print(textCount.value); // "0"
/// textCount.value = "42"; // Updates count to 42
/// ```
class ConvertComputed<T, U> extends WritableComputed<T> {
  /// Creates a type-converting computed signal.
  ///
  /// Parameters:
  /// - [source]: The source signal to convert from
  /// - [decode]: Function to convert from source type to target type
  /// - [encode]: Function to convert from target type to source type
  /// - [initialValue]: Optional initial value for the computed
  /// - [onDebug]: Optional debug callback
  ConvertComputed(this.source,
      {required this.decode,
      required this.encode,
      super.initialValue,
      super.onDebug})
      : super(
          () => decode(source.value),
          (value) => source.value = encode(value),
        );

  /// The source signal to convert from.
  final Signal<U> source;

  /// Function to convert from source type to target type.
  final T Function(U value) decode;

  /// Function to convert from target type to source type.
  final U Function(T value) encode;
}
