import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/inspector_value/models/jolt_inspected_value.dart';
import 'package:jolt_devtools_extension/src/inspector_value/widgets/jolt_editable_scalar_field.dart';
import 'package:jolt_devtools_extension/src/inspector_value/widgets/jolt_object_header.dart';
import 'package:jolt_devtools_extension/src/utils/theme.dart';

class JoltValueRow extends StatefulWidget {
  const JoltValueRow({
    super.key,
    required this.value,
    required this.depth,
    this.label,
    this.isGetter = false,
    this.showObjectProperties = true,
    this.isExpanded = false,
    this.onToggle,
    this.onEdit,
    this.onRefresh,
    this.onSubmitEdit,
    this.onCancelEdit,
    this.isEditing = false,
  });

  final String? label;
  final bool isGetter;
  final bool showObjectProperties;
  final JoltInspectedValue value;
  final int depth;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onRefresh;
  final ValueChanged<String>? onSubmitEdit;
  final VoidCallback? onCancelEdit;
  final bool isEditing;

  @override
  State<JoltValueRow> createState() => _JoltValueRowState();
}

class _JoltValueRowState extends State<JoltValueRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final canExpand = widget.value.isExpandable;
    final hasInlineValue = widget.value.displayValue.isNotEmpty;
    final showActions = _isHovered || widget.isEditing;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: canExpand ? widget.onToggle : null,
        child: Padding(
          padding:
              EdgeInsets.only(left: widget.depth * 12.0, top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: canExpand
                    ? Icon(
                        widget.isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 16,
                        color: Colors.grey.shade500,
                      )
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (widget.label != null && widget.isGetter)
                          Text(
                            'get',
                            style: AppTheme.getterStyle,
                          ),
                        if (widget.label != null)
                          Text(
                            widget.label!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade300,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (widget.label != null && hasInlineValue)
                          Text(
                            ':',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        if (hasInlineValue &&
                            widget.isEditing &&
                            widget.onSubmitEdit != null &&
                            widget.onCancelEdit != null)
                          JoltEditableScalarField(
                            initialValue: _editableText(widget.value),
                            onSubmit: widget.onSubmitEdit!,
                            onCancel: widget.onCancelEdit!,
                          )
                        else if (hasInlineValue)
                          Text(
                            widget.value.displayValue,
                            style: AppTheme.getStyleForNode(
                              kind: _kindToVmKind(widget.value.kind),
                              type: widget.value.typeName,
                              label: widget.label ?? '',
                              display: widget.value.displayValue,
                            ),
                          ),
                        if (!widget.isEditing &&
                            widget.onEdit != null &&
                            showActions)
                          InkWell(
                            onTap: widget.onEdit,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        if (!widget.isEditing &&
                            widget.onRefresh != null &&
                            showActions)
                          Tooltip(
                            message: 'Refresh value',
                            child: InkWell(
                              onTap: widget.onRefresh,
                              child: Icon(
                                Icons.refresh,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.showObjectProperties &&
                        (widget.value.isExpandable ||
                            widget.value.hashCodeDisplay != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: JoltObjectHeader(value: widget.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _kindToVmKind(JoltInspectedValueKind kind) {
    return switch (kind) {
      JoltInspectedValueKind.boolean => 'Bool',
      JoltInspectedValueKind.number => 'Int',
      JoltInspectedValueKind.string => 'String',
      JoltInspectedValueKind.list => 'List',
      JoltInspectedValueKind.map => 'Map',
      JoltInspectedValueKind.set => 'Set',
      JoltInspectedValueKind.record => 'Record',
      JoltInspectedValueKind.nullValue => 'Null',
      _ => null,
    };
  }

  String _editableText(JoltInspectedValue value) {
    if (value.kind == JoltInspectedValueKind.string &&
        value.displayValue.startsWith('"') &&
        value.displayValue.endsWith('"')) {
      return value.displayValue.substring(1, value.displayValue.length - 1);
    }
    if (value.kind == JoltInspectedValueKind.nullValue) {
      return '';
    }
    return value.displayValue;
  }
}
