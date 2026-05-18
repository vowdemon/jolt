import "package:jolt/jolt.dart";
import "package:jolt/tricks.dart";
import "package:test/test.dart";

void main() {
  group("ConvertComputed", () {
    test("Basic type conversion", () {
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

    test("Reactive updates through conversion", () {
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
      expect(converted.value, equals(20));

      converted.value = 30;
      expect(changes, equals([10, 20, 30]));
      expect(source.value, equals("30"));
    });

    test("Complex type conversion", () {
      final source = Signal({"name": "Alice", "age": "25"});
      final converted = ConvertComputed<Map<String, dynamic>, Map<String, String>>(
        source,
        decode: (value) => {
          "name": value["name"],
          "age": int.parse(value["age"]!),
        },
        encode: (value) => {
          "name": value["name"]!,
          "age": value["age"].toString(),
        },
      );

      expect(converted.value, equals({"name": "Alice", "age": 25}));

      converted.value = {"name": "Bob", "age": 30};
      expect(source.value, equals({"name": "Bob", "age": "30"}));
    });

    test("Error handling in conversion", () {
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
