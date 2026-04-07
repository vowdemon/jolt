import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:devtools_app_shared/service.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_object_field.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_inspector_policy.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_child.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_resolution.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:vm_service/vm_service.dart';

class JoltValueInspectorService {
  JoltValueInspectorService([this.serviceManager]);

  factory JoltValueInspectorService.test() => JoltValueInspectorService();

  static const _debugLibraryUriSuffix = 'jolt/src/core/debug.dart';
  static const _rangeThreshold = 100;

  final ServiceManager<Object?>? serviceManager;
  final Map<JoltValuePath, JoltInspectedValue> _valueCache = {};
  final Map<_ChildrenCacheKey, List<JoltValueChild>> _childrenCache = {};
  final Map<JoltValuePath, _ResolvedValue> _refCache = {};
  final Map<int, _ResolvedValue> _rootRefCache = {};
  final Map<int, String> _unavailableRoots = {};

  String? _debugLibraryId;
  String? _debugLibraryIsolateId;

  VmService get _service {
    final manager = serviceManager;
    final service = manager?.service;
    if (manager == null || service == null) {
      throw StateError('Not connected to VM service');
    }
    return service as VmService;
  }

  JoltInspectedValue inspectVmError(String message) {
    return JoltInspectedValue.error(message);
  }

  Future<JoltValueResolution?> inspectRoot(
    JoltNode node, {
    JoltValueInspectorPolicy policy = const JoltValueInspectorPolicy(),
  }) async {
    final value = await inspect(
      JoltValuePath.root(nodeId: node.id),
      node: node,
      policy: policy,
    );
    return JoltValueResolution(
      path: JoltValuePath.root(nodeId: node.id),
      value: _attachRootSetter(node, value),
    );
  }

  Future<JoltInspectedValue> inspect(
    JoltValuePath path, {
    JoltNode? node,
    JoltValueInspectorPolicy policy = const JoltValueInspectorPolicy(),
  }) async {
    final unavailableReason = _unavailableRoots[path.nodeId];
    if (unavailableReason != null) {
      return JoltInspectedValue.unavailable(unavailableReason);
    }

    final cached = _valueCache[path];
    if (cached != null) {
      return node != null ? _attachRootSetter(node, cached) : cached;
    }

    final value = await loadValue(path);
    final next = node != null ? _attachRootSetter(node, value) : value;
    _valueCache[path] = next;
    return next;
  }

  Future<List<JoltValueChild>> listChildren(
    JoltValuePath path, {
    JoltValueInspectorPolicy policy = const JoltValueInspectorPolicy(),
  }) async {
    final cacheKey = _ChildrenCacheKey(path: path, policy: policy);
    final cached = _childrenCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final rows = await loadChildren(path, policy: policy);
    final filtered = filterChildren(rows, policy: policy);
    _childrenCache[cacheKey] = filtered;
    for (final child in filtered) {
      _valueCache[child.path] = child.value;
    }
    return filtered;
  }

  Future<void> refreshRoot(JoltValuePath path) async {
    invalidateNode(path.nodeId);
  }

  void invalidateNode(int nodeId) {
    _rootRefCache.remove(nodeId);
    _unavailableRoots.remove(nodeId);
    _refCache.removeWhere((path, _) => path.nodeId == nodeId);
    _valueCache.removeWhere((path, _) => path.nodeId == nodeId);
    _childrenCache.removeWhere((key, _) => key.path.nodeId == nodeId);
  }

  void markNodeUnavailable(int nodeId, {String reason = 'unavailable'}) {
    invalidateNode(nodeId);
    _unavailableRoots[nodeId] = reason;
  }

  void clearCaches() {
    _unavailableRoots.clear();
    _rootRefCache.clear();
    _refCache.clear();
    _valueCache.clear();
    _childrenCache.clear();
  }

