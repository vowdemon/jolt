import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/views/inspector_page.dart';
import 'package:jolt_devtools_extension/src/widgets/node_details_panel.dart';
import 'package:jolt_devtools_extension/src/widgets/nodes_list_panel.dart';
import 'package:jolt_devtools_extension/src/widgets/watch_list_panel.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('watch panel renders watched node state and removes nodes',
      (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(
      id: 1,
      label: 'counter',
      value: 42,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      count: 3,
      dependencies: [2],
      subscribers: [3],
    );
    controller.addNodeToWatch(1);

    await tester.pumpWidget(
      _wrap(controller, const WatchListPanel(width: 280)),
    );

    expect(find.text('Watch (1)'), findsOneWidget);
    expect(find.text('counter'), findsOneWidget);
    expect(find.text('id: 1'), findsOneWidget);
    expect(find.text('value: 42'), findsNothing);
    expect(find.text('count: 3'), findsOneWidget);
    expect(find.text('deps: 1'), findsNothing);
    expect(find.text('subs: 1'), findsNothing);
    expect(find.text('active'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from Watch'));
    await tester.pumpAndSettle();

    expect(controller.$watchedNodeIds.value, isEmpty);
    expect(find.text('No watched nodes'), findsOneWidget);
  });

  testWidgets('watch panel item opens details and enters selection history',
      (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');
    controller.$nodes[2] = _node(id: 2, label: 'total');
    await controller.selectNode(2);
    controller.addNodeToWatch(1);

    await tester.pumpWidget(
      _wrap(controller, const WatchListPanel(width: 280)),
    );
    await tester.tap(find.text('counter'));
    await tester.pump();

    expect(controller.$selectedNodeId.value, 1);
    expect(controller.selectionHistory, [2, 1]);
    expect(controller.canNavigateBack, isTrue);
  });

  testWidgets('node list and details can toggle node watch state',
      (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter', type: 'State');
    controller.$nodes[2] = _node(id: 2, label: 'total', type: 'State');
    await controller.selectNode(2);

    await tester.pumpWidget(
      _wrap(
        controller,
        Row(
          children: [
            const Expanded(child: NodesListPanel()),
            SizedBox(
              width: 360,
              child: NodeDetailsPanel(node: controller.$selectedNode.value!),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNWidgets(6));

    await tester.tap(find.byType(IconButton).at(0));
    await tester.pump();

    expect(controller.$watchedNodeIds.value, [1]);

    await tester.tap(find.byType(IconButton).at(0));
    await tester.pump();

    expect(controller.$watchedNodeIds.value, isEmpty);

    await tester.tap(find.byTooltip('Add to Watch').last);
    await tester.pump();

    expect(controller.$watchedNodeIds.value, [2]);
  });

  testWidgets('watch toggle hides and shows the left panel', (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);

    await tester.pumpWidget(
      InheritedProvider<JoltInspectorController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                WatchPanelToggleButton(controller: controller),
              ],
            ),
            body: JoltBuilderBody(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byType(WatchListPanel), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Watch'));
    await tester.pumpAndSettle();

    expect(find.byType(WatchListPanel), findsNothing);

    await tester.tap(find.byTooltip('Show Watch'));
    await tester.pumpAndSettle();

    expect(find.byType(WatchListPanel), findsOneWidget);
  });

  testWidgets('watch panel width can be resized', (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    final width = ValueNotifier<double>(280);

    await tester.pumpWidget(
      _wrap(
        controller,
        StatefulBuilder(
          builder: (context, setState) {
            return Row(
              children: [
                WatchListPanel(width: width.value),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      width.value += details.delta.dx;
                    });
                  },
                  child: const SizedBox(width: 6, height: 400),
                ),
                const Expanded(child: SizedBox()),
              ],
            );
          },
        ),
      ),
    );

    expect(_watchPanelWidth(tester), 280);

    await tester.drag(find.byType(GestureDetector), const Offset(40, 0));
    await tester.pump();

    expect(_watchPanelWidth(tester), 320);
  });
}

double _watchPanelWidth(WidgetTester tester) {
  return tester
      .getSize(
        find.descendant(
          of: find.byType(WatchListPanel),
          matching: find.byType(Container).first,
        ),
      )
      .width;
}

Widget _wrap(JoltInspectorController controller, Widget child) {
  return MaterialApp(
    home: InheritedProvider<JoltInspectorController>.value(
      value: controller,
      child: Scaffold(body: child),
    ),
  );
}

class JoltBuilderBody extends StatelessWidget {
  const JoltBuilderBody({super.key, required this.controller});

  final JoltInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return WatchBody(controller: controller);
  }
}

class WatchBody extends StatelessWidget {
  const WatchBody({super.key, required this.controller});

  final JoltInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      return controller.$watchPanelExpanded.value
          ? const WatchListPanel(width: 280)
          : const SizedBox.shrink();
    });
  }
}

JoltNode _node({
  required int id,
  String type = 'Signal',
  required String label,
  dynamic value = 0,
  int? updatedAt,
  int count = 0,
  List<int> dependencies = const [],
  List<int> subscribers = const [],
}) {
  return JoltNode(
    id: id,
    type: type,
    label: label,
    debugType: type,
    isDisposed: false,
    value: value,
    flags: 0,
    valueType: 'int',
    updatedAt: updatedAt,
    count: count,
    dependencies: dependencies,
    subscribers: subscribers,
  );
}
