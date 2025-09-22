import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/single_signal_scene.dart';

void main() {
  group('Single Signal Response Tests', () {
    testWidgets('Signal Basic Response - Integer', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = BasicSignalScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 2'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Signal Basic Response - List', (tester) async {
      int rebuildCount = 0;
      final listSignal = Signal<List<int>>([1, 2, 3]);

      final widget = ListSignalScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: listSignal,
      );

      await tester.pumpWidget(widget);

      expect(find.text('List: [1, 2, 3]'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('add')));
      await tester.pumpAndSettle();

      expect(find.text('List: [1, 2, 3, 4]'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('remove')));
      await tester.pumpAndSettle();

      expect(find.text('List: [1, 2, 3]'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Signal Basic Response - Object', (tester) async {
      int rebuildCount = 0;
      final userSignal = Signal(User(name: 'Alice', age: 25));

      final widget = ObjectSignalScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: userSignal,
      );

      await tester.pumpWidget(widget);

      expect(find.text('User: Alice, 25'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('update')));
      await tester.pumpAndSettle();

      expect(find.text('User: Bob, 30'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Signal Basic Response - Nullable Type', (tester) async {
      int rebuildCount = 0;
      final nullableSignal = Signal<String?>(null);

      final widget = NullableSignalScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: nullableSignal,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: null'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('set')));
      await tester.pumpAndSettle();

      expect(find.text('Value: Hello'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('clear')));
      await tester.pumpAndSettle();

      expect(find.text('Value: null'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Signal Basic Response - Direct Assignment', (tester) async {
      int rebuildCount = 0;
      final directSignal = Signal(0);

      final widget = DirectAssignmentScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: directSignal,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('set5')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 5'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('set10')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 10'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Signal Basic Response - Same Value Does Not Trigger Update',
        (tester) async {
      int rebuildCount = 0;
      final sameValueSignal = Signal(5);

      final widget = SameValueScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: sameValueSignal,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: 5'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('setSame')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 5'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('setDifferent')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 10'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Signal Basic Response - Multiple Listeners', (tester) async {
      int rebuildCount = 0;
      final multiListenerSignal = Signal(0);

      final widget = MultiListenerScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: multiListenerSignal,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Listener1: 0'), findsOneWidget);
      expect(find.text('Listener2: 0'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Listener1: 1'), findsOneWidget);
      expect(find.text('Listener2: 1'), findsOneWidget);
      expect(rebuildCount, 4);
    });
  });
}