  Future<void> writeValue(
    JoltNode node,
    JoltValuePath path,
    String rawInput, {
    JoltValueSetter? setter,
  }) async {
    final effectiveSetter = setter ??
        _valueCache[path]?.setter ??
        JoltValueSetter.rootSignal(
          nodeId: node.id,
          editableKind: _guessEditableKind(node.value.value),
        );

    final isolateId = await _getIsolateId();
    if (isolateId == null) {
      throw StateError('No isolate available');
    }
    final libraryId = await _getDebugLibraryId(isolateId);
    if (libraryId == null) {
      throw StateError('Debug library not found');
    }

    if (path.segments.isNotEmpty) {
      throw UnsupportedError('Only root scalar editing is supported');
    }

    final expression = _buildRootWriteExpression(effectiveSetter, rawInput);
    await _service.evaluate(
      isolateId,
      libraryId,
      expression,
      disableBreakpoints: true,
    );
    invalidateNode(node.id);
  }

  JoltInspectedValue inspectVmValue(Object? value) {
    if (value is ErrorRef) {
      return JoltInspectedValue.error(value.message ?? 'unknown');
    }
    if (value is Sentinel) {
      return JoltInspectedValue.unavailable(
        value.valueAsString ?? value.kind ?? 'sentinel',
      );
    }
    if (value == null) {
      return const JoltInspectedValue(
        kind: JoltInspectedValueKind.nullValue,
        state: JoltInspectedValueState.available,
        displayValue: 'null',
      );
    }
    if (value is InstanceRef) {
      return _inspectInstanceRef(value);
    }
    if (value is Instance) {
      return _inspectInstanceRef(value);
    }
    return JoltInspectedValue(
      kind: JoltInspectedValueKind.unknown,
      state: JoltInspectedValueState.available,
      displayValue: value.toString(),
    );
  }

  List<JoltObjectField> buildObjectFields({
    required ClassRef? ownerClass,
    required List<BoundField> fields,
    List<String> getterNames = const [],
  }) {
    final descriptors = <JoltObjectField>[];
    final seenNames = <String>{};

    for (final field in fields) {
      final name = field.name?.toString();
      if (name == null || name.isEmpty) {
        continue;
      }
      descriptors.add(
        _buildObjectFieldDescriptor(
          ownerClass: ownerClass,
          name: name,
        ),
      );
      seenNames.add(name);
    }

    for (final getterName in getterNames) {
      if (getterName.isEmpty || seenNames.contains(getterName)) {
        continue;
      }
      descriptors.add(
        _buildObjectFieldDescriptor(
          ownerClass: ownerClass,
          name: getterName,
          isGetter: true,
        ),
      );
    }

    return descriptors;
  }

  JoltValuePath childPathForField(JoltValuePath parent, JoltObjectField field) {
    return parent.childField(field);
  }

  JoltValuePath childPathForIndex(JoltValuePath parent, int index) {
    return parent.childIndex(index);
  }

  JoltValuePath childPathForMapKey(
    JoltValuePath parent,
    JoltMapEntryIdentity identity,
  ) {
    return parent.childMapKey(identity);
  }

  JoltValuePath childPathForMapValue(
    JoltValuePath parent,
    JoltMapEntryIdentity identity,
  ) {
    return parent.childMapValue(identity);
  }

  JoltValuePath childPathForRange(
    JoltValuePath parent,
    int start,
    int end,
  ) {
    return parent.childRange(start, end);
  }

  Future<JoltValueResolution?> resolveRoot(JoltNode node) async {
    return inspectRoot(node);
  }

  Future<JoltInspectedValue> loadValue(JoltValuePath path) async {
    final lastSegment = path.segments.isEmpty ? null : path.segments.last;
    if (lastSegment?.kind == JoltPathSegmentKind.range) {
      final start = lastSegment!.start!;
      final end = lastSegment.end!;
      return JoltInspectedValue(
        kind: JoltInspectedValueKind.range,
        state: JoltInspectedValueState.available,
        displayValue: '',
        length: end - start,
        isExpandable: true,
      );
    }

    final resolved = await _resolvePath(path);
    final normalizedValue = await _normalizeDisplayTarget(
      resolved.value,
      isolateId: resolved.isolateId,
    );
    final value = inspectVmValue(normalizedValue);
    return value.copyWith(
      objectId: _objectIdOf(normalizedValue) ?? value.objectId,
      hashCodeDisplay: _hashCodeOf(normalizedValue),
    );
  }

