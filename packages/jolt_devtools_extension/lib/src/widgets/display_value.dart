import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/vm_node.dart';
import 'package:jolt_devtools_extension/src/utils/theme.dart';
import 'package:jolt_devtools_extension/src/widgets/value_root.dart';

/// Widget for displaying non-expandable values.
class DisplayValue extends StatefulWidget {
  final VmValueNode node;
  final JoltInspectorController? controller;
  final ValueRootState? valueRootState;

  const DisplayValue({
    super.key,
    required this.node,
    this.controller,
    this.valueRootState,
  });

  @override
  State<DisplayValue> createState() => _DisplayValueState();
}

class _DisplayValueState extends State<DisplayValue> {
  bool _isHovered = false;

  Future<void> _copyValueString() async {
    if (widget.controller == null || widget.valueRootState == null) {
      _showMessage('Cannot copy: controller or valueRootState not available');
      return;
    }

    try {
      // Find parent node to get objectId
      final root = widget.valueRootState!.$root.value;
      if (root == null) {
        _showMessage('Cannot copy: root node not available');
        return;
      }

      // Extract parent key from current node's key
      final keyParts = widget.node.key.split('/');
      if (keyParts.length < 2) {
        // This is root or invalid, use display value directly
        await Clipboard.setData(ClipboardData(text: widget.node.display));
        if (mounted) {
          _showMessage('Copied to clipboard');
        }
        return;
      }

      // Find parent node
      final parentKey = keyParts.sublist(0, keyParts.length - 1).join('/');
      final parentNode = _findNodeByKey(root, parentKey);
      if (parentNode == null || parentNode.objectId == null) {
        // Fallback to display value
        await Clipboard.setData(ClipboardData(text: widget.node.display));
        if (mounted) {
          _showMessage('Copied to clipboard');
        }
        return;
      }

      // Get value string from parent's field/getter
      final fieldName = widget.node.label;
      if (fieldName.isNotEmpty && parentNode.objectId != null) {
        // Use valueService to get the value string
        final valueString = await widget.controller!.joltService
            .getVmValueStringByFieldOrGetter(
          parentNode.objectId!,
          fieldName,
        );

        if (valueString != null) {
          await Clipboard.setData(ClipboardData(text: valueString));
          if (mounted) {
            _showMessage('Copied to clipboard');
          }
          return;
        }
      }

      // Fallback to display value
      await Clipboard.setData(ClipboardData(text: widget.node.display));
      if (mounted) {
        _showMessage('Copied to clipboard');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: ${e.toString()}');
      }
    }
  }

  /// Recursively finds a node by key in the tree.
  VmValueNode? _findNodeByKey(VmValueNode? node, String key) {
    if (node == null) return null;
    if (node.key == key) return node;
    for (final child in node.children) {
      final found = _findNodeByKey(child, key);
      if (found != null) return found;
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    // Root node (no controller) doesn't show label prefix
                    if (widget.controller != null) ...[
                      if (widget.node.isGetter) ...[
                        TextSpan(
                          text: 'get ',
                          style: AppTheme.getterStyle,
                        ),
                        TextSpan(
                          text: '${widget.node.label}: ',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ] else
                        TextSpan(
                          text: '${widget.node.label}: ',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                    TextSpan(
                      text: widget.node.display,
                      style: AppTheme.getStyleForNode(
                        kind: widget.node.kind,
                        type: widget.node.type,
                        label: widget.node.label,
                        display: widget.node.display,
                        isGetter: widget.node.isGetter,
                      ),
                    ),
                    // Copy button as rich text widget span
                    if (_isHovered &&
                        widget.controller != null &&
                        widget.valueRootState != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: _copyValueString,
                              tooltip: 'Copy value string',
                              padding: EdgeInsets.zero,
                              iconSize: 12,
                              color: Colors.grey.shade400,
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
