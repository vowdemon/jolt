import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useReset', () {
    testWidgets('useReset() returns resetSetup function', (tester) async {
      void Function()? resetFn;
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          resetFn = useReset();
          return () => Text('Setup count: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(resetFn, isNotNull);
      expect(setupCount, 1);
      expect(find.text('Setup count: 1'), findsOneWidget);
    });

    testWidgets('useReset() can be called to reset setup', (tester) async {
      int setupCount = 0;
      void Function()? resetFn;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          resetFn = useReset();
          return () => Text('Count: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Count: 1'), findsOneWidget);

      // Call resetSetup
      resetFn!();
      await tester.pumpAndSettle();

      // Setup should be re-run
      expect(setupCount, 2);
      expect(find.text('Count: 2'), findsOneWidget);
    });

    testWidgets('useReset() resets all hooks and state', (tester) async {
      int setupCount = 0;
      Signal<int>? signal;
      void Function()? resetFn;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          signal = useSignal(0);
          resetFn = useReset();
          return () => Text('Setup: $setupCount, Signal: ${signal!.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(signal!.value, 0);
      expect(find.text('Setup: 1, Signal: 0'), findsOneWidget);

      // Change signal value
      signal!.value = 10;
      await tester.pumpAndSettle();
      expect(find.text('Setup: 1, Signal: 10'), findsOneWidget);

      // Reset setup - should create new signal
      resetFn!();
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      // New signal should be created with initial value
      expect(signal!.value, 0);
      expect(find.text('Setup: 2, Signal: 0'), findsOneWidget);
    });
  });

  group('useReset.listen', () {
    testWidgets('listens to Listenable and resets setup on notify',
        (tester) async {
      final notifier = ValueNotifier(0);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          useReset.listen(() => [notifier]);
          return () => Text('Setup: $setupCount, Value: ${notifier.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, Value: 0'), findsOneWidget);

      // Change notifier value - should trigger reset
      notifier.value = 1;
      await tester.pumpAndSettle();

      // Setup should be reset
      expect(setupCount, 2);
      expect(find.text('Setup: 2, Value: 1'), findsOneWidget);

      // Change again
      notifier.value = 2;
      await tester.pumpAndSettle();

      expect(setupCount, 3);
      expect(find.text('Setup: 3, Value: 2'), findsOneWidget);
    });

    testWidgets('removes listener on unmount', (tester) async {
      final notifier = ValueNotifier(0);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          useReset.listen(() => [notifier]);
          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Change notifier - should not trigger reset
      final countBefore = setupCount;
      notifier.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, countBefore);
    });

    testWidgets('works with ChangeNotifier', (tester) async {
      final notifier = ChangeNotifier();
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;
          useReset.listen(() => [notifier]);
          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      // Notify - should trigger reset
      notifier.notifyListeners();
      await tester.pumpAndSettle();

      expect(setupCount, 2);
    });
  });

  group('useReset.watch', () {
    testWidgets('watches signals and resets setup on change', (tester) async {
      final countSignal = Signal(0);
      final nameSignal = Signal('Alice');
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.watch(() => [countSignal, nameSignal]);

          return () => Text(
              'Setup: $setupCount, Count: ${countSignal.value}, Name: ${nameSignal.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, Count: 0, Name: Alice'), findsOneWidget);

      // Change count signal - should trigger reset
      countSignal.value = 10;
      await tester.pumpAndSettle();

      // Setup should be reset
      expect(setupCount, 2);
      expect(find.text('Setup: 2, Count: 10, Name: Alice'), findsOneWidget);

      // Change name signal - should trigger reset again
      nameSignal.value = 'Bob';
      await tester.pumpAndSettle();

      expect(setupCount, 3);
      expect(find.text('Setup: 3, Count: 10, Name: Bob'), findsOneWidget);
    });

    testWidgets('watches computed values', (tester) async {
      // Create signal outside setup so it persists across resets
      final countSignal = Signal(5);
      final doubled = Computed(() => countSignal.value * 2);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.watch(() => [doubled]);

          return () => Text('Setup: $setupCount, Doubled: ${doubled.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, Doubled: 10'), findsOneWidget);

      // Change signal - computed changes, should trigger reset
      countSignal.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      expect(find.text('Setup: 2, Doubled: 20'), findsOneWidget);
    });

    testWidgets('disposes effect on unmount', (tester) async {
      final signal = Signal(0);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.watch(() => [signal]);

          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Change signal - should not trigger reset
      final countBefore = setupCount;
      signal.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, countBefore);
    });

    testWidgets('watches multiple signals', (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(3);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.watch(() => [signal1, signal2, signal3]);

          return () => Text(
              'Setup: $setupCount, S1: ${signal1.value}, S2: ${signal2.value}, S3: ${signal3.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, S1: 1, S2: 2, S3: 3'), findsOneWidget);

      // Change any signal - should trigger reset
      signal2.value = 20;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      expect(find.text('Setup: 2, S1: 1, S2: 20, S3: 3'), findsOneWidget);
    });
  });

  group('useReset.select', () {
    testWidgets('selects value and resets setup when it changes',
        (tester) async {
      final countSignal = Signal(0);
      final nameSignal = Signal('Alice');
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.select(() => '${nameSignal.value}: ${countSignal.value}');

          return () => Text(
              'Setup: $setupCount, Count: ${countSignal.value}, Name: ${nameSignal.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, Count: 0, Name: Alice'), findsOneWidget);

      // Change count signal - selected value changes, should trigger reset
      countSignal.value = 10;
      await tester.pumpAndSettle();

      // Setup should be reset
      expect(setupCount, 2);
      expect(find.text('Setup: 2, Count: 10, Name: Alice'), findsOneWidget);

      // Change name signal - selected value changes, should trigger reset again
      nameSignal.value = 'Bob';
      await tester.pumpAndSettle();

      expect(setupCount, 3);
      expect(find.text('Setup: 3, Count: 10, Name: Bob'), findsOneWidget);
    });

    testWidgets('selects computed values', (tester) async {
      // Create signal outside setup so it persists across resets
      final countSignal = Signal(5);
      final doubled = Computed(() => countSignal.value * 2);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.select(() => doubled.value);

          return () => Text('Setup: $setupCount, Doubled: ${doubled.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, Doubled: 10'), findsOneWidget);

      // Change signal - computed changes, selected value changes, should trigger reset
      countSignal.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      expect(find.text('Setup: 2, Doubled: 20'), findsOneWidget);
    });

    testWidgets('does not reset when selected value is the same',
        (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          // Select sum, which should remain the same when we swap values
          useReset.select(() => signal1.value + signal2.value);

          return () => Text(
              'Setup: $setupCount, S1: ${signal1.value}, S2: ${signal2.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, S1: 1, S2: 2'), findsOneWidget);

      // Change signals but keep sum the same - should not trigger reset
      signal1.value = 2;
      signal2.value = 1;
      await tester.pumpAndSettle();

      // Setup should not be reset because selected value (sum) is the same
      expect(setupCount, 1);
      expect(find.text('Setup: 1, S1: 2, S2: 1'), findsOneWidget);

      // Now change to make sum different - should trigger reset
      signal1.value = 5;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      expect(find.text('Setup: 2, S1: 5, S2: 1'), findsOneWidget);
    });

    testWidgets('disposes effect on unmount', (tester) async {
      final signal = Signal(0);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.select(() => signal.value);

          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Change signal - should not trigger reset
      final countBefore = setupCount;
      signal.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, countBefore);
    });

    testWidgets('selects from multiple signals', (tester) async {
      final signal1 = Signal(1);
      final signal2 = Signal(2);
      final signal3 = Signal(3);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          setupCount++;

          useReset.select(() => '${signal1.value}-${signal2.value}-${signal3.value}');

          return () => Text(
              'Setup: $setupCount, S1: ${signal1.value}, S2: ${signal2.value}, S3: ${signal3.value}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1, S1: 1, S2: 2, S3: 3'), findsOneWidget);

      // Change any signal - selected value changes, should trigger reset
      signal2.value = 20;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      expect(find.text('Setup: 2, S1: 1, S2: 20, S3: 3'), findsOneWidget);
    });
  });

  group('useReset with SetupMixin', () {
    testWidgets('useReset() works with SetupMixin', (tester) async {
      int setupCount = 0;
      void Function()? resetFn;

      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context) {
          setupCount++;
          resetFn = useReset();
          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(find.text('Setup: 1'), findsOneWidget);

      // Call resetSetup
      resetFn!();
      await tester.pumpAndSettle();

      expect(setupCount, 2);
      expect(find.text('Setup: 2'), findsOneWidget);
    });

    testWidgets('useReset.listen works with SetupMixin', (tester) async {
      final notifier = ValueNotifier(0);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context) {
          setupCount++;
          useReset.listen(() => [notifier]);
          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      notifier.value = 1;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
    });

    testWidgets('useReset.watch works with SetupMixin', (tester) async {
      Signal<int>? signal;
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context) {
          setupCount++;
          signal = useSignal(0);

          useReset.watch(() => [signal!]);

          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      signal!.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
    });

    testWidgets('useReset.select works with SetupMixin', (tester) async {
      final signal = Signal(0);
      int setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _TestStatefulWidget(setup: (context) {
          setupCount++;

          useReset.select(() => signal.value);

          return () => Text('Setup: $setupCount');
        }),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1);

      signal.value = 10;
      await tester.pumpAndSettle();

      expect(setupCount, 2);
    });
  });
}

/// Helper StatefulWidget for testing SetupMixin
class _TestStatefulWidget extends StatefulWidget {
  const _TestStatefulWidget({required this.setup});

  final WidgetFunction<_TestStatefulWidget> Function(BuildContext) setup;

  @override
  State<_TestStatefulWidget> createState() => _TestStatefulWidgetState();
}

class _TestStatefulWidgetState extends State<_TestStatefulWidget>
    with SetupMixin<_TestStatefulWidget> {
  @override
  setup(context) => widget.setup(context);
}
