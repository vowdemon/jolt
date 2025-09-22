import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import 'test_helpers.dart';

void main() {
  group('Effect', () {
    test('should run effect function immediately', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));
    });

    test('should re-run effect when dependencies change', () {
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

    test('should track multiple dependencies', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final List<int> values = [];

      Effect(() {
        values.add(signal1.value + signal2.value);
      });

      expect(values, equals([3]));

      signal1.value = 10;
      expect(values, equals([3, 12]));

      signal2.value = 20;
      expect(values, equals([3, 12, 30]));
    });

    test('should track computed dependencies', () {
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

    test('should handle nested effects', () {
      final signal = Signal(1);
      final List<int> outerValues = [];
      final List<int> innerValues = [];

      Effect(() {
        outerValues.add(signal.value);

        Effect(() {
          innerValues.add(signal.value * 2);
        });
      });

      expect(outerValues, equals([1]));
      expect(innerValues, equals([2]));

      signal.value = 3;
      expect(outerValues, equals([1, 3]));
      expect(innerValues, equals([2, 6]));
    });

    test('should handle dispose nested effects', () {
      final signal1 = Signal(1);
      final List<int> outerValues = [];
      final List<int> innerValues1 = [];
      final List<int> innerValues2 = [];
      late Effect outerEffect;
      final List<Effect> innerEffect1 = [];
      final List<Effect> innerEffect2 = [];
      final signals = <Signal<int>>[];
      late Computed<int> computed;

      outerEffect = Effect(() {
        outerValues.add(signal1.value);
        signals.add(Signal(1));
        if (signals.isNotEmpty) {
          computed = Computed(() => signals[0].value * 2);
          computed.value;
        }

        innerEffect1.add(Effect(() {
          innerValues1.add(signal1.value * 2);
          signals.add(Signal(2));
        }));

        innerEffect2.add(Effect(() {
          innerValues2.add(signal1.value * 3);
          signals.add(Signal(3));
        }));
      });

      signal1.value = 3;
      // define in effect inner will call 2 times
      expect(signals.length, equals(6));

      for (var e in innerEffect1) {
        e.dispose();
      }
      expect(innerEffect1.every((e) => e.isDisposed), isTrue);
      expect(innerEffect2.every((e) => e.isDisposed), isFalse);
      expect(outerEffect.isDisposed, isFalse);
      expect(outerValues, equals([1, 3]));
      expect(innerValues1, equals([2, 6]));
      expect(innerValues2, equals([3, 9]));
      expect(signals.length, equals(6));

      signals[0].value = 4;

      outerEffect.dispose();
      signal1.value = 4;
      expect(innerEffect1.every((e) => e.isDisposed), isTrue);
      expect(innerEffect2.every((e) => e.isDisposed), isTrue);
      expect(outerEffect.isDisposed, isTrue);
      expect(outerValues, equals([1, 3, 3]));
      expect(innerValues1, equals([2, 6, 6]));
      expect(innerValues2, equals([3, 9, 9]));
      expect(signals.length, equals(9));

      expect(computed.isDisposed, isFalse);
      expect(signals[0].isDisposed, isFalse);
      expect(computed.value, 8);
    });

    test('should dispose effect properly', () {
      final signal = Signal(1);
      final List<int> values = [];

      final effect = Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));
      expect(effect.isDisposed, isFalse);

      effect.dispose();
      expect(effect.isDisposed, isTrue);

      signal.value = 2;
      // 已释放的effect不应该重新运行
      expect(values, equals([1]));
    });

    test('should handle effect errors', () {
      final signal = Signal(1);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
        if (signal.value > 1) {
          throw Exception('Test error');
        }
      });

      expect(values, equals([1]));

      expect(() => signal.value = 2, throwsA(isA<Exception>()));
      expect(values, equals([1, 2]));
    });

    test('should work with batch updates', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final List<int> values = [];

      Effect(() {
        values.add(signal1.value + signal2.value);
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      // 批处理中只应该触发一次更新
      expect(values, equals([3, 30]));
    });

    test('should work with untracked', () {
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
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2, 2]));

      signal2.value = 20;
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2, 2]));
    });

    test('should handle conditional dependencies', () {
      final conditionSignal = Signal(true);
      final valueSignal = Signal(42);
      final List<int> values = [];

      Effect(() {
        if (conditionSignal.value) {
          values.add(valueSignal.value);
        } else {
          values.add(0);
        }
      });

      expect(values, equals([42]));

      valueSignal.value = 100;
      expect(values, equals([42, 100]));

      conditionSignal.value = false;
      expect(values, equals([42, 100, 0]));

      valueSignal.value = 200;
      expect(values, equals([42, 100, 0]));
    });

    test('should work with async operations', () async {
      final signal = Signal(1);
      final List<int> values = [];

      bool setted = false;
      Effect(() {
        values.add(signal.value);
        // 在effect中执行异步操作
        Future.delayed(const Duration(milliseconds: 1), () {
          if (setted) return;
          setted = true;
          values.add(signal.value * 10);
        });
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      await Future.delayed(const Duration(milliseconds: 2));
      expect(values, equals([1, 2, 20]));
    });

    test('should work with different data types', () {
      final stringSignal = Signal('hello');
      final List<String> values = [];

      Effect(() {
        values.add(stringSignal.value);
      });

      expect(values, equals(['hello']));

      stringSignal.value = 'world';
      expect(values, equals(['hello', 'world']));
    });

    test('should work with nullable values', () {
      final signal = Signal<int?>(null);
      final List<int?> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([null]));

      signal.value = 42;
      expect(values, equals([null, 42]));
    });

    test('should handle rapid value changes', () {
      final signal = Signal(0);
      final List<int> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([0]));

      // 快速连续更改值
      for (int i = 1; i <= 10; i++) {
        signal.value = i;
      }

      // 应该记录所有值
      expect(values, equals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
    });

    test('should work with custom objects', () {
      final signal = Signal(TestPerson('Alice', 30));
      final List<TestPerson> values = [];

      Effect(() {
        values.add(signal.value);
      });

      expect(values, equals([TestPerson('Alice', 30)]));

      signal.value = TestPerson('Bob', 25);
      expect(values, equals([TestPerson('Alice', 30), TestPerson('Bob', 25)]));
    });
  });

  group('EffectScope', () {
    test('should create effect scope', () {
      final signal = Signal(1);
      final List<int> values = [];

      final _ = EffectScope((_) {
        values.add(signal.value);
      });

      expect(values, equals([1]));
      // scope is disposed
    });

    test('should not watching in effect scope', () {
      final signal = Signal(1);
      final List<int> values = [];

      final _ = EffectScope((_) {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      signal.value = 2;

      expect(values, equals([1]));
    });

    test('should dispose all node in effect scope', () async {
      late Signal<int> signal;
      late Computed<int> computed;
      late Effect effect;
      final values = <int>[];
      final scope = EffectScope((s) {
        signal = Signal(1);
        computed = Computed<int>(() => signal.value * 2);
        effect = Effect(() {
          values.add(signal.value);
        });
      });

      expect(scope.isDisposed, isFalse);
      expect(signal.isDisposed, isFalse);
      expect(computed.isDisposed, isFalse);
      expect(effect.isDisposed, isFalse);
      expect(values, equals([1]));

      scope.dispose();

      expect(scope.isDisposed, isTrue);
      expect(signal.isDisposed, isTrue);
      expect(computed.isDisposed, isTrue);
      expect(effect.isDisposed, isTrue);
      expect(values, equals([1]));
    });

    test('should handle nested effect scopes', () {
      final signal = Signal(1);
      final List<int> outerValues = [];
      final List<int> innerValues = [];
      late EffectScope outerScope;
      late EffectScope innerScope;

      outerScope = EffectScope((_) {
        Effect(() {
          outerValues.add(signal.value);
        });

        innerScope = EffectScope((_) {
          Effect(() {
            innerValues.add(signal.value * 2);
          });
        });

        // innerScope is disposed
      });

      expect(outerValues, equals([1]));
      expect(innerValues, equals([2]));

      signal.value = 3;
      expect(outerValues, equals([1, 3]));
      expect(innerValues, equals([2, 6]));

      outerScope.dispose();
      expect(outerScope.isDisposed, isTrue);
      expect(innerScope.isDisposed, isTrue);
    });

    test('should work with multiple effect scopes', () {
      final signal = Signal(1);
      final List<int> scope1Values = [];
      final List<int> scope2Values = [];

      final scope1 = EffectScope((_) {
        Effect(() {
          scope1Values.add(signal.value);
        });
      });

      final scope2 = EffectScope((_) {
        Effect(() {
          scope2Values.add(signal.value * 2);
        });
      });

      expect(scope1Values, equals([1]));
      expect(scope2Values, equals([2]));

      signal.value = 3;
      expect(scope1Values, equals([1, 3]));
      expect(scope2Values, equals([2, 6]));

      scope1.dispose();
      expect(scope1.isDisposed, isTrue);
      expect(scope2.isDisposed, isFalse);
      expect(signal.isDisposed, isFalse);
      signal.value = 5;
      expect(scope1Values, equals([1, 3]));
      expect(scope2Values, equals([2, 6, 10]));
    });

    test('should handle effect scope errors', () {
      final signal = Signal(1);
      final List<int> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(signal.value);
          if (signal.value > 1) {
            throw Exception('Test error');
          }
        });
      });

      expect(values, equals([1]));

      expect(() => signal.value = 2, throwsA(isA<Exception>()));
      expect(values, equals([1, 2]));
    });

    test('should work with batch updates', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final List<int> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(signal1.value + signal2.value);
        });
      });

      expect(values, equals([3]));

      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      // 批处理中只应该触发一次更新
      expect(values, equals([3, 30]));
    });

    test('should work with untracked', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final List<int> trackedValues = [];
      final List<int> untrackedValues = [];

      final _ = EffectScope((_) {
        Effect(() {
          trackedValues.add(signal1.value);
        });
        Effect(() {
          untrackedValues.add(untracked(() => signal2.value));
        });
      });

      expect(trackedValues, equals([1]));
      expect(untrackedValues, equals([2]));

      signal1.value = 10;
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2]));

      signal2.value = 20;
      expect(trackedValues, equals([1, 10]));
      expect(untrackedValues, equals([2]));
    });

    test('should work with async operations', () async {
      final signal = Signal(1);
      final List<int> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(signal.value);
        });
        // 在scope中执行异步操作
        Future.delayed(const Duration(milliseconds: 1), () {
          values.add(signal.value * 10);
        });
      });

      expect(values, equals([1]));

      signal.value = 2;
      expect(values, equals([1, 2]));

      await Future.delayed(const Duration(milliseconds: 2));
      expect(values, equals([1, 2, 20]));
    });

    test('should work with different data types', () {
      final stringSignal = Signal('hello');
      final List<String> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(stringSignal.value);
        });
      });

      expect(values, equals(['hello']));

      stringSignal.value = 'world';
      expect(values, equals(['hello', 'world']));
    });

    test('should work with nullable values', () {
      final signal = Signal<int?>(null);
      final List<int?> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(signal.value);
        });
      });

      expect(values, equals([null]));

      signal.value = 42;
      expect(values, equals([null, 42]));
    });

    test('should handle rapid value changes', () {
      final signal = Signal(0);
      final List<int> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(signal.value);
        });
      });

      expect(values, equals([0]));

      // 快速连续更改值
      for (int i = 1; i <= 10; i++) {
        signal.value = i;
      }

      // 应该记录所有值
      expect(values, equals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
    });

    test('should work with custom objects', () {
      final signal = Signal(TestPerson('Alice', 30));
      final List<TestPerson> values = [];

      final _ = EffectScope((_) {
        Effect(() {
          values.add(signal.value);
        });
      });

      expect(values, equals([TestPerson('Alice', 30)]));

      signal.value = TestPerson('Bob', 25);
      expect(values, equals([TestPerson('Alice', 30), TestPerson('Bob', 25)]));
    });
  });

  group('Watcher', () {
    test('should work with sources eventually', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed(() => signal1.value + signal2.value);
      final values = <(int, int, int)>[];
      Watcher(() => (signal1.value, signal2.value, computed1.value),
          (value, _) {
        final (a, b, c) = value;
        values.add((a, b, c));
      });

      expect(values, equals([]));
      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      expect(values, equals([(2, 4, 6)]));

      signal1.value = 4;

      expect(values, equals([(2, 4, 6), (4, 4, 8)]));
    });

    test('should work with sources immediately', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed(() => signal1.value + signal2.value);
      final values = <(int, int, int)>[];
      Watcher(() => (signal1.value, signal2.value, computed1.value),
          (value, _) {
        final (a, b, c) = value;
        values.add((a, b, c));
      }, immediately: true);

      expect(values, equals([(1, 2, 3)]));
      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });

      expect(values, equals([(1, 2, 3), (2, 4, 6)]));
    });

    test('should work with sources builtin comparator', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed(() => signal1.value + signal2.value);
      final values = <(int, int, int)>[];
      Watcher(() => (signal1.value, signal2.value, computed1.value),
          (value, _) {
        final (a, b, c) = value;
        values.add((a, b, c));
      });

      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      expect(values, equals([(2, 4, 6)]));
    });

    test('should work with sources custom comparator', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed(() => signal1.value + signal2.value);
      final values1 = <(int, int, int)>[];
      Watcher(
        () => (signal1.value, signal2.value, computed1.value),
        (value, _) {
          final (a, b, c) = value;
          values1.add((a, b, c));
        },
        when: (newValue, oldValue) => true,
      );

      final values2 = <(int, int, int)>[];
      Watcher(
        () => (signal1.value, signal2.value, computed1.value),
        (value, _) {
          final (a, b, c) = value;
          values2.add((a, b, c));
        },
        when: (newValue, oldValue) => newValue != oldValue,
      );

      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      signal1.notify();

      expect(values1, equals([(2, 4, 6), (2, 4, 6)]));
      expect(
          values2,
          equals([
            (2, 4, 6),
          ]));
    });

    test('should handle watcher dispose', () {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final computed1 = Computed(() => signal1.value + signal2.value);
      final values = <(int, int, int)>[];
      final watcher = Watcher(
          () => (signal1.value, signal2.value, computed1.value), (value, _) {
        final (a, b, c) = value;
        values.add((a, b, c));
      });

      expect(values, equals([]));
      batch(() {
        signal1.value = 2;
        signal2.value = 4;
      });
      expect(values, equals([(2, 4, 6)]));

      watcher.dispose();

      signal1.value = 4;

      expect(
          values,
          equals([
            (2, 4, 6),
          ]));
    });
  });

  test(
      'should handle deeply nested effect scopes with cross-scope signals/computed/effects',
      () {
    final globalSignal = Signal(10);
    final globalComputed = Computed(() => globalSignal.value * 2);

    final globalEffectValues = <int>[];
    Effect(() {
      globalEffectValues.add(globalComputed.value);
    });

    final outerValues = <int>[];
    final midValues = <int>[];
    final innerValues = <int>[];
    final crossValues = <int>[];

    late EffectScope outerScope;
    late EffectScope midScope;
    late EffectScope innerScope;

    late Signal<int> outerSignal;
    late Computed<int> outerComputed;
    late Effect outerEffect;

    late Signal<int> midSignal;
    late Computed<int> midComputed;
    late Effect midEffect;

    late Signal<int> innerSignal;
    late Computed<int> innerComputed;
    late Effect innerEffect1;
    late Effect innerEffect2;

    outerScope = EffectScope((s) {
      outerSignal = Signal(1);
      outerComputed = Computed(() => outerSignal.value + globalSignal.value);

      outerEffect = Effect(() {
        outerValues.add(outerComputed.value);
      });

      midScope = EffectScope((s) {
        midSignal = Signal(5);
        midComputed = Computed(() => midSignal.value + outerSignal.value);

        midEffect = Effect(() {
          midValues.add(midComputed.value);
        });

        innerScope = EffectScope((s) {
          innerSignal = Signal(100);
          innerComputed = Computed(
            () => innerSignal.value + midSignal.value + globalSignal.value,
          );

          innerEffect1 = Effect(() {
            innerValues.add(innerComputed.value);
          });

          innerEffect2 = Effect(() {
            crossValues.add(innerSignal.value * outerSignal.value);
          });
        });
      });
    });

    expect(globalEffectValues, equals([20]));
    expect(outerValues, equals([11]));
    expect(midValues, equals([6]));
    expect(innerValues, equals([115]));
    expect(crossValues, equals([100]));

    globalSignal.value = 20;
    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21]));
    expect(midValues, equals([6]));
    expect(innerValues, equals([115, 125]));
    expect(crossValues, equals([100]));

    midSignal.value = 7;
    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21]));
    expect(midValues, equals([6, 8]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100]));

    outerSignal.value = 2;
    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21, 22]));
    expect(midValues, equals([6, 8, 9]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));

    innerScope.dispose();
    expect(innerScope.isDisposed, isTrue);
    expect(innerSignal.isDisposed, isTrue);
    expect(innerComputed.isDisposed, isTrue);
    expect(innerEffect1.isDisposed, isTrue);
    expect(innerEffect2.isDisposed, isTrue);

    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21, 22]));
    expect(midValues, equals([6, 8, 9]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));

    outerSignal.value = 3;
    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21, 22, 23]));
    expect(midValues, equals([6, 8, 9, 10]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));

    midScope.dispose();
    expect(midScope.isDisposed, isTrue);
    expect(midSignal.isDisposed, isTrue);
    expect(midComputed.isDisposed, isTrue);
    expect(midEffect.isDisposed, isTrue);

    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21, 22, 23]));
    expect(midValues, equals([6, 8, 9, 10]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));

    outerSignal.value = 4;
    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21, 22, 23, 24]));
    expect(midValues, equals([6, 8, 9, 10]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));

    outerScope.dispose();
    expect(outerScope.isDisposed, isTrue);
    expect(outerSignal.isDisposed, isTrue);
    expect(outerComputed.isDisposed, isTrue);
    expect(outerEffect.isDisposed, isTrue);

    expect(globalEffectValues, equals([20, 40]));
    expect(outerValues, equals([11, 21, 22, 23, 24]));
    expect(midValues, equals([6, 8, 9, 10]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));

    globalSignal.value = 30;
    expect(globalEffectValues, equals([20, 40, 60]));
    expect(outerValues, equals([11, 21, 22, 23, 24]));
    expect(midValues, equals([6, 8, 9, 10]));
    expect(innerValues, equals([115, 125, 127]));
    expect(crossValues, equals([100, 200]));
  });
}
