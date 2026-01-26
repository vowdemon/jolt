import 'package:flutter/material.dart';
import 'package:jolt_devtools_extension/src/controllers/jolt_inspector_controller.dart';
import 'package:jolt_devtools_extension/src/widgets/disconnected_view.dart';
import 'package:jolt_devtools_extension/src/widgets/nodes_list_panel.dart';
import 'package:jolt_devtools_extension/src/widgets/node_details_panel.dart';
import 'package:jolt_devtools_extension/src/widgets/search_syntax_dialog.dart';
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
  double _detailsWidth = _detailsWidthDefault;

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
