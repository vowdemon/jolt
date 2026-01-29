/// Data models for Jolt DevTools Extension.
library;

import 'package:jolt_devtools_extension/src/models/jolt_debug.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

export 'package:jolt_devtools_extension/src/models/vm_node.dart';

/// Represents a Jolt reactive node in the inspector.
class JoltNode {
  final int id;
  final String type;
  final String label;
  final String debugType;
  final bool isDisposed;
  final Signal<int> flags;
  final Signal<dynamic> value;
  final Signal<String> valueType;
  final ListSignal<int> dependencies;
  final ListSignal<int> subscribers;
  final Signal<String?> creationStack;
  final Signal<int?> updatedAt;
  final int? createdAt;
  final Signal<int> count;
  final bool isReadable;

  JoltNode({
    required this.id,
    required this.type,
    required this.label,
    required this.debugType,
    required this.isDisposed,
    dynamic value,
    required int flags,
    required String valueType,
    List<int> dependencies = const [],
    List<int> subscribers = const [],
    String? creationStack,
    int? updatedAt,
    this.createdAt,
    int count = 0,
  })  : value = Signal(value),
        flags = Signal(flags),
        valueType = Signal(valueType),
        dependencies = ListSignal(dependencies),
        subscribers = ListSignal(subscribers),
        creationStack = Signal(creationStack),
        updatedAt = Signal<int?>(updatedAt),
        count = Signal(count),
        isReadable = type == 'Signal' || type == 'Computed';

  factory JoltNode.fromJson(Map<String, dynamic> json) {
    final dependencies = (json['dependencies'] as List?)?.cast<int>() ?? [];
    final subscribers = (json['subscribers'] as List?)?.cast<int>() ?? [];
    return JoltNode(
      id: json['id'] as int,
      type: json['nodeType'] as String, // Use 'nodeType' instead of 'type'
      label: json['label'] as String,
      debugType:
          json['type'] as String, // debugType from JoltDebugOption.type()
      flags: json['flags'] as int,
      isDisposed: json['isDisposed'] as bool,
      value: json['value'],
      valueType: json['valueType'] as String? ?? 'Unknown',
      dependencies: dependencies,
      subscribers: subscribers,
      updatedAt: json['updatedAt'] as int?,
      createdAt: json['createdAt'] as int?,
      count: json['count'] as int? ?? 0,
    );
  }

  factory JoltNode.fromDebugNode(JoltDebugNode node) {
    return JoltNode(
        id: node.id,
        type: node.type,
        label: node.label,
        debugType: node.debugType,
        isDisposed: node.isDisposed,
        value: node.value,
        flags: node.flags,
        valueType: node.valueType,
        dependencies: node.dependencies,
        subscribers: node.subscribers,
        updatedAt: node.updatedAt,
        createdAt: node.createdAt,
        count: node.count ?? 0);
  }

  @override
  String toString() => 'JoltNode($label: $value)';
}

/// Represents a real-time node update.
class NodeUpdate {
  final int? nodeId;
  final String operation;
  final dynamic value;
  final String? valueType;
  final int timestamp;
  final JoltNode? node; // For nodeCreated operation
  final int? depId; // For link/unlink operations
  final int? subId; // For link/unlink operations
  final int? count; // New count after set/notify/effect

  NodeUpdate({
    this.nodeId,
    required this.operation,
    this.value,
    this.valueType,
    required this.timestamp,
    this.node,
    this.depId,
    this.subId,
    this.count,
  });

  factory NodeUpdate.fromJson(Map<String, dynamic> json) {
    return NodeUpdate(
      nodeId: json['nodeId'] as int?,
      operation: json['operation'] as String,
      value: json['value'],
      valueType: json['valueType'] as String?,
      timestamp: json['timestamp'] as int,
      node: json['node'] != null
          ? JoltNode.fromJson(json['node'] as Map<String, dynamic>)
          : null,
      depId: json['depId'] as int?,
      subId: json['subId'] as int?,
      count: json['count'] as int?,
    );
  }

  @override
  String toString() =>
      'NodeUpdate(node: $nodeId, op: $operation, time: $timestamp)';
}
