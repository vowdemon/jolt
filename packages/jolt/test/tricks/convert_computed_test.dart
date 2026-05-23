import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("ConvertComputed", () {
    test("decode and encode round-trip", () {
      final source = Signal("42");
      final converted = ConvertComputed<int, String>(
        source,
        decode: int.parse,
        encode: (value) => value.toString(),
      );

      expect(converted.value, equals(42));
      expect(source.value, equals("42"));

      converted.value = 100;
      expect(converted.value, equals(100));
      expect(source.value, equals("100"));
    });

    test("propagates source and encoded writes to dependents", () {
      final source = Signal("10");
      final converted = ConvertComputed<int, String>(
        source,
        decode: int.parse,
        encode: (value) => value.toString(),
      );

      final changes = <int>[];
      Effect(() {
        changes.add(converted.value);
      });

      expect(changes, equals([10]));

      source.value = "20";
      expect(changes, equals([10, 20]));

      converted.value = 30;
      expect(changes, equals([10, 20, 30]));
      expect(source.value, equals("30"));
    });

    test("bridges Writable source that is not a Signal", () {
      final base = Signal("1");
      final source = WritableComputed<String>(
        () => base.value,
        (value) => base.value = value,
      );
      final converted = ConvertComputed<int, String>(
        source,
        decode: int.parse,
        encode: (value) => value.toString(),
      );

      final changes = <int>[];
      Effect(() {
        changes.add(converted.value);
      });

      expect(changes, equals([1]));

      base.value = "5";
      expect(changes, equals([1, 5]));
      expect(source.value, equals("5"));

      converted.value = 9;
      expect(changes, equals([1, 5, 9]));
      expect(base.value, equals("9"));
    });

    test("decode failure surfaces on read", () {
      final source = Signal("invalid");
      final converted = ConvertComputed<int, String>(
        source,
        decode: int.parse,
        encode: (value) => value.toString(),
      );

      expect(() => converted.value, throwsA(isA<FormatException>()));
    });
  });
}
