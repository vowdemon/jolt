import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Signal", () {
    test("should create signal with initial value", () {
      final signal = Signal(42);

      expect(signal.value, equals(42));
      expect(signal.peek, equals(42));
      expect(signal.toString(), equals("42"));
    });

    test("should update signal value", () {
      final signal = Signal(1);
      expect(signal.value, equals(1));

      signal.value = 2;
      expect(signal.value, equals(2));
      expect(signal.peek, equals(2));
    });

    test("should force update signal", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.notify();
      expect(values, equals([1, 1]));
    });

    test("notify re-runs every subscriber when value is unchanged", () {
      final signal = Signal(1);
      final first = <int>[];
      final second = <int>[];

      Effect(() => first.add(signal.value));
      Effect(() => second.add(signal.value));

      expect(first, equals([1]));
      expect(second, equals([1]));

      signal.notify();

      expect(first, equals([1, 1]));
      expect(second, equals([1, 1]));
    });

    test("should track signal in computed", () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.value, equals(10));

      signal.value = 10;
      expect(computed.value, equals(20));
    });

    test("should track signal in effect", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      signal.value = 3;
      expect(values, equals([1, 2, 3]));
    });

    test("should not rerun effect when writing same value", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.value = 1;
      signal.value = 1;

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));
    });

    group("disposed signal no longer reactive", () {
      test("disposed signal works as value container", () {
        final signal = Signal(42);

        signal.dispose();

        expect(signal.isDisposed, isTrue);
        expect(signal.value, equals(42));
        expect(signal.peek, equals(42));

        signal.value = 1;
        signal.notify();

        expect(signal.value, equals(1));
        expect(signal.peek, equals(1));
      });

      test("reading disposed signal inside effect does not subscribe", () {
        final signal = Signal(42)..dispose();
        final values = <int>[];
        final effect = Effect(() {
          values.add(signal.value);
        });

        expect(values, equals([42]));

        signal.value = 1;
        signal.notify();

        expect(signal.value, equals(1));
        expect(signal.peek, equals(1));
        expect(values, equals([42]),
            reason: "disposed signals should provide a snapshot only");

        effect.dispose();
      });

      test("disposed signal stays inert for existing effects", () {
        final signal = Signal(0);
        final values = <int>[];
        final effect = Effect(() {
          values.add(signal.value);
        });

        expect(values, equals([0]));

        signal.value = 1;
        expect(values, equals([0, 1]));

        signal.dispose();
        signal.value = 2;
        signal.notify();

        expect(signal.isDisposed, isTrue);
        expect(values, equals([0, 1]),
            reason: "disposed signals must not rerun existing effects");

        effect.dispose();
      });

      test("disposed signal stays inert for existing stream listeners",
          () async {
        final signal = Signal(1);
        final values = <int>[];
        final subscription = signal.stream.listen(values.add);

        signal.value = 2;
        await Future.delayed(const Duration(milliseconds: 1));
        expect(values, equals([2]));

        signal.dispose();
        signal.value = 3;
        signal.notify();
        await Future.delayed(const Duration(milliseconds: 1));

        expect(signal.isDisposed, isTrue);
        expect(values, equals([2]),
            reason: "disposed signals must not emit to existing listeners");

        await subscription.cancel();
      });
    });

    test("should handle rapid value changes", () {
      final signal = Signal(0);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      for (var i = 1; i <= 100; i++) {
        signal.value = i;
      }

      expect(values.length, equals(101));
      expect(values.last, equals(100));
    });

    test("should throw error when accessing uninitialized lazy signal", () {
      final lazySignal = Signal<int>.lazy();

      // Accessing uninitialized lazy signal should throw
      expect(() => lazySignal.value, throwsA(isA<TypeError>()));
      expect(() => lazySignal.peek, throwsA(isA<TypeError>()));

      // After setting a value, it should work
      lazySignal.value = 42;
      expect(lazySignal.value, equals(42));
      expect(lazySignal.peek, equals(42));
    });
  });
}
