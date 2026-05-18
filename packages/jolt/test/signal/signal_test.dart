import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:meta/meta.dart";
import "package:test/test.dart";

@immutable
class _TestPerson {
  _TestPerson(this.name, this.age);
  final String name;
  final int age;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestPerson && name == other.name && age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

void main() {
  group("Signal", () {
    test("should create signal with initial value", () {
      final signal = Signal(42);

      expect(signal.value, equals(42));
      expect(signal.peek, equals(42));
    });

    test("should update signal value by set and value", () {
      final signal = Signal(1);
      expect(signal.value, equals(1));

      signal.value = 2;
      expect(signal.value, equals(2));
      expect(signal.peek, equals(2));

      signal.set(3);
      expect(signal.value, equals(3));
      expect(signal.peek, equals(3));
    });

    test("should use get value by get and value", () {
      final signal = Signal(42);
      expect(signal.get(), equals(42));
      expect(signal.value, equals(42));
    });

    test("should support call() method that returns same as get()", () {
      final signal = Signal(5);
      expect(signal(), equals(5));
      expect(signal(), equals(signal.get()));
      expect(signal(), equals(signal.value));

      signal.value = 10;
      expect(signal(), equals(10));
      expect(signal(), equals(signal.get()));
      expect(signal(), equals(signal.value));
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
      signal.set(1);

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));
    });

    test("should emit stream events", () async {
      final signal = Signal(1);
      final values = <int>[];

      signal.stream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 3]));
    });

    test("should support multiple stream listeners", () async {
      final signal = Signal(1);
      final values1 = <int>[];
      final values2 = <int>[];

      signal.stream.listen(values1.add);
      signal.stream.listen(values2.add);

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      expect(values1, equals([2]));
      expect(values2, equals([2]));
    });

    test("disposed signal stays inert for new reactive consumers", () {
      final signal = Signal(42)..dispose();
      final values = <int>[];
      final effect = Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([42]));
      expect(signal.value, equals(42));
      signal.value = 1;
      signal.notify();
      expect(signal.value, equals(1));
      expect(signal.peek, equals(1));
      expect(values, equals([42]),
          reason: "disposed signals must not resubscribe new effects");

      effect.dispose();
    });

    group("disposed signal no longer reactive", () {
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

      test("batch ignores disposed signals but still flushes active ones once",
          () {
        final disposed = Signal(0);
        final active = Signal(0);
        final disposedValues = <int>[];
        final activeValues = <int>[];

        Effect(() {
          disposedValues.add(disposed.value);
        });
        Effect(() {
          activeValues.add(active.value);
        });

        expect(disposedValues, equals([0]));
        expect(activeValues, equals([0]));

        disposed.value = 1;
        active.value = 1;

        expect(disposedValues, equals([0, 1]));
        expect(activeValues, equals([0, 1]));

        disposed.dispose();
        batch(() {
          disposed.value = 2;
          disposed.notify();
          active
            ..value = 2
            ..value = 3;
        });

        expect(disposed.isDisposed, isTrue);
        expect(disposedValues, equals([0, 1]),
            reason: "disposed signals must stay inert inside batch");
        expect(activeValues, equals([0, 1, 3]),
            reason:
                "active signals should still flush the final batched value");
      });

      test("disposed signal freezes all existing subscribers", () {
        final signal = Signal(1);
        final v1 = <int>[];
        final v2 = <int>[];
        final e1 = Effect(() => v1.add(signal.value));
        final e2 = Effect(() => v2.add(signal.value));

        expect(v1, equals([1]));
        expect(v2, equals([1]));

        signal.dispose();
        signal.value = 2;
        signal.notify();

        expect(v1, equals([1]));
        expect(v2, equals([1]));

        e1.dispose();
        e2.dispose();
      });
    });

    test("equal-value writes do not rerun effects, even in batches", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      signal.value = 1;
      batch(() {
        signal.value = 1;
        signal.value = 1;
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));
    });

    test("peek stays untracked while value/get()/call() stay reactive", () {
      final signal = Signal(1);
      var peekRuns = 0;
      var valueRuns = 0;
      var getRuns = 0;
      var callRuns = 0;

      Effect(() {
        peekRuns++;
        signal.peek;
      });
      Effect(() {
        valueRuns++;
        signal.value;
      });
      Effect(() {
        getRuns++;
        signal.get();
      });
      Effect(() {
        callRuns++;
        signal();
      });

      signal.value = 2;

      expect(peekRuns, equals(1));
      expect(valueRuns, equals(2));
      expect(getRuns, equals(2));
      expect(callRuns, equals(2));
    });

    test("should work with different data types", () {
      // String signal
      final stringSignal = Signal("hello");
      expect(stringSignal.value, equals("hello"));
      stringSignal.value = "world";
      expect(stringSignal.value, equals("world"));

      // List signal
      final listSignal = Signal<List<int>>([1, 2, 3]);
      expect(listSignal.value, equals([1, 2, 3]));
      listSignal.value = [4, 5, 6];
      expect(listSignal.value, equals([4, 5, 6]));

      // Map signal
      final mapSignal = Signal<Map<String, int>>({"a": 1});
      expect(mapSignal.value, equals({"a": 1}));
      mapSignal.value = {"b": 2};
      expect(mapSignal.value, equals({"b": 2}));

      // Nullable signal
      final nullableSignal = Signal<int?>(null);
      expect(nullableSignal.value, isNull);
      nullableSignal.value = 42;
      expect(nullableSignal.value, equals(42));

      final personSignal = Signal(_TestPerson("Alice", 30));
      expect(personSignal.value.name, equals("Alice"));
      expect(personSignal.value.age, equals(30));

      personSignal.value = _TestPerson("Bob", 25);
      expect(personSignal.value.name, equals("Bob"));
      expect(personSignal.value.age, equals(25));
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

    test("should work with batch updates", () {
      final signal = Signal(1);
      final values = <int>[];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        signal
          ..value = 2
          ..value = 3
          ..value = 4;
      });

      expect(values, equals([1, 4]));
    });

    test("should return ReadonlySignal type after readonly", () {
      final signal = Signal(5);

      expect(signal.value, equals(5));

      final readonlySignal = signal.readonly();

      expect(readonlySignal, isA<Readonly<int>>());
      expect(readonlySignal.value, equals(5));

      signal.value = 6;
      expect(readonlySignal.value, equals(6));
    });

    test("should return value.toString() in toString", () {
      final signal = Signal(42);
      expect(signal.toString(), equals("42"));
      expect(signal.toString(), equals(signal.value.toString()));

      signal.value = 100;
      expect(signal.toString(), equals("100"));
      expect(signal.toString(), equals(signal.value.toString()));

      final stringSignal = Signal("hello");
      expect(stringSignal.toString(), equals("hello"));
      expect(stringSignal.toString(), equals(stringSignal.value));

      stringSignal.value = "world";
      expect(stringSignal.toString(), equals("world"));
      expect(stringSignal.toString(), equals(stringSignal.value));
    });

    test("should throw error when accessing uninitialized lazy signal", () {
      final lazySignal = Signal<int>.lazy();

      // Accessing uninitialized lazy signal should throw
      expect(() => lazySignal.value, throwsA(isA<TypeError>()));
      expect(() => lazySignal.get(), throwsA(isA<TypeError>()));
      expect(() => lazySignal.peek, throwsA(isA<TypeError>()));

      // After setting a value, it should work
      lazySignal.value = 42;
      expect(lazySignal.value, equals(42));
      expect(lazySignal.get(), equals(42));
      expect(lazySignal.peek, equals(42));
    });

    test("should work with nullable lazy signal", () {
      final lazySignal = Signal<int?>.lazy();

      // Nullable lazy signal can be accessed without error
      expect(lazySignal.value, isNull);
      expect(lazySignal.get(), isNull);
      expect(lazySignal.peek, isNull);

      // Can set value
      lazySignal.value = 42;
      expect(lazySignal.value, equals(42));

      // Can set back to null
      lazySignal.value = null;
      expect(lazySignal.value, isNull);
    });

    test(
        "should throw error when accessing uninitialized lazy signal in computed",
        () {
      final lazySignal = Signal<int>.lazy();

      // Accessing in computed should throw
      expect(() => Computed(() => lazySignal.value * 2),
          throwsA(isA<TypeError>()));

      // After setting a value, computed should work
      lazySignal.value = 5;
      final computed = Computed(() => lazySignal.value * 2);
      expect(computed.value, equals(10));
    });

    test(
        "should throw error when accessing uninitialized lazy signal in effect",
        () {
      final lazySignal = Signal<int>.lazy();
      final values = <int>[];

      // Accessing in effect should throw
      expect(
          () => Effect(() {
                values.add(lazySignal.value);
              }),
          throwsA(isA<TypeError>()));

      // After setting a value, effect should work
      lazySignal.value = 10;
      Effect(() {
        values.add(lazySignal.value);
      });
      expect(values, equals([10]));
    });
  });

  group("ReadonlySignal (ConstantSignal)", () {
    test("should create constant signal with ReadonlySignal factory", () {
      final constant = Readonly(42);
      expect(constant.value, equals(42));
      expect(constant.peek, equals(42));
      expect(constant.get(), equals(42));
    });

    test("should support call() method for constant signal", () {
      final constant = Readonly(100);
      expect(constant(), equals(100));
      expect(constant(), equals(constant.get()));
      expect(constant(), equals(constant.value));
      expect(constant(), equals(constant.peek));
    });

    test("constant signal should not be writable", () {
      final constant = Readonly(42);
      // ReadonlySignal doesn't have a value setter, so it's readonly
      expect(constant, isA<Readonly<int>>());
      // Verify it's not a Signal (which is writable)
      expect(constant, isNot(isA<Signal<int>>()));
    });

    test("constant signal should work with different types", () {
      final intConstant = Readonly(42);
      expect(intConstant(), equals(42));

      final stringConstant = Readonly("test");
      expect(stringConstant(), equals("test"));

      final listConstant = Readonly([1, 2, 3]);
      expect(listConstant(), equals([1, 2, 3]));

      final nullableConstant = Readonly<int?>(null);
      expect(nullableConstant(), isNull);
    });

    test("constant signal should work in computed", () {
      final constant = Readonly(5);
      final computed = Computed<int>(() => constant.value * 2);
      expect(computed.value, equals(10));
    });

    test("constant signal should work in effect", () {
      final constant = Readonly("hello");
      final values = <String>[];

      Effect(() {
        values.add(constant.value);
      });

      expect(values, equals(["hello"]));
    });

    test("constant signal toString should return value.toString()", () {
      final constant = Readonly(42);
      expect(constant.toString(), equals("42"));
      expect(constant.toString(), equals(constant.value.toString()));

      final stringConstant = Readonly("hello");
      expect(stringConstant.toString(), equals("hello"));
      expect(stringConstant.toString(), equals(stringConstant.value));

      final nullConstant = Readonly<int?>(null);
      expect(nullConstant.toString(), equals("null"));
      expect(nullConstant.toString(), equals(nullConstant.value.toString()));
    });
  });
}
