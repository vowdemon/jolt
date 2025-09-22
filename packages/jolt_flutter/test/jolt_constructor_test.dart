import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/jolt_constructor_scene.dart';

void main() {
  group('Jolt Constructor and Factory Function Tests', () {
    testWidgets('Jolt Constructor - Basic Feature', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = JoltConstructorScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Count: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Count: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Jolt.builder Factory Function', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = JoltBuilderScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Builder Count: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Builder Count: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Jolt Constructor - With Store Parameter', (tester) async {
      int rebuildCount = 0;

      final widget = JoltWithStoreScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Store Count: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Store Count: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Jolt Constructor - Nested Usage', (tester) async {
      int rebuildCount = 0;
      final counter1 = Signal(0);
      final counter2 = Signal(0);

      final widget = NestedJoltScene(
        rebuildCallback: (count) => rebuildCount = count,
        counter1: counter1,
        counter2: counter2,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Counter1: 0'), findsOneWidget);
      expect(find.text('Counter2: 0'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increment1')));
      await tester.pumpAndSettle();

      expect(find.text('Counter1: 1'), findsOneWidget);
      expect(find.text('Counter2: 0'), findsOneWidget);
      expect(rebuildCount, 4);

      await tester.tap(find.byKey(Key('increment2')));
      await tester.pumpAndSettle();

      expect(find.text('Counter1: 1'), findsOneWidget);
      expect(find.text('Counter2: 1'), findsOneWidget);
      expect(rebuildCount, 5);
    });
  });
}
