import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

/// Implementation of [ConvertComputed] that converts between different types.
///
/// This is the concrete implementation of the [ConvertComputed] interface.
/// ConvertComputed provides a way to create a computed signal that converts
/// between different types while maintaining reactivity. It acts as a bridge
/// between signals of different types, automatically handling the conversion
/// in both directions.
///
/// See [ConvertComputed] for the public interface and usage examples.
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
class ConvertComputedImpl<T, U> extends WritableComputedImpl<T>
    implements ConvertComputed<T, U> {
  /// Creates a type-converting computed signal.
  ///
  /// Parameters:
  /// - [source]: The source signal to convert from
  /// - [decode]: Function to convert from source type to target type
  /// - [encode]: Function to convert from target type to source type
  /// - [onDebug]: Optional debug callback
  ConvertComputedImpl(this.source,
      {required this.decode, required this.encode, super.onDebug})
      : super(
          () => decode(source.value),
          (value) => source.value = encode(value),
        );

  /// The source signal to convert from.
  final Writable<U> source;

  /// Function to convert from source type to target type.
  final T Function(U value) decode;

  /// Function to convert from target type to source type.
  final U Function(T value) encode;
}

/// Interface for type-converting computed signals.
///
/// ConvertComputed provides a way to create a computed signal that converts
/// between different types while maintaining reactivity. It acts as a bridge
/// between signals of different types, automatically handling the conversion
/// in both directions.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// ConvertComputed<String, int> textCount = ConvertComputed(
///   count,
///   decode: (int value) => value.toString(),
///   encode: (String value) => int.parse(value),
/// );
///
/// print(textCount.value); // "0"
/// textCount.value = "42"; // Updates count to 42
/// ```
abstract interface class ConvertComputed<T, U> implements WritableComputed<T> {
  /// Creates a type-converting computed signal.
  ///
  /// Parameters:
  /// - [source]: The source signal to convert from
  /// - [decode]: Function to convert from source type to target type
  /// - [encode]: Function to convert from target type to source type
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final convertComputed = ConvertComputed(
  ///   count,
  ///   decode: (int v) => v.toString(),
  ///   encode: (String v) => int.parse(v),
  /// );
  /// ```
  factory ConvertComputed(WritableNode<U> source,
      {required T Function(U value) decode,
      required U Function(T value) encode,
      JoltDebugFn? onDebug}) = ConvertComputedImpl<T, U>;
}
