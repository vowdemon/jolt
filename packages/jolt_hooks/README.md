# Jolt Hooks

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_hooks](https://img.shields.io/pub/v/jolt_hooks?label=jolt_hooks)](https://pub.dev/packages/jolt_hooks)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A Flutter hooks integration package for [Jolt](https://pub.dev/packages/jolt) reactive state management. Jolt Hooks provides a comprehensive Hooks API built on [flutter_hooks](https://pub.dev/packages/flutter_hooks), enabling you to use Jolt's reactive primitives seamlessly within Flutter's hook system. All hooks automatically dispose their resources when the widget is removed from the tree, ensuring memory safety and preventing leaks.

## Features

- **Unified API**: All hooks use a consistent class-based API with method chaining for better extensibility
- **Type-safe**: Full type safety with Dart's type system
- **Automatic disposal**: All reactive resources are automatically cleaned up when widgets are disposed
- **Comprehensive**: Supports signals, computed values, effects, watchers, and reactive collections
- **Flexible**: Works seamlessly with both `HookWidget` and `HookBuilder` patterns



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
    final todos = useSignal.list<String>([]);
    
    return Scaffold(
      body: JoltBuilder(
        builder: (context) => Column(
          children: [
            ...todos.value.map((todo) => ListTile(title: Text(todo))),
            ElevatedButton(
              onPressed: () => todos.add('New Todo'),
              child: Text('Add Todo'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## API Reference

### Signal Hooks

| Hook | Description |
|------|-------------|
| `useSignal(value)` | Creates a reactive signal with initial value |
| `useSignal.lazy()` | Creates a lazy signal without initial value |
| `useSignal.list(value)` | Creates a reactive list signal |
| `useSignal.map(value)` | Creates a reactive map signal |
| `useSignal.set(value)` | Creates a reactive set signal |
| `useSignal.iterable(getter)` | Creates a reactive iterable signal |
| `useSignal.async(source)` | Creates an async signal for managing async operations |
| `useSignal.persist(initialValue, read, write)` | Creates a persistent signal with automatic storage |

### Computed Hooks

| Hook | Description |
|------|-------------|
| `useComputed(getter)` | Creates a computed signal that derives from dependencies |
| `useComputed.writable(getter, setter)` | Creates a writable computed signal |
| `useComputed.convert(source, decode, encode)` | Creates a type-converting computed signal |

### Effect Hooks

| Hook | Description |
|------|-------------|
| `useJoltEffect(fn, {lazy})` | Creates a reactive effect that runs when dependencies change |
| `useJoltEffect.lazy(fn)` | Creates an effect that runs immediately upon creation |

### Watcher Hooks

| Hook | Description |
|------|-------------|
| `useWatcher(sourcesFn, fn, {immediately, when})` | Creates a watcher that observes specific sources |
| `useWatcher.immediately(sourcesFn, fn, {when})` | Creates a watcher that executes immediately |
| `useWatcher.once(sourcesFn, fn, {when})` | Creates a watcher that executes only once |

### Utility Hooks

| Hook | Description |
|------|-------------|
| `useEffectScope({fn})` | Creates an effect scope for managing effect lifecycles |
| `useJoltStream(value)` | Creates a stream from a reactive value |
| `useJoltWidget(builder)` | Creates a reactive widget that rebuilds when dependencies change |

## Related Packages

Jolt Hooks is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |
