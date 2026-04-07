import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_value_path.dart';
import 'package:jolt_devtools_extension/src/inspector_value/service/jolt_value_child.dart';
import 'package:jolt_devtools_extension/src/inspector_value/widgets/jolt_value_row.dart';

class JoltValueTree extends StatelessWidget {
  const JoltValueTree({
    super.key,
    required this.path,
    required this.label,
    required this.value,
    this.isGetter = false,
    this.canRefresh = false,
    this.showObjectProperties = true,
    required this.depth,
    required this.expandedPaths,
    required this.childrenByPath,
    required this.onToggle,
    required this.onRefreshPath,
    required this.onEdit,
    required this.onSubmitEdit,
    required this.editingPath,
  });

  final JoltValuePath path;
  final String? label;
  final dynamic value;
  final bool isGetter;
  final bool canRefresh;
  final bool showObjectProperties;
  final int depth;
  final Set<JoltValuePath> expandedPaths;
  final Map<JoltValuePath, List<JoltValueChild>> childrenByPath;
  final ValueChanged<JoltValuePath> onToggle;
  final ValueChanged<JoltValuePath> onRefreshPath;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onSubmitEdit;
  final JoltValuePath? editingPath;

  @override
  Widget build(BuildContext context) {
    final isExpanded = expandedPaths.contains(path);
    final rows = <Widget>[
      JoltValueRow(
        label: label,
        isGetter: isGetter,
        showObjectProperties: showObjectProperties,
        value: value,
        depth: depth,
        isExpanded: isExpanded,
        onToggle: value.isExpandable ? () => onToggle(path) : null,
        onRefresh: canRefresh ? () => onRefreshPath(path) : null,
        onEdit: onEdit,
        onSubmitEdit: onSubmitEdit,
        onCancelEdit:
            onEdit == null ? null : () => onToggle(editingPath ?? path),
        isEditing: editingPath == path,
      ),
    ];

    if (isExpanded) {
      final children = childrenByPath[path] ?? const <JoltValueChild>[];
      for (final child in children) {
        rows.add(
          JoltValueTree(
            path: child.path,
            label: child.label,
            value: child.value,
            isGetter: child.field?.isGetter ?? false,
            canRefresh: child.field != null,
            showObjectProperties: showObjectProperties,
            depth: depth + 1,
            expandedPaths: expandedPaths,
            childrenByPath: childrenByPath,
            onToggle: onToggle,
            onRefreshPath: onRefreshPath,
            onEdit: null,
            onSubmitEdit: null,
            editingPath: editingPath,
            key: ValueKey(child.path),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}
