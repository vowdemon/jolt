import "package:jolt/jolt.dart";
import "package:jolt/src/core/reactive.dart";
import "package:jolt/src/jolt/signal.dart";
import "package:test/test.dart";

import "../utils.dart";

/// Test implementation of ProxyReadonlySignal
class TestProxyReadonlySignal<T> extends ProxyReadonlySignal<T> {
  TestProxyReadonlySignal(this._getter, {super.onDebug})
      : super(flags: ReactiveFlags.mutable);

  final T Function() _getter;
  bool _dirty = false;

  @override
  T get() {
    getCustom(this);
    return _getter();
  }

  @override
  T get peek => _getter();

  void markDirty() {
    _dirty = true;
  }

  @override
  bool updateNode() {
    if (_dirty) {
      _dirty = false;
      return true;
    }
    return false;
  }

  @override
  void onDispose() {
    disposeNode(this);
  }
}

/// Test implementation of ProxySignal
class TestProxySignal<T> extends ProxySignal<T> {
  TestProxySignal(this._getter, this._setter, {super.onDebug})
      : super(flags: ReactiveFlags.mutable);

  final T Function() _getter;
  final T Function(T) _setter;
  bool _dirty = false;

  @override
  T get() {
    getCustom(this);
    return _getter();
  }

  @override
  T get peek => _getter();

  @override
  T get value => get();

  @override
  set value(T newValue) {
    set(newValue);
  }

  @override
  T set(T value) {
    final result = _setter(value);
    _dirty = true;
    notifyCustom(this);
    return result;
  }

  void markDirty() {
    _dirty = true;
  }

  @override
  bool updateNode() {
    if (_dirty) {
      _dirty = false;
      return true;
    }
    return false;
  }

  @override
  void onDispose() {
    disposeNode(this);
  }
}

/// Test implementation of ReadonlySignalImpl that uses internalSet
class TestReadonlySignalWithInternalSet<T> extends ReadonlySignalImpl<T> {
  TestReadonlySignalWithInternalSet(super.value, {super.onDebug});

  /// Expose internalSet for testing
  T testInternalSet(T value) => internalSet(value);
}

/// Test implementation of ProxyReadonlySignal that doesn't override updateNode
/// This is used to test the base class updateNode() method which always returns true
class TestProxyReadonlySignalBaseUpdateNode<T> extends ProxyReadonlySignal<T> {
  TestProxyReadonlySignalBaseUpdateNode(this._getter, {super.onDebug})
      : super(flags: ReactiveFlags.mutable);

  final T Function() _getter;

  @override
  T get() {
    getCustom(this);
    return _getter();
  }

  @override
  T get peek => _getter();

  @override
  void onDispose() {
    disposeNode(this);
  }
}

