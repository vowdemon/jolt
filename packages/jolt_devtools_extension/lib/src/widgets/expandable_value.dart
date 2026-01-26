import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolt_devtools_extension/src/models/vm_node.dart';
import 'package:jolt_devtools_extension/src/utils/theme.dart';
import 'package:jolt_devtools_extension/src/widgets/display_value.dart';
import 'package:jolt_devtools_extension/src/widgets/value_root.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

/// Widget for displaying expandable values (objects, lists, maps, sets, records, enums).
class ExpandableValue extends StatefulWidget {
  final VmValueNode node;
  final ValueRootState valueRootState;
  final int depth;

  const ExpandableValue({
    super.key,
    required this.node,
    required this.valueRootState,
    this.depth = 0,
  });

  @override
  State<ExpandableValue> createState() => _ExpandableValueState();
}

class _ExpandableValueState extends State<ExpandableValue> {
  bool _isExpanded = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // Root node is expanded by default
    if (widget.depth == 0) {
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(ExpandableValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset expansion state if node key changed
    if (oldWidget.node.key != widget.node.key) {
      _isExpanded = widget.depth == 0;
    }
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded &&
          widget.node.isExpandable &&
          !widget.node.childrenLoaded) {
        widget.valueRootState.loadVmChildren(widget.node);
      }
    });
  }

  Future<void> _refresh() async {
    if (!widget.node.isExpandable || widget.node.objectId == null) {
      _showMessage(
          'Cannot refresh: node is not expandable or objectId not available');
      return;
    }

    try {
      // Use the public refreshNode method
      await widget.valueRootState.refreshNode(widget.node);
    } catch (e) {
      if (mounted) {
        _showMessage('Error: Value may have been GC\'d or is unavailable');
      }
    }
  }

  Future<void> _copyValueString() async {
    if (widget.node.objectId == null) {
      _showMessage('Cannot copy: objectId not available');
      return;
    }

    final controller = widget.valueRootState.widget.controller;
    try {
      final valueString = await controller.joltService
          .getVmValueStringByObjectId(widget.node.objectId!);
      if (valueString != null) {
        await Clipboard.setData(ClipboardData(text: valueString));
        if (mounted) {
          _showMessage('Copied to clipboard');
        }
      } else {
        if (mounted) {
          _showMessage('Value is unavailable');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: Value is unavailable');
      }
    }
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
    return JoltBuilder(builder: (context) {
      // Rebuild when root changes to reflect updated children
      final root = widget.valueRootState.$root.value;

      // Find the current node in the updated tree by key
      VmValueNode? currentNode =
          _findNodeByKey(root, widget.node.key) ?? widget.node;

      final children = <Widget>[];

      // Build the row for this node
      children.add(_buildNodeRow(currentNode));

      // Build children if expanded
      if (_isExpanded && currentNode.isExpandable) {
        if (currentNode.isLoading) {
          children.add(_buildStatusRow('Loading...'));
        } else if (currentNode.error != null) {
          children.add(_buildStatusRow('Error: ${currentNode.error}'));
        } else if (currentNode.children.isEmpty) {
          children.add(_buildStatusRow('No data'));
        } else {
          for (final child in currentNode.children) {
            if (child.isExpandable) {
              children.add(
                ExpandableValue(
                  node: child,
                  valueRootState: widget.valueRootState,
                  depth: widget.depth + 1,
                ),
              );
            } else {
              children.add(
                Padding(
                  padding: EdgeInsets.only(left: (widget.depth + 1) * 12.0),
                  child: DisplayValue(
                    node: child,
                    controller: widget.valueRootState.widget.controller,
                    valueRootState: widget.valueRootState,
                  ),
                ),
              );
            }
          }
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    });
  }

  VmValueNode? _findNodeByKey(VmValueNode? node, String key) {
    if (node == null) return null;
    if (node.key == key) return node;
    for (final child in node.children) {
      final found = _findNodeByKey(child, key);
      if (found != null) return found;
    }
    return null;
  }

  Widget _buildNodeRow(VmValueNode node) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.depth * 12.0,
                top: 2,
                bottom: 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          // Root node (depth == 0) doesn't show label prefix
                          if (widget.depth > 0) ...[
                            if (node.isGetter) ...[
                              TextSpan(
                                text: 'get ',
                                style: AppTheme.getterStyle,
                              ),
                              TextSpan(
                                text: '${node.label}: ',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ] else
                              TextSpan(
                                text: '${node.label}: ',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                          TextSpan(
                            text: node.display,
                            style: AppTheme.getStyleForNode(
                              kind: node.kind,
                              type: node.type,
                              label: node.label,
                              display: node.display,
                              isGetter: node.isGetter,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Only show buttons for non-root nodes (depth > 0)
          // Root node uses ValueRoot's buttons
          if (_isHovered && node.objectId != null && widget.depth > 0)
            Positioned(
              top: 2,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.isExpandable)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refresh,
                        tooltip: 'Refresh',
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        color: Colors.grey.shade400,
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                      ),
                    ),
                  if (node.isExpandable) const SizedBox(width: 4),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: _copyValueString,
                      tooltip: 'Copy value string',
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      color: Colors.grey.shade400,
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String text) {
    return Padding(
      padding: EdgeInsets.only(
        left: (widget.depth + 1) * 12.0 + 20,
        top: 2,
        bottom: 2,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}
