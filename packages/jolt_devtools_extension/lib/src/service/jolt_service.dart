import 'dart:async';
import 'dart:developer' as developer;

import 'package:devtools_app_shared/service.dart';
import 'package:jolt_devtools_extension/src/models/jolt_debug.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/service/value_service.dart';

import 'package:vm_service/vm_service.dart';

export 'package:jolt_devtools_extension/src/service/value_service.dart';

/// Client for communicating with Jolt's VM Service extensions.
class JoltService {
  final ServiceManager<Object?> serviceManager;
  late final ValueService valueService = ValueService(serviceManager);

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
  Future<VmValueNode?> getVmValueTree(int nodeId) =>
      valueService.getVmValueTree(nodeId);

  Future<List<VmValueNode>> getVmChildren(VmValueNode node) =>
      valueService.getVmChildren(node);

  /// Gets the string representation of a VM value instance.
  Future<String?> getVmValueString(int nodeId) =>
      valueService.getVmValueString(nodeId);

  /// Gets the string representation of a VM value instance by objectId.
  /// May return null if the object has been GC'd.
  Future<String?> getVmValueStringByObjectId(String objectId) =>
      valueService.getVmValueStringByObjectId(objectId);

  /// Gets the string representation of a field or getter value from a parent object.
  Future<String?> getVmValueStringByFieldOrGetter(
    String parentObjectId,
    String fieldOrGetterName,
  ) =>
      valueService.getVmValueStringByFieldOrGetter(
        parentObjectId,
        fieldOrGetterName,
      );

  /// Invalidates the VM value cache for a specific node.
  /// Should be called when a node is updated or disposed.
  void invalidateVmValueCache(int nodeId) {
    valueService.invalidateVmValueCache(nodeId);
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
}
