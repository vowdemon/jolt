import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/widgets/detail_section.dart';
import 'package:jolt_devtools_extension/src/widgets/detail_row.dart';
import 'package:jolt_devtools_extension/src/widgets/node_icon.dart';
import 'package:jolt_devtools_extension/src/widgets/node_link_list_section.dart';
import 'package:jolt_devtools_extension/src/widgets/value_root.dart';
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
                DetailRow(
                    label: 'ID',
                    value: widget.node.id.toString(),
                    showCopyButton: true),
                DetailRow(
                    label: 'Type',
                    value: widget.node.type,
                    showCopyButton: true),
                DetailRow(
                    label: 'Debug Type',
                    value: widget.node.debugType,
                    showCopyButton: true),
                if (widget.node.createdAt != null)
                  JoltBuilder(builder: (context) {
                    controller.$now.value;
                    return DetailRow(
                      label: 'Created',
                      value: controller.formatTimeAgo(widget.node.createdAt),
                    );
                  }),
                JoltBuilder(builder: (context) {
                  controller.$now.value;
                  return DetailRow(
                    label: 'Updated',
                    value:
                        controller.formatTimeAgo(widget.node.updatedAt.value),
                  );
                }),
                JoltBuilder(builder: (context) {
                  widget.node.count.value;
                  return DetailRow(
                    label: 'Count',
                    value: widget.node.count.value.toString(),
                  );
                }),
                if (widget.node.isReadable) ...[
                  JoltBuilder(builder: (context) {
                    final valueType = widget.node.valueType.value;
                    return DetailRow(label: 'Value Type', value: valueType);
                  }),
                  JoltBuilder(builder: (context) {
                    return DetailRow(
                      label: 'Value',
                      value: controller.formatValue(widget.node.value.value),
                      showCopyButton: true,
                    );
                  }),
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
                  ValueRoot(
                    node: widget.node,
                    controller: controller,
                  ),
                ],
              ),
            ],
            NodeLinkListSection(
              title: 'Dependencies',
              nodeIds: widget.node.dependencies,
              controller: controller,
              collapseSignal: $hideDependencies,
            ),
            NodeLinkListSection(
              title: 'Subscribers',
              nodeIds: widget.node.subscribers,
              controller: controller,
              collapseSignal: $hideSubscribers,
            ),
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
          // Actions (Effect only)
          if (widget.node.type == 'Effect')
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade700)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
