import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

/// Widget that displays a section with title and children widgets.
class DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final WritableNode<bool>? collapseSignal;
  final VoidCallback? onToggle;

  const DetailSection({
    super.key,
    required this.title,
    required this.children,
    this.collapseSignal,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (collapseSignal == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      );
    }

    final signal = collapseSignal!;
    final isSignal = signal is Signal<bool>;
    final toggleCallback =
        isSignal ? () => signal.value = !signal.value : onToggle;

    return JoltBuilder(builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: toggleCallback,
            child: Row(
              children: [
                Icon(
                  signal.value ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          signal.value
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
        ],
      );
    });
  }
}
