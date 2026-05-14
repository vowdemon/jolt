import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/widgets/node_icon.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

class WatchListPanel extends StatelessWidget {
  const WatchListPanel({
    super.key,
    required this.width,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<JoltInspectorController>();
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: JoltBuilder(builder: (context) {
              final count = controller.$watchedNodeIds.length;
              return Text(
                'Watch ($count)',
                style: Theme.of(context).textTheme.titleSmall,
              );
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: JoltBuilder(builder: (context) {
              final nodes = controller.watchedNodes;
              if (nodes.isEmpty) {
                return Center(
                  child: Text(
                    'No watched nodes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return ListView.builder(
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  return _WatchListTile(
                    node: nodes[index],
                    controller: controller,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WatchListTile extends StatelessWidget {
  const _WatchListTile({
    required this.node,
    required this.controller,
  });

  final JoltNode node;
  final JoltInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      controller.$now.value;
      node.count.value;
      node.updatedAt.value;

      return ListTile(
        dense: true,
        leading: NodeIcon(type: node.type),
        title: Text(
          _nodeTitle(node),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: node.isDisposed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _badge(context, 'id: ${node.id}'),
              _badge(context, 'count: ${node.count.value}'),
              _badge(context,
                  'updated: ${controller.formatTimeAgo(node.updatedAt.value)}'),
              _badge(context, node.isDisposed ? 'disposed' : 'active'),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.visibility),
          iconSize: 16,
          tooltip: 'Remove from Watch',
          onPressed: () => controller.removeNodeFromWatch(node.id),
        ),
        onTap: () => controller.selectNode(
          node.id,
          reason: SelectionReason.watch,
        ),
      );
    });
  }

  String _nodeTitle(JoltNode node) {
    if (node.label.isNotEmpty && node.label != 'Unnamed') {
      return node.label;
    }
    return '${node.type}(${node.id})';
  }

  Widget _badge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
