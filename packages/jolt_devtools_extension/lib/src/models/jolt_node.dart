/// Data models for Jolt DevTools Extension.
library;

import 'package:jolt_devtools_extension/src/models/jolt_debug.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class VmValueNode {
  final String key;
  final String label;
  final String display;
  final String? type;
  final String? kind;
  final String? objectId;
  final bool isExpandable;
  final bool childrenLoaded;
  final bool isLoading;
  final String? error;
  final List<VmValueNode> children;

  const VmValueNode({
    required this.key,
    required this.label,
    required this.display,
    this.type,
    this.kind,
    this.objectId,
    this.isExpandable = false,
    this.childrenLoaded = false,
    this.isLoading = false,
    this.error,
    this.children = const [],
  });

  VmValueNode copyWith({
    String? display,
    String? type,
    bool? isExpandable,
    bool? childrenLoaded,
    bool? isLoading,
    String? error,
    List<VmValueNode>? children,
  }) {
    return VmValueNode(
      key: key,
      label: label,
      display: display ?? this.display,
      type: type ?? this.type,
      kind: kind,
      objectId: objectId,
      isExpandable: isExpandable ?? this.isExpandable,
      childrenLoaded: childrenLoaded ?? this.childrenLoaded,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      children: children ?? this.children,
    );
  }
}

class VmValueState {
  final bool isLoading;
  final VmValueNode? root;
  final String? error;

  const VmValueState._({
    this.isLoading = false,
    this.root,
    this.error,
  });

  const VmValueState.idle() : this._();
  const VmValueState.loading() : this._(isLoading: true);
  const VmValueState.success(VmValueNode root) : this._(root: root);
  const VmValueState.error(String error) : this._(error: error);

  bool get hasValue => root != null;
  bool get hasError => error != null;
}

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
  final Signal<VmValueState> vmValue;
  final ListSignal<int> dependencies;
  final ListSignal<int> subscribers;
  final Signal<String?> creationStack;
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
  })  : value = Signal(value),
        flags = Signal(flags),
        valueType = Signal(valueType),
        vmValue = Signal(const VmValueState.idle()),
        dependencies = ListSignal(dependencies),
        subscribers = ListSignal(subscribers),
        creationStack = Signal(creationStack),
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
        subscribers: node.subscribers);
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

  NodeUpdate({
    this.nodeId,
    required this.operation,
    this.value,
    this.valueType,
    required this.timestamp,
    this.node,
    this.depId,
    this.subId,
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
    );
  }

  @override
  String toString() =>
      'NodeUpdate(node: $nodeId, op: $operation, time: $timestamp)';
}
