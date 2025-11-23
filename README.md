# Jolt

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt](https://img.shields.io/pub/v/jolt?label=jolt)](https://pub.dev/packages/jolt)
[![jolt_flutter](https://img.shields.io/pub/v/jolt_flutter?label=jolt_flutter)](https://pub.dev/packages/jolt_flutter)
[![jolt_hooks](https://img.shields.io/pub/v/jolt_hooks?label=jolt_hooks)](https://pub.dev/packages/jolt_hooks)
[![jolt_surge](https://img.shields.io/pub/v/jolt_surge?label=jolt_surge)](https://pub.dev/packages/jolt_surge)
[![jolt_lint](https://img.shields.io/pub/v/jolt_lint?label=jolt_lint)](https://pub.dev/packages/jolt_lint)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Reactive state management for Dart and Flutter using signals, computed values, effects, and reactive collections. Focused on developer experience and efficiency with a concise API. Built on alien_signals for performance.

## Documentation

[Official Documentation](https://jolt.vowdemon.com)

## Packages

The Jolt ecosystem consists of five packages:

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
- `JoltProvider` - Resource management with lifecycle callbacks
- `JoltValueNotifier` - Integration with Flutter's ValueNotifier system

### [jolt_hooks](packages/jolt_hooks/) - Flutter Hooks Integration

Hooks API for using Jolt in HookWidget:
- `useSignal()` - Reactive signal hooks
- `useComputed()` - Computed value hooks
- `useAsyncSignal()` - Async state hooks
- `useJoltEffect()` - Side-effect hooks
- Reactive collection hooks: `useListSignal()`, `useMapSignal()`, `useSetSignal()`

### [jolt_surge](packages/jolt_surge/) - Signal-Powered Cubit Pattern

A state management pattern inspired by [BLoC's Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit), powered by Jolt Signals:
- `Surge<State>` - Reactive state container similar to Cubit
- `SurgeProvider` - Provides Surge instances to the widget tree
- `SurgeConsumer` - Unified widget for both building UI and handling side effects
- `SurgeBuilder`, `SurgeListener`, `SurgeSelector` - Convenience widgets

### [jolt_lint](packages/jolt_lint/) - Lint Tool

A lint tool designed for the Jolt ecosystem, providing code transformation assists and rule checks:
- Code transformation assists: Convert to/from Signal, wrap widgets with JoltBuilder/JoltProvider/JoltSelector
- Lint rules: `no_setup_this` rule to ensure Setup pattern purity
- IDE integration: Quick fixes and real-time code quality checks

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