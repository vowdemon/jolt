import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:jolt/extension.dart";
import "package:test/test.dart";

import "../utils.dart";

/// Test implementation of ReadonlySignalImpl that uses internalSet
class TestReadonlySignalWithInternalSet<T> extends ReadonlySignalImpl<T> {
  TestReadonlySignalWithInternalSet(super.value, {super.debug});

  /// Expose internalSet for testing
  T testInternalSet(T value) {
    assert(!isDisposed, "Signal is disposed");
    return setSignal(this, value);
  }
}

void main() {
  group("ReadonlySignalImpl", () {
    setUpAll(() {
      JoltDebug.init();
    });
    test("should create with initial value", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(42,
          debug: JoltDebugOption.of(onDebug: counter.onDebug));

      expect(signal.value, equals(42));
      expect(signal.peek, equals(42));
      expect(counter.getCount, equals(1));
    });

    test("should create with null initial value", () {
      final signal = ReadonlySignalImpl<int?>(null);

      expect(signal.value, isNull);
      expect(signal.peek, isNull);
    });

    test("should read value via get()", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(10,
          debug: JoltDebugOption.of(onDebug: counter.onDebug));

      expect(signal.get(), equals(10));
      expect(counter.getCount, equals(1));
    });

    test("should read value via call()", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(5,
          debug: JoltDebugOption.of(onDebug: counter.onDebug));

      expect(signal(), equals(5));
      expect(counter.getCount, equals(1));
    });

    test("should read value via value getter", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(7,
          debug: JoltDebugOption.of(onDebug: counter.onDebug));

      expect(signal.value, equals(7));
      expect(counter.getCount, equals(1));
    });

    test("should read value via peek without dependency", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(3,
          debug: JoltDebugOption.of(onDebug: counter.onDebug));

      expect(signal.peek, equals(3));
      expect(counter.getCount, equals(0)); // peek doesn't call get
    });

    test("should notify subscribers when notify() is called", () {
      final signal = ReadonlySignalImpl(0);
      final values = <int>[];

      final effect = Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([0]));

      signal.notify();
      expect(values, equals([0, 0])); // Effect runs again

      effect.dispose();
    });

    test("should throw when accessing value after dispose", () {
      final signal = ReadonlySignalImpl(42);
      signal.dispose();

      expect(() => signal.value, throwsA(isA<AssertionError>()));
      expect(() => signal.get(), throwsA(isA<AssertionError>()));
      expect(() => signal(), throwsA(isA<AssertionError>()));
    });

    test("should throw when accessing peek after dispose", () {
      final signal = ReadonlySignalImpl(42);
      signal.dispose();

      expect(() => signal.peek, throwsA(isA<AssertionError>()));
    });

    test("should throw when calling notify after dispose", () {
      final signal = ReadonlySignalImpl(42);
      signal.dispose();

      expect(() => signal.notify(), throwsA(isA<AssertionError>()));
    });

    test("should track in computed", () {
      final signal = ReadonlySignalImpl(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.value, equals(10));
    });

    test("should track in effect", () {
      final signal = ReadonlySignalImpl(3);
      final values = <int>[];

      final effect = Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([3]));

      signal.notify();
      expect(values, equals([3, 3]));

      effect.dispose();
    });

    test("should work with internalSet for subclasses", () {
      // ReadonlySignalImpl has internalSet method for subclasses
      // This is tested indirectly through SignalImpl which extends it
      final signal = SignalImpl(10);
      expect(signal.value, equals(10));
    });

    test("internalSet should set value and notify subscribers", () {
      final signal = TestReadonlySignalWithInternalSet(0);
      final values = <int>[];

      final effect = Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([0]));

      // Use internalSet to change value
      signal.testInternalSet(5);
      expect(signal.value, equals(5));
      expect(values, equals([0, 5])); // Effect should be notified

      signal.testInternalSet(10);
      expect(signal.value, equals(10));
      expect(values, equals([0, 5, 10])); // Effect should be notified again

      effect.dispose();
    });

    test("internalSet should throw when signal is disposed", () {
      final signal = TestReadonlySignalWithInternalSet(42);
      signal.dispose();

      expect(() => signal.testInternalSet(100), throwsA(isA<AssertionError>()));
    });

    test("internalSet should return the set value", () {
      final signal = TestReadonlySignalWithInternalSet(0);

      final result1 = signal.testInternalSet(7);
      expect(result1, equals(7));
      expect(signal.value, equals(7));

      final result2 = signal.testInternalSet(15);
      expect(result2, equals(15));
      expect(signal.value, equals(15));
    });

    test("should support onDebug callback", () {
      int getCount = 0;
      void onDebug(DebugNodeOperationType type, ReactiveNode node, {link}) {
        if (type == DebugNodeOperationType.get) {
          getCount++;
        }
      }

      final signal =
          ReadonlySignalImpl(42, debug: JoltDebugOption.of(onDebug: onDebug));
      signal.value;
      signal.peek;

      expect(getCount, greaterThan(0));
    });

    test("should return value.toString() in toString", () {
      final signal = ReadonlySignalImpl(42);
      expect(signal.toString(), equals("42"));
      expect(signal.toString(), equals(signal.value.toString()));

      final stringSignal = ReadonlySignalImpl("hello");
      expect(stringSignal.toString(), equals("hello"));
      expect(stringSignal.toString(), equals(stringSignal.value));

      final nullSignal = ReadonlySignalImpl<int?>(null);
      expect(nullSignal.toString(), equals("null"));
      expect(nullSignal.toString(), equals(nullSignal.value.toString()));
    });
  });
}
