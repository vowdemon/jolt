import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_devtools_extension/src/widgets/expandable_value.dart';
import 'package:jolt_devtools_extension/src/widgets/display_value.dart';

/// Root widget for displaying VM value.
///
/// Self-manages VmValueNode lifecycle. When the input node changes,
/// automatically reloads the VM value.
class ValueRoot extends StatefulWidget {
  final JoltNode node;
  final JoltInspectorController controller;

  const ValueRoot({
    super.key,
    required this.node,
    required this.controller,
  });

  @override
  State<ValueRoot> createState() => ValueRootState();
}

class ValueRootState extends State<ValueRoot> {
  final $isLoading = Signal(false);
  final $error = Signal<String?>(null);
  final $root = Signal<VmValueNode?>(null);

  int? _loadedNodeId;

  @override
  void initState() {
    super.initState();
    _loadVmValue();
  }

  @override
  void didUpdateWidget(ValueRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _loadVmValue();
    }
  }

  Future<void> _loadVmValue() async {
    if (!widget.node.isReadable) {
      return;
    }

    final nodeId = widget.node.id;
    if (_loadedNodeId == nodeId && $root.value != null) {
      return;
    }

    $isLoading.value = true;
    $error.value = null;

    try {
      final result = await widget.controller.joltService.getVmValueTree(nodeId);
      // Check if node changed during load
      if (widget.node.id != nodeId) {
        return;
      }
      _loadedNodeId = nodeId;
      $root.value = result;
      if (result == null) {
        $error.value = 'Failed to load VM value';
      }
    } catch (e) {
      if (widget.node.id == nodeId) {
        $error.value = e.toString();
      }
    } finally {
      if (widget.node.id == nodeId) {
        $isLoading.value = false;
      }
    }
  }

  Future<void> loadVmChildren(VmValueNode target) async {
    if (!widget.node.isReadable) {
      return;
    }
    if (!target.isExpandable || target.objectId == null) {
      return;
    }
    if (target.childrenLoaded || target.isLoading) {
      return;
    }

    _updateVmNode(
        target.key, (node) => node.copyWith(isLoading: true, error: null));

    try {
      final children =
          await widget.controller.joltService.getVmChildren(target);
      _updateVmNode(
        target.key,
        (node) => node.copyWith(
          children: children,
          childrenLoaded: true,
          isLoading: false,
        ),
      );
    } catch (e) {
      _updateVmNode(target.key,
          (node) => node.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _updateVmNode(
    String key,
    VmValueNode Function(VmValueNode node) update,
  ) {
    final root = $root.value;
    if (root == null) {
      return;
    }

    final updatedRoot = _updateVmNodeRecursive(root, key, update);
    if (updatedRoot != null) {
      $root.value = updatedRoot;
    }
  }

  /// Refreshes a specific node by reloading its children.
  Future<void> refreshNode(VmValueNode node) async {
    if (!node.isExpandable || node.objectId == null) {
      return;
    }

    // Reset children loaded state
    _updateVmNode(
      node.key,
      (n) => n.copyWith(childrenLoaded: false, children: [], isLoading: false),
    );

    // Get the updated node from the tree
    final root = $root.value;
    if (root == null) {
      return;
    }

    final updatedNode = _findNodeByKey(root, node.key);
    if (updatedNode == null ||
        !updatedNode.isExpandable ||
        updatedNode.objectId == null) {
      return;
    }

    // Load children with the updated node
    await loadVmChildren(updatedNode);
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

  VmValueNode? _updateVmNodeRecursive(
    VmValueNode current,
    String key,
    VmValueNode Function(VmValueNode node) update,
  ) {
    if (current.key == key) {
      return update(current);
    }

    if (current.children.isEmpty) {
      return null;
    }

    var updated = false;
    final nextChildren = <VmValueNode>[];
    for (final child in current.children) {
      final updatedChild = _updateVmNodeRecursive(child, key, update);
      if (updatedChild != null) {
        nextChildren.add(updatedChild);
        updated = true;
      } else {
        nextChildren.add(child);
      }
    }

    if (!updated) {
      return null;
    }

    return current.copyWith(children: nextChildren);
  }

  Future<void> _copyValueString() async {
    if (!widget.node.isReadable) {
      return;
    }

    try {
      final valueString =
          await widget.controller.joltService.getVmValueString(widget.node.id);
      if (valueString != null) {
        await Clipboard.setData(ClipboardData(text: valueString));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get value string'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true, // Stop scroll events from bubbling
        child: Scrollbar(
          thumbVisibility: true,
          child: MouseRegion(
            child: SingleChildScrollView(
              child: _ValueContent(
                valueRootState: this,
                onRefresh: () {
                  _loadedNodeId = null;
                  _loadVmValue();
                },
                onCopy: _copyValueString,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueContent extends StatefulWidget {
  final ValueRootState valueRootState;
  final VoidCallback onRefresh;
  final VoidCallback onCopy;

  const _ValueContent({
    required this.valueRootState,
    required this.onRefresh,
    required this.onCopy,
  });

  @override
  State<_ValueContent> createState() => _ValueContentState();
}

class _ValueContentState extends State<_ValueContent> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          JoltBuilder(builder: (context) {
            final state = widget.valueRootState;
            if (state.$isLoading.value) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Loading...', style: TextStyle(fontSize: 12)),
              );
            }

            final error = state.$error.value;
            if (error != null) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error: $error',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                ),
              );
            }

            final root = state.$root.value;
            if (root == null) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Not loaded', style: TextStyle(fontSize: 12)),
              );
            }

            // If root is expandable, render ExpandableValue
            // Otherwise render DisplayValue
            if (root.isExpandable) {
              return ExpandableValue(
                node: root,
                valueRootState: state,
                depth: 0,
              );
            } else {
              return DisplayValue(
                node: root,
              );
            }
          }),
          if (_isHovered)
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: widget.onRefresh,
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
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: widget.onCopy,
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
}
