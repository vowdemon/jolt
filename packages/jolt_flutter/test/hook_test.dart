import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'templates/hook_scene.dart';

void main() {
  group('Hook Feature Tests', () {
    testWidgets('Hook Basic Feature - Single Signal', (tester) async {
      int rebuildCount = 0;

      final widget = BasicHookScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Count: 0'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Count: 1'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Hook Feature - Multiple Signals', (tester) async {
      int rebuildCount = 0;

      final widget = MultiSignalHookScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('A: 0, B: 0'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('incrementA')));
      await tester.pumpAndSettle();

      expect(find.text('A: 1, B: 0'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.tap(find.byKey(Key('incrementB')));
      await tester.pumpAndSettle();

      expect(find.text('A: 1, B: 1'), findsOneWidget);
      expect(rebuildCount, 4);
    });

    testWidgets('Hook Feature - Signal + Computed', (tester) async {
      int rebuildCount = 0;

      final widget = SignalComputedHookScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);
      expect(rebuildCount, 3);

      expect(find.text('Count: 0, Double: 0'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Count: 1, Double: 2'), findsOneWidget);
      expect(rebuildCount, 4);
    });

    testWidgets('Hook Feature - Complex Computation Logic', (tester) async {
      int rebuildCount = 0;

      final widget = ComplexHookScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Sum: 0, Product: 0, Average: 0.0'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.tap(find.byKey(Key('setA')));
      await tester.pumpAndSettle();

      expect(find.text('Sum: 5, Product: 0, Average: 2.5'), findsOneWidget);
      expect(rebuildCount, 4);

      await tester.tap(find.byKey(Key('setB')));
      await tester.pumpAndSettle();

      expect(find.text('Sum: 8, Product: 15, Average: 4.0'), findsOneWidget);
      expect(rebuildCount, 5);
    });

    testWidgets('Hook Feature - Nested Hook', (tester) async {
      int rebuildCount = 0;
      int runHookCount = 0;

      final widget = NestedHookScene(
        rebuildCallback: (count) => rebuildCount = count,
        runHookCallback: (count) => runHookCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Outer: 0'), findsOneWidget);
      expect(find.text('Inner: 0'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.tap(find.byKey(Key('incrementOuter')));
      await tester.pumpAndSettle();

      expect(find.text('Outer: 1'), findsOneWidget);
      expect(find.text('Inner: 0'), findsOneWidget);
      expect(rebuildCount, 5);

      await tester.tap(find.byKey(Key('incrementInner')));
      await tester.pumpAndSettle();

      expect(find.text('Outer: 1'), findsOneWidget);
      expect(find.text('Inner: 1'), findsOneWidget);
      expect(rebuildCount, 6);

      expect(runHookCount, 2);
    });

    testWidgets('Hook Feature - Conditional Rendering', (tester) async {
      int rebuildCount = 0;

      final widget = ConditionalHookScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Show: false'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Show: true'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Hook Feature - Async Operations', (tester) async {
      int rebuildCount = 0;

      final widget = AsyncHookScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Loading: false, Data: null'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('load')));
      await tester.pump();

      expect(find.text('Loading: true, Data: null'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.pumpAndSettle();

      expect(find.text('Loading: false, Data: Hello World'), findsOneWidget);
      expect(rebuildCount, 5);
    });
  });
}
