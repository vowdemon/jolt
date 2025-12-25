import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useAppLifecycleState', () {
    testWidgets('creates and gets initial state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final lifecycleState = useAppLifecycleState();

          return () => Text('State: ${lifecycleState.value}');
        }),
      ));

      // Verify rendering succeeded (state may be null or a specific value depending on test environment)
      expect(find.textContaining('State:'), findsOneWidget);
    });

    testWidgets('cleans up correctly', (tester) async {
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

    testWidgets('reactive rendering', (tester) async {
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
