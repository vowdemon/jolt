import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/widgets/node_details_panel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('details panel exposes back and forward navigation controls',
      (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');
    controller.$nodes[2] = _node(id: 2, label: 'total');

    await controller.selectNode(1);
    await controller.selectNode(2);

    await tester.pumpWidget(
      MaterialApp(
        home: InheritedProvider<JoltInspectorController>.value(
          value: controller,
          child: Scaffold(
            body: NodeDetailsPanel(node: controller.$selectedNode.value!),
          ),
        ),
      ),
    );

    expect(_iconButton(tester, Icons.arrow_back).onPressed, isNotNull);
    expect(_iconButton(tester, Icons.arrow_forward).onPressed, isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(controller.$selectedNodeId.value, 1);
    expect(_iconButton(tester, Icons.arrow_back).onPressed, isNull);
    expect(_iconButton(tester, Icons.arrow_forward).onPressed, isNotNull);
  });
}

IconButton _iconButton(WidgetTester tester, IconData icon) {
  return tester.widget<IconButton>(
    find.widgetWithIcon(IconButton, icon),
  );
}

JoltNode _node({
  required int id,
  String type = 'State',
  required String label,
}) {
  return JoltNode(
    id: id,
    type: type,
    label: label,
    debugType: type,
    isDisposed: false,
    flags: 0,
    valueType: 'int',
  );
}
