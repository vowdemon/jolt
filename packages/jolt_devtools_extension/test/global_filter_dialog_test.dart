import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/views/inspector_page.dart';
import 'package:jolt_devtools_extension/src/widgets/nodes_list_panel.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
      'global filter action sits between help and refresh and opens dialog',
      (tester) async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter', debugType: 'store');
    controller.$nodes[2] =
        _node(id: 2, label: 'builder', debugType: 'JoltBuilder');
    controller.$nodes[3] =
        _node(id: 3, label: 'props', debugType: 'SetupProps');

    await tester.pumpWidget(
      MaterialApp(
        home: InheritedProvider<JoltInspectorController>.value(
          value: controller,
          child: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () {},
                  tooltip: 'Search Syntax Help',
                ),
                GlobalFilterButton(controller: controller),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {},
                  tooltip: 'Refresh',
                ),
              ],
            ),
            body: const NodesListPanel(),
          ),
        ),
      ),
    );

    expect(find.text('Matched 1 / 1 nodes'), findsOneWidget);

    final helpX = tester.getCenter(find.byTooltip('Search Syntax Help')).dx;
    final filterX = tester.getCenter(find.byTooltip('Global Filter')).dx;
    final refreshX = tester.getCenter(find.byTooltip('Refresh')).dx;
    expect(helpX < filterX && filterX < refreshX, isTrue);

    await tester.tap(find.byTooltip('Global Filter'));
    await tester.pump();

    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text(defaultGlobalFilterQuery), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(controller.$globalFilterEnabled.value, isFalse);
    expect(find.text('Matched 3 / 3 nodes'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
    );
    expect(field.enabled, isFalse);
  });
}

JoltNode _node({
  required int id,
  String type = 'Signal',
  required String label,
  required String debugType,
}) {
  return JoltNode(
    id: id,
    type: type,
    label: label,
    debugType: debugType,
    isDisposed: false,
    flags: 0,
    valueType: 'int',
  );
}
