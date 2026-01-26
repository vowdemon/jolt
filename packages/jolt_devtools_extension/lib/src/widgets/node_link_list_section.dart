import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/widgets/detail_section.dart';
import 'package:jolt_devtools_extension/src/widgets/node_icon.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

/// Collapsible section listing node IDs (dependencies or subscribers) as
/// clickable items that select the target node.
class NodeLinkListSection extends StatelessWidget {
  final String title;
  final ListSignal<int> nodeIds;
  final JoltInspectorController controller;
  final Signal<bool> collapseSignal;

  const NodeLinkListSection({
    super.key,
    required this.title,
    required this.nodeIds,
    required this.controller,
    required this.collapseSignal,
  });

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      final ids = nodeIds.value;
      if (ids.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        children: [
          const SizedBox(height: 16),
          DetailSection(
            title: '$title (${ids.length})',
            collapseSignal: collapseSignal,
            onToggle: () => collapseSignal.value = !collapseSignal.value,
            children: [
              _NodeLinkList(nodeIds: nodeIds, controller: controller),
            ],
          ),
        ],
      );
    });
  }
}

class _NodeLinkList extends StatelessWidget {
  final ListSignal<int> nodeIds;
  final JoltInspectorController controller;

  const _NodeLinkList({
    required this.nodeIds,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      final ids = nodeIds.value;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.2,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ids.map((nodeId) {
              final node = controller.$nodes[nodeId];
              return Padding(
                padding:
                    const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
                child: InkWell(
                  onTap: () => controller.selectNode(
                    nodeId,
                    reason: SelectionReason.depJump,
                  ),
                  child: Row(
                    children: [
                      NodeIcon(type: node?.type ?? 'Unknown'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          node == null
                              ? 'Unknown'
                              : (node.label == 'Unnamed'
                                  ? node.debugType
                                  : node.label),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
  }
}
