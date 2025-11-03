import 'package:jolt/jolt.dart';
import 'package:test/test.dart';
import '../utils.dart';

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

      for (int i = 1; i <= 10; i++) {
        signal.value = i;
      }

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

    test('should support many effects', () {
      // Create a signal that will trigger many effects at once
      final signal = Signal(0);

      // Create more than 64 effects to test queued.add expansion
      // (queue initial size is 64)
      const int effectCount = 100;
      final List<List<int>> allValues = List.generate(
        effectCount,
        (_) => <int>[],
      );

      for (int i = 0; i < effectCount; i++) {
        final index = i;
        Effect(() {
          allValues[index].add(signal.value);
        });
      }

      // Verify all effects ran initially
      for (int i = 0; i < effectCount; i++) {
        expect(allValues[i], equals([0]));
      }

      // Trigger all effects simultaneously
      signal.value = 1;

      // Verify all effects were flushed correctly
      for (int i = 0; i < effectCount; i++) {
        expect(allValues[i], equals([0, 1]));
      }

      // Trigger again to ensure queued.add still works correctly
      signal.value = 2;

      // Verify all effects were flushed again
      for (int i = 0; i < effectCount; i++) {
        expect(allValues[i], equals([0, 1, 2]));
      }
    });

    test(
        'should handle effect modifying values during recursedCheck propagation',
        () {
      // Create complex scenario where effect modifies values during execution
      // This triggers complex recursive propagation with recursedCheck state
      final signalA = Signal(1);
      final signalB = Signal(2);
      final signalC = Signal(3);

      late Computed<int> computed1;
      late Computed<int> computed2;
      late Computed<int> computed3;
      late Computed<int> computed4;

      // Computed 1 depends on signalA
      computed1 = Computed<int>(() => signalA.value * 10);

      // Computed 2 depends on computed1 and signalB
      computed2 = Computed<int>(() {
        // Access computed1 during recursedCheck
        final c1 = computed1.value;
        return c1 + signalB.value;
      });

      // Computed 3 depends on computed2, but also accesses computed1
      computed3 = Computed<int>(() {
        // Access computed1 during recursedCheck state
        computed1.value;
        return computed2.value * 2;
      });

      // Computed 4 depends on computed3 and computed1
      computed4 = Computed<int>(() {
        // Access computed1 during recursedCheck state
        computed1.value;
        return computed3.value + computed1.value;
      });

      final effectValues = <int>[];
      final effectCallCount = <int>[0];
      final modifiedOnce = <bool>[false];

      // Effect depends on computed4, and modifies signal values during execution
      // This creates complex propagation where nodes are in recursedCheck state
      // but are neither dirty nor pending, triggering the special branch
      Effect(() {
        effectCallCount[0]++;
        // Access multiple computed values during recursedCheck
        computed4.value;
        computed2.value;
        computed3.value;

        // Modify signal values during effect execution (only once to avoid infinite loop)
        // This triggers new propagation while effect is in recursedCheck state
        if (!modifiedOnce[0] && signalA.value == 2) {
          modifiedOnce[0] = true;
          signalB.value = signalB.value + 1;
        }

        effectValues.add(computed4.value);
      });

      expect(computed1.value, equals(10));
      expect(computed2.value, equals(12));
      expect(computed3.value, equals(24));
      expect(computed4.value, equals(34));
      expect(effectValues, equals([34]));
      expect(effectCallCount[0], equals(1));

      // Update signalA to trigger complex propagation
      // During propagation, effect runs and modifies signalB,
      // creating cascading updates with recursedCheck states
      signalA.value = 2;

      expect(computed1.value, equals(20));
      expect(computed2.value, equals(23)); // signalB was incremented by effect
      expect(computed3.value, equals(46));
      expect(computed4.value, equals(66));
      expect(effectValues.length, greaterThan(1)); // Effect runs multiple times

      // Create another complex scenario with batch update
      batch(() {
        signalA.value = 3;
        signalC.value = 10;
      });

      expect(computed1.value, equals(30));
    });

    test(
        'should trigger recursedCheck branch with effect modifying computed dependencies',
        () {
      // Create scenario with multiple effects and computed values
      // where effects modify signals that other computed values depend on
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(0);

      late Computed<int> compA;
      late Computed<int> compB;
      late Computed<int> compC;

      // Computed A depends on signal1
      compA = Computed<int>(() => signal1.value * 5);

      // Computed B depends on compA and signal2
      compB = Computed<int>(() {
        // Access compA during recursedCheck
        compA.value;
        return compA.value + signal2.value;
      });

      // Computed C depends on compB and also accesses compA
      compC = Computed<int>(() {
        // Access compA during recursedCheck state
        compA.value;
        return compB.value * 2;
      });

      final effect1Values = <int>[];
      final effect2Values = <int>[];
      final effect1Called = <bool>[false];
      final effect2Called = <bool>[false];

      // Effect 1 depends on compC and modifies signal3 (not signal2 to avoid loops)
      Effect(() {
        if (!effect1Called[0]) {
          effect1Called[0] = true;
          effect1Values.add(compC.value);
          // Modify signal3 during recursedCheck (not signal2 to avoid infinite loop)
          signal3.value = signal3.value + 1;
        }
      });

      // Effect 2 depends on compB and accesses compA
      Effect(() {
        if (!effect2Called[0]) {
          effect2Called[0] = true;
          // Access compA during recursedCheck
          compA.value;
          effect2Values.add(compB.value);
          // Modify signal3 during recursedCheck (not signal1 to avoid infinite loop)
          signal3.value = signal3.value + 1;
        }
      });

      expect(compA.value, equals(5));
      expect(compB.value, equals(7));
      expect(compC.value, equals(14));

      // Update signal1 to trigger complex propagation
      // Effects will modify signal3 during their recursedCheck state,
      // creating cascading updates that trigger the special branch
      signal1.value = 3;

      expect(compA.value, equals(15));
      // compB = compA + signal2 = 15 + 2 = 17 (signal2 unchanged)
      expect(compB.value, equals(17));
      expect(compC.value, equals(34));

      // Reset flags for next test
      effect1Called[0] = false;
      effect2Called[0] = false;

      // Test with batch update
      batch(() {
        signal1.value = 5;
        signal2.value = 10;
      });

      expect(compA.value, equals(25));
      // compB = compA + signal2 = 25 + 10 = 35
      expect(compB.value, equals(35));
      expect(compC.value, equals(70));
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
      expect(signal.testNoSubscribers(), isTrue);
      expect(computed.testNoSubscribers(), isTrue);
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
    expect(innerSignal.testNoSubscribers(), isTrue);
    expect(innerComputed.testNoSubscribers(), isTrue);
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
    expect(midSignal.testNoSubscribers(), isTrue);
    expect(midComputed.testNoSubscribers(), isTrue);
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
    expect(outerSignal.testNoSubscribers(), isTrue);
    expect(outerComputed.testNoSubscribers(), isTrue);
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

  group('onEffectCleanup', () {
    test('should call cleanup when effect is disposed', () {
      final cleanupCalled = <bool>[false];

      final effect = Effect(() {
        onEffectCleanup(() {
          cleanupCalled[0] = true;
        });
      });

      expect(cleanupCalled[0], isFalse);

      effect.dispose();

      expect(cleanupCalled[0], isTrue);
    });

    test('should call all cleanups when effect runs again', () {
      final signal = Signal(1);
      final cleanup1Called = <bool>[false];
      final cleanup2Called = <bool>[false];
      final cleanup3Called = <bool>[false];

      Effect(() {
        signal.value;
        onEffectCleanup(() {
          cleanup1Called[0] = true;
        });
        onEffectCleanup(() {
          cleanup2Called[0] = true;
        });
        onEffectCleanup(() {
          cleanup3Called[0] = true;
        });
      });

      // Cleanups should not be called during initial registration
      expect(cleanup1Called[0], isFalse);
      expect(cleanup2Called[0], isFalse);
      expect(cleanup3Called[0], isFalse);

      // Trigger effect to run again, all cleanups should be called
      signal.value = 2;
      expect(cleanup1Called[0], isTrue);
      expect(cleanup2Called[0], isTrue);
      expect(cleanup3Called[0], isTrue);
    });

    test('should call all cleanups when effect is disposed', () {
      final cleanup1Called = <bool>[false];
      final cleanup2Called = <bool>[false];

      final effect = Effect(() {
        onEffectCleanup(() {
          cleanup1Called[0] = true;
        });
        onEffectCleanup(() {
          cleanup2Called[0] = true;
        });
      });

      expect(cleanup1Called[0], isFalse);
      expect(cleanup2Called[0], isFalse);

      effect.dispose();

      // All cleanups should be called on dispose
      expect(cleanup1Called[0], isTrue);
      expect(cleanup2Called[0], isTrue);
    });

    test('should call cleanups in registration order', () {
      final signal = Signal(1);
      final cleanupOrder = <int>[];

      Effect(() {
        signal.value;
        onEffectCleanup(() {
          cleanupOrder.add(1);
        });
        onEffectCleanup(() {
          cleanupOrder.add(2);
        });
        onEffectCleanup(() {
          cleanupOrder.add(3);
        });
      });

      signal.value = 2;

      // Cleanups should be called in registration order
      expect(cleanupOrder, equals([1, 2, 3]));
    });

    test('should clear cleanups after execution', () {
      final signal = Signal(1);
      final cleanupCallCount = <int>[0];

      Effect(() {
        signal.value;
        // Register cleanup - will be called before next run
        onEffectCleanup(() {
          cleanupCallCount[0]++;
        });
      });

      expect(cleanupCallCount[0], equals(0));

      // First run - cleanup registered but not called yet
      signal.value = 2;
      // Cleanup is called before effect runs, then cleared
      expect(cleanupCallCount[0], equals(1));

      // Second run - cleanup is called again because it's re-registered in effect
      signal.value = 3;
      // Effect runs again, registers cleanup again, so it's called before this run
      expect(cleanupCallCount[0], equals(2));
    });

    test('should allow multiple cleanups in nested effects', () {
      final signal = Signal(1);
      final outerCleanup1Called = <bool>[false];
      final outerCleanup2Called = <bool>[false];
      final innerCleanupCalled = <bool>[false];

      late Effect innerEffect;

      Effect(() {
        signal.value;
        onEffectCleanup(() {
          outerCleanup1Called[0] = true;
        });
        onEffectCleanup(() {
          outerCleanup2Called[0] = true;
        });

        innerEffect = Effect(() {
          signal.value;
          onEffectCleanup(() {
            innerCleanupCalled[0] = true;
          });
        });
      });

      expect(outerCleanup1Called[0], isFalse);
      expect(outerCleanup2Called[0], isFalse);
      expect(innerCleanupCalled[0], isFalse);

      // Dispose inner effect
      innerEffect.dispose();
      expect(innerCleanupCalled[0], isTrue);
      expect(outerCleanup1Called[0], isFalse);
      expect(outerCleanup2Called[0], isFalse);

      // Trigger outer effect
      signal.value = 2;
      expect(outerCleanup1Called[0], isTrue);
      expect(outerCleanup2Called[0], isTrue);
    });

    test('should work with Watcher', () {
      final signal = Signal(1);
      final cleanupCalled = <bool>[false];
      final watcherValues = <int>[];

      final watcher = Watcher(
        () => signal.value,
        (newValue, _) {
          watcherValues.add(newValue);
          // onEffectCleanup can automatically detect Watcher via activeWatcher
          onEffectCleanup(() {
            cleanupCalled[0] = true;
          });
        },
      );

      expect(cleanupCalled[0], isFalse);
      expect(watcherValues, isEmpty);

      // Trigger watcher
      signal.value = 2;
      expect(watcherValues, equals([2]));
      // Cleanup should not be called yet (only registered)
      expect(cleanupCalled[0], isFalse);

      // Dispose watcher - cleanup should be called
      watcher.dispose();
      expect(cleanupCalled[0], isTrue);
    });

    test('should call all cleanups in Watcher when it runs again', () {
      final signal = Signal(1);
      final cleanup1Called = <bool>[false];
      final cleanup2Called = <bool>[false];
      final cleanup3Called = <bool>[false];

      Watcher(
        () => signal.value,
        (newValue, _) {
          // onEffectCleanup automatically detects Watcher via activeWatcher
          onEffectCleanup(() {
            cleanup1Called[0] = true;
          });
          onEffectCleanup(() {
            cleanup2Called[0] = true;
          });
          onEffectCleanup(() {
            cleanup3Called[0] = true;
          });
        },
      );

      expect(cleanup1Called[0], isFalse);
      expect(cleanup2Called[0], isFalse);
      expect(cleanup3Called[0], isFalse);

      // Trigger watcher first time - no cleanup called yet
      signal.value = 2;
      expect(cleanup1Called[0], isFalse);
      expect(cleanup2Called[0], isFalse);
      expect(cleanup3Called[0], isFalse);

      // Trigger watcher again - all cleanups should be called
      signal.value = 3;
      expect(cleanup1Called[0], isTrue);
      expect(cleanup2Called[0], isTrue);
      expect(cleanup3Called[0], isTrue);
    });

    test('should call cleanups in Watcher in registration order', () {
      final signal = Signal(1);
      final cleanupOrder = <int>[];

      Watcher(
        () => signal.value,
        (newValue, _) {
          onEffectCleanup(() {
            cleanupOrder.add(1);
          });
          onEffectCleanup(() {
            cleanupOrder.add(2);
          });
          onEffectCleanup(() {
            cleanupOrder.add(3);
          });
        },
      );

      // First trigger - no cleanup yet
      signal.value = 2;
      expect(cleanupOrder, isEmpty);

      // Second trigger - cleanups should be called in order
      signal.value = 3;
      expect(cleanupOrder, equals([1, 2, 3]));
    });

    test('should call cleanup when Watcher is disposed', () {
      final signal = Signal(1);
      final cleanupCalled = <bool>[false];

      final watcher = Watcher(
        () => signal.value,
        (newValue, _) {
          onEffectCleanup(() {
            cleanupCalled[0] = true;
          });
        },
      );

      expect(cleanupCalled[0], isFalse);

      // Trigger watcher to register cleanup
      signal.value = 2;
      expect(
          cleanupCalled[0], isFalse); // Cleanup registered but not called yet

      watcher.dispose();

      expect(cleanupCalled[0], isTrue);
    });
  });

  group('onScopeDispose', () {
    test('should call cleanup when EffectScope is disposed', () {
      final cleanupCalled = <bool>[false];

      final scope = EffectScope((scope) {
        onScopeDispose(() {
          cleanupCalled[0] = true;
        });
      });

      expect(cleanupCalled[0], isFalse);

      scope.dispose();

      expect(cleanupCalled[0], isTrue);
    });

    test('should call all cleanups when EffectScope is disposed', () {
      final cleanup1Called = <bool>[false];
      final cleanup2Called = <bool>[false];
      final cleanup3Called = <bool>[false];

      final scope = EffectScope((scope) {
        onScopeDispose(() {
          cleanup1Called[0] = true;
        });
        onScopeDispose(() {
          cleanup2Called[0] = true;
        });
        onScopeDispose(() {
          cleanup3Called[0] = true;
        });
      });

      expect(cleanup1Called[0], isFalse);
      expect(cleanup2Called[0], isFalse);
      expect(cleanup3Called[0], isFalse);

      scope.dispose();

      // All cleanups should be called on dispose
      expect(cleanup1Called[0], isTrue);
      expect(cleanup2Called[0], isTrue);
      expect(cleanup3Called[0], isTrue);
    });

    test('should call cleanups in EffectScope in registration order', () {
      final cleanupOrder = <int>[];

      final scope = EffectScope((scope) {
        onScopeDispose(() {
          cleanupOrder.add(1);
        });
        onScopeDispose(() {
          cleanupOrder.add(2);
        });
        onScopeDispose(() {
          cleanupOrder.add(3);
        });
      });

      scope.dispose();

      // Cleanups should be called in registration order
      expect(cleanupOrder, equals([1, 2, 3]));
    });

    test('should work with nested EffectScopes', () {
      final outerCleanupCalled = <bool>[false];
      final innerCleanupCalled = <bool>[false];
      late EffectScope innerScope;

      final outerScope = EffectScope((scope) {
        onScopeDispose(() {
          outerCleanupCalled[0] = true;
        });

        innerScope = EffectScope((scope) {
          onScopeDispose(() {
            innerCleanupCalled[0] = true;
          });
        });
      });

      expect(outerCleanupCalled[0], isFalse);
      expect(innerCleanupCalled[0], isFalse);

      // Dispose inner scope
      innerScope.dispose();
      expect(innerCleanupCalled[0], isTrue);
      expect(outerCleanupCalled[0], isFalse);

      // Dispose outer scope
      outerScope.dispose();
      expect(outerCleanupCalled[0], isTrue);
    });

    test('should work with scope.run() method', () {
      final cleanupCalled = <bool>[false];

      final scope = EffectScope(null);

      scope.run((scope) {
        onScopeDispose(() {
          cleanupCalled[0] = true;
        });
      });

      expect(cleanupCalled[0], isFalse);

      scope.dispose();

      expect(cleanupCalled[0], isTrue);
    });

    test('should work with explicit owner parameter', () {
      final cleanupCalled = <bool>[false];
      final EffectScope scope = EffectScope(null);

      EffectScope(null).run((s) {
        // Use explicit owner parameter
        onScopeDispose(() {
          cleanupCalled[0] = true;
        }, owner: scope);
      });

      expect(cleanupCalled[0], isFalse);

      scope.dispose();

      expect(cleanupCalled[0], isTrue);
    });
  });
}
