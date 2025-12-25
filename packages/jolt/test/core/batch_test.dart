import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:jolt/src/core/reactive.dart";
import "package:test/test.dart";

void main() {
  group("batch", () {
    test("should batch multiple signal updates", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value + signal2.value);

      final values = <int>[];
      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      expect(values, equals([3, 30]));
    });

    test("should batch multiple computed updates", () {
      final signal = Signal(1);
      final computed1 = Computed<int>(() => signal.value * 2);
      final computed2 = Computed<int>(() => signal.value * 3);
      final computed3 = Computed<int>(() => computed1.value + computed2.value);

      final values = <int>[];
      Effect(() {
        values.add(computed3.value);
      });

      expect(values, equals([5])); // 2 + 3

      batch(() {
        signal.value = 1;
        signal.value = 2;
      });

      expect(values, equals([5, 10])); // 4 + 6
    });

    test("should batch nested batch calls", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value + signal2.value);

      final values = <int>[];
      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        batch(() {
          signal2.value = 20;
          signal1.value = 15;
        });
        signal2.value = 25;
      });

      expect(values, equals([3, 40])); // 15 + 25
    });

    test("should handle batch with effects", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);

      final effect1Values = <int>[];
      final effect2Values = <int>[];

      Effect(() {
        effect1Values.add(signal1.value);
      });

      Effect(() {
        effect2Values.add(signal2.value);
      });

      expect(effect1Values, equals([1]));
      expect(effect2Values, equals([2]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      expect(effect1Values, equals([1, 10]));
      expect(effect2Values, equals([2, 20]));
    });

    test("should handle batch with stream emissions", () async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);

      final stream1Values = <int>[];
      final stream2Values = <int>[];

      signal1.stream.listen(stream1Values.add);
      signal2.stream.listen(stream2Values.add);

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      await Future.delayed(const Duration(milliseconds: 1));

      expect(stream1Values, equals([10]));
      expect(stream2Values, equals([20]));
    });

    test("should handle batch with conditional dependencies", () {
      final conditionSignal = Signal(true);
      final valueSignal = Signal(42);

      final computed = Computed<int>(() {
        if (conditionSignal.value) {
          return valueSignal.value;
        } else {
          return 0;
        }
      });

      final values = <int>[];
      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([42]));

      batch(() {
        conditionSignal.value = false;
        valueSignal.value = 100;
      });

      expect(values, equals([42, 0]));
    });

    test("should handle batch with error in function", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      expect(
          () => batch(() {
                signal.value = 2;
                throw Exception("Test error");
              }),
          throwsA(isA<Exception>()));

      expect(signal.value, equals(2));
      expect(values, equals([1, 2]));
    });

    test("should throw when reading disposed signal in batch", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value + signal2.value);

      final values = <int>[];
      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([3]));

      expect(
          () => batch(() {
                signal1.value = 10;
                signal1.dispose();
                signal2.value = 20;
              }),
          throwsA(isA<AssertionError>()));
    });

    test("should handle batch with rapid updates", () {
      final signal = Signal(0);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([0]));

      batch(() {
        for (var i = 1; i <= 100; i++) {
          signal.value = i;
        }
      });

      // Should only trigger one update during batch
      expect(values, equals([0, 100]));
    });

    test("should handle batch with dual computed", () {
      final signal = Signal(1);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );

      final values = <int>[];
      Effect(() {
        values.add(dualComputed.value);
      });

      expect(values, equals([2]));

      batch(() {
        dualComputed.value = 8;
        dualComputed.value = 12;
        dualComputed.value = 16;
      });

      // Should only trigger one update during batch
      expect(values, equals([2, 16]));
      expect(signal.value, equals(8));
    });

    test("should handle empty batch", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        // Empty batch
      });

      // Empty batch should not trigger any updates
      expect(values, equals([1]));
    });

    test("should handle batch with async operations", () async {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        signal.value = 2;
        // Execute async operation in batch
        Future.delayed(const Duration(milliseconds: 1), () {
          signal.value = 3;
        });
      });

      // Batch should complete immediately, async operation executes outside batch
      expect(values, equals([1, 2]));

      await Future.delayed(const Duration(milliseconds: 2));
      expect(values, equals([1, 2, 3]));
    });

    test("should handle sync part of async batch", () async {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      await batch(() async {
        signal.value = 20;
        signal.value = 2;
        await Future.microtask(() {});
        signal.value = 30;
        signal.value = 3;
      });

      expect(values, equals([1, 2, 30, 3]));

      await batch(() async {
        signal.value = 40;
        signal.value = 4;
        await Future.microtask(() {});
        batch(() {
          signal.value = 50;
          signal.value = 5;
        });
      });
      expect(values, equals([1, 2, 30, 3, 4, 5]));
    });

    group("getBatchDepth", () {
      test("should correctly track depth with multiple batch calls", () {
        expect(getBatchDepth(), equals(0));

        batch(() {
          expect(getBatchDepth(), equals(1));
        });

        expect(getBatchDepth(), equals(0));

        batch(() {
          expect(getBatchDepth(), equals(1));

          batch(() {
            expect(getBatchDepth(), equals(2));
          });

          expect(getBatchDepth(), equals(1));
        });

        expect(getBatchDepth(), equals(0));
      });

      test("should flush effects only when outermost batch completes", () {
        final signal = Signal(1);
        final values = <int>[];

        Effect(() {
          values.add(signal.value);
        });

        expect(values, equals([1]));

        batch(() {
          expect(getBatchDepth(), equals(1));
          signal.value = 10;

          batch(() {
            expect(getBatchDepth(), equals(2));
            signal.value = 20;
            // In nested batch, values should not be updated yet
            expect(values, equals([1]));
            expect(signal.value, equals(20));
          });

          expect(getBatchDepth(), equals(1));
          // Still in batch, values should not be updated yet
          expect(values, equals([1]));
          expect(signal.value, equals(20));

          signal.value = 30;
          expect(signal.value, equals(30));
        });

        // After outermost batch ends, depth should be 0, flush should have been executed
        expect(getBatchDepth(), equals(0));
        expect(values, equals([1, 30]));
      });

      test("should flush effects correctly after nested batch completes", () {
        final signal1 = Signal(1);
        final signal2 = Signal(2);
        final values1 = <int>[];
        final values2 = <int>[];

        Effect(() {
          values1.add(signal1.value);
        });

        Effect(() {
          values2.add(signal2.value);
        });

        expect(values1, equals([1]));
        expect(values2, equals([2]));

        batch(() {
          signal1.value = 10;
          expect(getBatchDepth(), equals(1));

          batch(() {
            signal2.value = 20;
            signal1.value = 15;
            expect(getBatchDepth(), equals(2));
            // In nested batch, values should not be updated yet
            expect(values1, equals([1]));
            expect(values2, equals([2]));
          });

          expect(getBatchDepth(), equals(1));
          signal2.value = 25;
          // Still in batch, values should not be updated yet
          expect(values1, equals([1]));
          expect(values2, equals([2]));
        });

        // After outermost batch ends, depth should be 0, flush should have been executed
        expect(getBatchDepth(), equals(0));
        expect(values1, equals([1, 15]));
        expect(values2, equals([2, 25]));
      });
    });
  });
}
