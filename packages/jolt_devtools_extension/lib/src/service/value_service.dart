import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:devtools_app_shared/service.dart';
import 'package:jolt_devtools_extension/src/models/vm_node.dart';
import 'package:jolt_devtools_extension/src/service/vm_value_cache.dart';
import 'package:vm_service/vm_service.dart';

/// Service for reading and building VM values for Jolt nodes.
class ValueService {
  final ServiceManager<Object?> serviceManager;
  static const _debugLibraryUriSuffix = 'jolt/src/core/debug.dart';

  /// Threshold for creating range nodes.
  static const _rangeThreshold = 100;

  String? _debugLibraryId;
  String? _debugLibraryIsolateId;

  /// LRU cache for VM value trees (caches 10 most recent).
  final _vmValueCache = VmValueCache(maxSize: 10);

  ValueService(this.serviceManager);

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
      final isolateRef = serviceManager.isolateManager.selectedIsolate.value;
      if (isolateRef != null) {
        return isolateRef.id;
      }

      final vm = await _service.getVM();
      return vm.isolates?.firstOrNull?.id;
    } catch (e) {
      developer.log('[Value Service] Error getting isolate ID: $e');
      return null;
    }
  }

  /// Gets the string representation of a VM value instance.
  /// Returns null if the value cannot be retrieved or converted to string.
  Future<String?> getVmValueString(int nodeId) async {
    if (serviceManager.service == null) {
      return null;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        return null;
      }

      final libraryId = await _getDebugLibraryId(isolateId);
      if (libraryId == null) {
        return null;
      }

      // Get the instance reference
      final response = await _service.evaluate(
        isolateId,
        libraryId,
        'debugNodes[$nodeId]?.target?.pendingValue',
        disableBreakpoints: true,
      );

      if (response is ErrorRef) {
        return null;
      }
      if (response is Sentinel) {
        return null;
      }
      if (response is! InstanceRef && response is! Instance) {
        return null;
      }

      // Get the object ID
      String? objectId;
      if (response is Instance) {
        objectId = response.id;
      } else if (response is InstanceRef) {
        objectId = response.id;
      }

      if (objectId == null) {
        return null;
      }

      // Call toString() on the instance
      final toStringResult = await _service.evaluate(
        isolateId,
        objectId,
        'toString()',
        disableBreakpoints: true,
      );

      if (toStringResult is ErrorRef) {
        return null;
      }
      if (toStringResult is Sentinel) {
        return null;
      }

      // Extract string value
      if (toStringResult is InstanceRef) {
        if (toStringResult.kind == InstanceKind.kString) {
          final stringObj =
              await _service.getObject(isolateId, toStringResult.id!);
          if (stringObj is Instance && stringObj.valueAsString != null) {
            return stringObj.valueAsString;
          }
        }
      } else if (toStringResult is Instance) {
        if (toStringResult.kind == InstanceKind.kString) {
          return toStringResult.valueAsString;
        }
      }

      // Fallback to toString() of the result
      return toStringResult.toString();
    } catch (e) {
      developer.log('[Value Service] Error getting VM value string: $e');
      return null;
    }
  }

  /// Gets the real VM value for a readable node as a tree.
  /// Returns null if the value cannot be retrieved.
  /// Uses LRU cache to speed up repeated access.
  Future<VmValueNode?> getVmValueTree(int nodeId) async {
    if (serviceManager.service == null) {
      return null;
    }

    // Check cache first
    final cached = _vmValueCache.get(nodeId);
    if (cached != null) {
      return cached;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        return null;
      }

      final libraryId = await _getDebugLibraryId(isolateId);
      if (libraryId == null) {
        return null;
      }

      final response = await _service.evaluate(
        isolateId,
        libraryId,
        'debugNodes[$nodeId]?.target?.pendingValue',
        disableBreakpoints: true,
      );

      if (response is ErrorRef) {
        return null;
      }
      if (response is Sentinel) {
        return null;
      }
      if (response is! InstanceRef && response is! Instance) {
        return null;
      }

      final result = await _buildNodeFromResponse(
        response,
        label: 'Value',
        key: 'root:$nodeId',
        isolateId: isolateId,
        loadChildren: true,
      );

      // Cache the result
      _vmValueCache.put(nodeId, result);

      return result;
    } catch (e) {
      developer.log('[Value Service] Error getting VM value tree: $e');
      return null;
    }
  }

  /// Removes a node's VM value from the cache.
  /// Called when a node is updated or disposed.
  void invalidateVmValueCache(int nodeId) {
    _vmValueCache.remove(nodeId);
  }

  /// Gets the string representation of a field or getter value from a parent object.
  /// Returns null if the value cannot be retrieved or converted to string.
  Future<String?> getVmValueStringByFieldOrGetter(
    String parentObjectId,
    String fieldOrGetterName,
  ) async {
    if (serviceManager.service == null) {
      return null;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        return null;
      }

      // Evaluate the field/getter from parent object
      final result = await _service.evaluate(
        isolateId,
        parentObjectId,
        fieldOrGetterName,
        disableBreakpoints: true,
      );

      if (result is ErrorRef) {
        return null;
      }
      if (result is Sentinel) {
        return null;
      }

      // Get object ID for the result
      String? objId;
      if (result is Instance) {
        objId = result.id;
      } else if (result is InstanceRef) {
        objId = result.id;
      }

      if (objId == null) {
        // For primitive values, return their string representation
        return result.toString();
      }

      // Call toString() on the result
      final toStringResult = await _service.evaluate(
        isolateId,
        objId,
        'toString()',
        disableBreakpoints: true,
      );

      if (toStringResult is ErrorRef) {
        return null;
      }
      if (toStringResult is Sentinel) {
        return null;
      }

      // Extract string value
      if (toStringResult is InstanceRef) {
        if (toStringResult.kind == InstanceKind.kString) {
          final stringObj =
              await _service.getObject(isolateId, toStringResult.id!);
          if (stringObj is Instance && stringObj.valueAsString != null) {
            return stringObj.valueAsString;
          }
        }
      } else if (toStringResult is Instance) {
        if (toStringResult.kind == InstanceKind.kString) {
          return toStringResult.valueAsString;
        }
      }

      // Fallback to toString() of the result
      return toStringResult.toString();
    } catch (e) {
      developer.log(
          '[Value Service] Error getting VM value string by field/getter: $e');
      return null;
    }
  }

  /// Gets the string representation of a VM value instance by objectId.
  /// Returns null if the value cannot be retrieved or converted to string.
  /// May return null if the object has been GC'd.
  Future<String?> getVmValueStringByObjectId(String objectId) async {
    if (serviceManager.service == null) {
      return null;
    }

    try {
      final isolateId = await _getIsolateId();
      if (isolateId == null) {
        return null;
      }

      // Try to get the object first to check if it still exists
      final obj = await _service.getObject(isolateId, objectId);
      if (obj is! Instance && obj is! InstanceRef) {
        return null;
      }

      // Call toString() on the instance
      final toStringResult = await _service.evaluate(
        isolateId,
        objectId,
        'toString()',
        disableBreakpoints: true,
      );

      if (toStringResult is ErrorRef) {
        return null;
      }
      if (toStringResult is Sentinel) {
        return null;
      }

      // Extract string value
      if (toStringResult is InstanceRef) {
        if (toStringResult.kind == InstanceKind.kString) {
          final stringObj =
              await _service.getObject(isolateId, toStringResult.id!);
          if (stringObj is Instance && stringObj.valueAsString != null) {
            return stringObj.valueAsString;
          }
        }
      } else if (toStringResult is Instance) {
        if (toStringResult.kind == InstanceKind.kString) {
          return toStringResult.valueAsString;
        }
      }

      // Fallback to toString() of the result
      return toStringResult.toString();
    } catch (e) {
      developer
          .log('[Value Service] Error getting VM value string by objectId: $e');
      return null;
    }
  }

  /// Gets children for a VmValueNode.
  /// Handles both regular nodes and range nodes.
  Future<List<VmValueNode>> getVmChildren(VmValueNode node) async {
    final isolateId = await _getIsolateId();
    if (isolateId == null) {
      return const [];
    }
    final objectId = node.objectId;
    if (objectId == null) {
      return const [];
    }

    // Handle range nodes
    if (node.isRangeNode) {
      return _buildRangeChildren(node, isolateId);
    }

    final Obj obj = await _service.getObject(isolateId, objectId);
    if (obj is! Instance) {
      return const [];
    }
    return await _buildChildrenFromInstance(obj, isolateId, node.key);
  }

  /// Builds children for a range node.
  /// Returns sub-ranges if the range is large, otherwise returns actual elements.
  Future<List<VmValueNode>> _buildRangeChildren(
    VmValueNode rangeNode,
    String isolateId,
  ) async {
    final objectId = rangeNode.objectId;
    final start = rangeNode.rangeStart;
    final end = rangeNode.rangeEnd;
    final listLength = rangeNode.listLength;
    final kind = rangeNode.kind;

    if (objectId == null ||
        start == null ||
        end == null ||
        listLength == null) {
      return const [];
    }

    final rangeLength = end - start;

    // If range is small enough, load actual elements
    if (rangeLength <= _rangeThreshold) {
      return _loadListElements(
        isolateId,
        objectId,
        start,
        rangeLength,
        rangeNode.key,
        kind,
      );
    }

    // Otherwise, create sub-ranges
    return _createRangeNodes(
      parentKey: rangeNode.key,
      start: start,
      end: end,
      listLength: listLength,
      objectId: objectId,
      kind: kind,
    );
  }

  /// Loads actual list elements from a specific range.
  Future<List<VmValueNode>> _loadListElements(
    String isolateId,
    String objectId,
    int offset,
    int count,
    String parentKey,
    String? kind,
  ) async {
    final obj = await _service.getObject(
      isolateId,
      objectId,
      offset: offset,
      count: count,
    );

    if (obj is! Instance) {
      return const [];
    }

    final elements = obj.elements ?? const [];
    final nodes = <VmValueNode>[];

    for (var i = 0; i < elements.length; i++) {
      final actualIndex = offset + i;
      nodes.add(_buildNodeFromValue(
        elements[i],
        label: '[$actualIndex]',
        key: '$parentKey/$actualIndex',
      ));
    }

    return nodes;
  }

  /// Creates range nodes for a section of a list.
  List<VmValueNode> _createRangeNodes({
    required String parentKey,
    required int start,
    required int end,
    required int listLength,
    required String? objectId,
    required String? kind,
  }) {
    final rangeLength = end - start;
    final rangeSize = _calculateRangeSize(rangeLength);
    final nodes = <VmValueNode>[];

    var currentStart = start;
    while (currentStart < end) {
      final currentEnd = math.min(currentStart + rangeSize, end);
      nodes.add(VmValueNode.range(
        key: '$parentKey/range_$currentStart-$currentEnd',
        start: currentStart,
        end: currentEnd,
        listLength: listLength,
        objectId: objectId,
        kind: kind,
      ));
      currentStart = currentEnd;
    }

    return nodes;
  }

  /// Calculates the appropriate range size based on length.
  /// Returns 100^floor(log100(length)) but at least 100.
  int _calculateRangeSize(int length) {
    if (length < _rangeThreshold) {
      return length;
    }

    // floor(log100(length)) gives us the number of levels
    // We want 100^(levels-1) as the range size for the current level
    final levels = (math.log(length) / math.log(_rangeThreshold)).floor();
    if (levels <= 1) {
      return _rangeThreshold;
    }

    return math.pow(_rangeThreshold, levels - 1).toInt();
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
      final obj = await _service.getObject(isolateId, ref.id!);
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
      listLength: ref.length,
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
      listLength: instance.length,
    );
  }

  Future<List<VmValueNode>> _buildChildrenFromInstance(
    Instance instance,
    String isolateId,
    String parentKey,
  ) async {
    final kind = instance.kind;

    // Handle List and Set with range pagination
    if (kind == InstanceKind.kList || kind == InstanceKind.kSet) {
      final totalLength = instance.length ?? 0;

      // Small list: load all elements directly
      if (totalLength < _rangeThreshold) {
        // Need to get full object if not already loaded
        final obj = await _service.getObject(
          isolateId,
          instance.id!,
          offset: 0,
          count: totalLength,
        );
        if (obj is! Instance) {
          return const [];
        }

        final elements = obj.elements ?? const [];
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

      // Large list: create range nodes
      return _createRangeNodes(
        parentKey: parentKey,
        start: 0,
        end: totalLength,
        listLength: totalLength,
        objectId: instance.id,
        kind: kind,
      );
    }

    // Handle Map with range pagination
    if (kind == InstanceKind.kMap) {
      final totalLength = instance.length ?? 0;

      // Small map: load all entries directly
      if (totalLength < _rangeThreshold) {
        final obj = await _service.getObject(
          isolateId,
          instance.id!,
          offset: 0,
          count: totalLength,
        );
        if (obj is! Instance) {
          return const [];
        }

        final associations = obj.associations ?? const [];
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
        return nodes;
      }

      // Large map: create range nodes
      return _createRangeNodes(
        parentKey: parentKey,
        start: 0,
        end: totalLength,
        listLength: totalLength,
        objectId: instance.id,
        kind: kind,
      );
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

    // Handle typed data (bytes) with range pagination
    if (instance.bytes != null) {
      final bytes = base64Decode(instance.bytes!);
      final totalLength = bytes.length;

      if (totalLength < _rangeThreshold) {
        final nodes = <VmValueNode>[];
        for (var i = 0; i < bytes.length; i++) {
          nodes.add(VmValueNode(
            key: '$parentKey/$i',
            label: '[$i]',
            display: bytes[i].toString(),
            type: 'int',
          ));
        }
        return nodes;
      }

      // Large byte array: create range nodes
      // Note: For bytes we handle it differently since data is already loaded
      return _createBytesRangeNodes(bytes, parentKey);
    }

    return const [];
  }

  /// Creates range nodes for bytes data (already loaded in memory).
  List<VmValueNode> _createBytesRangeNodes(List<int> bytes, String parentKey) {
    final rangeSize = _calculateRangeSize(bytes.length);
    final nodes = <VmValueNode>[];

    var currentStart = 0;
    while (currentStart < bytes.length) {
      final currentEnd = math.min(currentStart + rangeSize, bytes.length);
      // For bytes, we create a special node that will be handled differently
      nodes.add(VmValueNode(
        key: '$parentKey/bytes_$currentStart-$currentEnd',
        label: '[$currentStart-${currentEnd - 1}]',
        display: '${currentEnd - currentStart} bytes',
        isExpandable: true,
        isRangeNode: true,
        rangeStart: currentStart,
        rangeEnd: currentEnd,
        listLength: bytes.length,
      ));
      currentStart = currentEnd;
    }

    return nodes;
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
          label: name,
          key: key,
          isolateId: isolateId,
          loadChildren: false,
        );
        // Mark as getter and update the node
        nodes.add(node.copyWith(isGetter: true));
      } catch (e) {
        nodes.add(VmValueNode(
          key: key,
          label: name,
          display: '<error: $e>',
          isGetter: true,
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
        listLength: value.length,
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
        listLength: value.length,
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
