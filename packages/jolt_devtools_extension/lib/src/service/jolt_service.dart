import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:devtools_app_shared/service.dart';
import 'package:jolt_devtools_extension/src/models/jolt_debug.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';

import 'package:vm_service/vm_service.dart';

/// Client for communicating with Jolt's VM Service extensions.
class JoltService {
  final ServiceManager<Object?> serviceManager;
  static const _debugLibraryUriSuffix = 'jolt/src/core/debug.dart';
  static const _maxCollectionPreview = 20;

  String? _debugLibraryId;
  String? _debugLibraryIsolateId;

  JoltService(this.serviceManager);

  /// Gets the VM service, throwing if not connected.
  VmService get _service {
    final service = serviceManager.service;
    if (service == null) {
      throw StateError('Not connected to VM service');
    }
    return service as VmService;
  }

  /// Gets the selected isolate ID, or the main isolate if none selected.
  Future<String?> _getIsolateId() async {
    try {
      // 尝试从 isolateManager 获取选中的 isolate
      final isolateRef = serviceManager.isolateManager.selectedIsolate.value;
      if (isolateRef != null) {
        developer
            .log('[Jolt Service] Using selected isolate: ${isolateRef.id}');
        return isolateRef.id;
      }

      // 如果没有选中，获取第一个可用的 isolate
      final vm = await _service.getVM();
      final isolateId = vm.isolates?.firstOrNull?.id;
      if (isolateId != null) {
        developer
            .log('[Jolt Service] Using first available isolate: $isolateId');
      }
      return isolateId;
    } catch (e) {
      developer.log('[Jolt Service] Error getting isolate ID: $e');
      return null;
    }
  }

  /// Gets all reactive nodes from the connected app.
  Future<List<JoltDebugNode>> getNodes() async {
    if (serviceManager.service == null) {
      return [];
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        developer.log('[Jolt Service] No isolate available for getNodes');
        return [];
      }

      final response = await _service.callServiceExtension(
        'ext.jolt.getNodes',
        isolateId: isolateId,
      );

      final data = response.json;
      if (data is! Map<String, dynamic>) return [];

      return (data['nodes'] as List)
          .map((n) => JoltDebugNode.fromJson(n as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error getting nodes: $e');
      return [];
    }
  }

  /// Gets the creation stack for a specific node (with LRU cache).
  Future<String?> getCreationStack(int nodeId) async {
    if (serviceManager.service == null) {
      return null;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        developer
            .log('[Jolt Service] No isolate available for getCreationStack');
        return null;
      }

      final response = await _service.callServiceExtension(
        'ext.jolt.getNodeDetails',
        isolateId: isolateId,
        args: {'nodeId': nodeId.toString()},
      );

      final data = response.json;
      if (data is! Map<String, dynamic>) {
        return null;
      }

      if (data.containsKey('error')) {
        developer.log('Error getting creation stack: ${data['error']}');
        return null;
      }

      final details = JoltDebugNodeDetails.fromJson(data);
      final creationStack = details.creationStack;

      return creationStack;
    } catch (e) {
      developer.log('Error getting creation stack: $e');
      return null;
    }
  }

