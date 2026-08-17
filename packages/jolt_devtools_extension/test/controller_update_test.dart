import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

void main() {
  test('applies primitive realtime values without treating them as envelopes',
      () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    final node = _node();
    controller.$nodes[node.id] = node;

    expect(
      () => controller.applyUpdate(NodeUpdate(
        nodeId: node.id,
        operation: 'set',
        value: 2,
        valueType: 'int',
        timestamp: 100,
        count: 1,
      )),
      returnsNormally,
    );

    expect(node.value.value, 2);
    expect(node.valueType.value, 'int');
    expect(node.updatedAt.value, 100);
    expect(node.count.value, 1);
  });

  test('preserves user maps containing protocol-like keys', () {
    final controller = JoltInspectorController(initializeConnection: false);
    addTearDown(controller.dispose);
    final node = _node();
    controller.$nodes[node.id] = node;
    final value = <String, Object?>{
      'value': 2,
      'flags': 'user data',
      'dependencies': [99],
    };

    controller.applyUpdate(NodeUpdate(
      nodeId: node.id,
      operation: 'set',
      value: value,
      valueType: '_Map<String, Object?>',
      timestamp: 100,
    ));

    expect(node.value.value, same(value));
    expect(node.flags.value, 0);
    expect(node.dependencies.value, isEmpty);
  });
}

JoltNode _node() => JoltNode(
      id: 1,
      type: 'Signal',
      label: 'counter',
      debugType: 'Signal<int>',
      isDisposed: false,
      value: 0,
      flags: 0,
      valueType: 'int',
    );
