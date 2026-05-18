import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("WritableComputed", () {
    test("should update value through setter", () {
      final signal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => signal.value,
        (value) => signal.value = value * 2,
      );

      expect(writableComputed.value, equals(5));
      expect(signal.value, equals(5));

      writableComputed.value = 10;
      expect(writableComputed.value, equals(20));
      expect(signal.value, equals(20));
    });
    test(
        "disposed writable computed keeps cached read and still delegates writes",
        () {
      final signal = Signal(1);
      final writableComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );

      expect(writableComputed.value, equals(2));

      writableComputed.dispose();
      signal.value = 2;
      expect(writableComputed.value, equals(2));

      writableComputed.value = 10;
      expect(signal.value, equals(5));
    });

    test("should handle setter errors gracefully", () {
      final signal = Signal(1);
      final writableComputed =
          WritableComputed<int>(() => signal.value * 2, (value) {
        if (value < 0) {
          throw ArgumentError("Value cannot be negative");
        }
        signal.value = value ~/ 2;
      });

      expect(writableComputed.value, equals(2));

      expect(
        () => writableComputed.value = -10,
        throwsA(isA<ArgumentError>()),
      );
      expect(signal.value, equals(1));
    });

    test("setter updating getter dependency triggers recompute", () {
      final signal = Signal(2);
      final writableComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );
      final values = <int>[];

      Effect(() {
        values.add(writableComputed.value);
      });

      expect(values, equals([4]));

      writableComputed.value = 10;
      expect(signal.value, equals(5));
      expect(values, equals([4, 10]));
    });

    test("setter without reactive writes does not trigger recompute", () {
      final signal = Signal(1);
      var plainValue = 0;
      final writableComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => plainValue = value,
      );
      final values = <int>[];

      Effect(() {
        values.add(writableComputed.value);
      });

      expect(writableComputed.value, equals(2));
      expect(values, equals([2]));

      writableComputed.value = 10;
      expect(plainValue, equals(10));
      expect(writableComputed.value, equals(2));
      expect(values, equals([2]));

      signal.value = 3;
      expect(writableComputed.value, equals(6));
      expect(values, equals([2, 6]));
    });

    test("withPrevious passes prior computed value to getter", () {
      final signal = Signal(1);
      final previousValues = <int?>[];
      final writable = WritableComputed.withPrevious(
        (int? previous) {
          previousValues.add(previous);
          return signal.value * 2;
        },
        (value) => signal.value = value ~/ 2,
      );

      expect(writable.value, equals(2));
      expect(previousValues, equals([null]));

      signal.value = 2;
      expect(writable.value, equals(4));
      expect(previousValues, equals([null, 2]));
    });

    test("setter writing unrelated signal does not trigger recompute", () {
      final source = Signal(1);
      final unrelated = Signal(0);
      final writableComputed = WritableComputed<int>(
        () => source.value * 2,
        (value) => unrelated.value = value,
      );
      final values = <int>[];

      Effect(() {
        values.add(writableComputed.value);
      });

      expect(writableComputed.value, equals(2));
      expect(values, equals([2]));

      writableComputed.value = 10;
      expect(unrelated.value, equals(10));
      expect(writableComputed.value, equals(2));
      expect(values, equals([2]));

      unrelated.value = 20;
      expect(writableComputed.value, equals(2));
      expect(values, equals([2]));

      source.value = 3;
      expect(writableComputed.value, equals(6));
      expect(values, equals([2, 6]));
    });
  });
}
