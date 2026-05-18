import "dart:async";

import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("FutureSignal", () {
    test("should create FutureSignal", () async {
      final future = Future.value("hello");
      final futureSignal = AsyncSignal.fromFuture(future);

      expect(futureSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(futureSignal.value, isA<AsyncSuccess<String>>());
      expect(futureSignal.data, equals("hello"));
    });

    test("should handle Future error", () async {
      final future = Future<String>.error(Exception("Test error"));
      final futureSignal = AsyncSignal.fromFuture(future);

      expect(futureSignal.value, isA<AsyncLoading<String>>());

      await Future.delayed(const Duration(milliseconds: 1));

      expect(futureSignal.value, isA<AsyncError<String>>());
      expect(futureSignal.data, isNull);
    });

    test("should work with different data types", () async {
      final listFuture = Future.value([1, 2, 3]);
      final listSignal = AsyncSignal.fromFuture(listFuture);

      await Future.delayed(const Duration(milliseconds: 1));

      expect(listSignal.data, equals([1, 2, 3]));
    });
  });
}
