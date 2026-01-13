import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("Computed", () {
    group("initial value", () {
      test("should have peek initialize value when initialValue is null", () {
        final computed = Computed<int>(() => 10);
        expect(computed.peek, equals(10));
        expect(computed.value, equals(10));
      });

      test("should treat peek as untracked", () {
        final signal = Signal(1);
        final computed = Computed<int>(() => signal.value * 2);
        Effect(() {
          computed.peekCached;
        });

        expect(computed.peekCached, equals(2));
        expect(computed.value, equals(2));

        signal.value = 2;
        expect(computed.peekCached, equals(2));
        expect(computed.value, equals(4));
      });

      test("peekCached should return cached value when available", () {
        final signal = Signal(1);
        var computeCount = 0;
        final computed = Computed<int>(() {
          computeCount++;
          return signal.value * 2;
        });

        // First access - no cache, should compute
        expect(computed.peekCached, equals(2));
        expect(computeCount, equals(1));

        // Second access with cached value - should return cache without recomputing
        expect(computed.peekCached, equals(2));
        expect(computeCount, equals(1)); // Count should not increase

        // Accessing value will update it and invalidate cache
        signal.value = 2;
        expect(computed.value, equals(4));
        expect(computeCount, equals(2));

        // peekCached should now return the cached value (4)
        expect(computed.peekCached, equals(4));
        expect(computeCount, equals(2)); // Still no recompute
      });

      test("peekCached should compute only when no cache exists", () {
        final computed = Computed<int>(() => 10);

        // First access - no cache, computes
        expect(computed.peekCached, equals(10));

        // Subsequent accesses return cache without computing
        expect(computed.peekCached, equals(10));
        expect(computed.peekCached, equals(10));
      });

      test("peekCached should not establish reactive dependency", () {
        final signal = Signal(1);
        final computed = Computed<int>(() => signal.value * 2);
        final values = <int>[];

        Effect(() {
          values.add(computed.peekCached);
        });

        expect(values, equals([2]));

        // Changing signal should not trigger effect because peekCached doesn't track
        signal.value = 3;
        expect(values, equals([2])); // Effect not triggered

        // peekCached still returns old cached value
        expect(computed.peekCached, equals(2));
      });

      test("peek vs peekCached difference", () {
        final signal = Signal(1);
        var computeCount = 0;
        final computed = Computed<int>(() {
          computeCount++;
          return signal.value * 2;
        });

        // Initial state - both should compute
        expect(computed.peek, equals(2));
        expect(computeCount, equals(1));
        expect(computed.peekCached, equals(2));
        expect(computeCount, equals(1)); // peekCached uses cache from peek

        // Change signal
        signal.value = 3;

        // peek always recomputes (if needed), so it gets fresh value
        expect(computed.peek, equals(6));
        expect(computeCount, equals(2)); // Recomputed

        // peekCached returns cached value (from previous peek call)
        expect(computed.peekCached, equals(6));
        expect(computeCount, equals(2)); // No recompute, uses cache

        // Change signal again
        signal.value = 4;

        // peekCached still returns stale cached value
        expect(computed.peekCached, equals(6));
        expect(computeCount, equals(2)); // Still no recompute

        // peek recomputes and gets fresh value
        expect(computed.peek, equals(8));
        expect(computeCount, equals(3)); // Recomputed

        // Now peekCached gets fresh cache
        expect(computed.peekCached, equals(8));
        expect(computeCount, equals(3)); // No recompute
      });
    });

    test("should create computed with getter function", () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.value, equals(10));
      expect(computed.peek, equals(10));
    });

    test("should support call() method that returns same as get()", () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed(), equals(10));
      expect(computed(), equals(computed.get()));
      expect(computed(), equals(computed.value));

      signal.value = 3;
      expect(computed(), equals(6));
      expect(computed(), equals(computed.get()));
      expect(computed(), equals(computed.value));
    });

    test("should update when dependencies change", () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value + 1);

      expect(computed.value, equals(2));

      signal.value = 5;
      expect(computed.value, equals(6));
    });

    test("should work with multiple dependencies", () {
      final signal1 = Signal(2);
      final signal2 = Signal(3);
      final computed = Computed<int>(() => signal1.value * signal2.value);

      expect(computed.value, equals(6));

      signal1.value = 4;
      expect(computed.value, equals(12));

      signal2.value = 5;
      expect(computed.value, equals(20));
    });

    test("should track computed in effect", () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([2]));

      signal.value = 3;
      expect(values, equals([2, 6]));
    });

    test("should emit stream events", () async {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      computed.stream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([4]));
    });

    test("should work with different data types", () {
      final stringSignal = Signal("hello");
      final computed = Computed<String>(
        () => stringSignal.value.toUpperCase(),
      );

      expect(computed.value, equals("HELLO"));

      stringSignal.value = "world";
      expect(computed.value, equals("WORLD"));
    });

    test("should work with nullable values", () {
      final signal = Signal<int?>(null);
      final computed = Computed<String>(
        () => signal.value?.toString() ?? "null",
      );

      expect(computed.value, equals("null"));

      signal.value = 42;
      expect(computed.value, equals("42"));
    });

    test("should handle complex computations", () {
      final listSignal = Signal<List<int>>([1, 2, 3]);
      final computed = Computed<int>(
        () => listSignal.value.fold(0, (sum, item) => sum + item),
      );

      expect(computed.value, equals(6));

      listSignal.value = [4, 5, 6, 7];
      expect(computed.value, equals(22));
    });

    test("should work with nested computed", () {
      final signal = Signal(2);
      final computed1 = Computed<int>(() => signal.value * 2);
      final computed2 = Computed<int>(() => computed1.value + 1);

      expect(computed1.value, equals(4));
      expect(computed2.value, equals(5));

      signal.value = 3;
      expect(computed1.value, equals(6));
      expect(computed2.value, equals(7));
    });

    test(
      "should throw ComputedAssertionError when accessing disposed computed",
      () async {
        final signal = Signal(1);
        final computed = Computed<int>(() => signal.value * 2);

        expect(computed.value, equals(2));

        computed.dispose();
        expect(() => computed.value, throwsA(isA<AssertionError>()));
      },
    );

    test("should work with batch updates", () {
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

    test("should handle conditional dependencies", () {
      final conditionSignal = Signal(true);
      final valueSignal = Signal(42);
      final computed = Computed<int>(() {
        if (conditionSignal.value) {
          return valueSignal.value;
        } else {
          return 0;
        }
      });

      expect(computed.value, equals(42));

      conditionSignal.value = false;
      expect(computed.value, equals(0));

      valueSignal.value = 100;
      expect(computed.value, equals(0));

      conditionSignal.value = true;
      expect(computed.value, equals(100));
    });
  });

  group("DualComputed", () {
    test("should create dual computed with getter and setter", () {
      final signal = Signal(5);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );

      expect(dualComputed.value, equals(10));
    });

    test("should update value through setter", () {
      final signal = Signal(5);
      final dualComputed = WritableComputed<int>(
        () => signal.value,
        (value) => signal.value = value * 2,
      );

      expect(dualComputed.value, equals(5));
      expect(signal.value, equals(5));

      dualComputed.value = 10;
      expect(dualComputed.value, equals(20));
      expect(signal.value, equals(20));
    });

    test("should use set method to update value", () {
      final signal = Signal(3);
      final dualComputed = WritableComputed<int>(
        () => signal.value,
        (value) => signal.value = value * 3,
      );

      expect(dualComputed.value, equals(3));

      dualComputed.set(15);
      expect(dualComputed.peekCached, equals(3));
      expect(dualComputed.value, equals(45));
      expect(signal.value, equals(45));
    });

    test("should track dual computed in effect", () {
      final signal = Signal(2);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );
      final values = <int>[];

      Effect(() {
        values.add(dualComputed.value);
      });

      expect(values, equals([4]));

      signal.value = 6;
      expect(values, equals([4, 12]));
    });

    test("should emit stream events", () async {
      final signal = Signal(1);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );
      final values = <int>[];

      dualComputed.stream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([6]));
    });

    test("should work with string transformations", () {
      final signal = Signal("hello");
      final dualComputed = WritableComputed<String>(
        () => signal.value.toUpperCase(),
        (value) => signal.value = value.toLowerCase(),
      );

      expect(dualComputed.value, equals("HELLO"));

      dualComputed.value = "WORLD";
      expect(dualComputed.value, equals("WORLD"));
      expect(signal.value, equals("world"));
    });

    test("should handle complex transformations", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      final dualComputed = WritableComputed<int>(
        () => signal.value.length,
        (value) => signal.value = List.generate(value, (i) => i + 1),
      );

      expect(dualComputed.value, equals(3));

      dualComputed.value = 5;
      expect(dualComputed.value, equals(5));
      expect(signal.value, equals([1, 2, 3, 4, 5]));
    });

    test(
      "should throw ComputedAssertionError when accessing disposed dual computed",
      () {
        final signal = Signal(1);
        final dualComputed = WritableComputed<int>(
          () => signal.value * 2,
          (value) => signal.value = value ~/ 2,
        );

        expect(dualComputed.value, equals(2));

        dualComputed.dispose();
        expect(() => dualComputed.value, throwsA(isA<AssertionError>()));
        expect(
          () => dualComputed.value = 10,
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test("should work with batch updates", () {
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
        dualComputed
          ..value = 8
          ..value = 12;
      });

      expect(values, equals([2, 12]));
      expect(signal.value, equals(6));
    });

    test("should handle setter errors gracefully", () {
      final signal = Signal(1);
      final dualComputed =
          WritableComputed<int>(() => signal.value * 2, (value) {
        if (value < 0) {
          throw ArgumentError("Value cannot be negative");
        }
        signal.value = value ~/ 2;
      });

      expect(dualComputed.value, equals(2));

      expect(() => dualComputed.value = -10, throwsA(isA<ArgumentError>()));
      expect(signal.value, equals(1));
    });

    test("computed notify times", () {
      final firstName = Signal("John");
      final lastName = Signal("Doe");
      final fullName = WritableComputed(
        () => "${firstName.value} ${lastName.value}",
        (value) {
          final parts = value.split(" ");
          if (parts.length >= 2) {
            firstName.value = parts[0];
            lastName.value = parts.sublist(1).join(" ");
          }
        },
      );
      var count = 0;
      Effect(() {
        fullName.value;
        count++;
      });
      expect(count, equals(1));
      firstName.value = "Jane";
      expect(count, equals(2));
      lastName.value = "Smith";
      expect(count, equals(3));
      fullName.value = "Jane1 Smith2";
      expect(count, equals(4));
    });

    test("should return Computed type after readonly", () {
      final signal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );

      expect(writableComputed.value, equals(10));

      final readonlyComputed = writableComputed.readonly();

      expect(readonlyComputed, isA<Computed<int>>());
      expect(readonlyComputed.value, equals(10));

      signal.value = 6;
      expect(readonlyComputed.value, equals(12));
    });
  });

  group("Computed.withPrevious", () {
    test("should pass null as previous value on first computation", () {
      final signal = Signal(5);
      int? previousValue;
      final computed = Computed<int>.withPrevious((prev) {
        previousValue = prev;
        return signal.value * 2;
      });

      expect(computed.value, equals(10));
      expect(previousValue, isNull);
    });

    test("should work with nullable types", () {
      final signal = Signal<int?>(null);
      final previousValues = <int?>[];
      final computed = Computed<int?>.withPrevious((prev) {
        previousValues.add(prev);
        return signal.value;
      });

      expect(computed.value, isNull);
      expect(previousValues, equals([null]));

      signal.value = 42;
      expect(computed.value, equals(42));
      expect(previousValues, equals([null, null]));

      signal.value = 100;
      expect(computed.value, equals(100));
      expect(previousValues, equals([null, null, 42]));
    });

    test("should work with complex calculations using previous value", () {
      final signal = Signal(1);
      final computed = Computed<int>.withPrevious((prev) {
        if (prev == null) {
          return signal.value;
        } else {
          return prev + signal.value;
        }
      });

      expect(computed.value, equals(1));

      signal.value = 2;
      expect(computed.value, equals(3)); // 1 + 2

      signal.value = 3;
      expect(computed.value, equals(6)); // 3 + 3

      signal.value = 4;
      expect(computed.value, equals(10)); // 6 + 4
    });

    test("should remain stable when new object has same value as previous", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final computed = Computed<List<int>>.withPrevious((prev) {
        computeCount++;
        final newList = List<int>.from(signal.value);

        if (prev != null &&
            prev.length == newList.length &&
            prev.every((item) => newList.contains(item)) &&
            newList.every((item) => prev.contains(item))) {
          return prev;
        }

        return newList;
      });

      Effect(() {
        effectValues.add(List<int>.from(computed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));
      expect(effectValues.last, equals([1, 2, 3]));

      signal.value = [1, 2, 3];
      expect(computeCount, equals(2));
      expect(effectValues.length, equals(1));
      expect(computed.value, equals([1, 2, 3]));

      signal.value = [4, 5, 6];
      expect(computeCount, equals(3));
      expect(effectValues.length, equals(2));
      expect(effectValues.last, equals([4, 5, 6]));

      signal.value = [4, 5, 6];
      expect(computeCount, equals(4));
      expect(effectValues.length, equals(2));
    });
  });
  group("WritableComputed.withPrevious", () {
    test("should pass null as previous value on first computation", () {
      final signal = Signal(5);
      int? previousValue;
      final writableComputed = WritableComputed<int>.withPrevious(
        (prev) {
          previousValue = prev;
          return signal.value * 2;
        },
        (value) => signal.value = value ~/ 2,
      );

      expect(writableComputed.value, equals(10));
      expect(previousValue, isNull);
    });

    test("should work with complex calculations using previous value", () {
      final signal = Signal(1);
      final previousValues = <int?>[];
      final writableComputed = WritableComputed<int>.withPrevious(
        (prev) {
          previousValues.add(prev);
          if (prev == null) {
            return signal.value;
          } else {
            return prev + signal.value;
          }
        },
        (value) {
          // Simple setter: set signal to a fixed value
          // This tests that setter works, even if the logic is simple
          signal.value = 5;
        },
      );

      expect(writableComputed.value, equals(1));
      expect(previousValues, equals([null]));

      signal.value = 2;
      expect(writableComputed.value, equals(3)); // 1 + 2
      expect(previousValues, equals([null, 1]));

      signal.value = 3;
      expect(writableComputed.value, equals(6)); // 3 + 3
      expect(previousValues, equals([null, 1, 3]));

      writableComputed.value = 10;
      expect(signal.value, equals(5)); // Setter sets signal to 5
      expect(writableComputed.value, equals(11)); // 6 + 5 = 11
      expect(previousValues, equals([null, 1, 3, 6]));
    });
  });

  group("toString", () {
    test("should return value.toString() in toString", () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.toString(), equals("10"));
      expect(computed.toString(), equals(computed.value.toString()));

      signal.value = 6;
      expect(computed.toString(), equals("12"));
      expect(computed.toString(), equals(computed.value.toString()));

      final stringSignal = Signal("hello");
      final stringComputed =
          Computed<String>(() => stringSignal.value.toUpperCase());

      expect(stringComputed.toString(), equals("HELLO"));
      expect(stringComputed.toString(), equals(stringComputed.value));

      stringSignal.value = "world";
      expect(stringComputed.toString(), equals("WORLD"));
      expect(stringComputed.toString(), equals(stringComputed.value));
    });

    test("should return value.toString() in toString for WritableComputed", () {
      final signal = Signal(5);
      final writableComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );

      expect(writableComputed.toString(), equals("10"));
      expect(writableComputed.toString(),
          equals(writableComputed.value.toString()));

      signal.value = 6;
      expect(writableComputed.toString(), equals("12"));
      expect(writableComputed.toString(),
          equals(writableComputed.value.toString()));

      writableComputed.value = 20;
      expect(writableComputed.toString(), equals("20"));
      expect(writableComputed.toString(),
          equals(writableComputed.value.toString()));
    });
  });

  group("Computed equals", () {
    test("should use custom equals function to prevent unnecessary updates",
        () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final computed = Computed<List<int>>(
        () {
          computeCount++;
          return List<int>.from(signal.value);
        },
        equals: (a, b) {
          if (a is! List<int> || b is! List<int>) return a == b;
          if (a.length != b.length) return false;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
          }
          return true;
        },
      );

      Effect(() {
        effectValues.add(List<int>.from(computed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));
      expect(effectValues.last, equals([1, 2, 3]));

      // Set to a new list with same values - equals should return true
      signal.value = [1, 2, 3];
      expect(computeCount, equals(2)); // Computed again
      expect(effectValues.length, equals(1)); // Effect not triggered
      expect(computed.value, equals([1, 2, 3]));

      // Set to different values - equals should return false
      signal.value = [4, 5, 6];
      expect(computeCount, equals(3));
      expect(effectValues.length, equals(2)); // Effect triggered
      expect(effectValues.last, equals([4, 5, 6]));
    });

    test("should use default == comparison when equals is not provided", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final computed = Computed<List<int>>(() {
        computeCount++;
        return List<int>.from(signal.value);
      });

      Effect(() {
        effectValues.add(List<int>.from(computed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));

      // New list with same values - default == will return false (different instances)
      signal.value = [1, 2, 3];
      expect(computeCount, equals(2));
      expect(effectValues.length,
          equals(2)); // Effect triggered (different instances)
    });

    test("should work with equals for primitive types", () {
      final signal = Signal(5);
      var effectCount = 0;

      final computed = Computed<int>(
        () => signal.value,
        equals: (a, b) => (a as int).abs() == (b as int).abs(),
      );

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));

      // Set to -5, equals should return true (same absolute value)
      signal.value = -5;
      expect(effectCount, equals(1)); // Effect not triggered

      // Set to 10, equals should return false
      signal.value = 10;
      expect(effectCount, equals(2)); // Effect triggered
    });

    test("should work with equals in Computed.withPrevious", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final computed = Computed<List<int>>.withPrevious(
        (prev) {
          computeCount++;
          final newList = List<int>.from(signal.value);
          // Return previous if equals says they're the same
          if (prev != null) {
            bool equalsFn(a, b) {
              if (a is! List<int> || b is! List<int>) return a == b;
              if (a.length != b.length) return false;
              for (var i = 0; i < a.length; i++) {
                if (a[i] != b[i]) return false;
              }
              return true;
            }

            if (equalsFn(newList, prev)) {
              return prev;
            }
          }
          return newList;
        },
        equals: (a, b) {
          if (a is! List<int> || b is! List<int>) return a == b;
          if (a.length != b.length) return false;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
          }
          return true;
        },
      );

      Effect(() {
        effectValues.add(List<int>.from(computed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));

      // Set to same values
      signal.value = [1, 2, 3];
      expect(computeCount, equals(2));
      expect(effectValues.length, equals(1)); // Effect not triggered

      // Set to different values
      signal.value = [4, 5, 6];
      expect(computeCount, equals(3));
      expect(effectValues.length, equals(2)); // Effect triggered
    });
  });

  group("WritableComputed equals", () {
    test("should use custom equals function to prevent unnecessary updates",
        () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final writableComputed = WritableComputed<List<int>>(
        () {
          computeCount++;
          return List<int>.from(signal.value);
        },
        (value) => signal.value = List<int>.from(value),
        equals: (a, b) {
          if (a is! List<int> || b is! List<int>) return a == b;
          if (a.length != b.length) return false;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
          }
          return true;
        },
      );

      Effect(() {
        effectValues.add(List<int>.from(writableComputed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));

      // Set to same values
      signal.value = [1, 2, 3];
      expect(computeCount, equals(2));
      expect(effectValues.length, equals(1)); // Effect not triggered

      // Set to different values
      signal.value = [4, 5, 6];
      expect(computeCount, equals(3));
      expect(effectValues.length, equals(2)); // Effect triggered
    });

    test("should work with equals when setting value", () {
      final signal = Signal(5);
      var effectCount = 0;

      final writableComputed = WritableComputed<int>(
        () => signal.value,
        (value) => signal.value = value,
        equals: (a, b) => (a as int).abs() == (b as int).abs(),
      );

      Effect(() {
        writableComputed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));

      // Set to -5, equals should return true
      writableComputed.value = -5;
      expect(effectCount, equals(1)); // Effect not triggered
      expect(signal.value, equals(-5));

      // Set to 10, equals should return false
      writableComputed.value = 10;
      expect(effectCount, equals(2)); // Effect triggered
      expect(signal.value, equals(10));
    });

    test("should work with equals in WritableComputed.withPrevious", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final effectValues = <List<int>>[];

      final writableComputed = WritableComputed<List<int>>.withPrevious(
        (prev) {
          computeCount++;
          final newList = List<int>.from(signal.value);
          if (prev != null) {
            bool equalsFn(a, b) {
              if (a is! List<int> || b is! List<int>) return a == b;
              if (a.length != b.length) return false;
              for (var i = 0; i < a.length; i++) {
                if (a[i] != b[i]) return false;
              }
              return true;
            }

            if (equalsFn(newList, prev)) {
              return prev;
            }
          }
          return newList;
        },
        (value) => signal.value = List<int>.from(value),
        equals: (a, b) {
          if (a is! List<int> || b is! List<int>) return a == b;
          if (a.length != b.length) return false;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
          }
          return true;
        },
      );

      Effect(() {
        effectValues.add(List<int>.from(writableComputed.value));
      });

      expect(computeCount, equals(1));
      expect(effectValues.length, equals(1));

      // Set to same values
      signal.value = [1, 2, 3];
      expect(computeCount, equals(2));
      expect(effectValues.length, equals(1)); // Effect not triggered

      // Set to different values
      signal.value = [4, 5, 6];
      expect(computeCount, equals(3));
      expect(effectValues.length, equals(2)); // Effect triggered
    });
  });

  group("Computed.getPeek", () {
    test("should return pending value when called inside computed getter", () {
      final signal = Signal(5);
      int? capturedValue;

      final computed = Computed<int>(() {
        signal.value; // Track dependency
        capturedValue = Computed.getPeek<int>();
        return signal.value * 2;
      });

      // First access - getPeek should return null (no previous value)
      expect(computed.value, equals(10));
      expect(capturedValue, isNull);

      // Second access - getPeek should return previous pending value
      signal.value = 6;
      expect(computed.value, equals(12));
      expect(capturedValue, equals(10)); // Previous value was 10
    });

    test("should throw StateError when called outside computed context", () {
      expect(
        () => Computed.getPeek<int>(),
        throwsA(isA<StateError>()),
      );
    });

    test("should work with nullable types", () {
      final signal = Signal<int?>(null);
      int? capturedValue;

      final computed = Computed<int?>(() {
        signal.value;
        capturedValue = Computed.getPeek<int?>();
        return signal.value;
      });

      // First access
      expect(computed.value, isNull);
      expect(capturedValue, isNull);

      // Second access
      signal.value = 42;
      expect(computed.value, equals(42));
      expect(capturedValue, isNull); // Previous was null
    });

    test("should work with complex types", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      List<int>? capturedValue;

      final computed = Computed<List<int>>(() {
        signal.value;
        capturedValue = Computed.getPeek<List<int>>();
        return List<int>.from(signal.value);
      });

      // First access
      expect(computed.value, equals([1, 2, 3]));
      expect(capturedValue, isNull);

      // Second access
      signal.value = [4, 5, 6];
      expect(computed.value, equals([4, 5, 6]));
      expect(capturedValue, equals([1, 2, 3])); // Previous value
    });

    test("should work with Computed.withPrevious", () {
      final signal = Signal(5);
      int? capturedValue;

      final computed = Computed<int>.withPrevious((prev) {
        signal.value;
        capturedValue = Computed.getPeek<int>();
        // getPeek should return the same as prev parameter
        return signal.value * 2;
      });

      // First access
      expect(computed.value, equals(10));
      expect(capturedValue, isNull);

      // Second access
      signal.value = 6;
      expect(computed.value, equals(12));
      expect(capturedValue, equals(10)); // Previous value
    });

    test("should work in nested computed", () {
      final signal = Signal(2);
      int? outerValue;
      int? innerValue;

      final inner = Computed<int>(() {
        signal.value;
        innerValue = Computed.getPeek<int>();
        return signal.value * 2;
      });

      final outer = Computed<int>(() {
        inner.value;
        outerValue = Computed.getPeek<int>();
        return inner.value * 2;
      });

      // First access
      expect(outer.value, equals(8)); // 2 * 2 * 2
      expect(innerValue, isNull);
      expect(outerValue, isNull);

      // Second access
      signal.value = 3;
      expect(outer.value, equals(12)); // 3 * 2 * 2
      expect(innerValue, equals(4)); // Previous inner value (2 * 2)
      expect(outerValue, equals(8)); // Previous outer value
    });
  });

  group("Computed notify force", () {
    test("should not notify subscribers when soft update and value unchanged",
        () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value);
      var effectCount = 0;

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));
      expect(computed.value, equals(5));

      // Soft update (force=false) - value hasn't changed, should not notify
      computed.notify(false);
      expect(effectCount, equals(1)); // Effect not triggered

      // Change signal to make computed value change
      signal.value = 10;
      expect(computed.value, equals(10));
      expect(effectCount, equals(2)); // Effect triggered by value change

      // Soft update after value change - should not notify again
      computed.notify(false);
      expect(
          effectCount, equals(2)); // Effect not triggered (value didn't change)
    });

    test("should notify subscribers when force update even if value unchanged",
        () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value);
      var effectCount = 0;

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));
      expect(computed.value, equals(5));

      // Force update (force=true) - should notify even if value unchanged
      computed.notify(true);
      expect(effectCount, equals(2)); // Effect triggered

      // Force update again
      computed.notify(true);
      expect(effectCount, equals(3)); // Effect triggered again
    });

    test(
        "should notify subscribers when soft update and value changed during recompute",
        () {
      final signal = Signal(5);
      var computeCount = 0;
      final computed = Computed<int>(() {
        computeCount++;
        return signal.value;
      });
      var effectCount = 0;

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));
      expect(computeCount, equals(1));

      // Soft update - value hasn't changed, should not notify
      computed.notify(false);
      expect(effectCount, equals(1)); // Effect not triggered
      expect(computeCount, equals(2)); // Recomputed but value unchanged

      // Change signal value - this will trigger effect automatically
      signal.value = 10;
      expect(computed.value, equals(10));
      expect(effectCount, equals(2)); // Effect triggered by value change
      expect(computeCount, equals(3)); // Recomputed

      // Soft update - value already updated, should not notify again
      computed.notify(false);
      expect(
          effectCount,
          equals(
              2)); // Effect not triggered (value didn't change during recompute)
      expect(computeCount, equals(4)); // Recomputed again
    });

    test("should work with equals parameter and soft update", () {
      final signal = Signal<List<int>>([1, 2, 3]);
      var effectCount = 0;
      var computeCount = 0;

      final computed = Computed<List<int>>(
        () {
          computeCount++;
          return List<int>.from(signal.value);
        },
        equals: (a, b) {
          if (a is! List<int> || b is! List<int>) return a == b;
          if (a.length != b.length) return false;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
          }
          return true;
        },
      );

      Effect(() {
        computed.value;
        effectCount++;
      });

      expect(effectCount, equals(1));
      expect(computeCount, equals(1));

      // Set to same values - equals returns true, value considered unchanged
      signal.value = [1, 2, 3];
      expect(computed.value, equals([1, 2, 3]));
      expect(
          effectCount, equals(1)); // Effect not triggered (equals returns true)
      expect(computeCount, equals(2)); // Recomputed

      // Soft update - value considered equal, should not notify
      computed.notify(false);
      expect(effectCount, equals(1)); // Effect not triggered
      expect(computeCount, equals(3)); // Recomputed but value unchanged

      // Force update - should notify even if equals returns true
      computed.notify(true);
      expect(effectCount, equals(2)); // Effect triggered
      expect(computeCount, equals(4)); // Recomputed
    });
  });
}
