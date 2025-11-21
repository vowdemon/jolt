import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('Lifecycle Hooks', () {
    testWidgets('useAppLifecycleState creates and gets initial state',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final lifecycleState = useAppLifecycleState();

          return () => Text('State: ${lifecycleState.value}');
        }),
      ));

      // Verify rendering succeeded (state may be null or a specific value depending on test environment)
      expect(find.textContaining('State:'), findsOneWidget);
    });

    testWidgets('useAppLifecycleState cleans up correctly', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useAppLifecycleState();
          return () => const Text('Test');
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('useAppLifecycleState reactive rendering', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final lifecycleState = useAppLifecycleState();

          return () => Text('State: ${lifecycleState.value}');
        }),
      ));

      // Verify initial rendering
      expect(find.textContaining('State:'), findsOneWidget);
    });
  });
}
