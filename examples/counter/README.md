# Counter Example

A minimal Flutter application demonstrating the core concepts of Jolt's reactive state management. This example showcases how to create and use reactive signals with the simplest possible use case.

## Overview

This counter app introduces you to Jolt's fundamental reactive primitives: **Signals** and **JoltBuilder**. It demonstrates how to create global reactive state and build UI that automatically updates when the state changes.

## Features

- **Reactive State**: Uses a global `Signal` to manage the counter value
- **Automatic UI Updates**: The UI rebuilds automatically when the signal value changes
- **Simple API**: Minimal code required to achieve reactivity

## Jolt Concepts Demonstrated

### Signal

Signals are the foundation of Jolt's reactivity system. They hold a value and notify listeners when that value changes.

```dart
final counter = Signal(0);
```

### JoltBuilder

`JoltBuilder` is a widget that automatically rebuilds when any accessed signals change. It tracks signal dependencies automatically.

```dart
JoltBuilder(
  builder: (context) => Text('$counter'),
)
```

### Mutating Signals

You can update signal values directly, and all dependent widgets will rebuild automatically:

```dart
counter.value++;  // Increment
counter.value--;  // Decrement
```

## Running the Example

```bash
cd examples/counter
flutter run
```

## Key Takeaways

1. **Global State**: Signals can be defined at the top level and accessed anywhere
2. **Automatic Tracking**: `JoltBuilder` automatically tracks which signals are accessed
3. **Simple Updates**: Changing a signal's value triggers automatic UI updates
4. **No Boilerplate**: No need for `setState`, `ValueNotifier`, or complex state management setup

This example is perfect for understanding the basics before moving on to more complex examples like the shopping cart or todo list.
