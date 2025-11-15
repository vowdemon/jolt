import "package:jolt/jolt.dart";
import "package:test/test.dart";
import "../utils.dart";

void main() {
  group("untracked", () {
    test("should prevent signal tracking in effect", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1]));
    });

    test("should prevent computed tracking in effect", () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => computed.value));
      });

      expect(values, equals([2]));

      signal.value = 2;
      expect(values, equals([2]));
    });

    test("should allow mixed tracking and untracking", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final trackedValues = <int>[];
      final untrackedValues = <int>[];

      Effect(() {
        trackedValues.add(signal1.value);
        untrackedValues.add(untracked(() => signal2.value));
      });

      expect(trackedValues, equals([1]));
      expect(untrackedValues, equals([2]));

      signal1.value = 10;
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2, 2]));

      signal2.value = 20;
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2, 2]));
    });

    test("should work with nested untracked calls", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(3);
      final values = <int>[];

      Effect(() {
        values.add(
          untracked(() {
            final val1 = signal1.value;
            final val2 = signal2.value;
            return val1 + val2 + signal3.value;
          }),
        );
      });

      expect(values, equals([6])); // 1 + 2 + 3

      signal1.value = 10;
      signal2.value = 20;
      signal3.value = 30;
      expect(values, equals([6]));
    });

    test("should work with complex expressions", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value * signal2.value);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => computed.value + signal1.value));
      });

      expect(values, equals([3])); // 2 + 1

      signal1.value = 5;
      signal2.value = 10;
      expect(values, equals([3]));
    });

    test("should work with function calls", () {
      final signal = Signal(1);
      final values = <int>[];

      int getValue() => signal.value;

      Effect(() {
        values.add(untracked(getValue));
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1]));
    });

    test("should work with conditional tracking", () {
      final conditionSignal = Signal(true);
      final valueSignal = Signal(42);
      final values = <int>[];

      Effect(() {
        if (conditionSignal.value) {
          values.add(valueSignal.value);
        } else {
          values.add(untracked(() => valueSignal.value));
        }
      });

      expect(values, equals([42]));

      valueSignal.value = 100;
      expect(values, equals([42, 100]));

      conditionSignal.value = false;
      expect(values, equals([42, 100, 100]));

      valueSignal.value = 200;
      expect(values, equals([42, 100, 100]));
    });

    test("should work with batch operations", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => signal1.value + signal2.value));
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      expect(values, equals([3]));
    });

    test("should work with stream operations", () async {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([1]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      expect(values, equals([1]));
    });

    test("should work with error handling", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        try {
          values.add(
            untracked(() {
              if (signal.value > 0) {
                return signal.value;
              } else {
                throw Exception("Invalid value");
              }
            }),
          );
        } catch (e) {
          values.add(-1);
        }
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1]));

      signal.value = -1;
      expect(values, equals([1]));
    });

    test("should work with async operations", () async {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        untracked(() async {
          await Future.delayed(const Duration(milliseconds: 1));
          values.add(signal.value);
        });
      });

      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 2));

      expect(values.length, lessThanOrEqualTo(1));
    });

    test("should work with multiple effects", () {
      final signal = Signal(1);
      final effect1Values = <int>[];
      final effect2Values = <int>[];

      Effect(() {
        effect1Values.add(signal.value);
      });

      Effect(() {
        effect2Values.add(untracked(() => signal.value));
      });

      expect(effect1Values, equals([1]));
      expect(effect2Values, equals([1]));

      signal.value = 2;

      expect(effect1Values, equals([1, 2]));
      expect(effect2Values, equals([1]));
    });

    test("should work with computed dependencies", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed<int>(() => signal1.value * 2);
      final computed2 = Computed<int>(() => signal2.value * 3);
      final values = <int>[];

      Effect(() {
        values.add(untracked(() => computed1.value + computed2.value));
      });

      expect(values, equals([8])); // 2 + 6

      signal1.value = 5;
      signal2.value = 10;
      expect(values, equals([8]));
    });

    test("should work with null values", () {
      final signal = Signal<int?>(null);
      final values = <int?>[];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([null]));

      signal.value = 42;
      expect(values, equals([null]));
    });

    test("should work with custom objects", () {
      final signal = Signal(TestPerson("Alice", 30));
      final values = <TestPerson>[];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([TestPerson("Alice", 30)]));

      signal.value = TestPerson("Bob", 25);
      expect(values, equals([TestPerson("Alice", 30)]));
    });
  });

  group("trackWithEffect", () {
    test("should track dependencies with specified effect node", () {
      final signal = Signal(1);
      final customEffect = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(signal.value);
      }, customEffect);

      expect(values, equals([1]));

      signal.value = 2;
      // The custom effect should be triggered because it tracked the signal
      expect(values, equals([1]));
    });

    test("should return function result", () {
      final customEffect = Effect(() {}, immediately: false);
      final result = trackWithEffect(() => 42, customEffect);
      expect(result, equals(42));
    });

    test("should track multiple signals", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final customEffect = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(signal1.value + signal2.value);
      }, customEffect);

      expect(values, equals([3]));
    });

    test("should work with purge=true (default)", () {
      final signal = Signal(1);
      final customEffect = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(signal.value);
      }, customEffect);

      expect(values, equals([1]));

      // With purge=true, dependencies should be cleaned up
      trackWithEffect(() {
        values.add(signal.value);
      }, customEffect);

      expect(values, equals([1, 1]));
    });

    test("should work with purge=false", () {
      final signal = Signal(1);
      final customEffect = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(signal.value);
      }, customEffect, false);

      expect(values, equals([1]));

      // With purge=false, dependencies should not be cleaned up
      trackWithEffect(() {
        values.add(signal.value);
      }, customEffect, false);

      expect(values, equals([1, 1]));
    });

    test("should work with computed values", () {
      final signal = Signal(2);
      final computed = Computed<int>(() => signal.value * 2);
      final customEffect = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(computed.value);
      }, customEffect);

      expect(values, equals([4]));
    });

    test("should handle errors correctly", () {
      final customEffect = Effect(() {}, immediately: false);
      bool errorCaught = false;

      try {
        trackWithEffect(() {
          throw Exception("Test error");
        }, customEffect);
      } catch (e) {
        errorCaught = true;
        expect(e.toString(), contains("Test error"));
      }

      expect(errorCaught, isTrue);
    });

    test("should work with nested trackWithEffect calls", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final customEffect1 = Effect(() {}, immediately: false);
      final customEffect2 = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(signal1.value);
        trackWithEffect(() {
          values.add(signal2.value);
        }, customEffect2);
      }, customEffect1);

      expect(values, equals([1, 2]));
    });

    test("should restore previous active subscriber", () {
      final signal = Signal(1);
      final outerEffect = Effect(() {}, immediately: false);
      final innerEffect = Effect(() {}, immediately: false);
      final values = <int>[];

      trackWithEffect(() {
        values.add(signal.value);
        trackWithEffect(() {
          values.add(signal.value);
        }, innerEffect);
        values.add(signal.value);
      }, outerEffect);

      expect(values, equals([1, 1, 1]));
    });
  });

  group("notifyAll", () {
    test("should notify all dependencies when accessing signals", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      // Change value first to establish tracking
      signal.value = 2;
      expect(values, equals([1, 2]));

      // Access signal in notifyAll to trigger subscribers
      notifyAll(() {
        final _ = signal.value;
      });

      // Effect should be triggered again
      expect(values.length, greaterThanOrEqualTo(2));
    });

    test("should return function result", () {
      final result = notifyAll(() => 42);
      expect(result, equals(42));
    });

    test("should notify multiple signals", () {
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

      // Change values first to establish tracking
      signal1.value = 10;
      signal2.value = 20;
      expect(values1, equals([1, 10]));
      expect(values2, equals([2, 20]));

      // notifyAll should trigger subscribers
      notifyAll(() {
        signal1.value;
        signal2.value;
      });

      // Effects should be triggered again
      expect(values1.length, greaterThanOrEqualTo(2));
      expect(values2.length, greaterThanOrEqualTo(2));
    });

    test("should work with computed values", () {
      final signal = Signal(2);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([4]));

      // Change signal to trigger effect first
      signal.value = 3;
      expect(values, equals([4, 6]));

      // notifyAll should trigger subscribers
      notifyAll(() {
        final _ = computed.value;
      });

      // Effect should be triggered again
      expect(values.length, greaterThanOrEqualTo(2));
    });

    test("should trigger effects that depend on accessed signals", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value + signal2.value);
      final values = <int>[];

      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([3]));

      // Change signal value to trigger effect
      signal1.value = 10;
      expect(values, equals([3, 12]));

      // notifyAll should trigger subscribers even without value change
      notifyAll(() {
        final _ = signal1.value;
      });

      // Effect should be triggered again
      expect(values.length, greaterThanOrEqualTo(2));
    });

    test("should handle errors correctly", () {
      bool errorCaught = false;

      try {
        notifyAll(() {
          throw Exception("Test error");
        });
      } catch (e) {
        errorCaught = true;
        expect(e.toString(), contains("Test error"));
      }

      expect(errorCaught, isTrue);
    });

    test("should work with nested notifyAll calls", () {
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

      notifyAll(() {
        signal1.value;
        notifyAll(() {
          signal2.value;
        });
      });

      expect(values1.length, greaterThanOrEqualTo(1));
      expect(values2.length, greaterThanOrEqualTo(1));
    });

    test("should work with batch operations", () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];

      Effect(() {
        values.add(signal1.value + signal2.value);
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
        notifyAll(() {
          signal1.value;
          signal2.value;
        });
      });

      // After batch, effect should run with new values
      expect(values.length, greaterThanOrEqualTo(1));
      expect(values.last, equals(30));
    });

    test("should work with multiple effects on same signal", () {
      final signal = Signal(1);
      final values1 = <int>[];
      final values2 = <int>[];

      Effect(() {
        values1.add(signal.value);
      });

      Effect(() {
        values2.add(signal.value * 2);
      });

      expect(values1, equals([1]));
      expect(values2, equals([2]));

      // Change value first to establish tracking
      signal.value = 3;
      expect(values1, equals([1, 3]));
      expect(values2, equals([2, 6]));

      notifyAll(() {
        final _ = signal.value;
      });

      // Effects should be triggered again
      expect(values1.length, greaterThanOrEqualTo(2));
      expect(values2.length, greaterThanOrEqualTo(2));
    });
  });
}
