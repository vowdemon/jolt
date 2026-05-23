import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltValueListenable', () {
    test('mirrors readable value', () {
      final signal = Signal(0);
      final listenable = signal.listenable;

      expect(listenable.value, 0);
      signal.value = 2;
      expect(listenable.value, 2);

      signal.dispose();
    });

    test('reuses cache until disposed', () {
      final signal = Signal(0);
      final first = signal.listenable;
      final second = signal.listenable;

      expect(identical(first, second), isTrue);

      first.dispose();

      final third = signal.listenable;
      expect(identical(first, third), isFalse);

      third.dispose();
      signal.dispose();
    });

    test('notifies listeners on change', () {
      final signal = Signal(0);
      final listenable = signal.listenable;
      var count = 0;

      listenable.addListener(() => count++);
      signal.value = 1;

      expect(count, 1);
      signal.dispose();
    });

    test('stops notifying after dispose', () {
      final signal = Signal(0);
      final listenable = signal.listenable;
      var count = 0;

      listenable.addListener(() => count++);
      signal.value = 1;
      listenable.dispose();

      signal.value = 2;
      expect(listenable.value, 2);
      expect(count, 1);

      signal.dispose();
    });

    testWidgets('works in ValueListenableBuilder', (tester) async {
      final signal = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: signal.listenable,
            builder: (context, value, _) => Text('$value'),
          ),
        ),
      );

      signal.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      signal.dispose();
    });
  });

  group('toListenableSignal', () {
    test('syncs from ValueListenable to readable', () {
      final notifier = ValueNotifier(0);
      final readable = notifier.toListenableSignal();

      notifier.value = 1;
      expect(readable.value, 1);

      notifier.dispose();
    });

    test('returns original node for JoltValueListenable', () {
      final signal = Signal(0);
      final bridge = signal.listenable.toListenableSignal();
      expect(identical(signal, bridge), isTrue);
      signal.dispose();
    });

    test('returns original node for JoltValueNotifier', () {
      final signal = Signal(0);
      final bridge = signal.notifier.toListenableSignal();
      expect(identical(signal, bridge), isTrue);
      signal.dispose();
    });

    test('shared bridge until dispose', () {
      final notifier = ValueNotifier(0);
      final a = notifier.toListenableSignal() as ValueListenableSignal<int>;
      final b = notifier.toListenableSignal() as ValueListenableSignal<int>;

      expect(identical(a, b), isTrue);

      a.dispose();
      expect(a.isDisposed, isTrue);
      expect(b.isDisposed, isTrue);

      notifier.value = 1;
      expect(b.value, 0);
      expect(b.peek, 0);

      final c = notifier.toListenableSignal() as ValueListenableSignal<int>;
      expect(c.value, 1);

      c.dispose();
      notifier.dispose();
    });

    testWidgets('drives JoltBuilder from notifier', (tester) async {
      final notifier = ValueNotifier(0);
      final readable = notifier.toListenableSignal();

      await tester.pumpWidget(
        MaterialApp(
          home: JoltBuilder(
            builder: (context) => Text('${readable.value}'),
          ),
        ),
      );

      notifier.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);

      notifier.dispose();
    });
  });

  group('JoltValueNotifier', () {
    test('bidirectional sync with writable', () {
      final signal = Signal(0);
      final notifier = signal.notifier;

      signal.value = 1;
      expect(notifier.value, 1);

      notifier.value = 2;
      expect(signal.value, 2);

      signal.dispose();
    });

    test('reuses cache until disposed', () {
      final signal = Signal(0);
      final first = signal.notifier;
      final second = signal.notifier;

      expect(identical(first, second), isTrue);

      first.dispose();

      final third = signal.notifier;
      expect(identical(first, third), isFalse);

      third.dispose();
      signal.dispose();
    });

    test('stops notifying after dispose', () {
      final signal = Signal(0);
      final notifier = signal.notifier;
      var count = 0;

      notifier.addListener(() => count++);
      signal.value = 1;
      notifier.dispose();

      notifier.value = 2;
      expect(count, 1);

      signal.dispose();
    });
  });

  group('toNotifierSignal', () {
    test('bidirectional sync with ValueNotifier', () {
      final notifier = ValueNotifier(0);
      final signal = notifier.toNotifierSignal();

      notifier.value = 1;
      expect(signal.value, 1);

      signal.value = 2;
      expect(notifier.value, 2);

      signal.dispose();
      notifier.dispose();
    });

    test('returns original signal for JoltValueNotifier', () {
      final signal = Signal(0);
      final bridge = signal.notifier.toNotifierSignal();
      expect(identical(signal, bridge), isTrue);
      signal.dispose();
    });

    test('shared writable bridge until dispose', () {
      final notifier = ValueNotifier(0);
      final a = notifier.toNotifierSignal();
      final b = notifier.toNotifierSignal();

      expect(identical(a, b), isTrue);

      a.dispose();
      expect(a.isDisposed, isTrue);
      expect(b.isDisposed, isTrue);

      b.value = 2;
      expect(notifier.value, 0);

      notifier.value = 1;
      expect(b.value, 0);
      expect(b.peek, 0);

      final c = notifier.toNotifierSignal();
      expect(c.value, 1);

      c.dispose();
      notifier.dispose();
    });
  });
}