  Future<List<JoltValueChild>> loadChildren(
    JoltValuePath path, {
    JoltValueInspectorPolicy policy = const JoltValueInspectorPolicy(),
  }) async {
    final lastSegment = path.segments.isEmpty ? null : path.segments.last;
    if (lastSegment?.kind == JoltPathSegmentKind.range) {
      return _loadRangeChildren(path);
    }

    final resolved = await _resolvePath(path);
    final value = resolved.value;

    if (value is! InstanceRef && value is! Instance) {
      return const [];
    }

    final instance = await _materializeInstance(resolved);
    if (instance == null) {
      return const [];
    }

    if (instance.kind == InstanceKind.kList ||
        instance.kind == InstanceKind.kSet) {
      return _loadEnumerableChildren(path, resolved.isolateId, instance);
    }
    if (instance.kind == InstanceKind.kMap) {
      return _loadMapChildren(path, resolved.isolateId, instance);
    }
    if (instance.kind == InstanceKind.kPlainInstance ||
        instance.kind == InstanceKind.kRecord) {
      return _loadObjectChildren(path, resolved.isolateId, instance, policy);
    }
    return const [];
  }

  List<JoltValueChild> filterChildren(
    List<JoltValueChild> rows, {
    JoltValueInspectorPolicy policy = const JoltValueInspectorPolicy(),
  }) {
    return rows.where((row) {
      final field = row.field;
      if (field == null) {
        return true;
      }
      if (field.isGetter && !policy.showGetters) {
        return false;
      }
      if (_isHashCodeOrRuntimeTypeGetter(field) &&
          !policy.showHashCodeAndRuntimeType) {
        return false;
      }
      if (field.isPrivate && !policy.showPrivateMembers) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<String?> _getIsolateId() async {
    final manager = serviceManager;
    if (manager == null) {
      return null;
    }

    try {
      final isolateRef = manager.isolateManager.selectedIsolate.value;
      if (isolateRef != null) {
        return isolateRef.id;
      }

      final vm = await _service.getVM();
      return vm.isolates?.firstOrNull?.id;
    } catch (error) {
      developer.log('[Jolt Value Inspector] isolate lookup failed: $error');
      return null;
    }
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

  JoltInspectedValue _inspectInstanceRef(InstanceRef value) {
    final kind = value.kind;
    final typeName = value.classRef?.name ?? kind;

    if (value is Instance) {
      final enumDisplay = _enumDisplayOf(value);
      if (enumDisplay != null) {
        return JoltInspectedValue(
          kind: JoltInspectedValueKind.enumeration,
          state: JoltInspectedValueState.available,
          displayValue: enumDisplay,
          typeName: typeName,
          objectId: value.id,
          isExpandable: value.id != null,
          hashCodeDisplay: value.identityHashCode?.toRadixString(16),
        );
      }
    }

    switch (kind) {
      case InstanceKind.kNull:
        return const JoltInspectedValue(
          kind: JoltInspectedValueKind.nullValue,
          state: JoltInspectedValueState.available,
          displayValue: 'null',
        );
      case InstanceKind.kBool:
        return JoltInspectedValue(
          kind: JoltInspectedValueKind.boolean,
          state: JoltInspectedValueState.available,
          displayValue: value.valueAsString ?? 'false',
          typeName: typeName,
        );
      case InstanceKind.kInt:
      case InstanceKind.kDouble:
        return JoltInspectedValue(
          kind: JoltInspectedValueKind.number,
          state: JoltInspectedValueState.available,
          displayValue: value.valueAsString ?? '0',
          typeName: typeName,
        );
      case InstanceKind.kString:
        return JoltInspectedValue(
          kind: JoltInspectedValueKind.string,
          state: JoltInspectedValueState.available,
          displayValue: '"${value.valueAsString ?? ''}"',
          typeName: typeName,
          length: value.length,
          objectId: value.id,
        );
      case InstanceKind.kList:
        return _buildCollectionValue(
          kind: JoltInspectedValueKind.list,
          label: 'List',
          value: value,
          typeName: typeName,
        );
      case InstanceKind.kMap:
        return _buildCollectionValue(
          kind: JoltInspectedValueKind.map,
          label: 'Map',
          value: value,
          typeName: typeName,
        );
      case InstanceKind.kSet:
        return _buildCollectionValue(
          kind: JoltInspectedValueKind.set,
          label: 'Set',
          value: value,
          typeName: typeName,
        );
      case InstanceKind.kRecord:
        return JoltInspectedValue(
          kind: JoltInspectedValueKind.record,
          state: JoltInspectedValueState.available,
          displayValue: 'Record',
          typeName: typeName,
          objectId: value.id,
          length: value.length,
          isExpandable: value.id != null,
        );
      default:
        return JoltInspectedValue(
          kind: JoltInspectedValueKind.object,
          state: JoltInspectedValueState.available,
          displayValue: typeName ?? 'Instance',
          typeName: typeName,
          objectId: value.id,
          length: value.length,
          isExpandable:
              value.id != null && !_isNonExpandableKind(kind, typeName),
          hashCodeDisplay: value.identityHashCode?.toRadixString(16),
        );
    }
  }

  Future<Object?> _normalizeDisplayTarget(
    Object? value, {
    required String isolateId,
  }) async {
    if (value is Instance) {
      return value;
    }
    if (value is InstanceRef &&
        value.kind == InstanceKind.kPlainInstance &&
        value.id != null) {
      final object = await _service.getObject(isolateId, value.id!);
      if (object is Instance) {
        return object;
      }
    }
    return value;
  }

  String? _enumDisplayOf(Instance instance) {
    if (instance.kind != InstanceKind.kPlainInstance) {
      return null;
    }

    final typeName = instance.classRef?.name;
    if (typeName == null || typeName.isEmpty) {
      return null;
    }

    InstanceRef? nameField;
    for (final field in instance.fields ?? const <BoundField>[]) {
      if (field.name?.toString() == '_name' && field.value is InstanceRef) {
        nameField = field.value as InstanceRef;
        break;
      }
    }

    if (nameField == null || nameField.kind != InstanceKind.kString) {
      return null;
    }

    final enumName = nameField.valueAsString;
    if (enumName == null || enumName.isEmpty) {
      return null;
    }

    return '$typeName.$enumName';
  }

  JoltInspectedValue _buildCollectionValue({
    required JoltInspectedValueKind kind,
    required String label,
    required InstanceRef value,
    required String? typeName,
  }) {
    final length = value.length;
    final summary = length == null ? label : '$label($length)';
    return JoltInspectedValue(
      kind: kind,
      state: JoltInspectedValueState.available,
      displayValue: summary,
      typeName: typeName,
      objectId: value.id,
      length: length,
      isExpandable: value.id != null,
      hashCodeDisplay: value.identityHashCode?.toRadixString(16),
    );
  }

  Future<_ResolvedValue> _resolvePath(JoltValuePath path) async {
    final cached = _refCache[path];
    if (cached != null) {
      return cached;
    }

    if (path.segments.isEmpty) {
      final root = await _resolveRootRef(path.nodeId);
      _refCache[path] = root;
      return root;
    }

    final parent = await _resolvePath(
      JoltValuePath(
          nodeId: path.nodeId,
          segments: path.segments.sublist(0, path.segments.length - 1)),
    );
    final segment = path.segments.last;
    final resolved = await _resolveChild(parent, segment);
    _refCache[path] = resolved;
    return resolved;
  }

  Future<_ResolvedValue> _resolveRootRef(int nodeId) async {
    final cached = _rootRefCache[nodeId];
    if (cached != null) {
      return cached;
    }
    if (serviceManager?.service == null) {
      return _ResolvedValue(
        isolateId: '',
        value: Sentinel(
          kind: SentinelKind.kCollected,
          valueAsString: 'Disconnected',
        ),
      );
    }
    final isolateId = await _getIsolateId();
    if (isolateId == null) {
      return _ResolvedValue(
        isolateId: '',
        value: Sentinel(
          kind: SentinelKind.kCollected,
          valueAsString: 'No isolate',
        ),
      );
    }
    final libraryId = await _getDebugLibraryId(isolateId);
    if (libraryId == null) {
      return _ResolvedValue(
        isolateId: isolateId,
        value: Sentinel(
            kind: SentinelKind.kCollected,
            valueAsString: 'Debug library unavailable'),
      );
    }
    final response = await _service.evaluate(
      isolateId,
      libraryId,
      'debugNodes[$nodeId]?.target?.pendingValue',
      disableBreakpoints: true,
    );
    final resolved = _ResolvedValue(isolateId: isolateId, value: response);
    _rootRefCache[nodeId] = resolved;
    return resolved;
  }

  Future<_ResolvedValue> _resolveChild(
    _ResolvedValue parent,
    JoltPathSegment segment,
  ) async {
    final instance = await _materializeInstance(parent);
    if (instance == null) {
      return _ResolvedValue(
        isolateId: parent.isolateId,
        value: Sentinel(kind: SentinelKind.kCollected, valueAsString: 'stale'),
      );
    }

    if (segment.kind == JoltPathSegmentKind.listIndex) {
      final index = segment.index!;
      final obj = await _service.getObject(
        parent.isolateId,
        instance.id!,
        offset: index,
        count: 1,
      );
      if (obj is Instance && (obj.elements?.isNotEmpty ?? false)) {
        return _ResolvedValue(
          isolateId: parent.isolateId,
          value: obj.elements!.first,
        );
      }
      return _ResolvedValue(
        isolateId: parent.isolateId,
        value: Sentinel(kind: SentinelKind.kCollected, valueAsString: 'stale'),
      );
    }

    if (segment.kind == JoltPathSegmentKind.range) {
      return parent;
    }

    if (segment.kind == JoltPathSegmentKind.mapKey ||
        segment.kind == JoltPathSegmentKind.mapValue) {
      final identity = segment.identity!;
      final mapObj = await _service.getObject(
        parent.isolateId,
        instance.id!,
        offset: 0,
        count: instance.length ?? 0,
      );
      if (mapObj is! Instance) {
        return _ResolvedValue(
          isolateId: parent.isolateId,
          value:
              Sentinel(kind: SentinelKind.kCollected, valueAsString: 'stale'),
        );
      }
      final associations = mapObj.associations ?? const <MapAssociation>[];
      for (final association in associations) {
        if (_matchesMapIdentity(association.key, identity)) {
          return _ResolvedValue(
            isolateId: parent.isolateId,
            value: segment.kind == JoltPathSegmentKind.mapKey
                ? association.key
                : association.value,
          );
        }
      }
      return _ResolvedValue(
        isolateId: parent.isolateId,
        value: Sentinel(kind: SentinelKind.kCollected, valueAsString: 'stale'),
      );
    }

    final fieldName = segment.name!;
    for (final field in instance.fields ?? const <BoundField>[]) {
      if (field.name?.toString() == fieldName) {
        return _ResolvedValue(isolateId: parent.isolateId, value: field.value);
      }
    }

    try {
      final result = await _service.evaluate(
        parent.isolateId,
        instance.id!,
        fieldName,
        disableBreakpoints: true,
      );
      return _ResolvedValue(isolateId: parent.isolateId, value: result);
    } catch (_) {
      return _ResolvedValue(
        isolateId: parent.isolateId,
        value: Sentinel(kind: SentinelKind.kCollected, valueAsString: 'stale'),
      );
    }
  }

  Future<Instance?> _materializeInstance(_ResolvedValue resolved) async {
    final value = resolved.value;
    if (value is Instance) {
      return value;
    }
    if (value is InstanceRef && value.id != null) {
      final object = await _service.getObject(resolved.isolateId, value.id!);
      return object is Instance ? object : null;
    }
    return null;
  }

  Future<List<JoltValueChild>> _loadEnumerableChildren(
    JoltValuePath path,
    String isolateId,
    Instance instance,
  ) async {
    final length = instance.length ?? 0;
    if (length > _rangeThreshold) {
      return buildRangeChildren(
        path: path,
        objectId: instance.id,
        start: 0,
        end: length,
      );
    }

    return _loadIndexSliceChildren(
      path: path,
      isolateId: isolateId,
      objectId: instance.id,
      offset: 0,
      count: length,
    );
  }

  Future<List<JoltValueChild>> _loadIndexSliceChildren({
    required JoltValuePath path,
    required String isolateId,
    required String? objectId,
    required int offset,
    required int count,
  }) async {
    if (objectId == null) {
      return const [];
    }
    final object = await _service.getObject(
      isolateId,
      objectId,
      offset: offset,
      count: count,
    );
    if (object is! Instance) {
      return const [];
    }

    final elements = object.elements ?? const [];
    final rows = <JoltValueChild>[];
    for (var i = 0; i < elements.length; i++) {
      final actualIndex = offset + i;
      final childPath = path.childIndex(actualIndex);
      rows.add(
        JoltValueChild.index(
          label: '[$actualIndex]',
          path: childPath,
          index: actualIndex,
          value: inspectVmValue(elements[i]),
        ),
      );
    }
    return rows;
  }

  Future<List<JoltValueChild>> _loadMapChildren(
    JoltValuePath path,
    String isolateId,
    Instance instance,
  ) async {
    final length = instance.length ?? 0;
    if (length > _rangeThreshold) {
      return buildRangeChildren(
        path: path,
        objectId: instance.id,
        start: 0,
        end: length,
      );
    }

    return _loadMapSliceChildren(
      path: path,
      isolateId: isolateId,
      objectId: instance.id,
      offset: 0,
      count: length,
    );
  }

  Future<List<JoltValueChild>> _loadMapSliceChildren({
    required JoltValuePath path,
    required String isolateId,
    required String? objectId,
    required int offset,
    required int count,
  }) async {
    if (objectId == null) {
      return const [];
    }
    final object = await _service.getObject(
      isolateId,
      objectId,
      offset: offset,
      count: count,
    );
    if (object is! Instance) {
      return const [];
    }
    final rows = <JoltValueChild>[];
    for (final association in object.associations ?? const <MapAssociation>[]) {
      final identity = _mapIdentityOf(association.key);
      rows.add(
        JoltValueChild.mapValue(
          label: _mapKeyLabel(association.key),
          path: path.childMapValue(identity),
          value: inspectVmValue(association.value),
        ),
      );
    }
    return rows;
  }

  Future<List<JoltValueChild>> _loadRangeChildren(JoltValuePath path) async {
    final segment = path.segments.last;
    final parentPath = path.parent;
    final resolved = await _resolvePath(parentPath);
    final instance = await _materializeInstance(resolved);
    if (instance == null) {
      return const [];
    }

    final start = segment.start!;
    final end = segment.end!;
    final rangeLength = end - start;
    if (rangeLength > _rangeThreshold) {
      return buildRangeChildren(
        path: path,
        objectId: instance.id,
        start: start,
        end: end,
      );
    }

    if (instance.kind == InstanceKind.kMap) {
      return _loadMapSliceChildren(
        path: path,
        isolateId: resolved.isolateId,
        objectId: instance.id,
        offset: start,
        count: rangeLength,
      );
    }

    return _loadIndexSliceChildren(
      path: path,
      isolateId: resolved.isolateId,
      objectId: instance.id,
      offset: start,
      count: rangeLength,
    );
  }

  List<JoltValueChild> buildRangeChildren({
    required JoltValuePath path,
    required String? objectId,
    required int start,
    required int end,
  }) {
    if (objectId == null) {
      return const [];
    }

    final rangeLength = end - start;
    final rangeSize = calculateRangeSize(rangeLength);
    final rows = <JoltValueChild>[];

    var currentStart = start;
    while (currentStart < end) {
      final currentEnd = math.min(currentStart + rangeSize, end);
      final childPath = path.childRange(currentStart, currentEnd);
      rows.add(
        JoltValueChild.range(
          label: '[$currentStart..${currentEnd - 1}]',
          path: childPath,
          start: currentStart,
          end: currentEnd,
          value: JoltInspectedValue(
            kind: JoltInspectedValueKind.range,
            state: JoltInspectedValueState.available,
            displayValue: '',
            length: currentEnd - currentStart,
            objectId: objectId,
            isExpandable: true,
          ),
        ),
      );
      currentStart = currentEnd;
    }

    return rows;
  }

  int calculateRangeSize(int length) {
    if (length <= _rangeThreshold) {
      return length;
    }

    var rangeSize = 1;
    var remaining = length;

    while (remaining > _rangeThreshold) {
      rangeSize *= _rangeThreshold;
      remaining ~/= _rangeThreshold;
    }

    return rangeSize;
  }

  Future<List<JoltValueChild>> _loadObjectChildren(
    JoltValuePath path,
    String isolateId,
    Instance instance,
    JoltValueInspectorPolicy policy,
  ) async {
    final rows = <JoltValueChild>[];
    final fields = instance.fields ?? const <BoundField>[];
    final ownerClass = instance.classRef;
    final fieldNames = <String>{};

    for (final field in fields) {
      final name = field.name?.toString();
      if (name == null || name.isEmpty) {
        continue;
      }
      fieldNames.add(name);
      final descriptor = _buildObjectFieldDescriptor(
        ownerClass: ownerClass,
        name: name,
      );
      rows.add(
        JoltValueChild.field(
          label: name,
          path: path.childField(descriptor),
          value: inspectVmValue(field.value),
          field: descriptor,
        ),
      );
    }

    final getterNames = await _loadGetterNames(ownerClass, isolateId);
    for (final getterName in getterNames) {
      if (fieldNames.contains(getterName)) {
        continue;
      }
      final descriptor = _buildObjectFieldDescriptor(
        ownerClass: ownerClass,
        name: getterName,
        isGetter: true,
      );
      final value = await _evaluateObjectMember(
        isolateId: isolateId,
        instanceId: instance.id,
        name: getterName,
      );
      rows.add(
        JoltValueChild.field(
          label: getterName,
          path: path.childField(descriptor),
          value: inspectVmValue(value),
          field: descriptor,
        ),
      );
    }

    return filterChildren(rows, policy: policy);
  }

  JoltObjectField _buildObjectFieldDescriptor({
    required ClassRef? ownerClass,
    required String name,
    bool isGetter = false,
  }) {
    final ownerName = ownerClass?.name ?? 'Object';
    final ownerUri = ownerClass?.library?.uri ?? '';
    return JoltObjectField(
      name: name,
      ownerName: ownerName,
      ownerUri: ownerUri,
      isGetter: isGetter,
      isPrivate: name.startsWith('_'),
      isDefinedByDependency: !(ownerUri.startsWith('package:jolt') ||
          ownerUri.startsWith('package:jolt_devtools_extension') ||
          ownerUri.startsWith('package:app') ||
          ownerUri.isEmpty),
    );
  }

  Future<List<String>> _loadGetterNames(
    ClassRef? ownerClass,
    String isolateId,
  ) async {
    final classId = ownerClass?.id;
    if (classId == null) {
      return const [];
    }

    final classObj = await _service.getObject(isolateId, classId);
    if (classObj is! Class) {
      return const [];
    }

    return (classObj.functions ?? const <FuncRef>[])
        .where((func) =>
            (func.isGetter ?? false) &&
            !(func.isStatic ?? false) &&
            !(func.isSetter ?? false) &&
            !(func.implicit ?? false))
        .map((func) => func.name)
        .whereType<String>()
        .where((name) => name.isNotEmpty && _isValidIdentifier(name))
        .toList();
  }

  Future<Object?> _evaluateObjectMember({
    required String isolateId,
    required String? instanceId,
    required String name,
  }) async {
    if (instanceId == null) {
      return ErrorRef(
        id: 'getter-error:$name:missing-object-id',
        message: 'object id unavailable',
      );
    }
    try {
      return await _service.evaluate(
        isolateId,
        instanceId,
        name,
        disableBreakpoints: true,
      );
    } catch (error) {
      return ErrorRef(
        id: 'getter-error:$name',
        message: error.toString(),
      );
    }
  }

  JoltInspectedValue _attachRootSetter(
      JoltNode node, JoltInspectedValue value) {
    if (!node.isReadable || node.type != 'Signal' || value.setter != null) {
      return value;
    }
    final editableKind = switch (value.kind) {
      JoltInspectedValueKind.boolean => JoltEditableKind.boolean,
      JoltInspectedValueKind.number => JoltEditableKind.number,
      JoltInspectedValueKind.string => JoltEditableKind.string,
      JoltInspectedValueKind.nullValue => JoltEditableKind.nullValue,
      _ => null,
    };
    if (editableKind == null) {
      return value;
    }
    return value.copyWith(
      setter: JoltValueSetter.rootSignal(
        nodeId: node.id,
        editableKind: editableKind,
      ),
    );
  }

  JoltEditableKind _guessEditableKind(Object? value) {
    if (value is bool) return JoltEditableKind.boolean;
    if (value is num) return JoltEditableKind.number;
    if (value is String) return JoltEditableKind.string;
    return JoltEditableKind.nullValue;
  }

  String _buildRootWriteExpression(JoltValueSetter setter, String rawInput) {
    final expression = switch (setter.editableKind) {
      JoltEditableKind.boolean => rawInput.trim(),
      JoltEditableKind.number => rawInput.trim(),
      JoltEditableKind.string => _quoteDartString(rawInput),
      JoltEditableKind.nullValue => 'null',
    };
    return 'debugNodes[${setter.nodeId}]?.target?.value = $expression';
  }

  String _quoteDartString(String input) {
    final escaped = input
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n');
    return "'$escaped'";
  }

  bool _matchesMapIdentity(Object? key, JoltMapEntryIdentity identity) {
    if (identity.kind == JoltMapEntryIdentityKind.primitive) {
      return _mapKeyLabel(key) == identity.primitiveKey;
    }
    return _objectIdOf(key) == identity.objectId;
  }

  JoltMapEntryIdentity _mapIdentityOf(Object? key) {
    final objectId = _objectIdOf(key);
    if (objectId != null) {
      return JoltMapEntryIdentity.object(
        objectId: objectId,
        fallbackLabel: _mapKeyLabel(key),
      );
    }
    return JoltMapEntryIdentity.primitive(_mapKeyLabel(key));
  }

  String _mapKeyLabel(Object? key) {
    if (key == null) {
      return 'null';
    }
    if (key is InstanceRef && key.kind == InstanceKind.kString) {
      return key.valueAsString ?? 'null';
    }
    return inspectVmValue(key).displayValue;
  }

  String? _objectIdOf(Object? value) {
    if (value is InstanceRef) {
      return value.id;
    }
    if (value is Instance) {
      return value.id;
    }
    return null;
  }

  String? _hashCodeOf(Object? value) {
    if (value is InstanceRef) {
      return value.identityHashCode?.toRadixString(16);
    }
    if (value is Instance) {
      return value.identityHashCode?.toRadixString(16);
    }
    return null;
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

  bool _isValidIdentifier(String value) {
    return RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(value);
  }

  bool _isHashCodeOrRuntimeTypeGetter(JoltObjectField field) {
    if (!field.isGetter) {
      return false;
    }
    return field.name == 'hashCode' || field.name == 'runtimeType';
  }
}

class _ChildrenCacheKey {
  const _ChildrenCacheKey({
    required this.path,
    required this.policy,
  });

  final JoltValuePath path;
  final JoltValueInspectorPolicy policy;

  @override
  bool operator ==(Object other) {
    return other is _ChildrenCacheKey &&
        other.path == path &&
        other.policy.showPrivateMembers == policy.showPrivateMembers &&
        other.policy.showGetters == policy.showGetters &&
        other.policy.showObjectProperties == policy.showObjectProperties &&
        other.policy.showHashCodeAndRuntimeType ==
            policy.showHashCodeAndRuntimeType;
  }

  @override
  int get hashCode => Object.hash(
        path,
        policy.showPrivateMembers,
        policy.showGetters,
        policy.showObjectProperties,
        policy.showHashCodeAndRuntimeType,
      );
}

class _ResolvedValue {
  const _ResolvedValue({
    required this.isolateId,
    required this.value,
  });

  final String isolateId;
  final Object? value;
}
