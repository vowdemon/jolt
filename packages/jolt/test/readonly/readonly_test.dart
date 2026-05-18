import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Readonly from Signal", () {
    test("readonly returns Readonly and reflects changes", () {
      final signal = Signal(42);
      final readonly = signal.readonly();

      expect(readonly, isA<Readonly<int>>());
      expect(readonly.value, equals(42));
      expect(readonly.peek, equals(42));

      signal.value = 10;
      expect(readonly.value, equals(10));
      expect(readonly.peek, equals(10));
    });

    test("readonly view establishes reactive dependency", () {
      final signal = Signal(0);
      final readonly = signal.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([0]));
      signal.value = 1;
      expect(values, equals([0, 1]));
    });

    test("readonly view toString returns value string", () {
      final signal = Signal(42);
      final readonly = signal.readonly();

      expect(readonly.toString(), equals("42"));

      signal.value = 100;
      expect(readonly.toString(), equals("100"));
    });

    test("readonly view equality and hashCode follow the root signal", () {
      final signal1 = Signal(5);
      final signal2 = Signal(5);
      final readonly1 = signal1.readonly();
      final readonly2 = signal1.readonly();
      final readonly3 = signal2.readonly();

      expect(readonly1 == readonly2, isTrue);
      expect(readonly1 == readonly3, isFalse);
      expect(readonly1.hashCode, equals(readonly2.hashCode));
    });
  });

  group("Readonly from WritableComputed", () {
    test("readonly view establishes reactive dependency", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();
      final values = <int>[];

      Effect(() {
        values.add(readonly.value);
      });

      expect(values, equals([10]));
      baseSignal.value = 10;
      expect(values, equals([10, 20]));
    });

    test("readonly view toString returns value string", () {
      final baseSignal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => baseSignal.value * 2,
        (value) => baseSignal.value = value ~/ 2,
      );
      final readonly = writableComputed.readonly();

      expect(readonly.toString(), equals("10"));

      writableComputed.value = 20;
      expect(readonly.toString(), equals("20"));
    });

    test(
        "readonly view equality and hashCode follow the root writable computed",
        () {
      final baseSignal1 = Signal(5);
      final baseSignal2 = Signal(5);
      final writableComputed1 = WritableComputed<int>(
        () => baseSignal1.value * 2,
        (value) => baseSignal1.value = value ~/ 2,
      );
      final writableComputed2 = WritableComputed<int>(
        () => baseSignal2.value * 2,
        (value) => baseSignal2.value = value ~/ 2,
      );
      final readonly1 = writableComputed1.readonly();
      final readonly2 = writableComputed1.readonly();
      final readonly3 = writableComputed2.readonly();

      expect(readonly1 == readonly2, isTrue);
      expect(readonly1 == readonly3, isFalse);
      expect(readonly1.hashCode, equals(readonly2.hashCode));
    });
  });
}
