import 'package:flutter/material.dart';

/// Widget that displays an icon for a node type.
class NodeIcon extends StatelessWidget {
  final String type;

  const NodeIcon({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color? color;

    switch (type) {
      case 'Signal':
        icon = Icons.circle;
        color = Colors.blue;
        break;
      case 'Computed':
        icon = Icons.functions;
        color = Colors.green;
        break;
      case 'Effect':
        icon = Icons.flash_on;
        color = Colors.orange;
        break;
      case 'EffectScope':
        icon = Icons.folder;
        color = Colors.purple;
        break;
      case 'Watcher':
        icon = Icons.visibility;
        color = Colors.teal;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }
}
