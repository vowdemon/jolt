# Jolt

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt](https://img.shields.io/pub/v/jolt?label=jolt)](https://pub.dev/packages/jolt)
[![jolt_flutter](https://img.shields.io/pub/v/jolt_flutter?label=jolt_flutter)](https://pub.dev/packages/jolt_flutter)
[![jolt_setup](https://img.shields.io/pub/v/jolt_setup?label=jolt_setup)](https://pub.dev/packages/jolt_setup)
[![jolt_hooks](https://img.shields.io/pub/v/jolt_hooks?label=jolt_hooks)](https://pub.dev/packages/jolt_hooks)
[![jolt_surge](https://img.shields.io/pub/v/jolt_surge?label=jolt_surge)](https://pub.dev/packages/jolt_surge)
[![jolt_lint](https://img.shields.io/pub/v/jolt_lint?label=jolt_lint)](https://pub.dev/packages/jolt_lint)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Reactive state management for Dart and Flutter using signals, computed values, effects, and reactive collections. Focused on developer experience and efficiency with a concise API. Built on alien_signals for performance.

## Documentation

[Official Documentation](https://jolt.vowdemon.com)

## Packages

The Jolt ecosystem consists of six packages:

### [jolt](packages/jolt/) - Core Library

The foundation of Jolt, providing reactive primitives for Dart and Flutter:
- `Signal<T>` - Reactive state containers
- `Computed<T>` - Automatically computed derived values
- `Effect` - Side-effect functions
- `AsyncSignal<T>` - Async state management
- Reactive collections: `ListSignal`, `MapSignal`, `SetSignal`, `IterableSignal`

### [jolt_flutter](packages/jolt_flutter/) - Flutter Integration

Flutter-specific widgets and utilities for reactive UI:
- `JoltBuilder` - Automatic reactive UI updates
- `JoltSelector` - Fine-grained selector updates
- `JoltValueNotifier` - Integration with Flutter's ValueNotifier system

### [jolt_setup](packages/jolt_setup/) - Setup Widget & Composition API

Composition API similar to Vue's Composition API for Flutter, with automatic resource management:
- `SetupWidget` - Composition-based widget with `setup()` function
- `SetupMixin` - Add composition API to existing StatefulWidgets
- `SetupBuilder` - Inline composition API for quick prototyping
- Automatic resource cleanup - No manual dispose() needed
- Rich hook library - Controllers, focus nodes, animations, lifecycle, and more

### [jolt_hooks](packages/jolt_hooks/) - Flutter Hooks Integration

Integration with flutter_hooks for using Jolt primitives in HookWidget:
- `useSignal()` - Create reactive signals in hooks
- `useComputed()` - Computed values that rebuild on changes
- `useJoltEffect()` - Side effects with automatic cleanup
- `useJoltWidget()` - Fine-grained reactive widgets
- Collection variants: `useSignal.list()`, `useSignal.map()`, `useSignal.set()`
- Compatible with Flutter Hooks patterns - runs on every build

### [jolt_surge](packages/jolt_surge/) - Signal-Powered Cubit Pattern

A state management pattern inspired by [BLoC's Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit), powered by Jolt Signals:
- `Surge<State>` - Reactive state container similar to Cubit
- `SurgeProvider` - Provides Surge instances to the widget tree
- `SurgeConsumer` - Unified widget for both building UI and handling side effects
- `SurgeBuilder`, `SurgeListener`, `SurgeSelector` - Convenience widgets

### [jolt_lint](packages/jolt_lint/) - Lint & Code Assists

Custom lint rules and code assists for the Jolt ecosystem:
- **Hook Rules Enforcement** - Ensures hooks are only called in setup or other hooks
- **Code Assists** - Quick fixes for converting between patterns, wrapping widgets
- **Compile-time Safety** - Catches async/callback hook usage before runtime
- **IDE Integration** - Real-time feedback and automatic fixes in your editor
- **Pattern Validation** - Enforces best practices for Setup Widget and reactive patterns

## Quick Start

```dart
import 'package:jolt/jolt.dart';

void main() {
  final count = Signal(0);
  final doubled = Computed(() => count.value * 2);
  
  Effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });
  
  count.value = 5; // Prints: "Count: 5, Doubled: 10"
}
```

## Related Links

- [Official Documentation](https://jolt.vowdemon.com) - Complete guides and API reference
- [BLoC's Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit) - Design pattern inspiration for jolt_surge
- [alien_signals](https://github.com/stackblitz/alien-signals) - Underlying reactive engine
- [Flutter Hooks](https://pub.dev/packages/flutter_hooks) - Flutter Hooks system

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.