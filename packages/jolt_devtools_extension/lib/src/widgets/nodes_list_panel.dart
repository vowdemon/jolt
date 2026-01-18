import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/models/jolt_node.dart';
import 'package:jolt_devtools_extension/src/widgets/node_icon.dart';

import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';
import 'package:provider/provider.dart';

/// Widget that displays a list of nodes with filtering capabilities.
class NodesListPanel extends StatefulWidget {
  const NodesListPanel({
    super.key,
  });

  @override
  State<NodesListPanel> createState() => _NodesListPanelState();
}

class _NodesListPanelState extends State<NodesListPanel>
    with SetupMixin<NodesListPanel> {
  late JoltInspectorController controller;

  // @override
  // void didUpdateWidget(covariant NodesListPanel oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (controller.searchQuery != _searchController.text) {
  //     _searchController.text = controller.searchQuery;
  //     _searchController.selection = TextSelection.collapsed(
  //       offset: _searchController.text.length,
  //     );
  //   }
  // }

  @override
  setup(BuildContext context) {
    controller = context.read<JoltInspectorController>();
    final searchController =
        useTextEditingController(text: controller.$searchQuery.value);
    final searchFocusNode = useFocusNode();

    return () {
      if (controller.$isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final filteredNodes = controller.filteredNodes;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    suffixIconConstraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    suffixIcon: JoltBuilder(builder: (context) {
                      return Visibility(
                        visible: searchController.text.isNotEmpty,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            icon: Icon(Icons.clear),
                            iconSize: 14,
                            onPressed: () {
                              searchController.clear();
                              controller.setSearchQuery('');
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  onChanged: controller.setSearchQuery,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Matched ${filteredNodes.length} / ${controller.$nodes.length} nodes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredNodes.isEmpty
                ? Center(
                    child: Text(
                      controller.$nodes.isEmpty
                          ? 'No reactive nodes found'
                          : 'No nodes match the filter',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView(
                    children: List.generate(filteredNodes.length,
                        (index) => _NodeTile(node: filteredNodes[index])),
                  ),
          ),
        ],
      );
    };
  }
}

class _NodeTile extends StatefulWidget {
  final JoltNode node;

  const _NodeTile({
    required this.node,
  });

  @override
  State<_NodeTile> createState() => _NodeTileState();
}

class _NodeTileState extends State<_NodeTile> with SetupMixin<_NodeTile> {
  @override
  setup(BuildContext context) {
    final controller = context.read<JoltInspectorController>();
    final isSelected =
        useComputed(() => controller.$selectedNodeId.value == widget.node.id);

    final color = useComputed(
        () => isSelected.value ? Colors.blue.shade900.withAlpha(72) : null);

    return () => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: color.value,
          child: ListTile(
            dense: true,
            selected: isSelected.value,
            leading: NodeIcon(type: widget.node.type),
            title: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              children: [
                Text(
                  (widget.node.label.isNotEmpty &&
                          widget.node.label != 'Unnamed')
                      ? widget.node.label
                      : '${widget.node.type}(${widget.node.id})',
                  style: TextStyle(
                    fontWeight: isSelected.value ? FontWeight.bold : null,
                    decoration: widget.node.isDisposed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700.withAlpha(36),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.blue.shade700.withAlpha(128),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.node.debugType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildBadge('deps: ${widget.node.dependencies.length}'),
                  _buildBadge('subs: ${widget.node.subscribers.length}'),
                  if (widget.node.isReadable)
                    _buildBadge(
                      'value: ${widget.node.valueType.value}',
                      maxWidth: 150,
                    )
                ],
              ),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [],
            ),
            onTap: () => controller.selectNode(
              widget.node.id,
              reason: SelectionReason.listClick,
            ),
          ),
        );
  }

  Widget _buildBadge(String text, {double? maxWidth}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
      ),
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth)
          : const BoxConstraints(),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade300,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
