import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/widgets/disconnected_view.dart';
import 'package:jolt_devtools_extension/src/widgets/nodes_list_panel.dart';
import 'package:jolt_devtools_extension/src/widgets/node_details_panel.dart';
import 'package:jolt_devtools_extension/src/widgets/search_syntax_dialog.dart';
import 'package:jolt_devtools_extension/src/widgets/watch_list_panel.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:provider/provider.dart';

class JoltInspectorPage extends StatefulWidget {
  const JoltInspectorPage({super.key});

  @override
  State<JoltInspectorPage> createState() => _JoltInspectorPageState();
}

class _JoltInspectorPageState extends State<JoltInspectorPage> {
  late final JoltInspectorController _controller;

  static const double _detailsWidthMin = 200;
  static const double _detailsWidthMax = 600;
  static const double _detailsWidthDefault = 350;
  static const double _watchWidthMin = 180;
  static const double _watchWidthMax = 520;
  static const double _watchWidthDefault = 280;
  double _detailsWidth = _detailsWidthDefault;
  double _watchWidth = _watchWidthDefault;

  @override
  void initState() {
    super.initState();
    _controller = JoltInspectorController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InheritedProvider.value(
      value: _controller,
      updateShouldNotify: (previous, next) => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jolt Inspector'),
          actions: [
            WatchPanelToggleButton(controller: _controller),
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const SearchSyntaxDialog(),
                );
              },
              tooltip: 'Search Syntax Help',
            ),
            GlobalFilterButton(controller: _controller),
            JoltBuilder(builder: (context) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _controller.$isConnected.value
                    ? _controller.loadNodes
                    : null,
                tooltip: 'Refresh',
              );
            }),
          ],
        ),
        body: JoltBuilder(builder: (context) {
          return switch (_controller.$isConnected.value) {
            false => const DisconnectedView(),
            true => _buildMainView(),
          };
        }),
      ),
    );
  }

  Widget _buildMainView() {
    return Row(
      children: [
        if (_controller.$watchPanelExpanded.value) ...[
          WatchListPanel(width: _watchWidth),
          _ResizableDetailsDivider(
            onDrag: (dx) {
              setState(() {
                _watchWidth =
                    (_watchWidth + dx).clamp(_watchWidthMin, _watchWidthMax);
              });
            },
          ),
        ],
        Expanded(
          child: NodesListPanel(),
        ),
        if (_controller.$selectedNode.value != null) ...[
          _ResizableDetailsDivider(
            onDrag: (dx) {
              setState(() {
                _detailsWidth = (_detailsWidth - dx)
                    .clamp(_detailsWidthMin, _detailsWidthMax);
              });
            },
          ),
          SizedBox(
            width: _detailsWidth,
            child: NodeDetailsPanel(
              node: _controller.$selectedNode.value!,
            ),
          ),
        ],
      ],
    );
  }
}

class GlobalFilterButton extends StatelessWidget {
  const GlobalFilterButton({
    super.key,
    required this.controller,
  });

  final JoltInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      return IconButton(
        icon: Icon(
          controller.$globalFilterEnabled.value
              ? Icons.filter_alt
              : Icons.filter_alt_off,
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => GlobalFilterDialog(controller: controller),
          );
        },
        tooltip: 'Global Filter',
      );
    });
  }
}

class WatchPanelToggleButton extends StatelessWidget {
  const WatchPanelToggleButton({
    super.key,
    required this.controller,
  });

  final JoltInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return JoltBuilder(builder: (context) {
      final expanded = controller.$watchPanelExpanded.value;
      return IconButton(
        icon: Icon(expanded ? Icons.visibility : Icons.visibility_off),
        onPressed: controller.toggleWatchPanel,
        tooltip: expanded ? 'Hide Watch' : 'Show Watch',
      );
    });
  }
}

class GlobalFilterDialog extends StatefulWidget {
  const GlobalFilterDialog({
    super.key,
    required this.controller,
  });

  final JoltInspectorController controller;

  @override
  State<GlobalFilterDialog> createState() => _GlobalFilterDialogState();
}

class _GlobalFilterDialogState extends State<GlobalFilterDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.$globalFilterQuery.value,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: JoltBuilder(builder: (context) {
            final enabled = widget.controller.$globalFilterEnabled.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Global Filter',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 16,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Global Filter'),
                  value: enabled,
                  onChanged: (value) {
                    setState(() {
                      widget.controller.setGlobalFilterEnabled(value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Global Filter',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: widget.controller.setGlobalFilterQuery,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Draggable divider for resizing the details panel width.
class _ResizableDetailsDivider extends StatelessWidget {
  final void Function(double dx) onDrag;

  const _ResizableDetailsDivider({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
