# Jolt Flutter

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_flutter](https://img.shields.io/pub/v/jolt_flutter?label=jolt_flutter)](https://pub.dev/packages/jolt_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Flutter integration for [Jolt](https://pub.dev/packages/jolt). Provides widgets like `JoltBuilder` and `JoltSelector` to use Jolt's reactive system in Flutter. Also includes bidirectional `ValueNotifier` conversion.

> **📦 Package Exports**
> 
> `jolt_flutter` re-exports all APIs from the `jolt` package, so you only need to import `jolt_flutter` to access all Jolt reactive primitives (Signal, Computed, Effect, etc.).

## Usage

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

JoltBuilder(
  builder: (context) => Text('Count: ${counter.value}'),
)
```

## Core Widgets

### JoltBuilder

Automatically rebuilds when any signal accessed in its builder changes:

```dart
final counter = Signal(0);
final name = Signal('Flutter');

JoltBuilder(
  builder: (context) => Column(
    children: [
      Text('Hello ${name.value}'),
      Text('Count: ${counter.value}'),
      ElevatedButton(
        onPressed: () => counter.value++,
        child: Text('Increment'),
      ),
    ],
  ),
)
```

### JoltSelector

Rebuilds only when a specific selector function's result changes:

```dart
final user = Signal(User(name: 'John', age: 30));

// Only rebuilds when the user's name changes, not age
JoltSelector(
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
)
```

The `selector` function receives the previous selected value (or `null` on first run) and returns the new value to watch. Rebuilds occur only when the returned value changes.

## ValueNotifier Integration

### Converting Jolt Signals to ValueNotifier

Bridge Jolt signals with Flutter's ValueNotifier system using the extension:

```dart
final counter = Signal(0);
final notifier = counter.notifier; // Returns JoltValueNotifier

// Use with AnimatedBuilder
AnimatedBuilder(
  animation: notifier,
  builder: (context, child) => Text('Count: ${notifier.value}'),
)

// Use with ValueListenableBuilder
ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('Count: $value'),
)
```

### Converting ValueNotifier to Jolt Signal

Convert Flutter's ValueNotifier to Jolt signals for bidirectional sync:

```dart
final notifier = ValueNotifier(0);
final signal = notifier.toNotifierSignal();

// Changes sync bidirectionally
notifier.value = 1; // signal.value becomes 1
signal.value = 2;   // notifier.value becomes 2
```

### Automatic Synchronization

ValueNotifier automatically syncs with Jolt signal changes:

```dart
final signal = Signal(0);
final notifier = signal.notifier;

// Changes to signal automatically update notifier
signal.value = 42; // notifier.value is now 42
```

## Related Packages

Jolt Flutter is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_setup](https://pub.dev/packages/jolt_setup) | Setup Widget API and Flutter hooks: SetupWidget, SetupMixin, useTextEditingController, useScrollController, etc. |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |
| [jolt_lint](https://pub.dev/packages/jolt_lint) | Custom lint and code assists: Wrap widgets, convert to/from Signals, Hook conversions |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