  /// Gets the real VM value for a readable node as a tree.
  Future<VmValueState> getVmValueTree(int nodeId) async {
    if (serviceManager.service == null) {
      return const VmValueState.error('Not connected to VM service');
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        return const VmValueState.error('No isolate available');
      }

      final libraryId = await _getDebugLibraryId(isolateId);
      if (libraryId == null) {
        return const VmValueState.error('Jolt debug library not found');
      }

      final response = await _service.evaluate(
        isolateId,
        libraryId,
        'debugNodes[$nodeId]?.target?.pendingValue',
        disableBreakpoints: true,
      );

      if (response is ErrorRef) {
        return VmValueState.error(response.message ?? 'VM evaluation error');
      }
      if (response is Sentinel) {
        return VmValueState.error(
            response.valueAsString ?? 'VM value unavailable');
      }
      if (response is! InstanceRef && response is! Instance) {
        return const VmValueState.error('Unexpected VM response');
      }

      final root = await _buildNodeFromResponse(
        response,
        label: 'Value',
        key: 'root:$nodeId',
        isolateId: isolateId,
        loadChildren: true,
      );
      return VmValueState.success(root);
    } catch (e) {
      return VmValueState.error('VM value error: $e');
    }
  }

  Future<List<VmValueNode>> getVmChildren(VmValueNode node) async {
    final isolateId = await _getIsolateId();
    if (isolateId == null) {
      return const [];
    }
    final objectId = node.objectId;
    if (objectId == null) {
      return const [];
    }

    final Obj obj = await _getObjectForNode(isolateId, node);
    if (obj is! Instance) {
      return const [];
    }
    return await _buildChildrenFromInstance(obj, isolateId, node.key);
  }

  /// Sets the value of a Signal node.
  Future<bool> setSignalValue(int nodeId, String value) async {
    if (serviceManager.service == null) {
      return false;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        developer.log('[Jolt Service] No isolate available for setSignalValue');
        return false;
      }

      await _service.callServiceExtension(
        'ext.jolt.setSignalValue',
        isolateId: isolateId,
        args: {
          'nodeId': nodeId.toString(),
          'value': value,
        },
      );
      return true;
    } catch (e) {
      developer.log('Error setting signal value: $e');
      return false;
    }
  }

  /// Manually triggers an Effect node to execute.
  Future<bool> triggerEffect(int nodeId) async {
    if (serviceManager.service == null) {
      return false;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        developer.log('[Jolt Service] No isolate available for triggerEffect');
        return false;
      }

      await _service.callServiceExtension(
        'ext.jolt.triggerEffect',
        isolateId: isolateId,
        args: {'nodeId': nodeId.toString()},
      );
      return true;
    } catch (e) {
      developer.log('Error triggering effect: $e');
      return false;
    }
  }

  /// Starts streaming real-time node updates.
  Future<void> startStreaming() async {
    if (serviceManager.service == null) {
      return;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        developer.log('[Jolt Service] No isolate available for startStreaming');
        return;
      }

      await _service.callServiceExtension(
        'ext.jolt.streamUpdates',
        isolateId: isolateId,
      );
    } catch (e) {
      developer.log('Error starting stream: $e');
    }
  }

  /// Stream of real-time node updates.
  ///
  /// You must call [startStreaming] first to activate the stream.
  Stream<NodeUpdate> get updates {
    if (serviceManager.service == null) {
      return const Stream.empty();
    }

    // Listen to Event stream (not ExtensionEvent) for developer.postEvent
    return _service.onEvent('Extension').where((event) {
      return event.extensionKind == 'jolt.nodeUpdate';
    }).map((event) {
      try {
        final data = event.extensionData?.data;
        if (data is! Map<String, dynamic>) {
          throw Exception('Invalid event data type: ${data.runtimeType}');
        }
        return NodeUpdate.fromJson(data);
      } catch (e) {
        developer.log('Error parsing node update: $e, event: $event');
        rethrow;
      }
    });
  }

  Future<String?> _getDebugLibraryId(String isolateId) async {
    if (_debugLibraryId != null && _debugLibraryIsolateId == isolateId) {
      return _debugLibraryId;
    }

    final isolate = await _service.getIsolate(isolateId);
    final libraries = isolate.libraries;
    if (libraries == null) {
      return null;
    }

    for (final library in libraries) {
      final uri = library.uri;
      if (uri != null && uri.endsWith(_debugLibraryUriSuffix)) {
        _debugLibraryId = library.id;
        _debugLibraryIsolateId = isolateId;
        return _debugLibraryId;
      }
    }

    return null;
  }

  Future<VmValueNode> _buildNodeFromResponse(
    Response response, {
    required String label,
    required String key,
    required String isolateId,
    bool loadChildren = false,
  }) async {
    if (response is ErrorRef) {
      return VmValueNode(
        key: key,
        label: label,
        display: '<error: ${response.message ?? 'unknown'}>',
      );
    }
    if (response is Sentinel) {
      return VmValueNode(
        key: key,
        label: label,
        display: '<${response.valueAsString ?? response.kind ?? 'sentinel'}>',
      );
    }
    if (response is Instance) {
      return await _buildNodeFromInstance(
        response,
        label: label,
        key: key,
        isolateId: isolateId,
        loadChildren: loadChildren,
      );
    }
    if (response is InstanceRef) {
      return await _buildNodeFromInstanceRef(
        response,
        label: label,
        key: key,
        isolateId: isolateId,
        loadChildren: loadChildren,
      );
    }

    return VmValueNode(
      key: key,
      label: label,
      display: response.toString(),
    );
  }

  Future<VmValueNode> _buildNodeFromInstanceRef(
    InstanceRef ref, {
    required String label,
    required String key,
    required String isolateId,
    bool loadChildren = false,
  }) async {
    final kind = ref.kind;
    final className = ref.classRef?.name;
    if (_isPrimitiveKind(kind)) {
      return VmValueNode(
        key: key,
        label: label,
        display: _formatPrimitiveDisplay(ref.valueAsString, kind),
        type: ref.classRef?.name ?? kind,
        kind: kind,
      );
    }

    final canExpand = ref.id != null && !_isNonExpandableKind(kind, className);
    if (loadChildren && canExpand) {
      final obj = await _getObjectForRef(isolateId, ref);
      if (obj is Instance) {
        return await _buildNodeFromInstance(
          obj,
          label: label,
          key: key,
          isolateId: isolateId,
          loadChildren: true,
        );
      }
    }

    return VmValueNode(
      key: key,
      label: label,
      display: _formatSummaryForRef(ref),
      type: ref.classRef?.name ?? kind,
      kind: kind,
      objectId: ref.id,
      isExpandable: canExpand,
    );
  }

  Future<VmValueNode> _buildNodeFromInstance(
    Instance instance, {
    required String label,
    required String key,
    required String isolateId,
    bool loadChildren = false,
  }) async {
    final kind = instance.kind;
    final className = instance.classRef?.name;
    if (_isPrimitiveKind(kind)) {
      return VmValueNode(
        key: key,
        label: label,
        display: _formatPrimitiveDisplay(instance.valueAsString, kind),
        type: instance.classRef?.name ?? kind,
        kind: kind,
      );
    }

    final canExpand =
        instance.id != null && !_isNonExpandableKind(kind, className);
    final children = (loadChildren && canExpand)
        ? await _buildChildrenFromInstance(instance, isolateId, key)
        : const <VmValueNode>[];

    return VmValueNode(
      key: key,
      label: label,
      display: _formatSummaryForInstance(instance),
      type: instance.classRef?.name ?? kind,
      kind: kind,
      objectId: instance.id,
      isExpandable: canExpand,
      childrenLoaded: loadChildren && canExpand,
      children: children,
    );
  }

  Future<List<VmValueNode>> _buildChildrenFromInstance(
    Instance instance,
    String isolateId,
    String parentKey,
  ) async {
    final kind = instance.kind;
    if (kind == InstanceKind.kList || kind == InstanceKind.kSet) {
      final elements = instance.elements ?? const [];
      final nodes = <VmValueNode>[];
      for (var i = 0; i < elements.length; i++) {
        nodes.add(_buildNodeFromValue(
          elements[i],
          label: '[$i]',
          key: '$parentKey/$i',
        ));
      }

      final totalLength = instance.length ?? elements.length;
      if (elements.length < totalLength) {
        nodes.add(_ellipsisNode('$parentKey/ellipsis'));
      }
      return nodes;
    }

    if (kind == InstanceKind.kMap) {
      final associations = instance.associations ?? const [];
      final nodes = <VmValueNode>[];
      for (var i = 0; i < associations.length; i++) {
        final assoc = associations[i];
        final entryKey = '$parentKey/entry$i';
        final keyPreview = _formatValuePreview(assoc.key);
        final valuePreview = _formatValuePreview(assoc.value);
        final keyNode = _buildNodeFromValue(
          assoc.key,
          label: 'key',
          key: '$entryKey/key',
        );
        final valueNode = _buildNodeFromValue(
          assoc.value,
          label: 'value',
          key: '$entryKey/value',
        );
        final expandable = keyNode.isExpandable || valueNode.isExpandable;
        nodes.add(VmValueNode(
          key: entryKey,
          label: keyPreview,
          display: valuePreview,
          isExpandable: expandable,
          childrenLoaded: expandable,
          children: expandable ? [keyNode, valueNode] : const [],
        ));
      }

      final totalLength = instance.length ?? associations.length;
      if (associations.length < totalLength) {
        nodes.add(_ellipsisNode('$parentKey/ellipsis'));
      }
      return nodes;
    }

    if (kind == InstanceKind.kRecord) {
      final fields = instance.fields ?? const [];
      if (fields.isNotEmpty) {
        final nodes = <VmValueNode>[];
        for (var i = 0; i < fields.length; i++) {
          final field = fields[i];
          final label = _formatFieldName(field, index: i);
          nodes.add(_buildNodeFromValue(
            field.value,
            label: label,
            key: '$parentKey/field$i',
          ));
        }
        return nodes;
      }
      final elements = instance.elements ?? const [];
      final nodes = <VmValueNode>[];
      for (var i = 0; i < elements.length; i++) {
        nodes.add(_buildNodeFromValue(
          elements[i],
          label: '[$i]',
          key: '$parentKey/$i',
        ));
      }
      return nodes;
    }

    if (kind == InstanceKind.kPlainInstance) {
      return await _buildPlainInstanceChildren(instance, isolateId, parentKey);
    }

    if (instance.bytes != null) {
      final bytes = base64Decode(instance.bytes!);
      final nodes = <VmValueNode>[];
      final maxCount = bytes.length < _maxCollectionPreview
          ? bytes.length
          : _maxCollectionPreview;
      for (var i = 0; i < maxCount; i++) {
        nodes.add(VmValueNode(
          key: '$parentKey/$i',
          label: '[$i]',
          display: bytes[i].toString(),
          type: 'int',
        ));
      }
      if (maxCount < bytes.length) {
        nodes.add(_ellipsisNode('$parentKey/ellipsis'));
      }
      return nodes;
    }

    return const [];
  }

  Future<List<VmValueNode>> _buildPlainInstanceChildren(
    Instance instance,
    String isolateId,
    String parentKey,
  ) async {
    final fields = instance.fields ?? const [];
    final fieldNames = fields.map((field) => _formatFieldName(field)).toSet();
    final nodes = <VmValueNode>[];

    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];
      final label = _formatFieldName(field, index: i);
      nodes.add(_buildNodeFromValue(
        field.value,
        label: label,
        key: '$parentKey/field$i',
      ));
    }

    final getterNodes =
        await _loadGetterNodes(instance, isolateId, parentKey, fieldNames);
    nodes.addAll(getterNodes);

    return nodes;
  }

  Future<List<VmValueNode>> _loadGetterNodes(
    Instance instance,
    String isolateId,
    String parentKey,
    Set<String> fieldNames,
  ) async {
    final classId = instance.classRef?.id;
    final instanceId = instance.id;
    if (classId == null || instanceId == null) {
      return const [];
    }

    final classObj = await _service.getObject(isolateId, classId);
    if (classObj is! Class) {
      return const [];
    }

    final getterNames = (classObj.functions ?? const [])
        .where((func) =>
            (func.isGetter ?? false) &&
            !(func.isStatic ?? false) &&
            !(func.isSetter ?? false) &&
            !(func.implicit ?? false))
        .map((func) => func.name)
        .whereType<String>()
        .where((name) =>
            name.isNotEmpty &&
            _isValidIdentifier(name) &&
            !fieldNames.contains(name))
        .toList();

    if (getterNames.isEmpty) {
      return const [];
    }

    final nodes = <VmValueNode>[];

    for (var i = 0; i < getterNames.length; i++) {
      final name = getterNames[i];
      final key = '$parentKey/getter$i';
      try {
        final result = await _service.evaluate(
          isolateId,
          instanceId,
          name,
          disableBreakpoints: true,
        );
        final node = await _buildNodeFromResponse(
          result,
          label: 'get $name',
          key: key,
          isolateId: isolateId,
          loadChildren: false,
        );
        nodes.add(node);
      } catch (e) {
        nodes.add(VmValueNode(
          key: key,
          label: 'get $name',
          display: '<error: $e>',
        ));
      }
    }

    return nodes;
  }

  VmValueNode _buildNodeFromValue(
    dynamic value, {
    required String label,
    required String key,
  }) {
    if (value is ErrorRef) {
      return VmValueNode(
        key: key,
        label: label,
        display: '<error: ${value.message ?? 'unknown'}>',
      );
    }
    if (value is Sentinel) {
      return VmValueNode(
        key: key,
        label: label,
        display: '<${value.valueAsString ?? value.kind ?? 'sentinel'}>',
      );
    }
    if (value is Instance) {
      final kind = value.kind;
      if (_isPrimitiveKind(kind)) {
        return VmValueNode(
          key: key,
          label: label,
          display: _formatPrimitiveDisplay(value.valueAsString, kind),
          type: value.classRef?.name ?? kind,
          kind: kind,
        );
      }
      final canExpand =
          value.id != null && !_isNonExpandableKind(kind, value.classRef?.name);
      return VmValueNode(
        key: key,
        label: label,
        display: _formatSummaryForInstance(value),
        type: value.classRef?.name ?? kind,
        kind: kind,
        objectId: value.id,
        isExpandable: canExpand,
      );
    }
    if (value is InstanceRef) {
      final kind = value.kind;
      if (_isPrimitiveKind(kind)) {
        return VmValueNode(
          key: key,
          label: label,
          display: _formatPrimitiveDisplay(value.valueAsString, kind),
          type: value.classRef?.name ?? kind,
          kind: kind,
        );
      }
      final canExpand =
          value.id != null && !_isNonExpandableKind(kind, value.classRef?.name);
      return VmValueNode(
        key: key,
        label: label,
        display: _formatSummaryForRef(value),
        type: value.classRef?.name ?? kind,
        kind: kind,
        objectId: value.id,
        isExpandable: canExpand,
      );
    }

    if (value == null) {
      return VmValueNode(
        key: key,
        label: label,
        display: 'null',
      );
    }

    return VmValueNode(
      key: key,
      label: label,
      display: value.toString(),
    );
  }

  Future<Obj> _getObjectForRef(String isolateId, InstanceRef ref) {
    final objectId = ref.id!;
    final kind = ref.kind;
    if (kind == InstanceKind.kList ||
        kind == InstanceKind.kSet ||
        kind == InstanceKind.kMap) {
      return _service.getObject(
        isolateId,
        objectId,
        offset: 0,
        count: _maxCollectionPreview,
      );
    }
    return _service.getObject(isolateId, objectId);
  }

  Future<Obj> _getObjectForNode(String isolateId, VmValueNode node) {
    final objectId = node.objectId!;
    final kind = node.kind;
    if (kind == InstanceKind.kList ||
        kind == InstanceKind.kSet ||
        kind == InstanceKind.kMap) {
      return _service.getObject(
        isolateId,
        objectId,
        offset: 0,
        count: _maxCollectionPreview,
      );
    }
    return _service.getObject(isolateId, objectId);
  }

  String _formatPrimitiveDisplay(String? value, String? kind) {
    if (kind == InstanceKind.kString) {
      return '"${value ?? ''}"';
    }
    if (kind == InstanceKind.kNull) {
      return 'null';
    }
    return value ?? 'null';
  }

  String _formatSummaryForRef(InstanceRef ref) {
    final kind = ref.kind;
    if (kind == InstanceKind.kList ||
        kind == InstanceKind.kSet ||
        kind == InstanceKind.kMap) {
      final length = ref.length;
      final label = kind ?? 'Collection';
      return length != null ? '$label($length)' : label;
    }
    if (kind == InstanceKind.kRecord) {
      return 'Record';
    }
    final className = ref.classRef?.name;
    return className ?? (kind ?? 'Instance');
  }

  String _formatSummaryForInstance(Instance instance) {
    final kind = instance.kind;
    if (kind == InstanceKind.kList ||
        kind == InstanceKind.kSet ||
        kind == InstanceKind.kMap) {
      final length = instance.length;
      final label = kind ?? 'Collection';
      return length != null ? '$label($length)' : label;
    }
    if (kind == InstanceKind.kRecord) {
      return 'Record';
    }
    final className = instance.classRef?.name;
    return className ?? (kind ?? 'Instance');
  }

  String _formatFieldName(BoundField field, {int? index}) {
    final name = field.name ?? field.decl?.name;
    if (name != null) {
      return name.toString();
    }
    if (index != null) {
      return '\$$index';
    }
    return 'field';
  }

  String _formatValuePreview(dynamic value) {
    if (value is InstanceRef) {
      if (_isPrimitiveKind(value.kind)) {
        return _formatPrimitiveDisplay(value.valueAsString, value.kind);
      }
      return _formatSummaryForRef(value);
    }
    if (value is Instance) {
      if (_isPrimitiveKind(value.kind)) {
        return _formatPrimitiveDisplay(value.valueAsString, value.kind);
      }
      return _formatSummaryForInstance(value);
    }
    if (value is Sentinel) {
      return '<${value.valueAsString ?? value.kind ?? 'sentinel'}>';
    }
    if (value == null) {
      return 'null';
    }
    return value.toString();
  }

  VmValueNode _ellipsisNode(String key) {
    return VmValueNode(
      key: key,
      label: '...',
      display: '...',
    );
  }

  bool _isPrimitiveKind(String? kind) {
    return kind == InstanceKind.kNull ||
        kind == InstanceKind.kBool ||
        kind == InstanceKind.kInt ||
        kind == InstanceKind.kDouble ||
        kind == InstanceKind.kString;
  }

  bool _isValidIdentifier(String name) {
    return RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(name);
  }

  bool _isNonExpandableKind(String? kind, String? className) {
    if (kind == InstanceKind.kClosure) {
      return true;
    }
    if (className == 'Function' || className == 'Closure') {
      return true;
    }
    return false;
  }
}
