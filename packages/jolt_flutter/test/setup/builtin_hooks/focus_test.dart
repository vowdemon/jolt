import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';

void main() {
  group('Focus Hooks', () {
    testWidgets('useFocusNode creates node', (tester) async {
      FocusNode? focusNode;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          focusNode = useFocusNode(debugLabel: 'Test Node');
          return (context) => const Text('Test');
        }),
      ));

      expect(focusNode, isNotNull);
      expect(focusNode!.debugLabel, 'Test Node');
    });

    testWidgets('useFocusNode auto-disposes', (tester) async {
      FocusNode? focusNode;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          focusNode = useFocusNode();
          return (context) => const Text('Test');
        }),
      ));

      expect(focusNode!.hasFocus, isFalse);

      // Unmount widget, focusNode will be disposed
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('useFocusScopeNode creates node', (tester) async {
      FocusScopeNode? scopeNode;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          scopeNode = useFocusScopeNode(debugLabel: 'Scope');
          return (context) => const Text('Test');
        }),
      ));

      expect(scopeNode, isNotNull);
      expect(scopeNode, isA<FocusScopeNode>());
      expect(scopeNode!.debugLabel, 'Scope');
    });

    testWidgets('useAutoFocus auto-focuses', (tester) async {
      FocusNode? focusNode;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            focusNode = useFocusNode();
            useAutoFocus(focusNode!);
            return (context) => TextField(focusNode: focusNode);
          }),
        ),
      ));

      await tester.pump();

      expect(focusNode!.hasFocus, isTrue);
    });

    testWidgets('useFocusState responds to focus changes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            final focusNode = useFocusNode();
            final hasFocus = useFocusState(focusNode);

            return (context) => TextField(
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: hasFocus.value ? 'Focused' : 'Unfocused',
                  ),
                );
          }),
        ),
      ));

      expect(find.text('Unfocused'), findsOneWidget);

      // Tap TextField to gain focus
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(find.text('Focused'), findsOneWidget);
    });

    testWidgets('multiple FocusNodes managed independently', (tester) async {
      FocusNode? node1;
      FocusNode? node2;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          node1 = useFocusNode(debugLabel: 'Node 1');
          node2 = useFocusNode(debugLabel: 'Node 2');

          return (context) => const Text('Test');
        }),
      ));

      expect(node1!.debugLabel, 'Node 1');
      expect(node2!.debugLabel, 'Node 2');
      expect(node1, isNot(equals(node2)));
    });

    testWidgets('useFocusState cleans up listeners', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            final focusNode = useFocusNode();
            useFocusState(focusNode);

            return (context) => TextField(focusNode: focusNode);
          }),
        ),
      ));

      // Unmount widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Should have no exception (listeners cleaned up)
      expect(tester.takeException(), isNull);
    });
  });
}
