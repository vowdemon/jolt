import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("JoltUtilsReadableExtension", () {
    group("call() and get() methods", () {
      test("return current value", () {
        final signal = Signal(42);
        expect(signal(), equals(42));
        expect(signal.get(), equals(42));
        expect(signal(), equals(signal.value));
        expect(signal.get(), equals(signal.value));
      });

      test("establish reactive dependency", () {
        final signal = Signal(0);
        final values = <int>[];

        Effect(() {
          values.add(signal()); // Using call()
        });

        expect(values, equals([0]));
        signal.value = 1;
        expect(values, equals([0, 1]));

        final signal2 = Signal(0);
        final values2 = <int>[];
        Effect(() {
          values2.add(signal2.get()); // Using get()
        });

        expect(values2, equals([0]));
        signal2.value = 1;
        expect(values2, equals([0, 1]));
      });

      test("work with nullable types", () {
        final nullableSignal = Signal<String?>(null);
        expect(nullableSignal(), isNull);
        expect(nullableSignal.get(), isNull);

        nullableSignal.value = "not null";
        expect(nullableSignal(), equals("not null"));
        expect(nullableSignal.get(), equals("not null"));
      });
    });

    group("derived() method", () {
      test("creates Computed and computes correctly", () {
        final signal = Signal(5);
        final derived = signal.derived((value) => value * 2);

        expect(derived, isA<Computed<int>>());
        expect(derived.value, equals(10));
      });

      test("reactively updates when source changes", () {
        final signal = Signal(5);
        final derived = signal.derived((value) => value * 2);
        final values = <int>[];

        Effect(() {
          values.add(derived.value);
        });

        expect(values, equals([10]));
        signal.value = 10;
        expect(values, equals([10, 20]));
      });

      test("supports type conversion", () {
        final intSignal = Signal(42);
        final stringDerived =
            intSignal.derived<String>((value) => value.toString());
        expect(stringDerived.value, equals("42"));
      });

      test("supports multiple derived from same source", () {
        final signal = Signal(10);
        final doubled = signal.derived((value) => value * 2);
        final tripled = signal.derived((value) => value * 3);

        expect(doubled.value, equals(20));
        expect(tripled.value, equals(30));

        signal.value = 5;
        expect(doubled.value, equals(10));
        expect(tripled.value, equals(15));
      });

      test("supports chained derived", () {
        final signal = Signal(2);
        final doubled = signal.derived((value) => value * 2);
        final quadrupled = doubled.derived((value) => value * 2);

        expect(quadrupled.value, equals(8));
        signal.value = 3;
        expect(quadrupled.value, equals(12));
      });

      test("works with nullable types", () {
        final nullableSignal = Signal<int?>(null);
        final derived = nullableSignal.derived<String?>((value) {
          return value?.toString();
        });

        expect(derived.value, isNull);
        nullableSignal.value = 42;
        expect(derived.value, equals("42"));
      });

      test("handles errors in computation function", () {
        final signal = Signal(0);
        final derived = signal.derived<int>((value) {
          if (value == 0) {
            throw Exception("Division by zero");
          }
          return 100 ~/ value;
        });

        expect(() => derived.value, throwsA(isA<Exception>()));
      });
    });

    group("Integration", () {
      test("extension methods work together", () {
        final signal = Signal(5);
        final derived = signal.derived((value) => value * 2);

        expect(signal(), equals(5));
        expect(signal.get(), equals(5));
        expect(derived(), equals(10));
        expect(derived.get(), equals(10));

        signal.value = 10;
        expect(derived(), equals(20));
        expect(derived.get(), equals(20));
      });

      test("works with Computed as source", () {
        final source = Signal(5);
        final computed = Computed<int>(() => source.value * 2);
        final derived = computed.derived((value) => value + 10);

        expect(derived.value, equals(20));
        source.value = 10;
        expect(derived.value, equals(30));
      });
    });
  });
}
