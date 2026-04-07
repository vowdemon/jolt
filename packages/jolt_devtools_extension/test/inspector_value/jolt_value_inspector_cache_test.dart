import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_inspector_service.dart';

void main() {
  group('JoltValueInspectorService cache lifecycle', () {
    test('reuses cached root inspection until invalidated', () async {
      final service = _FakeCachingInspectorService();
      final path = const JoltValuePath.root(nodeId: 1);

      final first = await service.inspect(path);
      final second = await service.inspect(path);

      expect(first.displayValue, 'load-1');
      expect(second.displayValue, 'load-1');
      expect(service.inspectCount, 1);

      service.invalidateNode(1);

      final third = await service.inspect(path);
      expect(third.displayValue, 'load-2');
      expect(service.inspectCount, 2);
    });

    test('marks cached root unavailable after dispose', () async {
      final service = _FakeCachingInspectorService();
      final path = const JoltValuePath.root(nodeId: 2);

      await service.inspect(path);
      service.markNodeUnavailable(2, reason: 'disposed');

      final disposed = await service.inspect(path);

      expect(disposed.state, JoltInspectedValueState.unavailable);
      expect(disposed.displayValue, contains('disposed'));
    });

    test('clears all caches on reconnect or isolate change', () async {
      final service = _FakeCachingInspectorService();
      final path = const JoltValuePath.root(nodeId: 3);

      await service.inspect(path);
      service.clearCaches();
      await service.inspect(path);

      expect(service.inspectCount, 2);
    });
  });
}

class _FakeCachingInspectorService extends JoltValueInspectorService {
  int inspectCount = 0;

  @override
  Future<JoltInspectedValue> loadValue(JoltValuePath path) async {
    inspectCount++;
    return JoltInspectedValue(
      kind: JoltInspectedValueKind.object,
      state: JoltInspectedValueState.available,
      displayValue: 'load-$inspectCount',
      isExpandable: true,
    );
  }
}
