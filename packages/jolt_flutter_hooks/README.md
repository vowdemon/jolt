# Jolt Flutter Hooks

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_flutter_hooks](https://img.shields.io/pub/v/jolt_flutter_hooks?label=jolt_flutter_hooks)](https://pub.dev/packages/jolt_flutter_hooks)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A collection of declarative hooks for Flutter widgets, built on top of [Jolt Flutter](https://pub.dev/packages/jolt_flutter) setup system. This package provides convenient hooks for managing common Flutter resources like controllers, focus nodes, and lifecycle states with automatic cleanup.

⚠️ **Warning**: The tests in this package are currently unstable and may occasionally fail. This is a known issue that we're working to resolve.

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

class MyWidget extends SetupWidget {
  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController('Hello');
    final focusNode = useFocusNode();
    
    return Scaffold(
      body: TextField(
        controller: textController,
        focusNode: focusNode,
      ),
    );
  }
}
```

## API Reference

| Hook | Description | Returns |
|------|-------------|---------|
| `useSingleTickerProvider()` | Creates a single ticker provider | `TickerProvider` |
| `useFocusNode({...})` | Creates a focus node | `FocusNode` |
| `useFocusScopeNode({...})` | Creates a focus scope node | `FocusScopeNode` |
| `useAppLifecycleState([initialState])` | Listens to app lifecycle state | `ReadonlySignal<AppLifecycleState?>` |
| `useScrollController({...})` | Creates a scroll controller | `ScrollController` |
| `usePageController({...})` | Creates a page controller | `PageController` |
| `useTabController({...})` | Creates a tab controller | `TabController` |
| `useFixedExtentScrollController({...})` | Creates a fixed extent scroll controller | `FixedExtentScrollController` |
| `useTextEditingController([text])` | Creates a text editing controller | `TextEditingController` |
| `useTextEditingController.fromValue([value])` | Creates a text editing controller from value | `TextEditingController` |

## Important Notes

### Automatic Cleanup

All hooks in this package automatically dispose their resources when the widget is unmounted. This ensures proper memory management and prevents leaks.

```dart
class MyWidget extends SetupWidget {
  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();
    // Controller is automatically disposed when MyWidget is removed from tree
    return ListView(controller: controller);
  }
}
```

### SetupWidget Integration

This package is designed to work with `SetupWidget` from `jolt_flutter`. The hooks rely on the lifecycle callbacks (`onMounted`, `onUnmounted`, etc.) provided by the setup system.

```dart
// Correct usage
class MyWidget extends SetupWidget {
  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();
    return ListView(controller: controller);
  }
}

// Incorrect - hooks won't work without SetupWidget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = useScrollController(); // Error: hooks require SetupWidget
    return ListView(controller: controller);
  }
}
```

### Multiple Tickers

If you need multiple tickers for different animation controllers, call `useSingleTickerProvider()` multiple times:

```dart
class MultiAnimationWidget extends SetupWidget {
  @override
  Widget build(BuildContext context) {
    final ticker1 = useSingleTickerProvider();
    final ticker2 = useSingleTickerProvider();
    
    final controller1 = AnimationController(vsync: ticker1);
    final controller2 = AnimationController(vsync: ticker2);
    
    return Column(
      children: [
        FadeTransition(opacity: controller1, child: Text('First')),
        FadeTransition(opacity: controller2, child: Text('Second')),
      ],
    );
  }
}
```

### Lifecycle State Reactivity

The `useAppLifecycleState` hook returns a reactive signal, allowing you to build reactive UI based on app lifecycle changes:

```dart
class LifecycleWidget extends SetupWidget {
  @override
  Widget build(BuildContext context) {
    final lifecycleState = useAppLifecycleState();
    
    return JoltBuilder(
      builder: (context) {
        switch (lifecycleState.value) {
          case AppLifecycleState.resumed:
            return Text('App is active');
          case AppLifecycleState.paused:
            return Text('App is paused');
          case AppLifecycleState.inactive:
            return Text('App is inactive');
          case AppLifecycleState.detached:
            return Text('App is detached');
          case null:
            return Text('Unknown state');
        }
      },
    );
  }
}
```

## Related Packages

Jolt Flutter Hooks is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider, and SetupWidget |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
