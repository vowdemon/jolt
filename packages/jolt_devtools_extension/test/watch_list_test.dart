import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

void main() {
  test('watch list keeps insertion order and ignores duplicates', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');
    controller.$nodes[2] = _node(id: 2, label: 'total');

    controller.addNodeToWatch(1);
    controller.addNodeToWatch(2);
    controller.addNodeToWatch(1);

    expect(controller.$watchedNodeIds.value, [1, 2]);
    expect(controller.watchedNodes.map((node) => node.label), [
      'counter',
      'total',
    ]);
  });

  test('watch list can remove nodes', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');

    controller.addNodeToWatch(1);
    controller.removeNodeFromWatch(1);

    expect(controller.$watchedNodeIds.value, isEmpty);
    expect(controller.watchedNodes, isEmpty);
  });

  test('watch list is independent from top-level and global filters', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] =
        _node(id: 1, label: 'hidden builder', debugType: 'JoltBuilder');
    controller.$nodes[2] = _node(id: 2, label: 'counter');

    controller.addNodeToWatch(1);
    controller.setSearchQuery('label:counter');

    expect(controller.filteredNodes.map((node) => node.id), [2]);
    expect(controller.watchedNodes.map((node) => node.id), [1]);
  });

  test('watch panel collapse keeps watched nodes', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    controller.$nodes[1] = _node(id: 1, label: 'counter');

    controller.addNodeToWatch(1);
    controller.toggleWatchPanel();

    expect(controller.$watchPanelExpanded.value, isFalse);
    expect(controller.$watchedNodeIds.value, [1]);
  });

  test('watch list exposes unavailable nodes', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.addNodeToWatch(99);

    expect(controller.watchedNodes.single.label, 'Unavailable node #99');
    expect(controller.watchedNodes.single.isDisposed, isTrue);
  });
}

JoltNode _node({
  required int id,
  String type = 'Signal',
  required String label,
  String? debugType,
  dynamic value = 0,
  int? updatedAt,
  int count = 0,
}) {
  return JoltNode(
    id: id,
    type: type,
    label: label,
    debugType: debugType ?? type,
    isDisposed: false,
    value: value,
    flags: 0,
    valueType: 'int',
    updatedAt: updatedAt,
    count: count,
  );
}
