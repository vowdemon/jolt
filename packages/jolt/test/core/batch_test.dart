import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

void main() {
  group('batch', () {
    test('should batch multiple signal updates', () {
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

    test('should batch multiple computed updates', () {
      final signal = Signal(1);
      final computed1 = Computed<int>(() => signal.value * 2);
      final computed2 = Computed<int>(() => signal.value * 3);
      final computed3 = Computed<int>(() => computed1.value + computed2.value);

      final List<int> values = [];
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

    test('should batch nested batch calls', () {
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
        batch(() {
          signal2.value = 20;
          signal1.value = 15;
        });
        signal2.value = 25;
      });

      expect(values, equals([3, 40])); // 15 + 25
    });

    test('should handle batch with effects', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);

      final List<int> effect1Values = [];
      final List<int> effect2Values = [];

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

    test('should handle batch with stream emissions', () async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);

      final List<int> stream1Values = [];
      final List<int> stream2Values = [];

      signal1.stream.listen((value) => stream1Values.add(value));
      signal2.stream.listen((value) => stream2Values.add(value));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      await Future.delayed(const Duration(milliseconds: 1));

      expect(stream1Values, equals([10]));
      expect(stream2Values, equals([20]));
    });

    test('should handle batch with conditional dependencies', () {
      final conditionSignal = Signal(true);
      final valueSignal = Signal(42);

      final computed = Computed<int>(() {
        if (conditionSignal.value) {
          return valueSignal.value;
        } else {
          return 0;
        }
      });

      final List<int> values = [];
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

    test('should handle batch with error in function', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      expect(() {
        return batch(() {
          signal.value = 2;
          throw Exception('Test error');
        });
      }, throwsA(isA<Exception>()));

      expect(signal.value, equals(2));
      expect(values, equals([1, 2]));
    });

    test('should throw when reading disposed signal in batch', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value + signal2.value);

      final List<int> values = [];
      Effect(() {
        values.add(computed.value);
      });

      expect(values, equals([3]));

      expect(() {
        return batch(() {
          signal1.value = 10;
          signal1.dispose();
          signal2.value = 20;
        });
      }, throwsA(isA<AssertionError>()));
    });

    test('should handle batch with rapid updates', () {
      final signal = Signal(0);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([0]));

      batch(() {
        for (int i = 1; i <= 100; i++) {
          signal.value = i;
        }
      });

      // 批处理中只应该触发一次更新
      expect(values, equals([0, 100]));
    });

    test('should handle batch with dual computed', () {
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
        dualComputed.value = 16;
      });

      // 批处理中只应该触发一次更新
      expect(values, equals([2, 16]));
      expect(signal.value, equals(8));
    });

    test('should handle empty batch', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        // 空批处理
      });

      // 空批处理不应该触发任何更新
      expect(values, equals([1]));
    });

    test('should handle batch with async operations', () async {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      batch(() {
        signal.value = 2;
        // 在批处理中执行异步操作
        Future.delayed(const Duration(milliseconds: 1), () {
          signal.value = 3;
        });
      });

      // 批处理应该立即完成，异步操作在批处理外执行
      expect(values, equals([1, 2]));

      await Future.delayed(const Duration(milliseconds: 2));
      expect(values, equals([1, 2, 3]));
    });

    test('should handle sync part of async batch', () async {
      final signal = Signal(1);
      final List<int> values = [];

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
  });
}
