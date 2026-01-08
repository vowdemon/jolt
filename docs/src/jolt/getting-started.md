---
---

# Getting Started

This guide will help you quickly get started with the Jolt reactive state management library.

## Installation

Install Jolt using the `pub add` command:

```bash
# Install core package
dart pub add jolt
```

For Flutter projects, it's recommended to install `jolt_flutter`:

```bash
# Recommended: Flutter Widget integration
flutter pub add jolt_flutter
```

For the Composition API and Setup Widget pattern, install `jolt_setup`:

```bash
# Composition API with automatic resource cleanup
flutter pub add jolt_setup
```

If using Flutter Hooks, you can install `jolt_hooks`:

```bash
# Optional: flutter_hooks integration
flutter pub add jolt_hooks
```

If you prefer the Cubit pattern, you can install `jolt_surge`:

```bash
# Optional: Surge pattern (similar to BLoC's Cubit)
flutter pub add jolt_surge
```

## Next Steps

### Core Concepts

- Check out [Signal](./core/signal.md) to learn the basics of signals
- Read [Computed](./core/computed.md) to learn about derived values
- Explore [Effect](./core/effect.md) for handling side effects
- Learn about [Watcher](./core/watcher.md) for fine-grained control
- Study [EffectScope](./core/effect-scope.md) for managing effect lifecycles
- Use [Batch](./core/batch.md) to optimize batch update performance
- Control [Track](./core/track.md) for fine-grained reactive dependency management
- Check out [Extensions](./core/extensions.md) for convenient conversion methods

### Flutter Integration

- Use [Flutter Widgets](./flutter/widgets.md) to build reactive UIs
- Learn about [ValueNotifier Integration](./flutter/value-notifier.md) for integrating with Flutter's system
- Use [FlutterEffect](./flutter/flutter-effect.md) for handling UI side effects
- Explore [SetupWidget](./flutter/setup-widget.md) for the composition-based API

### Hooks

- Use [Jolt Hooks](./flutter/flutter-hooks.md) to use reactive primitives in HookWidget
- Use Flutter resource Hooks in [SetupWidget](./flutter/setup-widget.md)

### Surge Pattern

- Learn about [Surge](./surge/surge.md) state management pattern
- Use [Surge Widgets](./surge/widgets.md) to use Surge in Flutter
- Configure [SurgeObserver](./surge/observer.md) to monitor state changes

### Advanced Features

- Handle [Async Signal](./advanced/async-signal.md) for managing async operations
- Use [Collection Signal](./advanced/collection-signal.md) for handling reactive collections
- Learn about [ConvertComputed](./advanced/convert-computed.md) for type conversion
- Use [PersistSignal](./advanced/persist-signal.md) to save and restore state
- Integrate [Stream](./advanced/stream.md) for stream API integration
- Learn [Extending Jolt](./advanced/extending-jolt.md) to create custom reactive primitives and tools

### Development Tools

- Use [Jolt Lint](./lint/lint.md) for code transformation assists and rule checking
