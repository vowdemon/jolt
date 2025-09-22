import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/multiple_signal_scene.dart';

void main() {
  group('Multiple Signal Response Tests', () {
    testWidgets('Multiple Independent Signals - Independent Updates',
        (tester) async {
      int rebuildCount = 0;
      final signalA = Signal(0);
      final signalB = Signal(0);

      final widget = IndependentSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        signalA: signalA,
        signalB: signalB,
      );

      await tester.pumpWidget(widget);

      expect(find.text('A: 0, B: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('incrementA')));
      await tester.pumpAndSettle();

      expect(find.text('A: 1, B: 0'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('incrementB')));
      await tester.pumpAndSettle();

      expect(find.text('A: 1, B: 1'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Signals - Simultaneous Updates', (tester) async {
      int rebuildCount = 0;
      final signalA = Signal(0);
      final signalB = Signal(0);

      final widget = SimultaneousSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        signalA: signalA,
        signalB: signalB,
      );

      await tester.pumpWidget(widget);

      expect(find.text('A: 0, B: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('incrementBoth')));
      await tester.pumpAndSettle();

      expect(find.text('A: 1, B: 1'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Signals - Chain Dependencies', (tester) async {
      int rebuildCount = 0;
      final signalA = Signal(0);
      final signalB = Signal(0);

      final widget = ChainedSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        signalA: signalA,
        signalB: signalB,
      );

      await tester.pumpWidget(widget);

      expect(find.text('A: 0, B: 0, C: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('incrementA')));
      await tester.pumpAndSettle();

      expect(find.text('A: 1, B: 1, C: 2'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Signals - Conditional Dependencies', (tester) async {
      int rebuildCount = 0;
      final condition = Signal(false);
      final valueA = Signal(0);
      final valueB = Signal(0);

      final widget = ConditionalSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        condition: condition,
        valueA: valueA,
        valueB: valueB,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Condition: false, Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('incrementA')));
      await tester.pumpAndSettle();

      expect(find.text('Condition: false, Value: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Condition: true, Value: 0'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.tap(find.byKey(Key('incrementB')));
      await tester.pumpAndSettle();

      expect(find.text('Condition: true, Value: 1'), findsOneWidget);
      expect(rebuildCount, 4);
    });

    testWidgets('Multiple Signals - Array Operations', (tester) async {
      int rebuildCount = 0;
      final listA = Signal<List<int>>([1, 2, 3]);
      final listB = Signal<List<int>>([4, 5, 6]);

      final widget = ArraySignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        listA: listA,
        listB: listB,
      );

      await tester.pumpWidget(widget);

      expect(find.text('ListA: [1, 2, 3], ListB: [4, 5, 6]'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('updateA')));
      await tester.pumpAndSettle();

      expect(
          find.text('ListA: [1, 2, 3, 4], ListB: [4, 5, 6]'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('updateB')));
      await tester.pumpAndSettle();

      expect(find.text('ListA: [1, 2, 3, 4], ListB: [4, 5, 6, 7]'),
          findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Signals - Object Properties', (tester) async {
      int rebuildCount = 0;
      final user = Signal(User(name: 'Alice', age: 25));
      final settings = Signal(Settings(theme: 'light', language: 'en'));

      final widget = ObjectSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        user: user,
        settings: settings,
      );

      await tester.pumpWidget(widget);

      expect(find.text('User: Alice, 25'), findsOneWidget);
      expect(find.text('Settings: light, en'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('updateUser')));
      await tester.pumpAndSettle();

      expect(find.text('User: Bob, 30'), findsOneWidget);
      expect(find.text('Settings: light, en'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('updateSettings')));
      await tester.pumpAndSettle();

      expect(find.text('User: Bob, 30'), findsOneWidget);
      expect(find.text('Settings: dark, zh'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Multiple Signals - Performance Test', (tester) async {
      int rebuildCount = 0;
      final signals = List.generate(10, (i) => Signal(i));

      final widget = PerformanceSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        signals: signals,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Sum: 45'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('updateMultiple')));
      await tester.pumpAndSettle();

      expect(find.text('Sum: 55'), findsOneWidget);
      expect(rebuildCount, 11);
    });

    testWidgets('Multiple Signals - Async Updates', (tester) async {
      int rebuildCount = 0;
      final loading = Signal(false);
      final data = Signal<String?>(null);
      final error = Signal<String?>(null);

      final widget = AsyncSignalsScene(
        rebuildCallback: (count) => rebuildCount = count,
        loading: loading,
        data: data,
        error: error,
      );

      await tester.pumpWidget(widget);

      expect(
          find.text('Loading: false, Data: null, Error: null'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('load')));
      await tester.pump();

      expect(
          find.text('Loading: true, Data: null, Error: null'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.pumpAndSettle();

      expect(find.text('Loading: false, Data: Success, Error: null'),
          findsOneWidget);
      expect(rebuildCount, 4);
    });
  });
}
