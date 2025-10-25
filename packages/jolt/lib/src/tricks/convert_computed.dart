import 'package:jolt/jolt.dart';

class ConvertComputed<T, U> extends WritableComputed<T> {
  ConvertComputed(this.source,
      {required this.decode,
      required this.encode,
      super.initialValue,
      super.onDebug})
      : super(
          () => decode(source.value),
          (value) => source.value = encode(value),
        );
  final Signal<U> source;
  final T Function(U value) decode;
  final U Function(T value) encode;
}
