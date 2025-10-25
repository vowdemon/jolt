import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('Computed', () {
    test('should create computed with getter function', () {
      final signal = Signal(5);
      final computed = Computed<int>(() => signal.value * 2);

      expect(computed.value, equals(10));
      expect(computed.peek, equals(10));
    });

    test('should update when dependencies change', () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value + 1);

      expect(computed.value, equals(2));

      signal.value = 5;
      expect(computed.value, equals(6));
    });

    test('should work with multiple dependencies', () {
      final signal1 = Signal(2);
      final signal2 = Signal(3);
      final computed = Computed<int>(() => signal1.value * signal2.value);

      expect(computed.value, equals(6));

      signal1.value = 4;
      expect(computed.value, equals(12));

      signal2.value = 5;
      expect(computed.value, equals(20));
    });

    test('should track computed in effect', () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final List<int> values = [];

      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([2]));

      signal.value = 3;
      expect(values, equals([2, 6]));
    });

    test('should emit stream events', () async {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final List<int> values = [];

      computed.stream.listen((value) {
        values.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([4]));
    });

    test('should work with different data types', () {
      final stringSignal = Signal('hello');
      final computed = Computed<String>(
        () => stringSignal.value.toUpperCase(),
      );

      expect(computed.value, equals('HELLO'));

      stringSignal.value = 'world';
      expect(computed.value, equals('WORLD'));
    });

    test('should work with nullable values', () {
      final signal = Signal<int?>(null);
      final computed = Computed<String>(
        () => signal.value?.toString() ?? 'null',
      );

      expect(computed.value, equals('null'));

      signal.value = 42;
      expect(computed.value, equals('42'));
    });

    test('should handle complex computations', () {
      final listSignal = Signal<List<int>>([1, 2, 3]);
      final computed = Computed<int>(
        () => listSignal.value.fold(0, (sum, item) => sum + item),
      );

      expect(computed.value, equals(6));

      listSignal.value = [4, 5, 6, 7];
      expect(computed.value, equals(22));
    });

    test('should work with nested computed', () {
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
      'should throw ComputedAssertionError when accessing disposed computed',
      () async {
        final signal = Signal(1);
        final computed = Computed<int>(() => signal.value * 2);

        expect(computed.value, equals(2));

        computed.dispose();
        expect(() => computed.value, throwsA(isA<AssertionError>()));
      },
    );

    test('should work with batch updates', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value + signal2.value);
      final List<int> values = [];

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

    test('should handle conditional dependencies', () {
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

  group('DualComputed', () {
    test('should create dual computed with getter and setter', () {
      final signal = Signal(5);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );

      expect(dualComputed.value, equals(10));
    });

    test('should update value through setter', () {
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

    test('should use set method to update value', () {
      final signal = Signal(3);
      final dualComputed = WritableComputed<int>(
        () => signal.value,
        (value) => signal.value = value * 3,
      );

      expect(dualComputed.value, equals(3));

      dualComputed.set(15);
      expect(dualComputed.peek, equals(3));
      expect(dualComputed.value, equals(45));
      expect(signal.value, equals(45));
    });

    test('should track dual computed in effect', () {
      final signal = Signal(2);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );
      final List<int> values = [];

      Effect(() {
        values.add(dualComputed.value);
      });

      expect(values, equals([4]));

      signal.value = 6;
      expect(values, equals([4, 12]));
    });

    test('should emit stream events', () async {
      final signal = Signal(1);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );
      final List<int> values = [];

      dualComputed.stream.listen((value) {
        values.add(value);
      });

      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([]));

      signal.value = 3;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(values, equals([6]));
    });

    test('should work with string transformations', () {
      final signal = Signal('hello');
      final dualComputed = WritableComputed<String>(
        () => signal.value.toUpperCase(),
        (value) => signal.value = value.toLowerCase(),
      );

      expect(dualComputed.value, equals('HELLO'));

      dualComputed.value = 'WORLD';
      expect(dualComputed.value, equals('WORLD'));
      expect(signal.value, equals('world'));
    });

    test('should handle complex transformations', () {
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
      'should throw ComputedAssertionError when accessing disposed dual computed',
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

    test('should work with batch updates', () {
      final signal = Signal(1);
      final dualComputed = WritableComputed<int>(
        () => signal.value * 2,
        (value) => signal.value = value ~/ 2,
      );
      final List<int> values = [];

      Effect(() {
        values.add(dualComputed.value);
      });

      expect(values, equals([2]));

      batch(() {
        dualComputed.value = 8;
        dualComputed.value = 12;
      });

      expect(values, equals([2, 12]));
      expect(signal.value, equals(6));
    });

    test('should handle setter errors gracefully', () {
      final signal = Signal(1);
      final dualComputed =
          WritableComputed<int>(() => signal.value * 2, (value) {
        if (value < 0) {
          throw ArgumentError('Value cannot be negative');
        }
        signal.value = value ~/ 2;
      });

      expect(dualComputed.value, equals(2));

      expect(() => dualComputed.value = -10, throwsA(isA<ArgumentError>()));
      expect(signal.value, equals(1));
    });

    test('computed notify times', () {
      final firstName = Signal('John');
      final lastName = Signal('Doe');
      final fullName = WritableComputed(
        () => '${firstName.value} ${lastName.value}',
        (value) {
          final parts = value.split(' ');
          if (parts.length >= 2) {
            batch(() {
              firstName.value = parts[0];
              lastName.value = parts.sublist(1).join(' ');
            });
          }
        },
      );
      int count = 0;
      Effect(() {
        fullName.value;
        count++;
      });
      expect(count, equals(1));
      firstName.value = 'Jane';
      expect(count, equals(2));
      lastName.value = 'Smith';
      expect(count, equals(3));
      fullName.value = 'Jane1 Smith2';
      expect(count, equals(4));
    });
  });
}
