import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltBuilder', () {
    testWidgets('renders initial reactive values', (tester) async {
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
      name.dispose();
    });

    testWidgets('rebuilds when a tracked signal changes', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Text('Count: ${counter.value}'),
          ),
        ),
      );

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('rebuilds when multiple tracked signals change',
        (tester) async {
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

      counter.value = 10;
      await tester.pumpAndSettle();
      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Name: Flutter'), findsOneWidget);

      name.value = 'Dart';
      await tester.pumpAndSettle();
      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Name: Dart'), findsOneWidget);

      counter.dispose();
      name.dispose();
    });

    testWidgets('rebuilds when a tracked computed changes', (tester) async {
      final counter = Signal(0);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Text('Doubled: ${doubled.value}'),
          ),
        ),
      );

      counter.value = 3;
      await tester.pumpAndSettle();

      expect(find.text('Doubled: 6'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('stops rebuilding after unmount', (tester) async {
      final counter = Signal(0);
      var buildCount = 0;

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

    testWidgets('rebuilds once after batched updates', (tester) async {
      final counter = Signal(0);
      final name = Signal('A');
      var buildCount = 0;

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

      batch(() {
        counter.value = 3;
        name.value = 'C';
      });

      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount + 1);
      expect(find.text('Count: 3, Name: C'), findsOneWidget);

      counter.dispose();
      name.dispose();
    });
  });

  group('JoltBuilder.manual', () {
    testWidgets('rebuilds only when a dep changes', (tester) async {
      final tracked = Signal(0);
      final untracked = Signal('x');
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder.manual(
            deps: [tracked],
            builder: (context) {
              buildCount++;
              return Text('${tracked.value}-${untracked.value}');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      untracked.value = 'y';
      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount);
      expect(find.text('0-x'), findsOneWidget);

      tracked.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount + 1);
      expect(find.text('1-y'), findsOneWidget);

      tracked.dispose();
      untracked.dispose();
    });

    testWidgets('does not track reactive reads inside builder', (tester) async {
      final dep = Signal(0);
      final onlyInBuilder = Signal(10);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder.manual(
            deps: [dep],
            builder: (context) {
              buildCount++;
              return Text('${dep.value}/${onlyInBuilder.value}');
            },
          ),
        ),
      );

      final initialBuildCount = buildCount;

      onlyInBuilder.value = 20;
      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount);
      expect(find.text('0/10'), findsOneWidget);

      dep.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, initialBuildCount + 1);
      expect(find.text('1/20'), findsOneWidget);

      dep.dispose();
      onlyInBuilder.dispose();
    });
  });
}
