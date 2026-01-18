import 'package:flutter/material.dart';

/// Widget displayed when no application is connected.
class DisconnectedView extends StatelessWidget {
  const DisconnectedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.offline_bolt,
            size: 64,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No application connected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Start your Flutter app to see Jolt signals',
          ),
        ],
      ),
    );
  }
}
