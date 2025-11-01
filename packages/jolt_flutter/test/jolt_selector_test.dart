import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltSelector Tests', () {
    testWidgets('should render with initial selector value', (tester) async {
      final counter = Signal(0);
      final name = Signal('Flutter');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<String>(
            selector: (_) => name.value,
            builder: (context, selectedValue) =>
                Text('Selected: $selectedValue'),
          ),
        ),
      );

      expect(find.text('Selected: Flutter'), findsOneWidget);

      counter.dispose();
      name.dispose();
    });

    testWidgets('should rebuild when selector value changes', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, selectedValue) => Text('Count: $selectedValue'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should not rebuild when selector value unchanged',
        (tester) async {
      final counter = Signal(10);
      final name = Signal('Flutter');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<String>(
            selector: (_) => name.value,
            builder: (context, selectedValue) {
              buildCount++;
              return Text('Name: $selectedValue($counter)');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      // Update counter (not watched by selector) - should not rebuild
      counter.value = 10;
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount));
      expect(find.text('Name: Flutter(10)'), findsOneWidget);

      // Update name (watched by selector) - should rebuild
      name.value = 'Dart';
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Name: Dart(10)'), findsOneWidget);

      counter.dispose();
      name.dispose();
    });

    testWidgets('should access previous state in selector', (tester) async {
      final counter = Signal(0);
      final previousValues = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (prevState) {
              final current = counter.value;
              if (prevState != null) {
                previousValues.add(prevState);
              }
              return current;
            },
            builder: (context, selectedValue) => Text('Count: $selectedValue'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(previousValues, isEmpty);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);
      expect(previousValues, equals([0]));

      counter.value = 10;
      await tester.pumpAndSettle();

      expect(find.text('Count: 10'), findsOneWidget);
      expect(previousValues, equals([0, 5]));

      counter.dispose();
    });

    testWidgets('should handle nested JoltSelector with independent rebuilds',
        (tester) async {
      final outerSignal = Signal('Outer');
      final innerSignal = Signal('Inner');

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<String>(
            selector: (_) => outerSignal.value,
            builder: (context, outerValue) => Column(
              children: [
                Text('Outer: $outerValue'),
                JoltSelector<String>(
                  selector: (_) => innerSignal.value,
                  builder: (context, innerValue) => Text('Inner: $innerValue'),
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

    testWidgets(
        'should dispose resources correctly and stop responding after unmount',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, selectedValue) {
              buildCount++;
              return Text('Count: $selectedValue');
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
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, selectedValue) {
              buildCount++;
              return Text('Count: $selectedValue');
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
        name.value = 'B'; // Not watched, should not trigger rebuild
        name.value = 'C';
      });

      await tester.pumpAndSettle();

      // Should only rebuild once after batch (counter changed from 0 to 3)
      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Count: 3'), findsOneWidget);

      counter.dispose();
      name.dispose();
    });

    testWidgets('should work with computed as selector', (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => doubled.value,
            builder: (context, selectedValue) =>
                Text('Doubled: $selectedValue'),
          ),
        ),
      );

      expect(find.text('Doubled: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Doubled: 10'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should not rebuild when selector returns same value',
        (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value.isEven ? 0 : 1,
            builder: (context, selectedValue) {
              buildCount++;
              return Text('Even/Odd: $selectedValue');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      // counter.value = 2, selector returns 0 (same as initial)
      counter.value = 2;
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount));
      expect(find.text('Even/Odd: 0'), findsOneWidget);

      // counter.value = 3, selector returns 1 (different)
      counter.value = 3;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Even/Odd: 1'), findsOneWidget);

      // counter.value = 5, selector returns 1 (same)
      counter.value = 5;
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('Even/Odd: 1'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('should rebuild when widget updates', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            key: const Key('selector1'),
            selector: (_) => counter.value,
            builder: (context, selectedValue) => Text('Count: $selectedValue'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      // Update widget with different key - should rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            key: const Key('selector2'),
            selector: (_) => counter.value,
            builder: (context, selectedValue) =>
                Text('New Count: $selectedValue'),
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
        home: JoltSelector<int>(
          selector: (_) => counter.value,
          builder: (context, selectedValue) => Text('Count: $selectedValue'),
        ),
      );

      await tester.pumpWidget(parent);

      expect(find.text('Count: 0'), findsOneWidget);

      // Change parent widget
      parent = MaterialApp(
        theme: ThemeData(primaryColor: Colors.blue),
        home: JoltSelector<int>(
          selector: (_) => counter.value,
          builder: (context, selectedValue) => Text('Count: $selectedValue'),
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
                JoltSelector<int>(
                  selector: (_) => counter.value,
                  builder: (context, selectedValue) =>
                      Text('NotifierB: $value Count: $selectedValue'),
                ),
              ],
            );
          },
        ),
      );
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

    testWidgets('should select from multiple signals', (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(3);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => signal2.value, // Only watch signal2
            builder: (context, selectedValue) {
              buildCount++;
              // Access all signals in builder, but only rebuild when signal2 changes
              return Text(
                  'S1: ${signal1.value}, S2: $selectedValue, S3: ${signal3.value}');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;
      expect(find.text('S1: 1, S2: 2, S3: 3'), findsOneWidget);

      // Update signal1 - should not rebuild, UI still shows old values
      signal1.value = 10;
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount));
      expect(find.text('S1: 1, S2: 2, S3: 3'), findsOneWidget);

      // Update signal2 - should rebuild, now shows latest values
      signal2.value = 20;
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('S1: 10, S2: 20, S3: 3'), findsOneWidget);

      // Update signal3 - should not rebuild, UI still shows old values
      signal3.value = 30;
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount + 1));
      expect(find.text('S1: 10, S2: 20, S3: 3'), findsOneWidget);

      signal1.dispose();
      signal2.dispose();
      signal3.dispose();
    });

    testWidgets('should handle selector returning objects', (tester) async {
      final user = Signal(_User(name: 'John', age: 30));
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<String>(
            selector: (_) => user.value.name, // Only watch name
            builder: (context, selectedName) {
              buildCount++;
              return Text('Name: $selectedName, Age: ${user.value.age}');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;
      expect(find.text('Name: John, Age: 30'), findsOneWidget);

      // Update age - should not rebuild (name unchanged), UI still shows old age
      user.value = _User(name: 'John', age: 31);
      await tester.pumpAndSettle();

      expect(buildCount, equals(initialBuildCount));
      expect(find.text('Name: John, Age: 30'), findsOneWidget);

      // Update name - should rebuild, now shows latest values
      user.value = _User(name: 'Jane', age: 31);
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Name: Jane, Age: 31'), findsOneWidget);

      user.dispose();
    });

    testWidgets('should handle modify signal in builder', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, selectedValue) {
              buildCount++;
              if (buildCount == 1) {
                counter.value++;
                (context as Element).markNeedsBuild();
              }
              return Text('Count: $selectedValue');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;
      expect(find.text('Count: 0'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Count: 1'), findsOneWidget);

      counter.dispose();
    });
  });
}

class _User {
  final String name;
  final int age;

  _User({required this.name, required this.age});
}
