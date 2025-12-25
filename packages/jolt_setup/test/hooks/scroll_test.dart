import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useScrollController', () {
    testWidgets('creates controller', (tester) async {
      ScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useScrollController();
            return () => ListView.builder(
                  controller: controller,
                  itemCount: 10,
                  itemBuilder: (context, index) => Text('Item $index'),
                );
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.hasClients, true);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      ScrollController? controllerFromSetup;
      ScrollController? controllerFromBuild;
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
              controllerFromSetup =
                  useScrollController(initialScrollOffset: 100.0);
              return () {
                buildCount++;
                // Use the controller from setup, don't call use hook in build
                controllerFromBuild = controllerFromSetup;
                return ListView.builder(
                  controller: controllerFromSetup,
                  itemCount: 10,
                  itemBuilder: (context, index) => Text('Item $index'),
                );
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

      // Modify scroll position
      controllerFromSetup!.jumpTo(200.0);
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
      expect(controllerFromBuild!.offset, 200.0,
          reason: 'Modified scroll position should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useScrollController();
            return () => ListView(children: const [Text('Item')]);
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useTabController', () {
    testWidgets('creates controller', (tester) async {
      TabController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useTabController(length: 3);
          return () => DefaultTabController(
                length: 3,
                child: Scaffold(
                  appBar: AppBar(
                    bottom: TabBar(
                      controller: controller,
                      tabs: const [
                        Tab(text: 'Tab 1'),
                        Tab(text: 'Tab 2'),
                        Tab(text: 'Tab 3'),
                      ],
                    ),
                  ),
                  body: const TabBarView(
                    children: [
                      Center(child: Text('Content 1')),
                      Center(child: Text('Content 2')),
                      Center(child: Text('Content 3')),
                    ],
                  ),
                ),
              );
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.length, 3);
      expect(controller!.index, 0);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      TabController? controllerFromSetup;
      TabController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: SetupBuilder(setup: (context) {
            setupCount++;
            controllerFromSetup = useTabController(length: 3);
            return () {
              buildCount++;
              // Use the controller from setup, don't call use hook in build
              controllerFromBuild = controllerFromSetup;
              return const Scaffold(body: SizedBox());
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

      // Modify tab index
      controllerFromSetup!.index = 1;
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
      expect(controllerFromBuild!.index, 1,
          reason: 'Modified tab index should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useTabController(length: 3);
          return () => const Scaffold(body: SizedBox());
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('usePageController', () {
    testWidgets('creates controller', (tester) async {
      PageController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = usePageController();
          return () => PageView(
                controller: controller,
                children: const [
                  Center(child: Text('Page 1')),
                  Center(child: Text('Page 2')),
                  Center(child: Text('Page 3')),
                ],
              );
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.initialPage, 0);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      PageController? controllerFromSetup;
      PageController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: SetupBuilder(setup: (context) {
            setupCount++;
            controllerFromSetup = usePageController();
            return () {
              buildCount++;
              // Use the controller from setup, don't call use hook in build
              controllerFromBuild = controllerFromSetup;
              return PageView(
                controller: controllerFromSetup,
                children: const [
                  Center(child: Text('Page 1')),
                  Center(child: Text('Page 2')),
                  Center(child: Text('Page 3')),
                ],
              );
            };
          }),
        ),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason:
              'Controller from build should be the same instance from setup');

      // Modify page
      controllerFromSetup!.jumpToPage(1);
      await tester.pumpAndSettle();

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
      expect(controllerFromBuild!.page, 1.0,
          reason: 'Modified page should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          usePageController();
          return () => PageView(
                children: const [Text('Page 1')],
              );
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useFixedExtentScrollController', () {
    testWidgets('creates controller', (tester) async {
      FixedExtentScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useFixedExtentScrollController();
          return () => SizedBox(
                height: 200,
                child: ListWheelScrollView(
                  controller: controller,
                  itemExtent: 50,
                  children: List.generate(
                    10,
                    (index) => Center(child: Text('Item $index')),
                  ),
                ),
              );
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.initialItem, 0);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      FixedExtentScrollController? controllerFromSetup;
      FixedExtentScrollController? controllerFromBuild;
      var setupCount = 0;
      var buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {
            buildCount++;
          },
          child: SetupBuilder(setup: (context) {
            setupCount++;
            controllerFromSetup = useFixedExtentScrollController();
            return () {
              buildCount++;
              // Use the controller from setup, don't call use hook in build
              controllerFromBuild = controllerFromSetup;
              return SizedBox(
                height: 200,
                child: ListWheelScrollView(
                  controller: controllerFromSetup,
                  itemExtent: 50,
                  children: List.generate(
                    10,
                    (index) => Center(child: Text('Item $index')),
                  ),
                ),
              );
            };
          }),
        ),
      ));

      await tester.pumpAndSettle();

      expect(setupCount, 1, reason: 'Setup should execute only once');
      expect(buildCount, greaterThan(0), reason: 'Build should execute');
      expect(controllerFromSetup, isNotNull);
      expect(controllerFromBuild, isNotNull);
      expect(identical(controllerFromSetup, controllerFromBuild), isTrue,
          reason:
              'Controller from build should be the same instance from setup');

      // Modify selected item
      controllerFromSetup!.jumpToItem(5);
      await tester.pumpAndSettle();

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
      expect(controllerFromBuild!.selectedItem, 5,
          reason: 'Modified selected item should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useFixedExtentScrollController();
          return () => SizedBox(
                height: 200,
                child: ListWheelScrollView(
                  itemExtent: 50,
                  children: const [Text('Item 0')],
                ),
              );
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useTrackingScrollController', () {
    testWidgets('creates controller', (tester) async {
      TrackingScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useTrackingScrollController();
            return () => ListView.builder(
                  controller: controller,
                  itemCount: 10,
                  itemBuilder: (context, index) => Text('Item $index'),
                );
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.hasClients, true);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      TrackingScrollController? controllerFromSetup;
      TrackingScrollController? controllerFromBuild;
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
              controllerFromSetup =
                  useTrackingScrollController(initialScrollOffset: 100.0);
              return () {
                buildCount++;
                // Use the controller from setup, don't call use hook in build
                controllerFromBuild = controllerFromSetup;
                return ListView.builder(
                  controller: controllerFromSetup,
                  itemCount: 10,
                  itemBuilder: (context, index) => Text('Item $index'),
                );
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

      // Modify scroll position
      controllerFromSetup!.jumpTo(200.0);
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
      expect(controllerFromBuild!.offset, 200.0,
          reason: 'Modified scroll position should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useTrackingScrollController();
            return () => ListView(children: const [Text('Item')]);
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useDraggableScrollableController', () {
    testWidgets('creates controller', (tester) async {
      DraggableScrollableController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useDraggableScrollableController();
            return () => DraggableScrollableSheet(
                  controller: controller,
                  builder: (context, scrollController) {
                    return ListView(
                      controller: scrollController,
                      children: const [Text('Content')],
                    );
                  },
                );
          }),
        ),
      ));

      expect(controller, isNotNull);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      DraggableScrollableController? controllerFromSetup;
      DraggableScrollableController? controllerFromBuild;
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
              controllerFromSetup = useDraggableScrollableController();
              return () {
                buildCount++;
                // Use the controller from setup, don't call use hook in build
                controllerFromBuild = controllerFromSetup;
                return DraggableScrollableSheet(
                  controller: controllerFromSetup,
                  builder: (context, scrollController) {
                    return ListView(
                      controller: scrollController,
                      children: const [Text('Content')],
                    );
                  },
                );
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
            useDraggableScrollableController();
            return () => DraggableScrollableSheet(
                  builder: (context, scrollController) {
                    return ListView(
                      controller: scrollController,
                      children: const [Text('Content')],
                    );
                  },
                );
          }),
        ),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('useCarouselController', () {
    testWidgets('creates controller', (tester) async {
      CarouselController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useCarouselController();
            return () => const SizedBox();
          }),
        ),
      ));

      expect(controller, isNotNull);
      expect(controller!.initialItem, 0);
    });

    testWidgets('maintains state across rebuilds', (tester) async {
      CarouselController? controllerFromSetup;
      CarouselController? controllerFromBuild;
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
              controllerFromSetup = useCarouselController(initialItem: 2);
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
      expect(controllerFromBuild!.initialItem, 2,
          reason: 'Initial item should persist');
    });

    testWidgets('disposes on unmount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            useCarouselController();
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
