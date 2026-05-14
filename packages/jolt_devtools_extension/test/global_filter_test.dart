import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

void main() {
  test('default global filter hides regular render nodes', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.$nodes[1] = _node(id: 1, label: 'counter', debugType: 'store');
    controller.$nodes[2] =
        _node(id: 2, label: 'builder', debugType: 'JoltBuilder');
    controller.$nodes[3] =
        _node(id: 3, label: 'props', debugType: 'SetupProps');
    controller.$nodes[4] =
        _node(id: 4, label: 'renderer', debugType: 'SetupRenderer');
    controller.$nodes[5] =
        _node(id: 5, label: 'context', debugType: 'SetupContext');
    controller.$nodes[6] =
        _node(id: 6, label: 'setup action', debugType: 'SetupAction');

    expect(controller.$globalFilterEnabled.value, isTrue);
    expect(controller.globalFilteredNodeCount, 2);
    expect(controller.filteredNodes.map((node) => node.id), [1, 6]);
  });

  test('disabled global filter includes all nodes in the main list', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.$nodes[1] = _node(id: 1, label: 'counter', debugType: 'store');
    controller.$nodes[2] =
        _node(id: 2, label: 'builder', debugType: 'JoltBuilder');

    controller.setGlobalFilterEnabled(false);

    expect(controller.globalFilteredNodeCount, 2);
    expect(controller.filteredNodes.map((node) => node.id), [2, 1]);
  });

  test('top-level filter applies within the global-filtered node set', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.$nodes[1] =
        _node(id: 1, type: 'Signal', label: 'counter', debugType: 'store');
    controller.$nodes[2] = _node(
      id: 2,
      type: 'Signal',
      label: 'builder signal',
      debugType: 'JoltBuilder',
    );
    controller.$nodes[3] =
        _node(id: 3, type: 'Computed', label: 'total', debugType: 'store');

    controller.setSearchQuery('type:Signal');

    expect(controller.globalFilteredNodeCount, 2);
    expect(controller.filteredNodes.map((node) => node.id), [1]);
  });

  test('custom global filter expression is combined with AND', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.$nodes[1] =
        _node(id: 1, type: 'Signal', label: 'counter', debugType: 'store');
    controller.$nodes[2] =
        _node(id: 2, type: 'Signal', label: 'total', debugType: 'store');
    controller.$nodes[3] =
        _node(id: 3, type: 'Computed', label: 'counter', debugType: 'store');

    controller.setGlobalFilterQuery('label:counter');
    controller.setSearchQuery('type:Signal');

    expect(controller.globalFilteredNodeCount, 2);
    expect(controller.filteredNodes.map((node) => node.id), [1]);
  });

  test('count numeric comparison works without colon', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.$nodes[1] =
        _node(id: 1, label: 'cold counter', debugType: 'store', count: 1);
    controller.$nodes[2] =
        _node(id: 2, label: 'hot counter', debugType: 'store', count: 3);

    controller.setSearchQuery('count>=2');

    expect(controller.filteredNodes.map((node) => node.id), [2]);
  });

  test('relation inner numeric comparison matches related nodes', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);

    controller.$nodes[1] = _node(
      id: 1,
      label: 'source',
      debugType: 'store',
      dependencies: [2],
    );
    controller.$nodes[2] =
        _node(id: 2, label: 'dependency', debugType: 'store', count: 3);
    controller.$nodes[3] = _node(
      id: 3,
      label: 'quiet source',
      debugType: 'store',
      dependencies: [4],
    );
    controller.$nodes[4] =
        _node(id: 4, label: 'quiet dependency', debugType: 'store', count: 1);

    controller.setSearchQuery('dep:{count>=2}');

    expect(controller.filteredNodes.map((node) => node.id), [1]);
  });
}

JoltNode _node({
  required int id,
  String type = 'Signal',
  required String label,
  required String debugType,
  List<int> dependencies = const [],
  int count = 0,
}) {
  return JoltNode(
    id: id,
    type: type,
    label: label,
    debugType: debugType,
    isDisposed: false,
    flags: 0,
    valueType: 'int',
    dependencies: dependencies,
    count: count,
  );
}
