import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('Text Hooks', () {
    testWidgets('useTextEditingController creates controller', (tester) async {
      TextEditingController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTextEditingController();
            return () => TextField(controller: controller);
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.text, isEmpty);
    });

    testWidgets('useTextEditingController with initial text', (tester) async {
      TextEditingController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTextEditingController('Initial text');
            return () => TextField(controller: controller);
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.text, 'Initial text');
      expect(find.text('Initial text'), findsOneWidget);
    });

    testWidgets('useTextEditingController.fromValue', (tester) async {
      TextEditingController? controller;
      const initialValue = TextEditingValue(
        text: 'Test text',
        selection: TextSelection.collapsed(offset: 2),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTextEditingController.fromValue(initialValue);
            return () => TextField(controller: controller);
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.text, 'Test text');
      expect(controller!.selection.baseOffset, 2);
    });

    testWidgets('useTextEditingController auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            final controller = useTextEditingController('Text');
            return () => TextField(controller: controller);
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('useTextEditingController text can be modified',
        (tester) async {
      TextEditingController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTextEditingController('Initial');
            return () => TextField(controller: controller);
          }),
        ),
      ));

      // Initial text
      expect(controller!.text, 'Initial');

      // Modify text
      controller!.text = 'New text';
      await tester.pump();

      // Verify text modified
      expect(controller!.text, 'New text');
      expect(find.text('New text'), findsOneWidget);
    });

    testWidgets('useTextEditingController supports user input', (tester) async {
      TextEditingController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTextEditingController();
            return () => TextField(controller: controller);
          }),
        ),
      ));

      // Initially empty
      expect(controller!.text, isEmpty);

      // User input
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      // Verify input succeeded
      expect(controller!.text, 'Hello');

      // Continue input
      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.pump();

      expect(controller!.text, 'Hello World');
    });

    testWidgets('multiple controllers work independently', (tester) async {
      TextEditingController? controller1;
      TextEditingController? controller2;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller1 = useTextEditingController('Controller 1');
            controller2 = useTextEditingController('Controller 2');

            return () => Column(
                  children: [
                    TextField(controller: controller1),
                    TextField(controller: controller2),
                  ],
                );
          }),
        ),
      ));

      // Two controllers are independent
      expect(controller1!.text, 'Controller 1');
      expect(controller2!.text, 'Controller 2');

      // Modify the first one
      controller1!.text = 'Modified 1';
      await tester.pump();

      expect(controller1!.text, 'Modified 1');
      expect(controller2!.text, 'Controller 2'); // Second one unchanged

      // Both should be cleaned up correctly on unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}
