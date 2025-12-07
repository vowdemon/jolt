import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('useTextEditingController', () {
    testWidgets('creates controller', (tester) async {
      TextEditingController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTextEditingController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.text, isEmpty);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      TextEditingController? controllerFromSetup;
      TextEditingController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: SetupBuilder(setup: (context) {
            setupCount++;
            controllerFromSetup = useTextEditingController(text: 'Initial');
            return () {
              buildCount++;
              // Use the controller from setup, don't call use hook in build
              controllerFromBuild = controllerFromSetup;
              return const SizedBox();
            };
          }),
        ),
      ));

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason:
              'Controller from build should be the same instance from setup');

      // Modify controller state
      controllerFromSetup!.text = 'Modified';
      await tester.pump();

      // Trigger rebuild
      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1, reason: 'Setup should still execute only once');
      expect(buildCount, greaterThan(1),
          reason: 'Build should execute multiple times');
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason: 'Controller should remain the same after rebuild');
      expect(controllerFromBuild!.text, 'Modified',
          reason: 'Modified state should persist across rebuilds');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useTextEditingController(text: 'Text');
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fromValue creates, maintains state, and disposes',
        (tester) async {
      TextEditingController? controllerFromSetup;
      TextEditingController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;
      const initialValue = TextEditingValue(
        text: 'Test text',
        selection: TextSelection.collapsed(offset: 2),
      );

      // Create
      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup =
                  useTextEditingController.fromValue(initialValue);
              return () {
                buildCount++;
                // Use the controller from setup, don't call use hook in build
                controllerFromBuild = controllerFromSetup;
                return const SizedBox();
              };
            }),
          ),
        ),
      ));

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(controllerFromSetup!.text, 'Test text');
      expect(controllerFromSetup!.selection.baseOffset, 2);

      // Maintains state across rebuilds
      controllerFromSetup!.text = 'Modified text';
      await tester.pump();

      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1, reason: 'Setup should still execute only once');
      expect(buildCount, greaterThan(1),
          reason: 'Build should execute multiple times');
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason: 'Controller should remain the same after rebuild');
      expect(controllerFromBuild!.text, 'Modified text',
          reason: 'Modified state should persist');

      // Disposes on unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useRestorableTextEditingController', () {
    testWidgets('creates controller', (tester) async {
      RestorableTextEditingController? controller;

      await tester.pumpWidget(MaterialApp(
        restorationScopeId: 'app',
        home: _TestRestorationWidget(
          child: SetupBuilder(setup: (context) {
            controller = useRestorableTextEditingController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      RestorableTextEditingController? controllerFromSetup;
      RestorableTextEditingController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        restorationScopeId: 'app',
        home: _TestRestorationWidget(
          child: _RebuildTestWidget(
            onRebuild: () {
              buildCount++;
            },
            child: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup =
                  useRestorableTextEditingController(text: 'Initial');
              return () {
                buildCount++;
                // Use the controller from setup, don't call use hook in build
                controllerFromBuild = controllerFromSetup;
                return const SizedBox();
              };
            }),
          ),
        ),
      ));

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason:
              'Controller from build should be the same instance from setup');

      // Trigger rebuild
      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1, reason: 'Setup should still execute only once');
      expect(buildCount, greaterThan(1),
          reason: 'Build should execute multiple times');
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason: 'Controller should remain the same after rebuild');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        restorationScopeId: 'app',
        home: _TestRestorationWidget(
          child: SetupBuilder(setup: (context) {
            useRestorableTextEditingController(text: 'Text');
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fromValue creates, maintains state, and disposes',
        (tester) async {
      RestorableTextEditingController? controllerFromSetup;
      RestorableTextEditingController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;
      const initialValue = TextEditingValue(
        text: 'Test text',
        selection: TextSelection.collapsed(offset: 2),
      );

      // Create
      await tester.pumpWidget(MaterialApp(
        restorationScopeId: 'app',
        home: _TestRestorationWidget(
          child: _RebuildTestWidget(
            onRebuild: () {
              buildCount++;
            },
            child: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup =
                  useRestorableTextEditingController.fromValue(initialValue);
              return () {
                buildCount++;
                // Use the controller from setup, don't call use hook in build
                controllerFromBuild = controllerFromSetup;
                return const SizedBox();
              };
            }),
          ),
        ),
      ));

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);

      // Maintains state across rebuilds
      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1, reason: 'Setup should still execute only once');
      expect(buildCount, greaterThan(1),
          reason: 'Build should execute multiple times');
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason: 'Controller should remain the same after rebuild');

      // Disposes on unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useUndoHistoryController', () {
    testWidgets('creates controller', (tester) async {
      UndoHistoryController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useUndoHistoryController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.value, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      UndoHistoryController? controllerFromSetup;
      UndoHistoryController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;
      const initialValue = UndoHistoryValue(
        canUndo: true,
        canRedo: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: SetupBuilder(setup: (context) {
            setupCount++;
            controllerFromSetup = useUndoHistoryController(value: initialValue);
            return () {
              buildCount++;
              // Use the controller from setup, don't call use hook in build
              controllerFromBuild = controllerFromSetup;
              return const SizedBox();
            };
          }),
        ),
      ));

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason:
              'Controller from build should be the same instance from setup');

      // Modify value
      const newValue = UndoHistoryValue(
        canUndo: false,
        canRedo: true,
      );
      controllerFromSetup!.value = newValue;
      await tester.pump();

      // Trigger rebuild
      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1, reason: 'Setup should still execute only once');
      expect(buildCount, greaterThan(1),
          reason: 'Build should execute multiple times');
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason: 'Controller should remain the same after rebuild');
      final value = controllerFromBuild!.value;
      expect(value, isNotNull);
      expect(value.canRedo, isTrue, reason: 'Modified value should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useUndoHistoryController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useSearchController', () {
    testWidgets('creates controller', (tester) async {
      SearchController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useSearchController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      SearchController? controllerFromSetup;
      SearchController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: SetupBuilder(setup: (context) {
            setupCount++;
            controllerFromSetup = useSearchController();
            return () {
              buildCount++;
              // Use the controller from setup, don't call use hook in build
              controllerFromBuild = controllerFromSetup;
              return const SizedBox();
            };
          }),
        ),
      ));

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason:
              'Controller from build should be the same instance from setup');

      // Trigger rebuild
      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1, reason: 'Setup should still execute only once');
      expect(buildCount, greaterThan(1),
          reason: 'Build should execute multiple times');
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason: 'Controller should remain the same after rebuild');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useSearchController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Helper widget that provides restoration scope for testing RestorableTextEditingController
class _TestRestorationWidget extends StatefulWidget {
  const _TestRestorationWidget({required this.child});

  final Widget child;

  @override
  State<_TestRestorationWidget> createState() => _TestRestorationWidgetState();
}

class _TestRestorationWidgetState extends State<_TestRestorationWidget>
    with RestorationMixin {
  @override
  String? get restorationId => 'test';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // Empty implementation for testing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: widget.child);
  }
}

/// Helper widget that can trigger rebuilds for testing state maintenance
class _RebuildTestWidget extends StatefulWidget {
  const _RebuildTestWidget({
    required this.child,
    required this.onRebuild,
  });

  final Widget child;
  final VoidCallback onRebuild;

  @override
  State<_RebuildTestWidget> createState() => _RebuildTestWidgetState();
}

class _RebuildTestWidgetState extends State<_RebuildTestWidget> {
  void triggerRebuild() {
    setState(() {
      widget.onRebuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
