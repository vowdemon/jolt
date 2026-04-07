import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_inspector_policy.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_child.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_inspector_service.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('JoltValueInspectorService', () {
    final service = JoltValueInspectorService.test();

    test('normalizes primitive and collection instance refs', () {
      final stringValue = service.inspectVmValue(
        InstanceRef(
          id: 'objects/1',
          kind: InstanceKind.kString,
          valueAsString: 'hello',
          length: 5,
          classRef: ClassRef(id: 'classes/1', name: 'String'),
        ),
      );
      final listValue = service.inspectVmValue(
        InstanceRef(
          id: 'objects/2',
          kind: InstanceKind.kList,
          length: 3,
          classRef: ClassRef(id: 'classes/2', name: 'List<int>'),
        ),
      );

      expect(stringValue.kind, JoltInspectedValueKind.string);
      expect(stringValue.displayValue, '"hello"');
      expect(listValue.kind, JoltInspectedValueKind.list);
      expect(listValue.length, 3);
      expect(listValue.isExpandable, isTrue);
    });

    test('normalizes enum instances to type and member display', () {
      final enumValue = service.inspectVmValue(
        Instance(
          id: 'objects/enum-1',
          kind: InstanceKind.kPlainInstance,
          classRef: ClassRef(id: 'classes/enum-1', name: 'SampleStatus'),
          fields: [
            BoundField(
              name: '_name',
              value: InstanceRef(
                id: 'objects/string-1',
                kind: InstanceKind.kString,
                valueAsString: 'idle',
                classRef: ClassRef(id: 'classes/string', name: 'String'),
              ),
            ),
          ],
        ),
      );

      expect(enumValue.kind, JoltInspectedValueKind.enumeration);
      expect(enumValue.displayValue, 'SampleStatus.idle');
      expect(enumValue.typeName, 'SampleStatus');
    });

    test('normalizes sentinel and error states', () {
      final unavailable = service.inspectVmValue(
        Sentinel(
          kind: SentinelKind.kCollected,
          valueAsString: 'Collected',
        ),
      );
      final error = service.inspectVmError('boom');

      expect(unavailable.state, JoltInspectedValueState.unavailable);
      expect(error.state, JoltInspectedValueState.error);
      expect(error.displayValue, contains('boom'));
    });

    test('builds stable object field metadata from owner class', () {
      final fields = service.buildObjectFields(
        ownerClass: ClassRef(
          id: 'classes/3',
          name: 'Counter',
          library: LibraryRef(
            id: 'libraries/1',
            uri: 'package:app/counter.dart',
            name: 'counter',
          ),
        ),
        fields: [
          BoundField(
            name: '_value',
            value: InstanceRef(
              id: 'objects/4',
              kind: InstanceKind.kInt,
              valueAsString: '1',
              classRef: ClassRef(id: 'classes/4', name: 'int'),
            ),
          ),
        ],
        getterNames: const ['total'],
      );

      expect(
        fields.first,
        JoltObjectField(
          name: '_value',
          ownerName: 'Counter',
          ownerUri: 'package:app/counter.dart',
        ),
      );
      expect(
        fields.last,
        JoltObjectField(
          name: 'total',
          ownerName: 'Counter',
          ownerUri: 'package:app/counter.dart',
          isGetter: true,
        ),
      );
    });

    test('builds child paths for list map and object values', () {
      final root = JoltValuePath.root(nodeId: 11);
      final field = JoltObjectField(
        name: 'items',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
      );

      expect(
        service.childPathForField(root, field),
        root.childField(field),
      );
      expect(
        service.childPathForIndex(root, 2),
        root.childIndex(2),
      );
      expect(
        service.childPathForMapValue(
          root,
          const JoltMapEntryIdentity.primitive('theme'),
        ),
        root.childMapValue(const JoltMapEntryIdentity.primitive('theme')),
      );
      expect(
        service.childPathForRange(root, 0, 100),
        root.childRange(0, 100),
      );
    });

    test('builds grouped range children for large enumerable collections', () {
      final root = JoltValuePath.root(nodeId: 42);

      final children = service.buildRangeChildren(
        path: root,
        objectId: 'objects/42',
        start: 0,
        end: 1000,
      );

      expect(children, hasLength(10));
      expect(children.first.kind, JoltValueChildKind.range);
      expect(children.first.label, '[0..99]');
      expect(children.first.path, root.childRange(0, 100));
      expect(children.first.value.kind, JoltInspectedValueKind.range);
      expect(children.first.value.isExpandable, isTrue);
      expect(children.last.label, '[900..999]');
      expect(children.last.path, root.childRange(900, 1000));
    });

    test('uses recursive bucket sizing for extra large collections', () {
      expect(service.calculateRangeSize(50), 50);
      expect(service.calculateRangeSize(100), 100);
      expect(service.calculateRangeSize(1000), 100);
      expect(service.calculateRangeSize(1000000), 10000);
    });

    test('filters private members and getters independently', () {
      final root = JoltValuePath.root(nodeId: 11);
      final publicField = JoltObjectField(
        name: 'count',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
      );
      final publicGetter = JoltObjectField(
        name: 'total',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
        isGetter: true,
      );
      final hashCodeGetter = JoltObjectField(
        name: 'hashCode',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
        isGetter: true,
      );
      final runtimeTypeGetter = JoltObjectField(
        name: 'runtimeType',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
        isGetter: true,
      );
      final privateGetter = JoltObjectField(
        name: '_hiddenTotal',
        ownerName: 'Counter',
        ownerUri: 'package:app/counter.dart',
        isGetter: true,
        isPrivate: true,
      );
      final rows = [
        JoltValueChild.field(
          label: 'count',
          path: root.childField(publicField),
          value: const JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '1',
          ),
          field: publicField,
        ),
        JoltValueChild.field(
          label: 'total',
          path: root.childField(publicGetter),
          value: const JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '3',
          ),
          field: publicGetter,
        ),
        JoltValueChild.field(
          label: 'hashCode',
          path: root.childField(hashCodeGetter),
          value: const JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '123',
          ),
          field: hashCodeGetter,
        ),
        JoltValueChild.field(
          label: 'runtimeType',
          path: root.childField(runtimeTypeGetter),
          value: const JoltInspectedValue(
            kind: JoltInspectedValueKind.string,
            state: JoltInspectedValueState.available,
            displayValue: '"Counter"',
          ),
          field: runtimeTypeGetter,
        ),
        JoltValueChild.field(
          label: '_hiddenTotal',
          path: root.childField(privateGetter),
          value: const JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '7',
          ),
          field: privateGetter,
        ),
      ];

      expect(service.filterChildren(rows).map((row) => row.label), ['count']);
      expect(
        service
            .filterChildren(
              rows,
              policy: const JoltValueInspectorPolicy(showGetters: true),
            )
            .map((row) => row.label),
        ['count', 'total'],
      );
      expect(
        service
            .filterChildren(
              rows,
              policy: const JoltValueInspectorPolicy(
                showHashCodeAndRuntimeType: true,
                showGetters: true,
              ),
            )
            .map((row) => row.label),
        ['count', 'total', 'hashCode', 'runtimeType'],
      );
      expect(
        service
            .filterChildren(
              rows,
              policy: const JoltValueInspectorPolicy(
                showPrivateMembers: true,
                showGetters: true,
                showHashCodeAndRuntimeType: true,
              ),
            )
            .map((row) => row.label),
        ['count', 'total', 'hashCode', 'runtimeType', '_hiddenTotal'],
      );
    });
  });
}
