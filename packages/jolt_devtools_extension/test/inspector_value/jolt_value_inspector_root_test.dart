import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_inspector_policy.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_child.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_inspector_service.dart';
import 'package:jolt_devtools_extension/src/inspector_value/widgets/jolt_value_inspector_root.dart';
import 'package:jolt_devtools_extension/src/inspector_value/widgets/jolt_value_row.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

void main() {
  group('JoltValueInspectorRoot', () {
    testWidgets('root is expanded by default and hides getters by default',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Counter'), findsWidgets);
      expect(find.text('count'), findsOneWidget);
      expect(find.text('items'), findsOneWidget);
      expect(find.text('profile'), findsNothing);
      expect(find.text('total'), findsNothing);
      expect(find.text('hashCode'), findsNothing);
      expect(find.text('runtimeType'), findsNothing);
      expect(find.text('_hiddenTotal'), findsNothing);
      expect(find.text('get'), findsNothing);
      expect(find.textContaining('#c0ffee'), findsOneWidget);
    });

    testWidgets('refresh keeps expanded child paths', (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('items'));
      await tester.pumpAndSettle();
      expect(find.text('[0]'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh VM value'));
      await tester.pumpAndSettle();

      expect(find.text('[0]'), findsOneWidget);
      expect(service.refreshCount, 1);
    });

    testWidgets(
        'field rows reveal refresh action on hover but index rows do not',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final countRow = find.ancestor(
        of: find.text('count'),
        matching: find.byType(JoltValueRow),
      );
      expect(find.byTooltip('Refresh value'), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final countRowCenter = tester.getCenter(countRow);
      await mouse.addPointer(location: countRowCenter);
      await mouse.moveTo(countRowCenter);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: countRow, matching: find.byTooltip('Refresh value')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
            of: countRow, matching: find.byTooltip('Refresh value')),
      );
      await tester.pumpAndSettle();

      expect(service.refreshCount, 1);

      await tester.tap(find.text('items'));
      await tester.pumpAndSettle();

      final indexRow = find.ancestor(
        of: find.text('[0]'),
        matching: find.byType(JoltValueRow),
      );
      final indexRowCenter = tester.getCenter(indexRow);
      await mouse.moveTo(indexRowCenter);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: indexRow, matching: find.byTooltip('Refresh value')),
        findsNothing,
      );
    });

    testWidgets('policy toggles private members and getters independently',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('count'), findsOneWidget);
      expect(find.text('profile'), findsNothing);
      expect(find.text('total'), findsNothing);
      expect(find.text('_internalState'), findsNothing);
      expect(find.text('_hiddenTotal'), findsNothing);

      await tester.tap(find.text('Getter'));
      await tester.pumpAndSettle();
      expect(find.text('profile'), findsOneWidget);
      expect(find.text('total'), findsOneWidget);
      expect(find.text('hashCode'), findsNothing);
      expect(find.text('runtimeType'), findsNothing);
      expect(find.text('_hiddenTotal'), findsNothing);
      expect(find.text('get'), findsWidgets);
      expect(find.textContaining('#baddad'), findsOneWidget);

      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();
      expect(find.text('_internalState'), findsOneWidget);
      expect(find.text('_hiddenTotal'), findsOneWidget);
    });

    testWidgets('policy toggles hashCode and runtimeType getter visibility',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Getter'));
      await tester.pumpAndSettle();

      expect(find.text('profile'), findsOneWidget);
      expect(find.text('hashCode'), findsNothing);
      expect(find.text('runtimeType'), findsNothing);

      await tester.tap(find.text('Object'));
      await tester.pumpAndSettle();

      expect(find.text('profile'), findsOneWidget);
      expect(find.text('hashCode'), findsOneWidget);
      expect(find.text('runtimeType'), findsOneWidget);
    });

    testWidgets('policy toggles object properties independently',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('#c0ffee'), findsOneWidget);

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();

      expect(find.textContaining('#c0ffee'), findsNothing);
    });

    testWidgets('renders local stale leaf error without crashing tree',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('brokenLeaf'));
      await tester.pumpAndSettle();

      expect(find.textContaining('stale'), findsWidgets);
      expect(find.text('count'), findsOneWidget);
    });

    testWidgets('reactively reloads inspected values after node updates',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);

      service.setCountValue(2);
      service.invalidateNode(node.id);
      node.value.value = 2;
      node.updatedAt.value = 2;

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(service.rootLoadCount, greaterThanOrEqualTo(2));
    });

    testWidgets('silent refresh does not show loading after first load',
        (tester) async {
      final service = _FakeTreeInspectorService()
        ..delaySubsequentReloads = true;
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      service.setCountValue(3);
      service.invalidateNode(node.id);
      node.value.value = 3;
      node.updatedAt.value = 3;

      await tester.pump();

      expect(find.text('Loading...'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('refresh falls back to parent when expanded leaf turns stale',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('brokenLeaf'));
      await tester.pumpAndSettle();
      expect(find.textContaining('stale'), findsWidgets);

      service.invalidateNode(node.id);
      node.value.value = 2;
      node.updatedAt.value = 2;

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('brokenLeaf'), findsOneWidget);
      expect(find.textContaining('stale'), findsNothing);
    });

    testWidgets(
        'refreshes expanded grandchild path even when root display is unchanged',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('nested'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('child'));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);

      service.setGrandchildValue(42);
      service.invalidateNode(node.id);
      node.value.value = 1;
      node.updatedAt.value = 2;

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets(
        'root value updates immediately even when child refresh is slow',
        (tester) async {
      final service = _FakeTreeInspectorService()
        ..delaySubsequentReloads = true
        ..setRootDisplayValue('Counter');
      final node = _buildReadableNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: node,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Counter'), findsWidgets);

      service.setRootDisplayValue('Counter v2');
      service.setCountValue(9);
      service.invalidateNode(node.id);
      node.value.value = 9;
      node.updatedAt.value = 9;

      await tester.pump();
      await tester.pump();

      expect(find.text('Counter v2'), findsWidgets);
      expect(find.text('9'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('9'), findsOneWidget);
    });

    testWidgets(
        'rebinding to a second selected node keeps auto refresh working',
        (tester) async {
      final service = _FakeTreeInspectorService();
      final firstNode = _buildReadableNode(id: 1, label: 'counterA');
      final secondNode = _buildReadableNode(id: 2, label: 'counterB');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: firstNode,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      service.setRootDisplayValueForNode(2, 'Counter B');
      service.setCountValueForNode(2, 7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoltValueInspectorRoot(
              node: secondNode,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Counter B'), findsWidgets);
      expect(find.text('7'), findsOneWidget);

      service.setRootDisplayValueForNode(2, 'Counter B v2');
      service.setCountValueForNode(2, 8);
      service.invalidateNode(secondNode.id);
      secondNode.value.value = 8;
      secondNode.updatedAt.value = 8;

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Counter B v2'), findsWidgets);
      expect(find.text('8'), findsOneWidget);
    });
  });
}

class _FakeTreeInspectorService extends JoltValueInspectorService {
  int refreshCount = 0;
  int rootLoadCount = 0;
  int countValue = 1;
  int grandchildValue = 10;
  bool delaySubsequentReloads = false;
  String rootDisplayValue = 'Counter';
  final Map<int, int> countValuesByNode = {1: 1};
  final Map<int, String> rootDisplayByNode = {1: 'Counter'};

  void setCountValue(int next) {
    countValue = next;
    countValuesByNode[1] = next;
  }

  void setGrandchildValue(int next) {
    grandchildValue = next;
  }

  void setRootDisplayValue(String next) {
    rootDisplayValue = next;
    rootDisplayByNode[1] = next;
  }

  void setCountValueForNode(int nodeId, int next) {
    countValuesByNode[nodeId] = next;
  }

  void setRootDisplayValueForNode(int nodeId, String next) {
    rootDisplayByNode[nodeId] = next;
  }

  Future<void> _maybeDelayReload() async {
    if (!delaySubsequentReloads || rootLoadCount < 2) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  @override
  Future<JoltInspectedValue> loadValue(JoltValuePath path) async {
    final rootPath = JoltValuePath.root(nodeId: path.nodeId);
    if (path == rootPath) {
      rootLoadCount++;
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.object,
        state: JoltInspectedValueState.available,
        displayValue: rootDisplayByNode[path.nodeId] ?? rootDisplayValue,
        typeName: 'Counter',
        isExpandable: true,
        hashCodeDisplay: 'c0ffee',
      );
    }
    if (path == rootPath.childField(_itemsField)) {
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.list,
        state: JoltInspectedValueState.available,
        displayValue: 'List(2)',
        typeName: 'List<int>',
        isExpandable: true,
        length: 2,
      );
    }
    if (path == rootPath.childField(_brokenField)) {
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.object,
        state: JoltInspectedValueState.available,
        displayValue: 'BrokenLeaf',
        isExpandable: true,
      );
    }
    if (path == rootPath.childField(_nestedField)) {
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.object,
        state: JoltInspectedValueState.available,
        displayValue: 'NestedState',
        typeName: 'NestedState',
        isExpandable: true,
      );
    }
    if (path == rootPath.childField(_nestedField).childField(_childField)) {
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.object,
        state: JoltInspectedValueState.available,
        displayValue: 'NestedChild',
        typeName: 'NestedChild',
        isExpandable: true,
      );
    }
    if (path ==
        rootPath
            .childField(_nestedField)
            .childField(_childField)
            .childField(_grandchildValueField)) {
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.number,
        state: JoltInspectedValueState.available,
        displayValue: '$grandchildValue',
        typeName: 'int',
      );
    }
    if (path == rootPath.childField(_brokenField).childIndex(0)) {
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.error,
        state: JoltInspectedValueState.stale,
        displayValue: '<stale: object reference expired>',
      );
    }
    return JoltInspectedValue(
      kind: JoltInspectedValueKind.number,
      state: JoltInspectedValueState.available,
      displayValue: '1',
      typeName: 'int',
    );
  }

  @override
  Future<List<JoltValueChild>> loadChildren(
    JoltValuePath path, {
    JoltValueInspectorPolicy policy = const JoltValueInspectorPolicy(),
  }) async {
    await _maybeDelayReload();
    final rootPath = JoltValuePath.root(nodeId: path.nodeId);
    if (path == rootPath) {
      final rows = [
        JoltValueChild.field(
          label: 'count',
          path: rootPath.childField(_countField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '${countValuesByNode[path.nodeId] ?? countValue}',
            typeName: 'int',
          ),
          field: _countField,
        ),
        JoltValueChild.field(
          label: 'items',
          path: rootPath.childField(_itemsField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.list,
            state: JoltInspectedValueState.available,
            displayValue: 'List(2)',
            typeName: 'List<int>',
            isExpandable: true,
            length: 2,
          ),
          field: _itemsField,
        ),
        JoltValueChild.field(
          label: 'nested',
          path: rootPath.childField(_nestedField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.object,
            state: JoltInspectedValueState.available,
            displayValue: 'NestedState',
            typeName: 'NestedState',
            isExpandable: true,
          ),
          field: _nestedField,
        ),
        JoltValueChild.field(
          label: 'profile',
          path: rootPath.childField(_profileField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.object,
            state: JoltInspectedValueState.available,
            displayValue: 'Profile(name: Nova)',
            typeName: 'Profile',
            hashCodeDisplay: 'baddad',
            isExpandable: true,
          ),
          field: _profileField,
        ),
        JoltValueChild.field(
          label: 'hashCode',
          path: rootPath.childField(_hashCodeField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '12648430',
            typeName: 'int',
          ),
          field: _hashCodeField,
        ),
        JoltValueChild.field(
          label: 'runtimeType',
          path: rootPath.childField(_runtimeTypeField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.string,
            state: JoltInspectedValueState.available,
            displayValue: '"Counter"',
            typeName: 'Type',
          ),
          field: _runtimeTypeField,
        ),
        JoltValueChild.field(
          label: 'total',
          path: rootPath.childField(_totalField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '3',
            typeName: 'int',
          ),
          field: _totalField,
        ),
        JoltValueChild.field(
          label: '_hiddenTotal',
          path: rootPath.childField(_hiddenTotalField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '7',
            typeName: 'int',
          ),
          field: _hiddenTotalField,
        ),
        JoltValueChild.field(
          label: 'brokenLeaf',
          path: rootPath.childField(_brokenField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.object,
            state: JoltInspectedValueState.available,
            displayValue: 'BrokenLeaf',
            isExpandable: true,
          ),
          field: _brokenField,
        ),
        JoltValueChild.field(
          label: '_internalState',
          path: rootPath.childField(_internalField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.string,
            state: JoltInspectedValueState.available,
            displayValue: '"debug"',
            typeName: 'String',
          ),
          field: _internalField,
        ),
        JoltValueChild.field(
          label: '_privateCache',
          path: rootPath.childField(_privateField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.string,
            state: JoltInspectedValueState.available,
            displayValue: '"hidden"',
            typeName: 'String',
          ),
          field: _privateField,
        ),
      ];
      return filterChildren(rows, policy: policy);
    }

    if (path == rootPath.childField(_itemsField)) {
      return [
        JoltValueChild.index(
          label: '[0]',
          path: path.childIndex(0),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '1',
            typeName: 'int',
          ),
          index: 0,
        ),
        JoltValueChild.index(
          label: '[1]',
          path: path.childIndex(1),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '2',
            typeName: 'int',
          ),
          index: 1,
        ),
      ];
    }

    if (path == rootPath.childField(_brokenField)) {
      return [
        JoltValueChild.index(
          label: 'stale',
          path: path.childIndex(0),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.error,
            state: JoltInspectedValueState.stale,
            displayValue: '<stale: object reference expired>',
          ),
          index: 0,
        ),
      ];
    }

    if (path == rootPath.childField(_nestedField)) {
      return [
        JoltValueChild.field(
          label: 'child',
          path: path.childField(_childField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.object,
            state: JoltInspectedValueState.available,
            displayValue: 'NestedChild',
            typeName: 'NestedChild',
            isExpandable: true,
          ),
          field: _childField,
        ),
      ];
    }

    if (path == rootPath.childField(_nestedField).childField(_childField)) {
      return [
        JoltValueChild.field(
          label: 'value',
          path: path.childField(_grandchildValueField),
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.number,
            state: JoltInspectedValueState.available,
            displayValue: '$grandchildValue',
            typeName: 'int',
          ),
          field: _grandchildValueField,
        ),
      ];
    }

    return const [];
  }

  @override
  Future<void> refreshRoot(JoltValuePath path) async {
    refreshCount++;
    invalidateNode(path.nodeId);
  }
}

