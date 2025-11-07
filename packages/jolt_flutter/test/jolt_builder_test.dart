import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltBuilder Tests', () {
    testWidgets('should render with initial values', (tester) async {
      final counter = Signal(0);
      final name = Signal('Flutter');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) =>
                Text('Count: ${counter.value}, Name: ${name.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0, Name: Flutter'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should respond to single signal change', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Text('Count: ${counter.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should respond to multiple signal changes', (tester) async {
      final counter = Signal(0);
      final name = Signal('Flutter');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Column(
              children: [
                Text('Count: ${counter.value}'),
                Text('Name: ${name.value}'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Name: Flutter'), findsOneWidget);

      // Update first signal
      counter.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Name: Flutter'), findsOneWidget);

      // Update second signal
      name.value = 'Dart';
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Name: Dart'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should respond to computed signal changes', (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) =>
                Text('Count: ${counter.value}, Doubled: ${doubled.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0, Doubled: 0'), findsOneWidget);

      counter.value = 3;
      await tester.pumpAndSettle();

      expect(find.text('Count: 3, Doubled: 6'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should respond to multiple signal and computed changes',
        (tester) async {
      final a = Signal(1);
      final b = Signal(2);
      final sum = Computed(() => a.value + b.value);
      final product = Computed(() => a.value * b.value);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Column(
              children: [
                Text('A: ${a.value}'),
                Text('B: ${b.value}'),
                Text('Sum: ${sum.value}'),
                Text('Product: ${product.value}'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('A: 1'), findsOneWidget);
      expect(find.text('B: 2'), findsOneWidget);
      expect(find.text('Sum: 3'), findsOneWidget);
      expect(find.text('Product: 2'), findsOneWidget);

      // Update signal a
      a.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('A: 5'), findsOneWidget);
      expect(find.text('B: 2'), findsOneWidget);
      expect(find.text('Sum: 7'), findsOneWidget);
      expect(find.text('Product: 10'), findsOneWidget);

      // Update signal b
      b.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('A: 5'), findsOneWidget);
      expect(find.text('B: 10'), findsOneWidget);
      expect(find.text('Sum: 15'), findsOneWidget);
      expect(find.text('Product: 50'), findsOneWidget);

      a.dispose();
      b.dispose();
    });

    testWidgets('should handle nested JoltBuilder with independent rebuilds',
        (tester) async {
      final outerSignal = Signal('Outer');
      final innerSignal = Signal('Inner');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Column(
              children: [
                Text('Outer: ${outerSignal.value}'),
                JoltBuilder(
                  builder: (context) => Text('Inner: ${innerSignal.value}'),
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

    testWidgets('should handle deeply nested JoltBuilder', (tester) async {
      final level1 = Signal('L1');
      final level2 = Signal('L2');
      final level3 = Signal('L3');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Column(
              children: [
                Text('Level1: ${level1.value}'),
                JoltBuilder(
                  builder: (context) => Column(
                    children: [
                      Text('Level2: ${level2.value}'),
                      JoltBuilder(
                        builder: (context) => Text('Level3: ${level3.value}'),
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
          home: JoltBuilder(
            builder: (context) {
              buildCount++;
              return Text('Count: ${counter.value}');
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
      final name = Signal('A');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) {
              buildCount++;
              return Text('Count: ${counter.value}, Name: ${name.value}');
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
        name.value = 'B';
        name.value = 'C';
      });

      await tester.pumpAndSettle();

      // Should only rebuild once after batch
      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 3, Name: C'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle multiple batch updates', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) {
              buildCount++;
              return Text('Count: ${counter.value}');
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
          home: JoltBuilder(
            key: const Key('builder1'),
            builder: (context) => Text('Count: ${counter.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Update widget with different key - should rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            key: const Key('builder2'),
            builder: (context) => Text('New Count: ${counter.value}'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Count: 0'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should rebuild when parent widget changes', (tester) async {
      final counter = Signal(0);
      Widget parent = MaterialApp(
        home: JoltBuilder(
          builder: (context) => Text('Count: ${counter.value}'),
        ),
      );

      await tester.pumpWidget(parent);

      expect(find.text('Count: 0'), findsOneWidget);

      // Change parent widget
      parent = MaterialApp(
        theme: ThemeData(primaryColor: Colors.blue),
        home: JoltBuilder(
          builder: (context) => Text('Count: ${counter.value}'),
        ),
      );

      await tester.pumpWidget(parent);
      await tester.pumpAndSettle();

      expect(find.text('Count: 0'), findsOneWidget);

      final valueNotifier = ValueNotifier(0);
      parent = MaterialApp(
          home: ValueListenableBuilder(
              valueListenable: valueNotifier,
              builder: (context, value, child) {
                return Column(
                  children: [
                    Text('NotifierA: $value'),
                    JoltBuilder(
                      builder: (context) =>
                          Text('NotifierB: $value Count: ${counter.value}'),
                    ),
                  ],
                );
              }));
      await tester.pumpWidget(parent);
      await tester.pumpAndSettle();
      expect(find.text('NotifierA: 0'), findsOneWidget);
      expect(find.text('NotifierB: 0 Count: 0'), findsOneWidget);

      valueNotifier.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('NotifierA: 1'), findsOneWidget);
      expect(find.text('NotifierB: 1 Count: 0'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should handle modify signal in builder', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) {
              buildCount++;
              if (buildCount == 1) {
                counter.value++;
                (context as Element).markNeedsBuild();
              }
              return Text('Count: ${counter.value}');
            },
          ),
        ),
      );

      // First build shows initial value (0), but counter is incremented during build
      // After markNeedsBuild, it should rebuild with new value (1)
      final initialBuildCount = buildCount;

      // First frame might show 0 or 1 depending on when the signal change happens
      // Let's pump once to see the initial state
      await tester.pump();

      // After first build, counter was incremented and markNeedsBuild was called
      // So we should see Count: 1 after settling
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 1'), findsOneWidget);

      counter.dispose();
    });
  });
}
