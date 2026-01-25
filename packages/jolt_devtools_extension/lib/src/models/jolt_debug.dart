class JoltDebugNodeDetails {
  final int nodeId;

  final String? creationStack;

  JoltDebugNodeDetails({
    required this.nodeId,
    required this.creationStack,
  });

  factory JoltDebugNodeDetails.fromJson(Map<String, dynamic> json) {
    return JoltDebugNodeDetails(
      nodeId: json['id'] as int,
      creationStack: json['creationStack'] as String?,
    );
  }
}

class JoltDebugNode {
  final int id;
  final String type;
  final String label;
  final String debugType;
  final bool isDisposed;
  final int flags;
  final dynamic value;
  final String valueType;
  final List<int> dependencies;
  final List<int> subscribers;

  JoltDebugNode({
    required this.id,
    required this.type,
    required this.label,
    required this.debugType,
    required this.isDisposed,
    required this.value,
    required this.flags,
    required this.valueType,
    this.dependencies = const [],
    this.subscribers = const [],
  });

  factory JoltDebugNode.fromJson(Map<String, dynamic> json) {
    final dependencies = (json['dependencies'] as List?)?.cast<int>() ?? [];
    final subscribers = (json['subscribers'] as List?)?.cast<int>() ?? [];
    return JoltDebugNode(
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

  @override
  String toString() => 'JoltNode($label: $value)';
}
