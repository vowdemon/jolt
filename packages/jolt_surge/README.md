# Jolt Surge

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_surge](https://img.shields.io/pub/v/jolt_surge?label=jolt_surge)](https://pub.dev/packages/jolt_surge)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A lightweight, signal-driven state management library for Flutter built on top of [Jolt Signals](https://pub.dev/packages/jolt). Jolt Surge provides a predictable state container pattern inspired by [BLoC's Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit), with fine-grained rebuild control, composable listeners, and selector-based rendering. Surge combines the simplicity and predictability of the Cubit pattern with the reactive capabilities of Jolt Signals, leveraging automatic dependency tracking to build highly efficient Flutter applications with minimal boilerplate.



## Quick Start

### Define a Surge

```dart
import 'package:jolt_surge/jolt_surge.dart';

class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);

  @override
  void onChange(Change<int> change) {
    // optional: observe transitions
  }
}
```

### Provide and consume

```dart
SurgeProvider<CounterSurge>(
  create: (_) => CounterSurge(), // auto-disposed on unmount
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state) => Text('count: $state'),
  ),
);
```

Using `.value` (you manage lifecycle):

```dart
final surge = CounterSurge();

SurgeProvider<CounterSurge>.value(
  value: surge, // not auto-disposed
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state) => Text('count: $state'),
  ),
);
```

### Actions (emit state)

```dart
ElevatedButton(
  onPressed: () => context.read<CounterSurge>().increment(),
  child: const Text('Increment'),
);
```

## Core Concepts

### Surge<State>

A reactive state container that manages state through Jolt Signals. It provides:
- `state`: Get the current state value (reactive, tracked)
- `emit(next)`: Emit a new state value
- `dispose()`: Clean up resources
- `onChange()`: Hook for observing state transitions

### Widgets

- **SurgeProvider**: Provides a Surge instance to the widget tree via `create` or `.value` constructors
- **SurgeConsumer**: Unified widget providing both `builder` and `listener` functionality with conditional controls
- **SurgeBuilder**: Convenience widget for builder-only functionality
- **SurgeListener**: Convenience widget for listener-only functionality (side effects)
- **SurgeSelector**: Fine-grained rebuild control using selector functions

### Tracking Semantics

Understanding tracking behavior is crucial for optimal performance:

- **Builder dependency tracking**: `builder` functions (in `SurgeBuilder`, `SurgeConsumer`, and `SurgeSelector`) are wrapped in `JoltBuilder`, allowing them to automatically track external signals, computed values, and other reactive dependencies accessed within the builder. When these dependencies change, the widget will automatically rebuild.
- **Non-tracked (untracked)**: `listener` functions are executed within an untracked context, preventing unnecessary reactive dependencies
- **Tracked by default**: `buildWhen`, `listenWhen`, and `selector` functions are tracked by default, allowing them to depend on external signals
- **Opt-out**: To disable tracking, wrap your reads with `untracked(() => ...)` or use `peek` property

## Comparison with Cubit

Jolt Surge provides **100% Cubit-compatible APIs**, making it a drop-in replacement for Cubit. Use `.full` constructors when you need access to the Surge instance in callbacks.

### Similarities

| Feature | Cubit | Surge |
|---------|-------|-------|
| State container | `Cubit<State>` | `Surge<State>` |
| State access | `state` getter | `state` getter (reactive) |
| State emission | `emit(State)` | `emit(State)` |
| Lifecycle hook | `onChange(Change)` | `onChange(Change)` |
| Disposal | `close()` | `dispose()` |
| Provider pattern | `BlocProvider` | `SurgeProvider` |
| Builder widget | `BlocBuilder` | `SurgeBuilder` (Cubit-compatible) |
| Consumer widget | `BlocConsumer` | `SurgeConsumer` (Cubit-compatible) |
| Listener widget | `BlocListener` | `SurgeListener` (Cubit-compatible) |
| Selector widget | `BlocSelector` | `SurgeSelector` (Cubit-compatible) |
| Conditional rebuild | `buildWhen` | `buildWhen` (Cubit-compatible) |
| Widget callback signature | `(context, state)` | `(context, state)` (Cubit-compatible) or `(context, state, surge)` (`.full`) |

### Key Differences

1. **Reactive Foundation**
   - **Cubit**: Built on Stream, requires explicit subscription management
   - **Surge**: Built on Jolt Signals, automatic dependency tracking and reactive updates

2. **State Access**
   - **Cubit**: `state` is a simple getter, no automatic dependency tracking
   - **Surge**: `state` is reactive and tracked, automatically creates dependencies in Effects and Computed

3. **Signal Integration**
   - **Cubit**: Limited ability to integrate with other reactive systems
   - **Surge**: Can depend on external Jolt signals in `builder`, `buildWhen`, `listenWhen`, and `selector` functions. Builder functions automatically track external dependencies via `JoltBuilder`.

4. **Performance Optimizations**
   - **Cubit**: Relies on Stream-based updates
   - **Surge**: Leverages Jolt's fine-grained dependency tracking for optimal rebuilds

5. **Widget Callback APIs**
   - **Cubit**: Callbacks receive `(context, state)`
   - **Surge**: Default callbacks receive `(context, state)`. Use `.full` constructors to access Surge instance: `(context, state, surge)`

### Code Example

The API is 100% compatible, making it a drop-in replacement:

```dart
// Cubit
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

BlocBuilder<CounterCubit, int>(
  builder: (context, state) => Text('Count: $state'),
);

// Surge (signal-powered Cubit) - Cubit-compatible API
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);
  void increment() => emit(state + 1);
}

SurgeBuilder<CounterSurge, int>(
  builder: (context, state) => Text('Count: $state'), // Same signature!
);
```

The main difference is the underlying reactive system: Cubit uses Streams, while Surge uses Jolt Signals, providing automatic dependency tracking and better performance optimizations.

## Widgets

All widgets support Cubit-compatible API by default. Use `.full` constructors to access the Surge instance in callbacks.

### SurgeConsumer

```dart
final externalSignal = Signal<String>('initial');

SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next) => next.isEven, // tracked
  listenWhen: (prev, next) => next > prev, // tracked
  builder: (context, state) {
    // Can access external signals - automatically tracked!
    final external = externalSignal.value;
    return Text('count: $state, external: $external');
  },
  listener: (context, state) {
    // e.g., SnackBar or analytics
  },
);

// With .full to access surge instance
SurgeConsumer<CounterSurge, int>.full(
  builder: (context, state, surge) => Text('${surge.doubled.value}'),
);
```

**Tracking:** 
- `builder` automatically tracks external signals, computed values, and reactive dependencies (via `JoltBuilder`)
- `listener` is non-tracked (executed in untracked context)
- `buildWhen` and `listenWhen` are tracked by default

### SurgeBuilder

```dart
final externalSignal = Signal<String>('initial');

SurgeBuilder<CounterSurge, int>(
  builder: (context, state) {
    // Can access external signals - automatically tracked!
    final external = externalSignal.value;
    return Text('count: $state, external: $external');
  },
  buildWhen: (prev, next) => next.isEven, // optional, tracked by default
);
```

**Tracking:** 
- `builder` automatically tracks external signals, computed values, and reactive dependencies (via `JoltBuilder`)
- `buildWhen` is tracked by default

### SurgeListener

```dart
SurgeListener<CounterSurge, int>(
  listener: (context, state) {
    // side-effect only
  },
  listenWhen: (prev, next) => next > prev, // optional
  child: const SizedBox.shrink(),
);
```

### SurgeSelector

Rebuild only when the selected value changes by equality.

```dart
final externalSignal = Signal<String>('initial');

SurgeSelector<CounterSurge, int, String>(
  selector: (state) => state.isEven ? 'even' : 'odd', // tracked by default
  builder: (context, selected) {
    // Can access external signals - automatically tracked!
    final external = externalSignal.value;
    return Text('$selected, external: $external');
  },
);
```

**Tracking:** 
- `builder` automatically tracks external signals, computed values, and reactive dependencies (via `JoltBuilder`)
- `selector` is tracked by default. Disable with `untracked(() => ...)`.

## Advanced Usage

### Custom State Creator

By default, Surge uses `Signal` to store state. You can customize the state storage mechanism using the `creator` parameter:

```dart
class CustomSurge extends Surge<int> {
  CustomSurge() : super(
    0,
    creator: (state) => WritableComputed(
      () => baseSignal.value,
      (value) => baseSignal.value = value,
    ),
  );
}
```

This is useful when you need to derive state from other signals or implement custom reactive behavior.

### SurgeObserver

Monitor Surge lifecycle events globally using `SurgeObserver`:

```dart
class MyObserver extends SurgeObserver {
  @override
  void onCreate(Surge surge) {
    print('Surge created: $surge');
  }

  @override
  void onChange(Surge surge, Change change) {
    print('State changed: ${change.currentState} -> ${change.nextState}');
  }

  @override
  void onDispose(Surge surge) {
    print('Surge disposed: $surge');
  }
}

// Set global observer
SurgeObserver.observer = MyObserver();
```

## Related Packages

Jolt Surge is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |

## Acknowledgments

Jolt Surge is inspired by the [Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit) pattern from the [BLoC](https://bloclibrary.dev/) library. We extend our gratitude to the BLoC team for their excellent design patterns and architectural insights that have influenced the development of this library.

## License

This project is part of the Jolt ecosystem. See individual package licenses for details.
