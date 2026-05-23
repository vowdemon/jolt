# Jolt Setup

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![jolt_setup](https://img.shields.io/pub/v/jolt_setup?label=jolt_setup)](https://pub.dev/packages/jolt_setup)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Setup-based widgets and hooks for Jolt-powered Flutter components.

`jolt_setup` lets a widget run `setup` once, create the state and resources it needs there, and keep later rebuilds focused on rendering. Hooks own long-lived pieces such as signals, animation controllers, focus nodes, timers, and lifecycle listeners, and clean them up with the widget.

## SetupWidget

```dart
import 'package:flutter/material.dart';
import 'package:jolt_setup/jolt_setup.dart';

class WelcomeLogo extends SetupWidget<WelcomeLogo> {
  const WelcomeLogo({super.key});

  @override
  setup(context, props) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 250),
    );
    onMounted(controller.forward);

    return () => FadeTransition(
      opacity: controller,
      child: const FlutterLogo(size: 72),
    );
  }
}
```

Use `SetupWidget` when you want a dedicated widget type and immutable widget fields, but still want `setup` to create and own long-lived resources once.

## SetupMixin

```dart
import 'package:flutter/material.dart';
import 'package:jolt_setup/jolt_setup.dart';

class WelcomePanel extends StatefulWidget {
  const WelcomePanel({super.key});

  @override
  State<WelcomePanel> createState() => _WelcomePanelState();
}

class _WelcomePanelState extends State<WelcomePanel>
    with SetupMixin<WelcomePanel> {
  late AnimationController controller;

  void show() => controller.forward();
  void hide() => controller.reverse();

  @override
  setup(context) {
    controller = useAnimationController(
      duration: const Duration(milliseconds: 250),
    );

    return () => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: controller,
          child: const FlutterLogo(size: 72),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: show,
              child: const Text('Show'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: hide,
              child: const Text('Hide'),
            ),
          ],
        ),
      ],
    );
  }
}
```

Use `SetupMixin` when you still want a normal `State<T>` class and its instance methods, but want setup hooks to own the resources used by that state object.

The package also includes `SetupBuilder` for local composition, plus hooks for reactive state, controllers, listenables, focus, scroll, animation, timers, and lifecycle callbacks.

## License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/vowdemon/jolt/blob/main/LICENSE) file for details.
