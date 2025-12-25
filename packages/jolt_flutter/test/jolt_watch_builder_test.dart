import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/extension.dart';

void main() {
  group('JoltWatchBuilder Tests', () {
    testWidgets('should render with initial signal value', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: counter,
            builder: (context, value) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should respond to signal change', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: counter,
            builder: (context, value) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should respond to computed signal changes', (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: doubled,
            builder: (context, value) => Text('Doubled: $value'),
          ),
        ),
      );

      expect(find.text('Doubled: 0'), findsOneWidget);

      counter.value = 3;
      await tester.pumpAndSettle();

      expect(find.text('Doubled: 6'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should work with JoltWatchBuilder.value factory',
        (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder.value(
            readable: counter,
            builder: (value) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle multiple signal changes', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: counter,
            builder: (context, value) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 1;
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);

      counter.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Count: 2'), findsOneWidget);

      counter.value = 100;
      await tester.pumpAndSettle();
      expect(find.text('Count: 100'), findsOneWidget);

      counter.dispose();
    });

    testWidgets(
        'should handle nested JoltWatchBuilder with independent signals',
        (tester) async {
      final outerSignal = Signal('Outer');
      final innerSignal = Signal('Inner');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<String>(
            readable: outerSignal,
            builder: (context, value) => Column(
              children: [
                Text('Outer: $value'),
                JoltWatchBuilder<String>(
                  readable: innerSignal,
                  builder: (context, value) => Text('Inner: $value'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Outer: Outer'), findsOneWidget);
      expect(find.text('Inner: Inner'), findsOneWidget);

      // Update outer signal - only outer should rebuild
      outerSignal.value = 'Outer2';
      await tester.pumpAndSettle();

      expect(find.text('Outer: Outer2'), findsOneWidget);
      expect(find.text('Inner: Inner'), findsOneWidget);

      // Update inner signal - only inner should rebuild
      innerSignal.value = 'Inner2';
      await tester.pumpAndSettle();

      expect(find.text('Outer: Outer2'), findsOneWidget);
      expect(find.text('Inner: Inner2'), findsOneWidget);

      outerSignal.dispose();
      innerSignal.dispose();
    });

    testWidgets('should handle deeply nested JoltWatchBuilder', (tester) async {
      final level1 = Signal('L1');
      final level2 = Signal('L2');
      final level3 = Signal('L3');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<String>(
            readable: level1,
            builder: (context, value) => Column(
              children: [
                Text('Level1: $value'),
                JoltWatchBuilder<String>(
                  readable: level2,
                  builder: (context, value) => Column(
                    children: [
                      Text('Level2: $value'),
                      JoltWatchBuilder<String>(
                        readable: level3,
                        builder: (context, value) => Text('Level3: $value'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Level1: L1'), findsOneWidget);
      expect(find.text('Level2: L2'), findsOneWidget);
      expect(find.text('Level3: L3'), findsOneWidget);

      // Update level3 - only level3 should rebuild
      level3.value = 'L3-2';
      await tester.pumpAndSettle();

      expect(find.text('Level1: L1'), findsOneWidget);
      expect(find.text('Level2: L2'), findsOneWidget);
      expect(find.text('Level3: L3-2'), findsOneWidget);

      // Update level2 - level2 and its children should rebuild
      level2.value = 'L2-2';
      await tester.pumpAndSettle();

      expect(find.text('Level1: L1'), findsOneWidget);
      expect(find.text('Level2: L2-2'), findsOneWidget);
      expect(find.text('Level3: L3-2'), findsOneWidget);

      level1.dispose();
      level2.dispose();
      level3.dispose();
    });

    testWidgets(
        'should dispose resources correctly and stop responding after unmount',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: counter,
            builder: (context, value) {
              buildCount++;
              return Text('Count: $value');
            },
          ),
        ),
      );

      expect(buildCount, greaterThan(0));
      final initialBuildCount = buildCount;

      // Update signal - should rebuild
      counter.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      final buildCountBeforeUnmount = buildCount;

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Update signal after unmount should not cause rebuild
      counter.value = 2;
      await tester.pumpAndSettle();

      expect(buildCount, equals(buildCountBeforeUnmount));

      counter.dispose();
    });

    testWidgets('should handle batch updates and rebuild only once after batch',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: counter,
            builder: (context, value) {
              buildCount++;
              return Text('Count: $value');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      // Batch updates - should only rebuild once after batch completes
      batch(() {
        counter.value = 1;
        counter.value = 2;
        counter.value = 3;
      });

      await tester.pumpAndSettle();

      // Should only rebuild once after batch
      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 3'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle multiple batch updates', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: counter,
            builder: (context, value) {
              buildCount++;
              return Text('Count: $value');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      // First batch
      batch(() {
        counter.value = 10;
        counter.value = 20;
      });
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 20'), findsOneWidget);

      // Second batch
      batch(() {
        counter.value = 30;
        counter.value = 40;
      });
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 2));
      expect(find.text('Count: 40'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should rebuild when widget itself changes', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            key: const Key('builder1'),
            readable: counter,
            builder: (context, value) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Update widget with different key - should rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            key: const Key('builder2'),
            readable: counter,
            builder: (context, value) => Text('New Count: $value'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Count: 0'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle different Readable types', (tester) async {
      // Test with Signal
      final signal = Signal('signal');
      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<String>(
            readable: signal,
            builder: (context, value) => Text('Signal: $value'),
          ),
        ),
      );
      expect(find.text('Signal: signal'), findsOneWidget);
      signal.dispose();

      // Test with Computed
      final source = Signal(5);
      final computed = Computed(() => source.value * 2);
      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<int>(
            readable: computed,
            builder: (context, value) => Text('Computed: $value'),
          ),
        ),
      );
      expect(find.text('Computed: 10'), findsOneWidget);

      source.value = 6;
      await tester.pumpAndSettle();
      expect(find.text('Computed: 12'), findsOneWidget);

      source.dispose();
    });

    testWidgets('should handle nullable values', (tester) async {
      final nullableSignal = Signal<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatchBuilder<String?>(
            readable: nullableSignal,
            builder: (context, value) => Text('Value: ${value ?? "null"}'),
          ),
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);

      nullableSignal.value = 'not null';
      await tester.pumpAndSettle();

      expect(find.text('Value: not null'), findsOneWidget);

      nullableSignal.dispose();
    });

    testWidgets('should handle complex computed values', (tester) async {
      final a = Signal(1);
      final b = Signal(2);
      final sum = Computed(() => a.value + b.value);
      final product = Computed(() => a.value * b.value);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              JoltWatchBuilder<int>(
                readable: sum,
                builder: (context, value) => Text('Sum: $value'),
              ),
              JoltWatchBuilder<int>(
                readable: product,
                builder: (context, value) => Text('Product: $value'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Sum: 3'), findsOneWidget);
      expect(find.text('Product: 2'), findsOneWidget);

      a.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Sum: 7'), findsOneWidget);
      expect(find.text('Product: 10'), findsOneWidget);

      a.dispose();
      b.dispose();
    });
  });

  group('Extension watch Tests', () {
    testWidgets('should work with extension watch method on Signal',
        (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: counter.watch((value) => Text('Count: $value')),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should work with extension watch method on Computed',
        (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: doubled.watch((value) => Text('Doubled: $value')),
        ),
      );

      expect(find.text('Doubled: 0'), findsOneWidget);

      counter.value = 3;
      await tester.pumpAndSettle();

      expect(find.text('Doubled: 6'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle multiple watch extensions', (tester) async {
      final counter = Signal(0);
      final name = Signal('Flutter');

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              counter.watch((value) => Text('Count: $value')),
              name.watch((value) => Text('Name: $value')),
            ],
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Name: Flutter'), findsOneWidget);

      counter.value = 10;
      name.value = 'Dart';
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Name: Dart'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle nested watch extensions', (tester) async {
      final outerSignal = Signal('Outer');
      final innerSignal = Signal('Inner');

      await tester.pumpWidget(
        MaterialApp(
          home: outerSignal.watch(
            (value) => Column(
              children: [
                Text('Outer: $value'),
                innerSignal.watch((value) => Text('Inner: $value')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Outer: Outer'), findsOneWidget);
      expect(find.text('Inner: Inner'), findsOneWidget);

      outerSignal.value = 'Outer2';
      await tester.pumpAndSettle();

      expect(find.text('Outer: Outer2'), findsOneWidget);
      expect(find.text('Inner: Inner'), findsOneWidget);

      innerSignal.value = 'Inner2';
      await tester.pumpAndSettle();

      expect(find.text('Outer: Outer2'), findsOneWidget);
      expect(find.text('Inner: Inner2'), findsOneWidget);

      outerSignal.dispose();
      innerSignal.dispose();
    });

    testWidgets('should handle watch extension with batch updates',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: counter.watch(
            (value) {
              buildCount++;
              return Text('Count: $value');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      batch(() {
        counter.value = 1;
        counter.value = 2;
        counter.value = 3;
      });

      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 3'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle watch extension with nullable values',
        (tester) async {
      final nullableSignal = Signal<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: nullableSignal.watch(
            (value) => Text('Value: ${value ?? "null"}'),
          ),
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);

      nullableSignal.value = 'not null';
      await tester.pumpAndSettle();

      expect(find.text('Value: not null'), findsOneWidget);

      nullableSignal.dispose();
    });

    testWidgets('should handle watch extension unmount correctly',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: counter.watch(
            (value) {
              buildCount++;
              return Text('Count: $value');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      counter.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      final buildCountBeforeUnmount = buildCount;

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      counter.value = 2;
      await tester.pumpAndSettle();

      expect(buildCount, equals(buildCountBeforeUnmount));

      counter.dispose();
    });

    testWidgets('should handle watch extension with complex computed',
        (tester) async {
      final a = Signal(1);
      final b = Signal(2);
      final sum = Computed(() => a.value + b.value);

      await tester.pumpWidget(
        MaterialApp(
          home: sum.watch((value) => Text('Sum: $value')),
        ),
      );

      expect(find.text('Sum: 3'), findsOneWidget);

      a.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Sum: 7'), findsOneWidget);

      a.dispose();
      b.dispose();
    });
  });
}
