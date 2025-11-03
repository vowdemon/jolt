---
---

# Jolt

Jolt is a lightweight reactive state management library for Dart and Flutter.

## What is a Reactive System?

A reactive system automatically tracks data dependencies and updates accordingly. When you access reactive data, the system **automatically establishes dependencies**. When data changes, all computed values and effects that depend on it **automatically re-execute**, eliminating manual subscription management.

For example:

```dart
final count = Signal(0);  // Reactive state
final doubled = Computed(() => count.value * 2);  // Automatically tracks count

Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');  // Automatically tracks dependencies
});

count.value = 5;  // Automatically triggers Effect and Computed updates
```

This mechanism makes state management automated and efficient. You focus on data changes, and the system handles updates automatically.

## The Jolt Ecosystem

The Jolt ecosystem consists of the following packages:

### [jolt](https://pub.dev/packages/jolt)

Core library providing Signal, Computed, Effect, reactive collections, async state, and utilities. Works in pure Dart or Flutter projects.

### [jolt_flutter](https://pub.dev/packages/jolt_flutter)

Flutter widgets: JoltBuilder, JoltSelector, JoltProvider. Recommended for all Flutter projects.

### [jolt_hooks](https://pub.dev/packages/jolt_hooks)

Built on [flutter_hooks](https://pub.dev/packages/flutter_hooks), provides Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget.

### [jolt_surge](https://pub.dev/packages/jolt_surge)

Inspired by BLoC's Cubit pattern. Provides Surge, SurgeProvider, SurgeConsumer, SurgeSelector for component-based state management.

## Quick Start

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create reactive state
  final count = Signal(0);
  final doubled = Computed(() => count.value * 2);

  // React to changes
  Effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });

  count.value = 5; // Output: "Count: 5, Doubled: 10"
}
```

## Documentation Navigation

### Getting Started
- [Getting Started](./getting-started.md) - Installation and basic usage

### Core Concepts
- [Signal](./core/signal.md) - The foundation of reactive state
- [Computed](./core/computed.md) - Automatically derived values
- [Effect](./core/effect.md) - Side-effect handling
- [Watcher](./core/watcher.md) - Value change monitoring
- [EffectScope](./core/effect-scope.md) - Effect lifecycle management
- [Batch](./core/batch.md) - Batch updates for performance
- [Untracked](./core/untracked.md) - Non-tracking access

### Advanced Topics
- [Async Signal](./advanced/async-signal.md) - AsyncSignal, FutureSignal, StreamSignal
- [Collection Signal](./advanced/collection-signal.md) - ListSignal, SetSignal, MapSignal, IterableSignal
- [ConvertComputed](./advanced/convert-computed.md) - Type-converting signals
- [PersistSignal](./advanced/persist-signal.md) - Persistent signals
- [Stream](./advanced/stream.md) - Converting between signals and streams
- [Custom System](./advanced/custom-system.md) - Custom implementations

### Flutter Integration
- [Widgets](./flutter/widgets.md) - JoltProvider, JoltBuilder, JoltSelector
- [Hooks](./flutter/hooks.md) - jolt_hooks integration
- [Surge](./flutter/surge.md) - jolt_surge state container

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/vowdemon/jolt/blob/main/LICENSE) file for details.

