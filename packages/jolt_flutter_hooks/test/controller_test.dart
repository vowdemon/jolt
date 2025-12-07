import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('useTransformationController', () {
    testWidgets('creates controller', (tester) async {
      TransformationController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTransformationController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      TransformationController? controllerFromSetup;
      TransformationController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useTransformationController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useTransformationController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useWidgetStatesController', () {
    testWidgets('creates controller', (tester) async {
      WidgetStatesController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useWidgetStatesController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      WidgetStatesController? controllerFromSetup;
      WidgetStatesController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useWidgetStatesController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useWidgetStatesController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useExpansibleController', () {
    testWidgets('creates controller', (tester) async {
      ExpansibleController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useExpansibleController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      ExpansibleController? controllerFromSetup;
      ExpansibleController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useExpansibleController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useExpansibleController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useTreeSliverController', () {
    testWidgets('creates controller', (tester) async {
      TreeSliverController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTreeSliverController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      TreeSliverController? controllerFromSetup;
      TreeSliverController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useTreeSliverController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useTreeSliverController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useOverlayPortalController', () {
    testWidgets('creates controller', (tester) async {
      OverlayPortalController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useOverlayPortalController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      OverlayPortalController? controllerFromSetup;
      OverlayPortalController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useOverlayPortalController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useOverlayPortalController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useSnapshotController', () {
    testWidgets('creates controller', (tester) async {
      SnapshotController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useSnapshotController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      SnapshotController? controllerFromSetup;
      SnapshotController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useSnapshotController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useSnapshotController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useCupertinoTabController', () {
    testWidgets('creates controller', (tester) async {
      CupertinoTabController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useCupertinoTabController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.index, 0);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      CupertinoTabController? controllerFromSetup;
      CupertinoTabController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useCupertinoTabController(initialIndex: 1);
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
      expect(controllerFromBuild!.index, 1,
          reason: 'Initial index should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useCupertinoTabController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useContextMenuController', () {
    testWidgets('creates controller', (tester) async {
      ContextMenuController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useContextMenuController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      ContextMenuController? controllerFromSetup;
      ContextMenuController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useContextMenuController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useContextMenuController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useMenuController', () {
    testWidgets('creates controller', (tester) async {
      MenuController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useMenuController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      MenuController? controllerFromSetup;
      MenuController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useMenuController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useMenuController();
            return () => const SizedBox();
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useMagnifierController', () {
    testWidgets('creates controller', (tester) async {
      MagnifierController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useMagnifierController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      MagnifierController? controllerFromSetup;
      MagnifierController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: Scaffold(
            body: SetupBuilder(setup: (context) {
              setupCount++;
              controllerFromSetup = useMagnifierController();
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
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useMagnifierController();
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
