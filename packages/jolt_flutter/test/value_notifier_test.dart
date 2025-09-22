import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/value_notifier_scene.dart';

void main() {
  group('ValueNotifier Integration Tests', () {
    testWidgets('Signal as ValueNotifier - Basic Feature', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = BasicValueNotifierScene(
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
    });

    testWidgets('Signal as ValueNotifier - Multiple Listeners', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = MultiListenerValueNotifierScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
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

    testWidgets('Signal as ValueNotifier - Listener Management',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = ListenerManagementScene(
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

      await tester.tap(find.byKey(Key('removeListener')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 2'), findsNothing);
      expect(rebuildCount, 2);
    });

    testWidgets('Computed as ValueNotifier - Basic Feature', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);
      final doubleCounter = Computed(() => counter.value * 2);

      final widget = ComputedValueNotifierScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
        computed: doubleCounter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Counter: 0, Double: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Counter: 1, Double: 2'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Signal as ValueNotifier - AnimatedBuilder Integration',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = AnimatedBuilderScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Animated Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Animated Value: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Signal as ValueNotifier - ValueListenableBuilder Integration',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = ValueListenableBuilderScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Listenable Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Listenable Value: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    testWidgets('Signal as ValueNotifier - Lifecycle Management',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = LifecycleValueNotifierScene(
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

      await tester.pumpWidget(Container());

      counter.value++;
      await tester.pumpAndSettle();

      expect(rebuildCount, 2);
    });

    testWidgets('Signal as ValueNotifier - Error Handling', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = ErrorHandlingValueNotifierScene(
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

      await tester.tap(find.byKey(Key('triggerError')));
      await tester.pumpAndSettle();

      expect(find.text('Value: Error'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    testWidgets('Signal as ValueNotifier - Performance Test', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = PerformanceValueNotifierScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      for (int i = 0; i < 10; i++) {
        counter.value = i + 1;
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Value: 10'), findsOneWidget);
      expect(rebuildCount, 11);
    });

    testWidgets('Signal as ValueNotifier - Conditional Listening',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);
      final isListening = Signal(true);

      final widget = ConditionalListeningScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
        isListening: isListening,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: 0, Listening: true'), findsOneWidget);
      expect(rebuildCount, 2);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 1, Listening: true'), findsOneWidget);
      expect(rebuildCount, 3);

      await tester.tap(find.byKey(Key('toggleListening')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 1, Listening: false'), findsOneWidget);
      expect(rebuildCount, 4);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 1, Listening: false'), findsOneWidget);
      expect(rebuildCount, 4);
    });
  });
}
