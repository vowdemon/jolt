import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltSelector', () {
    testWidgets('rebuilds when selector result changes', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, value) => Text('Count: $value'),
          ),
        ),
      );

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('skips rebuild when selector result is unchanged',
        (tester) async {
      final counter = Signal(10);
      final name = Signal('Flutter');
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<String>(
            selector: (_) => name.value,
            builder: (context, selected) {
              buildCount++;
              return Text('Name: $selected(${counter.value})');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      counter.value = 20;
      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount);
      expect(find.text('Name: Flutter(10)'), findsOneWidget);

      name.value = 'Dart';
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Name: Dart(20)'), findsOneWidget);

      counter.dispose();
      name.dispose();
    });

    testWidgets('passes previous selector result', (tester) async {
      final counter = Signal(0);
      final previous = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (prev) {
              final current = counter.value;
              if (prev != null) previous.add(prev);
              return current;
            },
            builder: (context, value) => Text('$value'),
          ),
        ),
      );

      counter.value = 5;
      await tester.pumpAndSettle();
      counter.value = 10;
      await tester.pumpAndSettle();

      expect(previous, [0, 5]);

      counter.dispose();
    });

    testWidgets('skips rebuild when mapped value stays equal', (tester) async {
      final counter = Signal(0);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value.isEven ? 0 : 1,
            builder: (context, value) {
              buildCount++;
              return Text('Bucket: $value');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      counter.value = 2;
      await tester.pumpAndSettle();
      expect(buildCount, initialBuildCount);

      counter.value = 3;
      await tester.pumpAndSettle();
      expect(buildCount, initialBuildCount + 1);

      counter.dispose();
    });

    testWidgets('stops rebuilding after unmount', (tester) async {
      final counter = Signal(0);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, value) {
              buildCount++;
              return Text('$value');
            },
          ),
        ),
      );

      counter.value = 1;
      await tester.pumpAndSettle();
      final countBeforeUnmount = buildCount;

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      counter.value = 2;
      await tester.pumpAndSettle();

      expect(buildCount, countBeforeUnmount);

      counter.dispose();
    });

    testWidgets('rebuilds once after batched dep changes', (tester) async {
      final counter = Signal(0);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => counter.value,
            builder: (context, value) {
              buildCount++;
              return Text('$value');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      batch(() {
        counter.value = 1;
        counter.value = 3;
      });

      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount + 1);
      expect(find.text('3'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('tracks computed values in selector', (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (_) => doubled.value,
            builder: (context, value) => Text('$value'),
          ),
        ),
      );

      counter.value = 4;
      await tester.pumpAndSettle();

      expect(find.text('8'), findsOneWidget);

      counter.dispose();
    });

    testWidgets(
        're-runs selector with a cleared previous value after widget update',
        (tester) async {
      final counter = Signal(0);
      final previous = <int?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (prev) {
              previous.add(prev);
              return counter.value;
            },
            builder: (context, value) => Text('v$value'),
          ),
        ),
      );

      counter.value = 1;
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltSelector<int>(
            selector: (prev) {
              previous.add(prev);
              return counter.value + 10;
            },
            builder: (context, value) => Text('v$value'),
          ),
        ),
      );

      expect(find.text('v11'), findsOneWidget);
      expect(previous, [null, 0, null]);

      counter.dispose();
    });
  });
}
