/// VM value node models for Jolt DevTools Extension.
library;

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

  /// Whether this is a virtual range node for large lists.
  final bool isRangeNode;

  /// Start index of the range (inclusive).
  final int? rangeStart;

  /// End index of the range (exclusive).
  final int? rangeEnd;

  /// Total length of the list (for calculating sub-ranges).
  final int? listLength;

  /// Whether this is a getter node.
  final bool isGetter;

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
    this.isRangeNode = false,
    this.rangeStart,
    this.rangeEnd,
    this.listLength,
    this.isGetter = false,
  });

  VmValueNode copyWith({
    String? display,
    String? type,
    bool? isExpandable,
    bool? childrenLoaded,
    bool? isLoading,
    String? error,
    List<VmValueNode>? children,
    bool? isGetter,
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
      isRangeNode: isRangeNode,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      listLength: listLength,
      isGetter: isGetter ?? this.isGetter,
    );
  }

  /// Creates a range node for a section of a list.
  factory VmValueNode.range({
    required String key,
    required int start,
    required int end,
    required int listLength,
    required String? objectId,
    required String? kind,
  }) {
    return VmValueNode(
      key: key,
      label: '[$start-${end - 1}]',
      display: '${end - start} items',
      kind: kind,
      objectId: objectId,
      isExpandable: true,
      isRangeNode: true,
      rangeStart: start,
      rangeEnd: end,
      listLength: listLength,
    );
  }
}
