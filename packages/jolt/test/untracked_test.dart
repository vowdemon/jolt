import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('untracked', () {
    test('should prevent signal tracking in effect', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([1]));

      signal.value = 2;
      // untracked应该阻止effect重新运行
      expect(values, equals([1]));
    });

    test('should prevent computed tracking in effect', () {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final List<int> values = [];

      Effect(() {
        values.add(untracked(() => computed.value));
      });

      expect(values, equals([2]));

      signal.value = 2;
      // untracked应该阻止effect重新运行
      expect(values, equals([2]));
    });

    test('should allow mixed tracking and untracking', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final List<int> trackedValues = [];
      final List<int> untrackedValues = [];

      Effect(() {
        trackedValues.add(signal1.value);
        untrackedValues.add(untracked(() => signal2.value));
      });

      expect(trackedValues, equals([1]));
      expect(untrackedValues, equals([2]));

      signal1.value = 10;
      // 只有trackedValues应该更新
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2, 2]));

      signal2.value = 20;
      // 两个列表都不应该更新，因为signal1没有变化
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2, 2]));
    });

    test('should work with nested untracked calls', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(3);
      final List<int> values = [];

      Effect(() {
        values.add(
          untracked(() {
            final val1 = untracked(() => signal1.value);
            final val2 = untracked(() => signal2.value);
            return val1 + val2 + signal3.value;
          }),
        );
      });

      expect(values, equals([6])); // 1 + 2 + 3

      signal1.value = 10;
      signal2.value = 20;
      signal3.value = 30;
      // 所有信号都不应该被跟踪
      expect(values, equals([6]));
    });

    test('should work with complex expressions', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed = Computed<int>(() => signal1.value * signal2.value);
      final List<int> values = [];

      Effect(() {
        values.add(untracked(() => computed.value + signal1.value));
      });

      expect(values, equals([3])); // 2 + 1

      signal1.value = 5;
      signal2.value = 10;
      // untracked应该阻止effect重新运行
      expect(values, equals([3]));
    });

    test('should work with function calls', () {
      final signal = Signal(1);
      final List<int> values = [];

      int getValue() => signal.value;

      Effect(() {
        values.add(untracked(() => getValue()));
      });

      expect(values, equals([1]));

      signal.value = 2;
      // untracked应该阻止effect重新运行
      expect(values, equals([1]));
    });

    test('should work with conditional tracking', () {
      final conditionSignal = Signal(true);
      final valueSignal = Signal(42);
      final List<int> values = [];

      Effect(() {
        if (conditionSignal.value) {
          values.add(valueSignal.value);
        } else {
          values.add(untracked(() => valueSignal.value));
        }
      });

      expect(values, equals([42]));

      valueSignal.value = 100;
      // 应该被跟踪，因为conditionSignal.value为true
      expect(values, equals([42, 100]));

      conditionSignal.value = false;
      // 应该被跟踪，因为conditionSignal.value变化了
      expect(values, equals([42, 100, 100]));

      valueSignal.value = 200;
      // 不应该被跟踪，因为现在使用untracked
      expect(values, equals([42, 100, 100]));
    });

    test('should work with batch operations', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final List<int> values = [];

      Effect(() {
        values.add(untracked(() => signal1.value + signal2.value));
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      // untracked应该阻止effect重新运行
      expect(values, equals([3]));
    });

    test('should work with stream operations', () async {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([1]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 1));

      // untracked应该阻止effect重新运行
      expect(values, equals([1]));
    });

    test('should work with error handling', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        try {
          values.add(
            untracked(() {
              if (signal.value > 0) {
                return signal.value;
              } else {
                throw Exception('Invalid value');
              }
            }),
          );
        } catch (e) {
          values.add(-1);
        }
      });

      expect(values, equals([1]));

      signal.value = 2;
      // untracked应该阻止effect重新运行
      expect(values, equals([1]));

      signal.value = -1;
      // untracked应该阻止effect重新运行
      expect(values, equals([1]));
    });

    test('should work with async operations', () async {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        untracked(() async {
          await Future.delayed(const Duration(milliseconds: 1));
          values.add(signal.value);
        });
      });

      expect(values, equals([]));

      signal.value = 2;
      await Future.delayed(const Duration(milliseconds: 2));

      // untracked应该阻止effect重新运行，但async操作可能已经执行
      expect(values.length, lessThanOrEqualTo(1));
    });

    test('should work with multiple effects', () {
      final signal = Signal(1);
      final List<int> effect1Values = [];
      final List<int> effect2Values = [];

      Effect(() {
        effect1Values.add(signal.value);
      });

      Effect(() {
        effect2Values.add(untracked(() => signal.value));
      });

      expect(effect1Values, equals([1]));
      expect(effect2Values, equals([1]));

      signal.value = 2;

      // 只有effect1应该重新运行
      expect(effect1Values, equals([1, 2]));
      expect(effect2Values, equals([1]));
    });

    test('should work with computed dependencies', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed<int>(() => signal1.value * 2);
      final computed2 = Computed<int>(() => signal2.value * 3);
      final List<int> values = [];

      Effect(() {
        values.add(untracked(() => computed1.value + computed2.value));
      });

      expect(values, equals([8])); // 2 + 6

      signal1.value = 5;
      signal2.value = 10;
      // untracked应该阻止effect重新运行
      expect(values, equals([8]));
    });

    test('should work with null values', () {
      final signal = Signal<int?>(null);
      final List<int?> values = [];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([null]));

      signal.value = 42;
      // untracked应该阻止effect重新运行
      expect(values, equals([null]));
    });

    test('should work with custom objects', () {
      final signal = Signal(TestPerson('Alice', 30));
      final List<TestPerson> values = [];

      Effect(() {
        values.add(untracked(() => signal.value));
      });

      expect(values, equals([TestPerson('Alice', 30)]));

      signal.value = TestPerson('Bob', 25);
      // untracked应该阻止effect重新运行
      expect(values, equals([TestPerson('Alice', 30)]));
    });
  });
}
