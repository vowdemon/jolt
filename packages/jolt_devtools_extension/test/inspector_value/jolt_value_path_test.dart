import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';

void main() {
  group('JoltValuePath', () {
    test('root paths with same node are equal', () {
      expect(JoltValuePath.root(nodeId: 7), JoltValuePath.root(nodeId: 7));
    });

    test('builds child paths for index and object field', () {
      final root = JoltValuePath.root(nodeId: 7);
      final field = JoltObjectField(
        name: 'value',
        ownerName: 'Signal<int>',
        ownerUri: 'package:jolt/src/core/debug.dart',
      );

      final path = root.childField(field).childIndex(3);

      expect(path.nodeId, 7);
      expect(path.segments, hasLength(2));
      expect(
          path.segments.first,
          const JoltPathSegment.field(
            name: 'value',
            ownerName: 'Signal<int>',
            ownerUri: 'package:jolt/src/core/debug.dart',
          ));
      expect(path.segments.last, const JoltPathSegment.index(3));
    });

    test('builds stable child paths for map entries', () {
      final root = JoltValuePath.root(nodeId: 9);

      final valuePath = root.childMapValue(
        const JoltMapEntryIdentity.primitive('theme'),
      );
      final keyPath = root.childMapKey(
        const JoltMapEntryIdentity.object(
          objectId: 'objects/17',
          fallbackLabel: 'User#17',
        ),
      );

      expect(
        valuePath.segments.single,
        const JoltPathSegment.mapValue(
          identity: JoltMapEntryIdentity.primitive('theme'),
        ),
      );
      expect(
        keyPath.segments.single,
        const JoltPathSegment.mapKey(
          identity: JoltMapEntryIdentity.object(
            objectId: 'objects/17',
            fallbackLabel: 'User#17',
          ),
        ),
      );
    });

    test('builds stable child paths for range groups', () {
      final root = JoltValuePath.root(nodeId: 12);
      final rangePath = root.childRange(100, 200);

      expect(
        rangePath.segments.single,
        const JoltPathSegment.range(start: 100, end: 200),
      );
      expect(rangePath.parent, root);
    });
  });
}
