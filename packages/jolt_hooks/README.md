# Jolt Hooks

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_hooks](https://img.shields.io/pub/v/jolt_hooks?label=jolt_hooks)](https://pub.dev/packages/jolt_hooks)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A Flutter hooks integration package for [Jolt](https://pub.dev/packages/jolt) reactive state management. Jolt Hooks provides a comprehensive Hooks API built on [flutter_hooks](https://pub.dev/packages/flutter_hooks), enabling you to use Jolt's reactive primitives seamlessly within Flutter's hook system. All hooks automatically dispose their resources when the widget is removed from the tree, ensuring memory safety and preventing leaks.



## Quick Start

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_hooks/jolt_hooks.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
    return Scaffold(
      body: JoltBuilder(
        builder: (context) => Text('Count: ${count.value}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### Reactive Collections

```dart
class TodoListWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
    return Scaffold(
      body: HookBuilder(
        builder: (context) => useJoltWidget(() {
          return Text('Count: ${count.value}');
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## API Reference

| Hook | Description |
|------|-------------|
| `useSignal` | Creates a reactive signal |
| `useComputed` | Creates a computed signal |
| `useWritableComputed` | Creates a writable computed signal |
| `useConvertComputed` | Creates a type-converting signal |
| `useListSignal` | Creates a reactive list |
| `useMapSignal` | Creates a reactive map |
| `useSetSignal` | Creates a reactive set |
| `useIterableSignal` | Creates a reactive iterable |
| `useJoltEffect` | Creates a reactive effect |
| `useJoltWatcher` | Creates a watcher |
| `useJoltEffectScope` | Creates an effect scope |
| `useAsyncSignal` | Creates an async signal |
| `usePersistSignal` | Creates a persistent signal |
| `useJoltStream` | Creates a stream from a reactive value |
| `useJoltWidget` | Creates a reactive widget that rebuilds when dependencies change |

## Related Packages

Jolt Hooks is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |
