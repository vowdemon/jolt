import "dart:async";

import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("StreamSignal", () {
    test("should create StreamSignal", () async {
      final stream = Stream.value("hello");
      final streamSignal = AsyncSignal.fromStream(stream);

      expect(streamSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(streamSignal.value, isA<AsyncSuccess<String>>());
      expect(streamSignal.data, equals("hello"));
    });

    test("should handle Stream error", () async {
      final stream = Stream<String>.error(Exception("Test error"));
      final streamSignal = AsyncSignal.fromStream(stream);

      expect(streamSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(streamSignal.value, isA<AsyncError<String>>());
      expect(streamSignal.data, isNull);
    });

    test("should handle multiple stream values", () async {
      final stream = Stream.fromIterable(["hello", "world"]);
      final streamSignal = AsyncSignal.fromStream(stream);
      final values = <String>[];

      streamSignal.listen((state) {
        if (state.isSuccess) {
          values.add(state.data!);
        }
      }, immediately: true);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(values.length, greaterThanOrEqualTo(2));
      expect(values, contains("hello"));
      expect(values, contains("world"));
    });

    test("should cancel stream subscription on dispose", () async {
      final stream = Stream.periodic(const Duration(milliseconds: 1), (i) => i);
      final streamSignal = AsyncSignal.fromStream(stream);

      expect(streamSignal.value, isA<AsyncLoading<int>>());

      await Future.delayed(const Duration(milliseconds: 5));

      expect(streamSignal.value, isA<AsyncSuccess<int>>());

      streamSignal.dispose();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(streamSignal.data, isA<int>());
      expect(streamSignal.value, isA<AsyncSuccess<int>>());
    });
  });
}