JoltNode _buildReadableNode({
  int id = 1,
  String label = 'counter',
}) {
  return JoltNode(
    id: id,
    type: 'Signal',
    label: label,
    debugType: 'Counter',
    isDisposed: false,
    value: 1,
    flags: 0,
    valueType: 'int',
    updatedAt: 1,
    count: 0,
  );
}

const _countField = JoltObjectField(
  name: 'count',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
);

const _itemsField = JoltObjectField(
  name: 'items',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
);

const _totalField = JoltObjectField(
  name: 'total',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isGetter: true,
);

const _profileField = JoltObjectField(
  name: 'profile',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isGetter: true,
);

const _nestedField = JoltObjectField(
  name: 'nested',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
);

const _childField = JoltObjectField(
  name: 'child',
  ownerName: 'NestedState',
  ownerUri: 'package:app/counter.dart',
);

const _grandchildValueField = JoltObjectField(
  name: 'value',
  ownerName: 'NestedChild',
  ownerUri: 'package:app/counter.dart',
);

const _hashCodeField = JoltObjectField(
  name: 'hashCode',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isGetter: true,
);

const _runtimeTypeField = JoltObjectField(
  name: 'runtimeType',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isGetter: true,
);

const _hiddenTotalField = JoltObjectField(
  name: '_hiddenTotal',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isGetter: true,
  isPrivate: true,
);

const _brokenField = JoltObjectField(
  name: 'brokenLeaf',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
);

const _internalField = JoltObjectField(
  name: '_internalState',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isPrivate: true,
);

const _privateField = JoltObjectField(
  name: '_privateCache',
  ownerName: 'Counter',
  ownerUri: 'package:app/counter.dart',
  isPrivate: true,
);
