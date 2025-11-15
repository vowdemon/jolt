import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

void main() {
  group('Scroll Hooks', () {
    testWidgets('useScrollController creates controller', (tester) async {
      ScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupBuilder(setup: (context) {
            controller = useScrollController();
            return (context) => ListView.builder(
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

    testWidgets('useScrollController with initial offset', (tester) async {
      ScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useScrollController(initialScrollOffset: 100.0);
          return (context) => ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (context, index) => SizedBox(
                  height: 50,
                  child: Text('Item $index'),
                ),
              );
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.initialScrollOffset, 100.0);
    });

    testWidgets('useScrollController auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final controller = useScrollController();
          return (context) => ListView(controller: controller);
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('useTabController creates controller', (tester) async {
      TabController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useTabController(length: 3);
          return (context) => DefaultTabController(
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

    testWidgets('useTabController with initial index', (tester) async {
      TabController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useTabController(length: 3, initialIndex: 1);
          return (context) => const Scaffold(body: SizedBox());
        }),
      ));

      expect(controller, isNotNull);
      expect(controller!.length, 3);
      expect(controller!.index, 1);
    });

    testWidgets('useTabController can switch tabs', (tester) async {
      TabController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useTabController(length: 3);
          return (context) => const Scaffold(body: SizedBox());
        }),
      ));

      expect(controller!.index, 0);

      // Switch to second tab
      controller!.animateTo(1);
      await tester.pumpAndSettle();

      expect(controller!.index, 1);

      // Switch to third tab
      controller!.animateTo(2);
      await tester.pumpAndSettle();

      expect(controller!.index, 2);
    });

    testWidgets('useTabController auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final controller = useTabController(length: 3);
          return (context) => Scaffold(
                body: TabBar(
                  controller: controller,
                  tabs: const [Tab(text: '1'), Tab(text: '2'), Tab(text: '3')],
                ),
              );
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('usePageController creates controller', (tester) async {
      PageController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = usePageController();
          return (context) => PageView(
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

    testWidgets('usePageController with initial page', (tester) async {
      PageController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = usePageController(initialPage: 1);
          return (context) => PageView(
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
      expect(controller!.initialPage, 1);
      await tester.pumpAndSettle();

      // Verify currently on second page
      expect(find.text('Page 2'), findsOneWidget);
    });

    testWidgets('usePageController can navigate pages', (tester) async {
      PageController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = usePageController();
          return (context) => PageView(
                controller: controller,
                children: const [
                  Center(child: Text('Page 1')),
                  Center(child: Text('Page 2')),
                  Center(child: Text('Page 3')),
                ],
              );
        }),
      ));

      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);

      // Jump to second page
      controller!.jumpToPage(1);
      await tester.pumpAndSettle();

      expect(find.text('Page 2'), findsOneWidget);

      // Jump to third page
      controller!.jumpToPage(2);
      await tester.pumpAndSettle();

      expect(find.text('Page 3'), findsOneWidget);
    });

    testWidgets('usePageController auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final controller = usePageController();
          return (context) => PageView(
                controller: controller,
                children: const [Text('Page 1')],
              );
        }),
      ));

      // Unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('useFixedExtentScrollController creates controller',
        (tester) async {
      FixedExtentScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useFixedExtentScrollController();
          return (context) => SizedBox(
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

    testWidgets('useFixedExtentScrollController with initial item',
        (tester) async {
      FixedExtentScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useFixedExtentScrollController(initialItem: 3);
          return (context) => SizedBox(
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
      expect(controller!.initialItem, 3);
    });

    testWidgets('useFixedExtentScrollController can jump to item',
        (tester) async {
      FixedExtentScrollController? controller;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          controller = useFixedExtentScrollController();
          return (context) => SizedBox(
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

      await tester.pumpAndSettle();

      // Jump to 5th item
      controller!.jumpToItem(5);
      await tester.pumpAndSettle();

      expect(controller!.selectedItem, 5);
    });

    testWidgets('useFixedExtentScrollController auto-disposes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final controller = useFixedExtentScrollController();
          return (context) => SizedBox(
                height: 200,
                child: ListWheelScrollView(
                  controller: controller,
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

    testWidgets('multiple controllers work independently', (tester) async {
      ScrollController? scrollController;
      PageController? pageController;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          scrollController = useScrollController();
          pageController = usePageController();

          return (context) => Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [Text('List Item')],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: pageController,
                      children: const [Text('Page 1')],
                    ),
                  ),
                ],
              );
        }),
      ));

      expect(scrollController, isNotNull);
      expect(pageController, isNotNull);
      expect(scrollController!.hasClients, true);
      expect(pageController!.hasClients, true);

      // Both should be cleaned up correctly on unmount
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}