void main() {
  group("ReadonlySignalImpl", () {
    test("should create with initial value", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(42, onDebug: counter.onDebug);

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
      final signal = ReadonlySignalImpl(10, onDebug: counter.onDebug);

      expect(signal.get(), equals(10));
      expect(counter.getCount, equals(1));
    });

    test("should read value via call()", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(5, onDebug: counter.onDebug);

      expect(signal(), equals(5));
      expect(counter.getCount, equals(1));
    });

    test("should read value via value getter", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(7, onDebug: counter.onDebug);

      expect(signal.value, equals(7));
      expect(counter.getCount, equals(1));
    });

    test("should read value via peek without dependency", () {
      final counter = DebugCounter();
      final signal = ReadonlySignalImpl(3, onDebug: counter.onDebug);

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
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        if (type == DebugNodeOperationType.get) {
          getCount++;
        }
      }

      final signal = ReadonlySignalImpl(42, onDebug: onDebug);
      signal.value;
      signal.peek;

      expect(getCount, greaterThan(0));
    });
  });

  group("ProxyReadonlySignal", () {
    test("should create and read value", () {
      int value = 10;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      expect(proxy.value, equals(10));
      expect(proxy.peek, equals(10));
      expect(proxy(), equals(10));
    });

    test("should read value via get()", () {
      int value = 5;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      expect(proxy.get(), equals(5));
    });

    test("should read value via call()", () {
      int value = 7;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      expect(proxy(), equals(7));
    });

    test("should update value when getter changes", () {
      int value = 0;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      expect(proxy.value, equals(0));

      value = 5;
      // Value changes but updateNode needs to be called
      proxy.markDirty();
      expect(proxy.value, equals(5));
    });

    test("should notify subscribers when notify() is called", () {
      int value = 0;
      final proxy = TestProxyReadonlySignal<int>(() => value);
      final values = <int>[];

      final effect = Effect(() {
        values.add(proxy.value);
      });

      expect(values, equals([0]));

      value = 1;
      proxy.markDirty();
      proxy.notify();
      expect(values, equals([0, 1]));

      effect.dispose();
    });

    test("should track in computed", () {
      int value = 3;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      final computed = Computed<int>(() => proxy.value * 2);

      expect(computed.value, equals(6));

      value = 5;
      proxy.markDirty();
      proxy.notify();
      expect(computed.value, equals(10));
    });

    test("should track in effect", () {
      int value = 2;
      final proxy = TestProxyReadonlySignal<int>(() => value);
      final values = <int>[];

      final effect = Effect(() {
        values.add(proxy.value);
      });

      expect(values, equals([2]));

      value = 4;
      proxy.markDirty();
      proxy.notify();
      expect(values, equals([2, 4]));

      effect.dispose();
    });

    test("updateNode should return true when dirty", () {
      int value = 0;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      proxy.markDirty();
      expect(proxy.updateNode(), isTrue);
      expect(proxy.updateNode(), isFalse); // No longer dirty
    });

    test("updateNode should return false when not dirty", () {
      int value = 0;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      expect(proxy.updateNode(), isFalse);
    });

    test("should work with multiple subscribers", () {
      int value = 0;
      final proxy = TestProxyReadonlySignal<int>(() => value);
      final values1 = <int>[];
      final values2 = <int>[];

      final effect1 = Effect(() {
        values1.add(proxy.value);
      });

      final effect2 = Effect(() {
        values2.add(proxy.value);
      });

      expect(values1, equals([0]));
      expect(values2, equals([0]));

      value = 10;
      proxy.markDirty();
      proxy.notify();

      expect(values1, equals([0, 10]));
      expect(values2, equals([0, 10]));

      effect1.dispose();
      effect2.dispose();
    });

    test("should support onDebug callback", () {
      int getCount = 0;
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        if (type == DebugNodeOperationType.get) {
          getCount++;
        }
      }

      int value = 42;
      final proxy = TestProxyReadonlySignal<int>(() => value, onDebug: onDebug);
      proxy.value;

      expect(getCount, greaterThan(0));
    });

    test("should dispose properly", () {
      int value = 0;
      final proxy = TestProxyReadonlySignal<int>(() => value);

      expect(proxy.isDisposed, isFalse);
      proxy.dispose();
      expect(proxy.isDisposed, isTrue);
    });

    test("base class updateNode should always return true", () {
      int value = 0;
      final proxy = TestProxyReadonlySignalBaseUpdateNode<int>(() => value);

      // Base class updateNode() always returns true
      expect(proxy.updateNode(), isTrue);
      expect(proxy.updateNode(), isTrue); // Always returns true
      expect(proxy.updateNode(), isTrue); // Always returns true
    });

    test("base class updateNode should be called via updateCustom", () {
      int value = 0;
      final proxy = TestProxyReadonlySignalBaseUpdateNode<int>(() => value);

      // updateCustom calls updateNode() for CustomReactiveNode
      final changed = updateCustom(proxy);
      expect(changed, isTrue); // Base class updateNode always returns true
    });

    test("base class updateNode should work with reactive system", () {
      int value = 0;
      final proxy = TestProxyReadonlySignalBaseUpdateNode<int>(() => value);
      final values = <int>[];

      final effect = Effect(() {
        values.add(proxy.value);
      });

      expect(values, equals([0]));

      // When accessing value, updateCustom is called which calls updateNode()
      // Base class updateNode always returns true, so subscribers are notified
      value = 5;
      proxy.notify();
      expect(values,
          equals([0, 5])); // Effect runs because updateNode returns true

      effect.dispose();
    });
  });

  group("ProxySignal", () {
    test("should create and read value", () {
      int value = 10;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      expect(proxy.value, equals(10));
      expect(proxy.peek, equals(10));
      expect(proxy(), equals(10));
    });

    test("should set value", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      proxy.value = 5;
      expect(proxy.value, equals(5));
      expect(value, equals(5));
    });

    test("should set value via set()", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      final result = proxy.set(7);
      expect(result, equals(7));
      expect(proxy.value, equals(7));
      expect(value, equals(7));
    });

    test("should notify subscribers when value changes", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );
      final values = <int>[];

      final effect = Effect(() {
        values.add(proxy.value);
      });

      expect(values, equals([0]));

      proxy.value = 1;
      expect(values, equals([0, 1]));

      proxy.set(2);
      expect(values, equals([0, 1, 2]));

      effect.dispose();
    });

    test("should track in computed", () {
      int value = 2;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      final computed = Computed<int>(() => proxy.value * 3);

      expect(computed.value, equals(6));

      proxy.value = 4;
      expect(computed.value, equals(12));
    });

    test("should track in effect", () {
      int value = 1;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );
      final values = <int>[];

      final effect = Effect(() {
        values.add(proxy.value);
      });

      expect(values, equals([1]));

      proxy.value = 3;
      expect(values, equals([1, 3]));

      proxy.set(5);
      expect(values, equals([1, 3, 5]));

      effect.dispose();
    });

    test("updateNode should return true when dirty", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      proxy.markDirty();
      expect(proxy.updateNode(), isTrue);
      expect(proxy.updateNode(), isFalse); // No longer dirty
    });

    test("updateNode should return false when not dirty", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      expect(proxy.updateNode(), isFalse);
    });

    test("should work with multiple subscribers", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );
      final values1 = <int>[];
      final values2 = <int>[];

      final effect1 = Effect(() {
        values1.add(proxy.value);
      });

      final effect2 = Effect(() {
        values2.add(proxy.value);
      });

      expect(values1, equals([0]));
      expect(values2, equals([0]));

      proxy.value = 10;
      expect(values1, equals([0, 10]));
      expect(values2, equals([0, 10]));

      effect1.dispose();
      effect2.dispose();
    });

    test("should support bidirectional sync with regular signal", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );
      final signal = Signal(0);

      final computed = Computed<int>(() => proxy.value + signal.value);
      final values = <int>[];

      final effect = Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([0]));

      proxy.value = 5;
      expect(values, equals([0, 5]));

      signal.value = 3;
      expect(values, equals([0, 5, 8]));

      effect.dispose();
    });

    test("should support onDebug callback", () {
      int getCount = 0;

      // ignore: unused_local_variable
      int setCount = 0;
      void onDebug(DebugNodeOperationType type, ReactiveNode node) {
        if (type == DebugNodeOperationType.get) {
          getCount++;
        } else if (type == DebugNodeOperationType.set) {
          setCount++;
        }
      }

      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
        onDebug: onDebug,
      );

      proxy.value;
      proxy.value = 5;

      expect(getCount, greaterThan(0));
      // Note: setCount might be 0 if set doesn't trigger debug events
      // This depends on implementation
    });

    test("should dispose properly", () {
      int value = 0;
      final proxy = TestProxySignal<int>(
        () => value,
        (v) => value = v,
      );

      expect(proxy.isDisposed, isFalse);
      proxy.dispose();
      expect(proxy.isDisposed, isTrue);
    });

    test("should work in complex reactive chain", () {
      int value1 = 1;
      int value2 = 2;
      final proxy1 = TestProxySignal<int>(
        () => value1,
        (v) => value1 = v,
      );
      final proxy2 = TestProxySignal<int>(
        () => value2,
        (v) => value2 = v,
      );
      final signal = Signal(3);

      final computed = Computed<int>(
        () => proxy1.value + proxy2.value + signal.value,
      );
      final values = <int>[];

      final effect = Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([6])); // 1 + 2 + 3

      proxy1.value = 10;
      expect(values, equals([6, 15])); // 10 + 2 + 3

      proxy2.set(20);
      expect(values, equals([6, 15, 33])); // 10 + 20 + 3

      signal.value = 5;
      expect(values, equals([6, 15, 33, 35])); // 10 + 20 + 5

      effect.dispose();
    });
  });
}
