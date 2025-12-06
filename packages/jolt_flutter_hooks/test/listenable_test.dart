import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

class _CustomNotifier extends ChangeNotifier {
  int _value = 0;
  int get value => _value;
  set value(int v) {
    if (_value != v) {
      _value = v;
      notifyListeners();
    }
  }
}

void main() {
  group('useValueNotifier', () {
    testWidgets('creates and disposes ValueNotifier', (tester) async {
      ValueNotifier<int>? notifier;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          notifier = useValueNotifier(42);
          return () => Text('Value: ${notifier!.value}');
        }),
      ));

      expect(notifier, isNotNull);
      expect(notifier!.value, 42);
      expect(find.text('Value: 42'), findsOneWidget);

      // Unmount - should dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('useValueListenable', () {
    testWidgets('subscribes, triggers listener, and disposes', (tester) async {
      final notifier = ValueNotifier(0);
      final values = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useValueListenable(notifier, (value) {
            values.add(value);
          });
          return () => Text('Value: ${notifier.value}');
        }),
      ));

      // Change value - should trigger listener
      notifier.value = 1;
      await tester.pumpAndSettle();
      expect(values, contains(1));

      // Unmount - should remove listener
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Change value after unmount - listener should not be called
      final countBefore = values.length;
      notifier.value = 10;
      await tester.pumpAndSettle();
      expect(values.length, countBefore);
    });
  });

  group('useListenable', () {
    testWidgets('subscribes, triggers listener, and disposes', (tester) async {
      final notifier = ChangeNotifier();
      int callCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useListenable(notifier, () {
            callCount++;
          });
          return () => const Text('Test');
        }),
      ));

      // Trigger notification - should call listener
      notifier.notifyListeners();
      await tester.pumpAndSettle();
      expect(callCount, greaterThan(0));

      // Unmount - should remove listener
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Trigger notification after unmount - listener should not be called
      final countBefore = callCount;
      notifier.notifyListeners();
      await tester.pumpAndSettle();
      expect(callCount, countBefore);
    });
  });

  group('useChangeNotifierSync', () {
    testWidgets('syncs ChangeNotifier to Signal (unidirectional)',
        (tester) async {
      final notifier = ValueNotifier(0);
      Signal<int>? signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(0);
          useListenableSync(
            signal!,
            notifier,
            getter: (notifier) => notifier.value,
          );
          return () => Text('Signal: ${signal!.value}');
        }),
      ));

      expect(signal!.value, 0);

      // Change notifier value
      notifier.value = 10;
      await tester.pumpAndSettle();

      expect(signal!.value, 10);
      expect(find.text('Signal: 10'), findsOneWidget);
    });

    testWidgets('syncs ChangeNotifier to Signal (bidirectional)',
        (tester) async {
      final notifier = ValueNotifier(0);
      Signal<int>? signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(0);
          useListenableSync(
            signal!,
            notifier,
            getter: (notifier) => notifier.value,
            setter: (value) => notifier.value = value,
          );
          return () =>
              Text('Signal: ${signal!.value}, Notifier: ${notifier.value}');
        }),
      ));

      expect(signal!.value, 0);
      expect(notifier.value, 0);

      // Change notifier value
      notifier.value = 10;
      await tester.pumpAndSettle();

      expect(signal!.value, 10);
      expect(notifier.value, 10);

      // Change signal value
      signal!.value = 20;
      await tester.pumpAndSettle();

      expect(signal!.value, 20);
      expect(notifier.value, 20);
    });

    testWidgets('avoids circular updates in bidirectional sync',
        (tester) async {
      final notifier = ValueNotifier(0);
      Signal<int>? signal;
      int notifierChangeCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(0);
          notifier.addListener(() {
            notifierChangeCount++;
          });
          useListenableSync(
            signal!,
            notifier,
            getter: (notifier) => notifier.value,
            setter: (value) => notifier.value = value,
          );
          return () => Text('Signal: ${signal!.value}');
        }),
      ));

      final initialCount = notifierChangeCount;

      // Change signal - should update notifier without triggering listener again
      signal!.value = 10;
      await tester.pumpAndSettle();

      expect(signal!.value, 10);
      expect(notifier.value, 10);
      // Should not cause infinite loop
      expect(notifierChangeCount, greaterThan(initialCount));
    });

    testWidgets('cleans up sync on unmount', (tester) async {
      final notifier = ValueNotifier(0);
      Signal<int>? signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(0);
          useListenableSync(
            signal!,
            notifier,
            getter: (notifier) => notifier.value,
          );
          return () => Text('Signal: ${signal!.value}');
        }),
      ));

      expect(signal!.value, 0);

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Change notifier after unmount
      notifier.value = 20;
      await tester.pumpAndSettle();

      // Signal should not update after unmount
      expect((signal! as SignalReactiveNode).pendingValue, 0);
    });

    testWidgets('works with custom ChangeNotifier', (tester) async {
      final notifier = _CustomNotifier();
      Signal<int>? signal;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          signal = useSignal(0);
          useListenableSync(
            signal!,
            notifier,
            getter: (notifier) => notifier.value,
            setter: (value) => notifier.value = value,
          );
          return () => Text('Signal: ${signal!.value}');
        }),
      ));

      expect(signal!.value, 0);

      // Change notifier
      notifier.value = 15;
      await tester.pumpAndSettle();

      expect(signal!.value, 15);

      // Change signal
      signal!.value = 25;
      await tester.pumpAndSettle();

      expect(notifier.value, 25);
    });
  });
}
