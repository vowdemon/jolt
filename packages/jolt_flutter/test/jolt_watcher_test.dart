import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('JoltWatcher', () {
    testWidgets('renders and updates from readable', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatcher<int>(
            readable: counter,
            builder: (context, value) => Text('Count: $value'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pumpAndSettle();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('JoltWatcher.value omits context', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatcher.value(
            readable: counter,
            builder: (value) => Text('$value'),
          ),
        ),
      );

      counter.value = 2;
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('tracks computed readable', (tester) async {
      final counter = Signal(1);
      final doubled = Computed(() => counter.value * 2);

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatcher<int>(
            readable: doubled,
            builder: (context, value) => Text('$value'),
          ),
        ),
      );

      counter.value = 3;
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('stops rebuilding after unmount', (tester) async {
      final counter = Signal(0);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatcher<int>(
            readable: counter,
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

    testWidgets('rebuilds once after batched updates', (tester) async {
      final counter = Signal(0);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: JoltWatcher<int>(
            readable: counter,
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
  });

  group('Readable.watch', () {
    testWidgets('rebuilds when extension target changes', (tester) async {
      final counter = Signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: counter.watch((value) => Text('$value')),
        ),
      );

      counter.value = 7;
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);

      counter.dispose();
    });
  });
}
