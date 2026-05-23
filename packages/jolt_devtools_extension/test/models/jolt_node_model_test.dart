import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/models/jolt_debug.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

void main() {
  group('JoltNode models', () {
    test('parse raw node snapshot payload', () {
      final json = {
        'id': 1,
        'nodeType': 'Computed',
        'label': 'total',
        'type': 'ComputedNode<int>',
        'flags': 3,
        'isDisposed': false,
        'value': 42,
        'valueType': 'int',
        'dependencies': [2],
        'subscribers': [3],
        'createdAt': 100,
        'updatedAt': 120,
        'count': 4,
      };

      final debugNode = JoltDebugNode.fromJson(json);
      final node = JoltNode.fromJson(json);

      expect(debugNode.type, equals('Computed'));
      expect(debugNode.debugType, equals('ComputedNode<int>'));
      expect(debugNode.dependencies, equals([2]));
      expect(debugNode.subscribers, equals([3]));

      expect(node.type, equals('Computed'));
      expect(node.debugType, equals('ComputedNode<int>'));
      expect(node.value.value, equals(42));
      expect(node.dependencies.value, equals([2]));
      expect(node.subscribers.value, equals([3]));
      expect(node.count.value, equals(4));
    });

    test('parse node update payload without link fields', () {
      final update = NodeUpdate.fromJson({
        'nodeId': 1,
        'operation': 'set',
        'value': 2,
        'valueType': 'int',
        'count': 1,
        'timestamp': 100,
      });

      expect(update.nodeId, equals(1));
      expect(update.operation, equals('set'));
      expect(update.value, equals(2));
      expect(update.valueType, equals('int'));
      expect(update.count, equals(1));
      expect(update.timestamp, equals(100));
    });

    test('parse link update payload for dependency graph updates', () {
      final update = NodeUpdate.fromJson({
        'operation': 'link',
        'depId': 1,
        'subId': 2,
        'timestamp': 100,
      });

      expect(update.operation, equals('link'));
      expect(update.depId, equals(1));
      expect(update.subId, equals(2));
      expect(update.timestamp, equals(100));
    });
  });
}
