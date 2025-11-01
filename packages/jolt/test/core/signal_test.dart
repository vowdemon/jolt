import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

import '../utils.dart';

class _TestPerson {
  final String name;
  final int age;

  _TestPerson(this.name, this.age);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestPerson && name == other.name && age == other.age;

  @override
  int get hashCode => name.hashCode ^ age.hashCode;
}

void main() {
  group('Signal', () {
    test('should create signal with initial value', () {
      final counter = DebugCounter();
      final signal = Signal(42, onDebug: counter.onDebug);

      expect(signal.value, equals(42));
      expect(signal.peek, equals(42));

      expect(counter.getCount, equals(1));
      signal.value;
      signal.peek;
      expect(counter.getCount, equals(2));
    });

    test('should update signal value by set and value', () {
      final counter = DebugCounter();
      final signal = Signal(1, onDebug: counter.onDebug);
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

    test('should use get value by get and value', () {
      final signal = Signal(42);
      expect(signal.get(), equals(42));
      expect(signal.value, equals(42));
    });

    test('should force update signal', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.notify();
      expect(values, equals([1, 1]));
    });

    test('should track signal in computed', () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.value, equals(10));

      signal.value = 10;
      expect(computed.value, equals(20));
    });

    test('should track signal in effect', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      signal.value = 3;
      expect(values, equals([1, 2, 3]));
    });

    test('should emit stream events', () async {
      final signal = Signal(1);
      final List<int> values = [];

      signal.stream.listen((value) {
        values.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2]));

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([2, 3]));
    });

    test('should support multiple stream listeners', () async {
      final signal = Signal(1);
      final List<int> values1 = [];
      final List<int> values2 = [];

      signal.stream.listen((value) => values1.add(value));
      signal.stream.listen((value) => values2.add(value));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      expect(values1, equals([2]));
      expect(values2, equals([2]));
    });

    test('should throw AssertionError when accessing disposed signal', () {
      final signal = Signal(42);
      signal.dispose();

      expect(() => signal.value, throwsA(isA<AssertionError>()));
      expect(() => signal.value = 1, throwsA(isA<AssertionError>()));
      expect(() => signal.notify(), throwsA(isA<AssertionError>()));
    });

    test('should work with different data types', () {
      // String signal
      final stringSignal = Signal('hello');
      expect(stringSignal.value, equals('hello'));
      stringSignal.value = 'world';
      expect(stringSignal.value, equals('world'));

      // List signal
      final listSignal = Signal<List<int>>([1, 2, 3]);
      expect(listSignal.value, equals([1, 2, 3]));
      listSignal.value = [4, 5, 6];
      expect(listSignal.value, equals([4, 5, 6]));

      // Map signal
      final mapSignal = Signal<Map<String, int>>({'a': 1});
      expect(mapSignal.value, equals({'a': 1}));
      mapSignal.value = {'b': 2};
      expect(mapSignal.value, equals({'b': 2}));

      // Nullable signal
      final nullableSignal = Signal<int?>(null);
      expect(nullableSignal.value, isNull);
      nullableSignal.value = 42;
      expect(nullableSignal.value, equals(42));

      final personSignal = Signal(_TestPerson('Alice', 30));
      expect(personSignal.value.name, equals('Alice'));
      expect(personSignal.value.age, equals(30));

      personSignal.value = _TestPerson('Bob', 25);
      expect(personSignal.value.name, equals('Bob'));
      expect(personSignal.value.age, equals(25));
    });

    test('should handle rapid value changes', () {
      final signal = Signal(0);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      for (int i = 1; i <= 100; i++) {
        signal.value = i;
      }

      expect(values.length, equals(101));
      expect(values.last, equals(100));
    });

    test('should work with batch updates', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        signal.value = 2;
        signal.value = 3;
        signal.value = 4;
      });

      expect(values, equals([1, 4]));
    });

    test('should return ReadonlySignal type after readonly', () {
      final signal = Signal(5);

      expect(signal.value, equals(5));

      final ReadonlySignal<int> readonlySignal = signal.readonly();

      expect(readonlySignal, isA<ReadonlySignal<int>>());
      expect(readonlySignal.value, equals(5));

      signal.value = 6;
      expect(readonlySignal.value, equals(6));
    });

    test('should return value.toString() in toString', () {
      final signal = Signal(42);
      expect(signal.toString(), equals('42'));
      expect(signal.toString(), equals(signal.value.toString()));

      signal.value = 100;
      expect(signal.toString(), equals('100'));
      expect(signal.toString(), equals(signal.value.toString()));

      final stringSignal = Signal('hello');
      expect(stringSignal.toString(), equals('hello'));
      expect(stringSignal.toString(), equals(stringSignal.value.toString()));

      stringSignal.value = 'world';
      expect(stringSignal.toString(), equals('world'));
      expect(stringSignal.toString(), equals(stringSignal.value.toString()));
    });
  });
}
