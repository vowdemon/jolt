import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/widgets/detail_section.dart';
import 'package:jolt_devtools_extension/src/widgets/detail_row.dart';
import 'package:jolt_devtools_extension/src/widgets/node_icon.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/jolt_setup.dart';
import 'package:provider/provider.dart';

/// Widget that displays detailed information about a selected node.
class NodeDetailsPanel extends StatefulWidget {
  final JoltNode node;

  const NodeDetailsPanel({
    super.key,
    required this.node,
  });

  @override
  State<NodeDetailsPanel> createState() => _NodeDetailsPanelState();
}

class _NodeDetailsPanelState extends State<NodeDetailsPanel>
    with SetupMixin<NodeDetailsPanel> {
  static final $hideGeneral = Signal(false);
  static final $hideVmValue = Signal(false);
  static final $hideCreationStack = Signal(false);
  static final $hideDependencies = Signal(false);
  static final $hideSubscribers = Signal(false);

  late JoltInspectorController controller;

  @override
  setup(BuildContext context) {
    controller = context.read<JoltInspectorController>();

    return () => Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade900,
            child: Row(
              children: [
                NodeIcon(type: widget.node.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.node.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  spacing: 12,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: controller.closeNodeDetails,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Details
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16.0), children: [
            DetailSection(
              title: 'General',
              collapseSignal: $hideGeneral,
              onToggle: () => $hideGeneral.value = !$hideGeneral.value,
              children: [
                DetailRow(label: 'ID', value: widget.node.id.toString()),
                DetailRow(label: 'Type', value: widget.node.type),
                DetailRow(label: 'Debug Type', value: widget.node.debugType),
                if (widget.node.isReadable) ...[
                  JoltBuilder(builder: (context) {
                    final vmType = widget.node.vmValue.value.root?.type;
                    final valueType = (vmType != null && vmType.isNotEmpty)
                        ? vmType
                        : widget.node.valueType.value;
                    return DetailRow(label: 'Value Type', value: valueType);
                  }),
                  DetailRow(
                    label: 'Value',
                    value: controller
                        .formatValue(widget.node.value.value)
                        .substring(0, 500),
                  ),
                ]
              ],
            ),
            if (widget.node.isReadable) ...[
              const SizedBox(height: 16),
              DetailSection(
                title: 'VM Value',
                collapseSignal: $hideVmValue,
                onToggle: () => $hideVmValue.value = !$hideVmValue.value,
                children: [
                  _VmValueTree(
                    node: widget.node,
                    controller: controller,
                  ),
                ],
              ),
            ],
            JoltBuilder(builder: (context) {
              final deps = widget.node.dependencies.value;
              if (deps.isNotEmpty) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    DetailSection(
                      title: 'Dependencies (${deps.length})',
                      collapseSignal: $hideDependencies,
                      onToggle: () =>
                          $hideDependencies.value = !$hideDependencies.value,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.2,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: deps.map((depId) {
                                final depNode = controller.$nodes[depId];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8.0, top: 4.0, bottom: 4.0),
                                  child: InkWell(
                                    onTap: () => controller.selectNode(
                                      depId,
                                      reason: SelectionReason.depJump,
                                    ),
                                    child: Row(
                                      children: [
                                        NodeIcon(
                                            type: depNode?.type ?? 'Unknown'),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                depNode?.label ?? 'Unknown')),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            JoltBuilder(builder: (context) {
              final subs = widget.node.subscribers.value;
              if (subs.isNotEmpty) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    DetailSection(
                      title: 'Subscribers (${subs.length})',
                      collapseSignal: $hideSubscribers,
                      onToggle: () =>
                          $hideSubscribers.value = !$hideSubscribers.value,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.2,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: subs.map((subId) {
                                final subNode = controller.$nodes[subId];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8.0, top: 4.0, bottom: 4.0),
                                  child: InkWell(
                                    onTap: () => controller.selectNode(
                                      subId,
                                      reason: SelectionReason.depJump,
                                    ),
                                    child: Row(
                                      children: [
                                        NodeIcon(
                                            type: subNode?.type ?? 'Unknown'),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                subNode?.label ?? 'Unknown')),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            if (widget.node.creationStack.value != null) ...[
              const SizedBox(height: 16),
              DetailSection(
                title: 'Creation Stack',
                collapseSignal: $hideCreationStack,
                onToggle: () =>
                    $hideCreationStack.value = !$hideCreationStack.value,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          widget.node.creationStack.value ?? '',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ])),
          // Actions
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.node.type == 'Signal')
                  ElevatedButton.icon(
                    onPressed: () => _editSignalValue(context, widget.node),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Value'),
                  ),
                if (widget.node.type == 'Effect')
                  ElevatedButton.icon(
                    onPressed: () => _triggerEffect(context, widget.node.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Trigger Effect'),
                  ),
              ],
            ),
          )
        ]);
  }

  Future<void> _editSignalValue(
    BuildContext context,
    JoltNode node,
  ) async {
    final textController = TextEditingController(
      text: node.value.value?.toString() ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${node.label}'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'New Value',
            hintText: 'Enter new value',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final success =
          await controller.joltService.setSignalValue(node.id, result);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signal value updated')),
        );
        // Reload nodes to see the update
        controller.loadNodes();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update signal')),
        );
      }
    }

    textController.dispose();
  }

  Future<void> _triggerEffect(BuildContext context, int nodeId) async {
    await controller.joltService.triggerEffect(nodeId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Effect triggered')),
    );
  }
}

class _VmValueTree extends StatefulWidget {
  final JoltNode node;
  final JoltInspectorController controller;

  const _VmValueTree({
    required this.node,
    required this.controller,
  });

  @override
  State<_VmValueTree> createState() => _VmValueTreeState();
}

class _VmValueTreeState extends State<_VmValueTree> {
  final Set<String> _expandedKeys = {};

  @override
  void didUpdateWidget(covariant _VmValueTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _expandedKeys.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      final state = widget.node.vmValue.value;
      if (state.isLoading) {
        return const Text('Loading...');
      }
      if (state.error != null) {
        return Text('Error: ${state.error}');
      }
      final root = state.root;
      if (root == null) {
        return const Text('Not loaded');
      }
      _expandedKeys.add(root.key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNode(root, 0),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => widget.controller.loadVmValue(
                widget.node,
                force: true,
              ),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh VM value',
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildNode(VmValueNode node, int depth) {
    final isExpanded = _expandedKeys.contains(node.key);
    final canExpand = node.isExpandable;
    final children = <Widget>[];

    children.add(_buildNodeRow(node, depth, isExpanded, canExpand));

    if (isExpanded && canExpand) {
      if (node.isLoading) {
        children.add(_buildStatusRow(depth + 1, 'Loading...'));
      } else if (node.error != null) {
        children.add(_buildStatusRow(depth + 1, 'Error: ${node.error}'));
      } else if (node.children.isEmpty) {
        children.add(_buildStatusRow(depth + 1, 'No data'));
      } else {
        for (final child in node.children) {
          children.add(_buildNode(child, depth + 1));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildStatusRow(int depth, String text) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0 + 20, top: 2, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildNodeRow(
    VmValueNode node,
    int depth,
    bool isExpanded,
    bool canExpand,
  ) {
    final icon = canExpand
        ? Icon(
            isExpanded ? Icons.expand_more : Icons.chevron_right,
            size: 16,
            color: Colors.grey.shade500,
          )
        : const SizedBox(width: 16, height: 16);
    return InkWell(
      onTap: canExpand ? () => _toggle(node, isExpanded) : null,
      child: Padding(
        padding: EdgeInsets.only(left: depth * 12.0, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 20, child: icon),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${node.label}: ',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: node.display,
                      style: const TextStyle(fontSize: 12),
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

  void _toggle(VmValueNode node, bool isExpanded) {
    setState(() {
      if (isExpanded) {
        _expandedKeys.remove(node.key);
      } else {
        _expandedKeys.add(node.key);
        if (node.isExpandable && !node.childrenLoaded) {
          widget.controller.loadVmChildren(widget.node, node);
        }
      }
    });
  }
}
