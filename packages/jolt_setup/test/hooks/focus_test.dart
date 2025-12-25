import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useFocusNode', () {
    testWidgets('creates node', (tester) async {
      FocusNode? focusNode;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          focusNode = useFocusNode(debugLabel: 'Test Node');
          return () => const Text('Test');
        }),
      ));

      expect(focusNode, isNotNull);
      expect(focusNode!.debugLabel, 'Test Node');
    });

    testWidgets('auto-disposes', (tester) async {
      FocusNode? focusNode;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          focusNode = useFocusNode();
          return () => const Text('Test');
        }),
      ));

      expect(focusNode!.hasFocus, isFalse);

      // Unmount widget, focusNode will be disposed
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple instances managed independently', (tester) async {
      FocusNode? node1;
      FocusNode? node2;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          node1 = useFocusNode(debugLabel: 'Node 1');
          node2 = useFocusNode(debugLabel: 'Node 2');

          return () => const Text('Test');
        }),
      ));

      expect(node1!.debugLabel, 'Node 1');
      expect(node2!.debugLabel, 'Node 2');
      expect(node1, isNot(equals(node2)));
    });
  });

  group('useFocusScopeNode', () {
    testWidgets('creates node', (tester) async {
      FocusScopeNode? scopeNode;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          scopeNode = useFocusScopeNode(debugLabel: 'Scope');
          return () => const Text('Test');
        }),
      ));

      expect(scopeNode, isNotNull);
      expect(scopeNode, isA<FocusScopeNode>());
      expect(scopeNode!.debugLabel, 'Scope');
    });
  });
}
