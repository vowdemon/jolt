import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'templates/value_notifier_scene.dart';

void main() {
  group('ValueNotifier Integration Tests', () {
    // 1. Test ValueNotifier.toNotifierSignal() bidirectional sync
    testWidgets('ValueNotifier.toNotifierSignal() - Bidirectional Sync',
        (tester) async {
      int rebuildCount = 0;

      final widget = ToNotifierSignalScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Notifier: 0, Signal: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      // Test updating from ValueNotifier to Signal
      await tester.tap(find.byKey(Key('incrementNotifier')));
      await tester.pumpAndSettle();

      expect(find.text('Notifier: 1, Signal: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      // Test updating from Signal to ValueNotifier
      await tester.tap(find.byKey(Key('incrementSignal')));
      await tester.pumpAndSettle();

      expect(find.text('Notifier: 2, Signal: 2'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    // 2. Test ValueListenable.toListenableSignal() unidirectional sync (read-only)
    testWidgets('ValueListenable.toListenableSignal() - Unidirectional Sync',
        (tester) async {
      int rebuildCount = 0;

      final widget = ToListenableSignalScene(
        rebuildCallback: (count) => rebuildCount = count,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Notifier: 0, Signal: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      // Test updating from ValueNotifier to Signal
      await tester.tap(find.byKey(Key('incrementNotifier')));
      await tester.pumpAndSettle();

      expect(find.text('Notifier: 1, Signal: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      // Try updating from Signal to ValueNotifier, should fail (read-only)
      await tester.tap(find.byKey(Key('tryIncrementSignal')));
      await tester.pumpAndSettle();

      // Signal should maintain original value because it's read-only
      expect(find.text('Notifier: 1, Signal: 1'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    // 3. Test Signal.notifier conversion
    testWidgets('Signal.notifier - Conversion and Bidirectional Sync',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = SignalNotifierScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Signal: 0, Notifier: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      // Test updating from Signal to Notifier
      await tester.tap(find.byKey(Key('incrementSignal')));
      await tester.pumpAndSettle();

      expect(find.text('Signal: 1, Notifier: 1'), findsOneWidget);
      expect(rebuildCount, 2);

      // Test updating from Notifier to Signal
      await tester.tap(find.byKey(Key('incrementNotifier')));
      await tester.pumpAndSettle();

      expect(find.text('Signal: 2, Notifier: 2'), findsOneWidget);
      expect(rebuildCount, 3);
    });

    // 4. Test Computed.notifier conversion (read-only)
    testWidgets('Computed.notifier - Conversion and Read-only Behavior',
        (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);
      final doubleCounter = Computed(() => counter.value * 2);

      final widget = ComputedNotifierScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
        computed: doubleCounter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Signal: 0, Computed: 0, Notifier: 0'), findsOneWidget);
      expect(rebuildCount, 1);

      // Test updating from Signal to Computed and Notifier
      await tester.tap(find.byKey(Key('incrementSignal')));
      await tester.pumpAndSettle();

      expect(find.text('Signal: 1, Computed: 2, Notifier: 2'), findsOneWidget);
      expect(rebuildCount, 2);

      // Try updating from Notifier to Computed, should fail (read-only)
      await tester.tap(find.byKey(Key('tryIncrementNotifier')));
      await tester.pumpAndSettle();

      // Computed and Notifier should maintain original values because Computed is read-only
      expect(find.text('Signal: 1, Computed: 2, Notifier: 2'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    // 5. Test .notifier caching mechanism
    testWidgets('Signal.notifier - Caching Mechanism', (tester) async {
      int rebuildCount = 0;
      final counter = Signal(0);

      final widget = NotifierCachingScene(
        rebuildCallback: (count) => rebuildCount = count,
        signal: counter,
      );

      await tester.pumpWidget(widget);

      expect(find.text('Value: 0, Same Instance: true'), findsOneWidget);
      expect(rebuildCount, 1);

      await tester.tap(find.byKey(Key('increment')));
      await tester.pumpAndSettle();

      expect(find.text('Value: 1, Same Instance: true'), findsOneWidget);
      expect(rebuildCount, 2);
    });

    test('Multiple transform tests', () {
      final n1 = ValueNotifier(0);
      final rs1 = n1.toListenableSignal();
      final s1 = n1.toNotifierSignal();
      final n2 = s1.notifier;
      final rs2 = n2.toListenableSignal();
      final s3 = n2.toNotifierSignal();

      // Initial state - all should be 0
      expect(n1.value, 0);
      expect(rs1.value, 0);
      expect(s1.value, 0);
      expect(n2.value, 0);
      expect(rs2.value, 0);
      expect(s3.value, 0);

      // Test 1: Update original ValueNotifier n1
      n1.value = 1;
      expect(n1.value, 1);
      expect(rs1.value, 1); // ReadonlySignal should sync from n1
      expect(s1.value, 1); // Signal should sync from n1
      expect(n2.value, 1); // n2 should sync from s1
      expect(rs2.value, 1); // rs2 should sync from n2
      expect(s3.value, 1); // s3 should sync from n2

      // Test 2: Update Signal s1
      s1.value = 2;
      expect(n1.value, 2); // n1 should sync from s1
      expect(rs1.value, 2); // rs1 should sync from n1
      expect(s1.value, 2);
      expect(n2.value, 2); // n2 should sync from s1
      expect(rs2.value, 2); // rs2 should sync from n2
      expect(s3.value, 2); // s3 should sync from n2

      // Test 3: Update ValueNotifier n2
      n2.value = 3;
      expect(n1.value, 3); // n1 should sync from n2 (through s1)
      expect(rs1.value, 3); // rs1 should sync from n1
      expect(s1.value, 3); // s1 should sync from n2
      expect(n2.value, 3);
      expect(rs2.value, 3); // rs2 should sync from n2
      expect(s3.value, 3); // s3 should sync from n2

      // Test 4: Update Signal s3
      s3.value = 4;
      expect(n1.value, 4); // n1 should sync from s3 (through n2 and s1)
      expect(rs1.value, 4); // rs1 should sync from n1
      expect(s1.value, 4); // s1 should sync from s3 (through n2)
      expect(n2.value, 4); // n2 should sync from s3
      expect(rs2.value, 4); // rs2 should sync from n2
      expect(s3.value, 4);

      // Test 5: Verify readonly signals cannot be updated directly
      // rs1 and rs2 are readonly, so they should not have setters
      // This is tested by the fact that we can only read their values

      // Cleanup
      n1.dispose();
      s1.dispose();
      s3.dispose();
    });

    test('Dispose synchronization tests', () {
      final n1 = ValueNotifier(0);
      final rs1 = n1.toListenableSignal();
      final s1 = n1.toNotifierSignal();

      // Initial sync
      expect(n1.value, 0);
      expect(rs1.value, 0);
      expect(s1.value, 0);

      // Test bidirectional sync before dispose
      n1.value = 1;
      expect(n1.value, 1);
      expect(rs1.value, 1);
      expect(s1.value, 1);

      s1.value = 2;
      expect(n1.value, 2);
      expect(rs1.value, 2);
      expect(s1.value, 2);

      // Dispose s1 (toNotifierSignal)
      s1.dispose();

      // After disposing s1, n1 and rs1 should still sync
      n1.value = 3;
      expect(n1.value, 3);
      expect(rs1.value, 3);
      // s1 is disposed, so we can't check its value

      // But s1 should no longer sync back to n1
      // This is tested by the fact that s1 is disposed and can't be used

      // Dispose rs1 (toListenableSignal)
      rs1.dispose();

      // After disposing rs1, n1 should still work independently
      n1.value = 4;
      expect(n1.value, 4);
      // rs1 is disposed, so we can't check its value

      // Cleanup
      n1.dispose();
    });

    test('Dispose multiple signals from same ValueNotifier', () {
      final n1 = ValueNotifier(0);
      final rs1 = n1.toListenableSignal();
      final rs2 = n1.toListenableSignal();
      final s1 = n1.toNotifierSignal();
      final s2 = n1.toNotifierSignal();

      // All should be in sync initially
      n1.value = 1;
      expect(n1.value, 1);
      expect(rs1.value, 1);
      expect(rs2.value, 1);
      expect(s1.value, 1);
      expect(s2.value, 1);

      // Dispose one readonly signal
      rs1.dispose();

      // Others should still work
      n1.value = 2;
      expect(n1.value, 2);
      expect(rs2.value, 2);
      expect(s1.value, 2);
      expect(s2.value, 2);

      // Dispose one writable signal
      s1.dispose();

      // Others should still work
      n1.value = 3;
      expect(n1.value, 3);
      expect(rs2.value, 3);
      expect(s2.value, 3);

      // Test bidirectional sync with remaining signal
      s2.value = 4;
      expect(n1.value, 4);
      expect(rs2.value, 4);
      expect(s2.value, 4);

      // Cleanup
      n1.dispose();
      rs2.dispose();
      s2.dispose();
    });

    test('JoltValueListenable extension tests', () {
      final signal = Signal(0);
      final computed = Computed(() => signal.value * 2);

      // Test Signal.listenable
      final signalListenable = signal.listenable;
      expect(signalListenable.value, 0);
      expect(signalListenable.joltValue, signal);

      // Test Computed.listenable
      final computedListenable = computed.listenable;
      expect(computedListenable.value, 0);
      expect(computedListenable.joltValue, computed);

      // Test synchronization from Signal to listenable
      signal.value = 1;
      expect(signalListenable.value, 1);
      expect(computedListenable.value, 2);

      // Test caching mechanism - should return same instance
      final signalListenable2 = signal.listenable;
      final computedListenable2 = computed.listenable;
      expect(identical(signalListenable, signalListenable2), true);
      expect(identical(computedListenable, computedListenable2), true);

      // Test multiple updates
      signal.value = 5;
      expect(signalListenable.value, 5);
      expect(computedListenable.value, 10);

      // Test that listenable is read-only (implements ValueListenable, not ValueNotifier)
      // ignore: unnecessary_type_check
      expect(signalListenable is ValueListenable<int>, true);
      expect(signalListenable is ValueNotifier<int>, false);

      // Cleanup
      signal.dispose();
    });

    test('JoltValueListenable with different signal types', () {
      // Test with Signal
      final signal = Signal('Hello');
      final signalListenable = signal.listenable;
      expect(signalListenable.value, 'Hello');

      signal.value = 'World';
      expect(signalListenable.value, 'World');

      // Test with Computed
      final lengthComputed = Computed(() => signal.value.length);
      final lengthListenable = lengthComputed.listenable;
      expect(lengthListenable.value, 5);

      signal.value = 'Flutter';
      expect(lengthListenable.value, 7);

      // Test caching across different signal types
      final signalListenable2 = signal.listenable;
      final lengthListenable2 = lengthComputed.listenable;
      expect(identical(signalListenable, signalListenable2), true);
      expect(identical(lengthListenable, lengthListenable2), true);

      // Cleanup
      signal.dispose();
    });

    test('JoltValueListenable dispose behavior', () {
      final signal = Signal(0);
      final listenable = signal.listenable;

      // Initial sync
      expect(listenable.value, 0);

      // Update signal
      signal.value = 1;
      expect(listenable.value, 1);

      // Cleanup listenable
      listenable.dispose();

      signal.value = 2;

      // Listenable should still have last value but be disposed
      expect(listenable.value, 1);

      // Dispose signal
      signal.dispose();
    });
  });
}
