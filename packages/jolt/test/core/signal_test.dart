import "package:jolt/core.dart";
import "package:jolt/extension.dart";
import "package:jolt/jolt.dart";
import "package:meta/meta.dart";
import "package:test/test.dart";

import "../utils.dart";

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
    setUpAll(() {
      JoltDebug.init();
    });
    test("should create signal with initial value", () {
      final counter = DebugCounter();
      final signal =
          Signal(42, debug: JoltDebugOption.of(onDebug: counter.onDebug));

      expect(signal.value, equals(42));
      expect(signal.peek, equals(42));

      expect(counter.getCount, equals(1));
      signal.value;
      // test code
      // ignore: cascade_invocations
      signal.peek;
      expect(counter.getCount, equals(2));
    });

    test("should update signal value by set and value", () {
      final counter = DebugCounter();
      final signal =
          Signal(1, debug: JoltDebugOption.of(onDebug: counter.onDebug));
      expect(signal.value, equals(1));

      signal.value = 2;
      expect(signal.value, equals(2));
      expect(signal.peek, equals(2));
      expect(counter.setCount, equals(1));

      signal.set(3);
      expect(signal.value, equals(3));
      expect(signal.peek, equals(3));
      expect(counter.setCount, equals(2));
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

    test("should throw AssertionError when accessing disposed signal", () {
      final signal = Signal(42)..dispose();

      expect(() => signal.value, throwsA(isA<AssertionError>()));
      expect(() => signal.value = 1, throwsA(isA<AssertionError>()));
      expect(signal.notify, throwsA(isA<AssertionError>()));
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

      expect(readonlySignal, isA<ReadonlySignal<int>>());
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
      // Effect runs immediately, so we should have one value
      expect(values.length, greaterThanOrEqualTo(1));
      expect(values.last, equals(10));
    });
  });

  group("ReadonlySignal (ConstantSignal)", () {
    test("should create constant signal with ReadonlySignal factory", () {
      final constant = ReadonlySignal(42);
      expect(constant.value, equals(42));
      expect(constant.peek, equals(42));
      expect(constant.get(), equals(42));
    });

    test("should support call() method for constant signal", () {
      final constant = ReadonlySignal(100);
      expect(constant(), equals(100));
      expect(constant(), equals(constant.get()));
      expect(constant(), equals(constant.value));
      expect(constant(), equals(constant.peek));
    });

    test("constant signal should always return same value", () {
      final constant = ReadonlySignal("hello");
      expect(constant.value, equals("hello"));
      expect(constant.value, equals("hello"));
      expect(constant(), equals("hello"));
      expect(constant.peek, equals("hello"));
    });

    test("constant signal should not be writable", () {
      final constant = ReadonlySignal(42);
      // ReadonlySignal doesn't have a value setter, so it's readonly
      expect(constant, isA<ReadonlySignal<int>>());
      // Verify it's not a Signal (which is writable)
      expect(constant, isNot(isA<Signal<int>>()));
    });

    test("constant signal should work with different types", () {
      final intConstant = ReadonlySignal(42);
      expect(intConstant(), equals(42));

      final stringConstant = ReadonlySignal("test");
      expect(stringConstant(), equals("test"));

      final listConstant = ReadonlySignal([1, 2, 3]);
      expect(listConstant(), equals([1, 2, 3]));

      final nullableConstant = ReadonlySignal<int?>(null);
      expect(nullableConstant(), isNull);
    });

    test("constant signal should work in computed", () {
      final constant = ReadonlySignal(5);
      final computed = Computed<int>(() => constant.value * 2);
      expect(computed.value, equals(10));
    });

    test("constant signal should work in effect", () {
      final constant = ReadonlySignal("hello");
      final values = <String>[];

      Effect(() {
        values.add(constant.value);
      });

      expect(values, equals(["hello"]));
    });

    test("constant signal should not trigger effect updates", () {
      final constant = ReadonlySignal(1);
      final values = <int>[];

      Effect(() {
        values.add(constant.value);
      });

      expect(values, equals([1]));

      // Constant signal cannot change, so effect should not run again
      // But we can't actually change it, so values should remain [1]
      expect(values, equals([1]));
    });

    test("constant signal toString should return value.toString()", () {
      final constant = ReadonlySignal(42);
      expect(constant.toString(), equals("42"));
      expect(constant.toString(), equals(constant.value.toString()));

      final stringConstant = ReadonlySignal("hello");
      expect(stringConstant.toString(), equals("hello"));
      expect(stringConstant.toString(), equals(stringConstant.value));

      final nullConstant = ReadonlySignal<int?>(null);
      expect(nullConstant.toString(), equals("null"));
      expect(nullConstant.toString(), equals(nullConstant.value.toString()));
    });

    test("constant signal dispose should be noop", () {
      final constant = ReadonlySignal(42);

      // Before dispose
      expect(constant.isDisposed, isFalse);
      expect(constant.value, equals(42));

      // Call dispose
      constant.dispose();

      // After dispose - should still work normally
      expect(constant.isDisposed, isFalse,
          reason: "isDisposed should remain false after dispose");
      expect(constant.value, equals(42),
          reason: "value should still be accessible after dispose");
      expect(constant.peek, equals(42),
          reason: "peek should still work after dispose");

      // Can call dispose multiple times without error
      constant.dispose();
      constant.dispose();
      expect(constant.isDisposed, isFalse);
    });

    test("constant signal isDisposed should always be false", () {
      final constant = ReadonlySignal(100);

      expect(constant.isDisposed, isFalse);

      // After dispose
      constant.dispose();
      expect(constant.isDisposed, isFalse);

      // Multiple disposes
      constant.dispose();
      constant.dispose();
      expect(constant.isDisposed, isFalse);
    });

    test("constant signal notify should be noop and not trigger updates", () {
      final constant = ReadonlySignal(5);
      final values = <int>[];

      // Create an effect that tracks the constant
      final effect = Effect(() {
        values.add(constant.value);
      });

      expect(values, equals([5]));

      // Call notify - should not trigger any updates
      constant.notify();

      // Effect should not run again (constant signals don't trigger reactivity)
      expect(values, equals([5]),
          reason: "notify should not trigger effect updates");

      // Can call notify multiple times without error
      constant.notify();
      constant.notify();
      expect(values, equals([5]));

      // Verify value is still accessible
      expect(constant.value, equals(5));
      expect(constant.isDisposed, isFalse);

      effect.dispose();
    });
  });
}
