---
---

# Jolt Surge

## Overview

`jolt_surge` is inspired by the [Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit) pattern from [BLoC](https://bloclibrary.dev/), providing a lightweight state management pattern based on signals. It combines Jolt's reactive signal system with Flutter's state management by encapsulating state containers and providing convenient widgets, making state management both simple and powerful.

Similar to Cubit, Surge is a state container that modifies state through the `emit` method and accesses the current state through the `state` property. The difference is that Surge's internal implementation is based on Jolt Signals, meaning state is a trackable reactive value that can automatically establish dependencies and trigger corresponding side effects and UI rebuilds when state changes.

This design maintains both the predictability and simplicity of the Cubit pattern while fully leveraging Jolt Signals' reactive capabilities, enabling you to build efficient and maintainable state management solutions in Flutter.

## Surge

`Surge<State>` is a state container that encapsulates the core logic of state management. It maintains state through internal signals and provides the `emit` method to modify state and the `state` property to access the current state.

### Creating Surge

Extend the `Surge` class and implement your business logic:

```dart
import 'package:jolt_surge/jolt_surge.dart';

class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);
  
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  
  @override
  void onChange(Change<int> change) {
    // Optional: observe state transitions
    print('State changed from ${change.currentState} to ${change.nextState}');
  }
}
```

### Custom Create

By default, Surge uses `Signal` to store state. You can customize the state storage method through the `creator` parameter in the constructor:

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

This is useful for scenarios where you need to associate state with other signals, such as deriving state from other computed values.

### Surge Conventions

- **State Modification**: Modify state through the `emit(nextState)` method. `emit` automatically compares old and new states; if values are the same, no update is triggered, ensuring performance optimization.
- **State Access**: Access the current state through the `state` property. Accessing `state` tracks dependencies (equivalent to accessing `signal.value`), and all computed values and effects that depend on it will automatically establish dependencies.
- **State Tracking**: `state` is a trackable reactive value, meaning you can use it in reactive contexts like Effect and Computed, and dependencies will be automatically established.

```dart
final counterSurge = CounterSurge();

// Use in Effect, automatically tracked
Effect(() {
  print('Counter: ${counterSurge.state}');  // Automatically tracks dependencies
});

// Modify state
counterSurge.increment();  // Triggers Effect to re-execute
```

## SurgeProvider

`SurgeProvider` is used to provide Surge instances in the widget tree, similar to how `Provider` works. It supports two approaches: the `create` constructor and the `.value` constructor.

### Using create

Using the `create` constructor automatically manages the Surge's lifecycle, calling `dispose()` when the widget is unmounted:

```dart
SurgeProvider<CounterSurge>(
  create: (_) => CounterSurge(),  // Automatically disposed on unmount
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, surge) => Text('count: $state'),
  ),
);
```

### Using .value

When using the `.value` constructor, the Surge's lifecycle must be managed manually:

```dart
final surge = CounterSurge();

SurgeProvider<CounterSurge>.value(
  value: surge,  // Not automatically disposed, requires manual management
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, s) => Text('count: $state'),
  ),
);
```

### Accessing from Descendant Widgets

```dart
// Get Surge instance
final surge = context.read<CounterSurge>();

// Trigger state modification
ElevatedButton(
  onPressed: () => surge.increment(),
  child: const Text('Increment'),
);
```

## SurgeConsumer

`SurgeConsumer` is a unified consumption point that supports both `builder` and `listener`, providing fine-grained control over rebuilds and listening.

- **builder**: Builds UI, default is non-tracked (untracked), only rebuilds when `buildWhen` returns `true`
- **listener**: Handles side effects (such as showing SnackBar, sending analytics events, etc.), default is non-tracked, only executes when `listenWhen` returns `true`
- **buildWhen**: Controls whether to rebuild, default is tracked (can depend on external signals)
- **listenWhen**: Controls whether to execute the listener, default is tracked (can depend on external signals)

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next, s) => next.isEven,  // Only rebuild when even
  listenWhen: (prev, next, s) => next > prev,  // Only listen when increasing
  builder: (context, state, s) => Text('count: $state'),
  listener: (context, state, s) {
    // Side effect: show SnackBar or send analytics event
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count is now: $state')),
    );
  },
);
```

### Disabling Tracking

If you need to use external signals in conditions without tracking them, you can use `untracked`:

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
  // ...
);
```

## SurgeBuilder

`SurgeBuilder` is a convenience version of `SurgeConsumer` that only provides the `builder` functionality:

```dart
SurgeBuilder<CounterSurge, int>(
  builder: (context, state, surge) => Text('count: $state'),
  buildWhen: (prev, next, s) => next.isEven,  // Optional: conditional rebuild
);
```

## SurgeListener

`SurgeListener` is a convenience version of `SurgeConsumer` that only provides the `listener` functionality for handling side effects:

```dart
SurgeListener<CounterSurge, int>(
  listenWhen: (prev, next, s) => next > prev,  // Optional: conditional listening
  listener: (context, state, surge) {
    // Only handle side effects, don't build UI
    print('Count increased to: $state');
  },
  child: const SizedBox.shrink(),
);
```

## SurgeSelector

`SurgeSelector` provides fine-grained rebuild control, only rebuilding when the value returned by `selector` changes (via `==` comparison):

```dart
SurgeSelector<CounterSurge, int, String>(
  selector: (state, s) => state.isEven ? 'even' : 'odd',  // Default is tracked
  builder: (context, selected, s) => Text(selected),
);
```

The `selector` function is tracked by default and can depend on external signals. If you need to use external signals in the selector without tracking them, you can use `untracked`:

```dart
SurgeSelector<CounterSurge, int, String>(
  selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  builder: (context, selected, s) => Text(selected),
);
```

