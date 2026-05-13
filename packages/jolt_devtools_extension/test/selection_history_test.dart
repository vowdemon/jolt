import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

void main() {
  test('selection history navigates back and forward', () async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');
    controller.$nodes[2] = _node(id: 2, label: 'total');

    await controller.selectNode(1, reason: SelectionReason.listClick);
    await controller.selectNode(2, reason: SelectionReason.depJump);

    expect(controller.$selectedNodeId.value, 2);
    expect(controller.canNavigateBack, isTrue);
    expect(controller.canNavigateForward, isFalse);

    await controller.navigateSelectionBack();

    expect(controller.$selectedNodeId.value, 1);
    expect(controller.canNavigateBack, isFalse);
    expect(controller.canNavigateForward, isTrue);

    await controller.navigateSelectionForward();

    expect(controller.$selectedNodeId.value, 2);
    expect(controller.canNavigateBack, isTrue);
    expect(controller.canNavigateForward, isFalse);
  });

  test('selecting a new node after back clears the forward stack', () async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');
    controller.$nodes[2] = _node(id: 2, label: 'total');
    controller.$nodes[3] = _node(id: 3, label: 'effect', type: 'Effect');

    await controller.selectNode(1);
    await controller.selectNode(2);
    await controller.navigateSelectionBack();
    await controller.selectNode(3);

    expect(controller.$selectedNodeId.value, 3);
    expect(controller.selectionHistory, [1, 3]);
    expect(controller.canNavigateBack, isTrue);
    expect(controller.canNavigateForward, isFalse);
  });

  test('selecting the current node does not duplicate history entries',
      () async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');

    await controller.selectNode(1);
    await controller.selectNode(1);

    expect(controller.selectionHistory, [1]);
    expect(controller.canNavigateBack, isFalse);
    expect(controller.canNavigateForward, isFalse);
  });

  test('selection history keeps the latest fifty entries', () async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    for (var id = 1; id <= 51; id++) {
      controller.$nodes[id] = _node(id: id, label: 'node $id');
      await controller.selectNode(id);
    }

    expect(controller.selectionHistoryLength, maxSelectionHistoryLength);
    expect(controller.selectionHistory.first, 2);
    expect(controller.selectionHistory.last, 51);
    expect(controller.$selectedNodeId.value, 51);
  });

  test('history can restore an unavailable node detail', () async {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');

    await controller.selectNode(1);
    await controller.selectNode(99);

    expect(controller.$selectedNodeId.value, 99);
    expect(controller.$selectedNode.value?.label, 'Unavailable node #99');
    expect(controller.$selectedNode.value?.isDisposed, isTrue);
    expect(controller.canNavigateBack, isTrue);
  });
}

JoltNode _node({
  required int id,
  String type = 'Signal',
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
