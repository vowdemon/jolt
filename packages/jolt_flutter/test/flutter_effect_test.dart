import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('FlutterEffect Tests', () {
    testWidgets('should execute effect function immediately when lazy=false',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      // Effect should run immediately (synchronously on creation)
      expect(values, equals([1]));

      signal.dispose();
    });

    testWidgets('FlutterEffect.lazy should not run automatically',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      final effect = FlutterEffect.lazy(() {
        values.add(signal.value);
      });

      expect(values, isEmpty); // Does not run automatically

      signal.value = 2;
      await tester.pump(); // Wait for frame
      await tester.pumpAndSettle(); // Wait for frame end

      // Still doesn't auto-run when dependency changes (lazy effect)
      expect(values, isEmpty);

      effect.run(); // Manually trigger
      expect(values, equals([2])); // Runs when manually triggered

      signal.dispose();
      effect.dispose();
    });

    testWidgets('should schedule effect execution at frame end',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      expect(values, equals([1])); // Initial execution

      signal.value = 2;
      // Effect should not run immediately
      expect(values, equals([1]));

      // Wait for frame end
      await tester.pumpAndSettle();

      // Effect should run at frame end
      expect(values, equals([1, 2]));

      signal.dispose();
    });

    testWidgets('should batch multiple triggers within same frame',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      expect(values, equals([1])); // Initial execution

      // Trigger multiple times in same frame
      signal.value = 2;
      signal.value = 3;
      signal.value = 4;

      // Should not execute yet
      expect(values, equals([1]));

      // Wait for frame end
      await tester.pumpAndSettle();

      // Should execute only once with the final value
      expect(values, equals([1, 4]));

      signal.dispose();
    });

    testWidgets(
        'should execute once per frame when triggered in different frames',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      expect(values, equals([1])); // Initial execution

      signal.value = 2;
      await tester.pumpAndSettle();
      expect(values, equals([1, 2]));

      signal.value = 3;
      await tester.pumpAndSettle();
      expect(values, equals([1, 2, 3]));

      signal.value = 4;
      await tester.pumpAndSettle();
      expect(values, equals([1, 2, 3, 4]));

      signal.dispose();
    });

    testWidgets('should work with batch operations', (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal1.value + signal2.value);
      });

      expect(values, equals([3])); // Initial execution

      // Batch multiple updates
      batch(() {
        signal1.value = 10;
        signal2.value = 20;
      });

      // Should not execute immediately
      expect(values, equals([3]));

      // Wait for frame end
      await tester.pumpAndSettle();

      // Should execute once at frame end with batched values
      expect(values, equals([3, 30]));

      signal1.dispose();
      signal2.dispose();
    });

    testWidgets('should batch multiple signals within batch() and execute once',
        (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(3);
      final values = <List<int>>[];

      FlutterEffect(() {
        values.add([signal1.value, signal2.value, signal3.value]);
      });

      expect(values.length, equals(1)); // Initial execution

      // Multiple batch updates
      batch(() {
        signal1.value = 10;
        signal2.value = 20;
        signal3.value = 30;
      });

      expect(values.length, equals(1)); // Still initial

      // Wait for frame end
      await tester.pumpAndSettle();

      // Should execute once with all batched values
      expect(values.length, equals(2));
      expect(values.last, equals([10, 20, 30]));

      signal1.dispose();
      signal2.dispose();
      signal3.dispose();
    });

    testWidgets('should track multiple dependencies correctly', (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal1.value + signal2.value);
      });

      expect(values, equals([3])); // Initial: 1 + 2

      signal1.value = 10;
      await tester.pumpAndSettle();
      expect(values, equals([3, 12])); // 10 + 2

      signal2.value = 20;
      await tester.pumpAndSettle();
      expect(values, equals([3, 12, 30])); // 10 + 20

      signal1.dispose();
      signal2.dispose();
    });

    testWidgets('should track computed dependencies', (tester) async {
      final signal = Signal(1);
      final computed = Computed<int>(() => signal.value * 2);
      final values = <int>[];

      FlutterEffect(() {
        values.add(computed.value);
      });

      expect(values, equals([2])); // Initial: 1 * 2

      signal.value = 5;
      await tester.pumpAndSettle();
      expect(values, equals([2, 10])); // 5 * 2

      signal.dispose();
    });

    testWidgets('should handle manual run() call immediately', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      final effect = FlutterEffect.lazy(() {
        values.add(signal.value);
      });

      expect(values, isEmpty);

      // Manual run should execute immediately
      effect.run();
      expect(values, equals([1]));

      signal.value = 2;
      effect.run();
      expect(values, equals([1, 2]));

      signal.dispose();
      effect.dispose();
    });

    testWidgets('should dispose properly and cancel scheduled execution',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      final effect = FlutterEffect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));
      expect(effect.isDisposed, isFalse);

      signal.value = 2;
      // Dispose before frame end
      effect.dispose();

      expect(effect.isDisposed, isTrue);

      // Wait for frame end - effect should not execute
      await tester.pumpAndSettle();

      expect(values, equals([1])); // Should not have executed

      signal.dispose();
    });

    testWidgets('should work correctly with nested batch calls',
        (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal1.value + signal2.value);
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

      await tester.pumpAndSettle();

      // Should execute once with final values
      expect(values, equals([3, 40])); // 15 + 25

      signal1.dispose();
      signal2.dispose();
    });

    testWidgets('should batch multiple rapid changes across frames correctly',
        (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      expect(values, equals([1]));

      // Trigger in frame 1
      signal.value = 2;
      signal.value = 3;
      await tester.pump(); // Start frame processing
      await tester.pumpAndSettle(); // Wait for frame end

      expect(values.length, equals(2));
      expect(values.last, equals(3));

      // Trigger in frame 2
      signal.value = 4;
      signal.value = 5;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(values.length, equals(3));
      expect(values.last, equals(5));

      signal.dispose();
    });

    testWidgets('should work with multiple FlutterEffects independently',
        (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final values1 = <int>[];
      final values2 = <int>[];

      FlutterEffect(() {
        values1.add(signal1.value);
      });

      FlutterEffect(() {
        values2.add(signal2.value);
      });

      expect(values1, equals([1]));
      expect(values2, equals([2]));

      signal1.value = 10;
      signal2.value = 20;

      await tester.pumpAndSettle();

      // Both should execute independently
      expect(values1, equals([1, 10]));
      expect(values2, equals([2, 20]));

      signal1.dispose();
      signal2.dispose();
    });
  });
}
