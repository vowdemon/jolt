---
---

# Surge

Surge is a lightweight state management library based on Jolt Signals, inspired by the [Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit) pattern from the [BLoC](https://bloclibrary.dev/) library. It combines Jolt's reactive signal system with Flutter's state management capabilities, providing a predictable and simple state management solution.

## Installation

```bash
flutter pub add jolt_surge
```

## Core Concepts

### Surge

`Surge` is a state container class for managing state and reactively notifying changes. It internally uses Jolt's `Signal` to manage state and provides the `emit` method to update state.

### Basic Usage

```dart
import 'package:jolt_surge/jolt_surge.dart';

// Create a Surge
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// Usage
final counter = CounterSurge();
print(counter.state); // 0
counter.increment();
print(counter.state); // 1
```

## Creating Surge

### Basic Creation

```dart
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);
  
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}
```

### Custom State Creator

You can customize state management through the `creator` parameter:

```dart
class CustomSurge extends Surge<int> {
  CustomSurge(int initial) : super(
    initial,
    creator: (state) => WritableComputed(
      () => state,
      (value) => state = value,
    ),
  );
}
```

## State Access

### state

Get the current state value. When accessed in reactive contexts, dependencies are automatically established.

```dart
final surge = CounterSurge();
print(surge.state); // 0

Effect(() => print('State: ${surge.state}'));
surge.emit(1); // Effect outputs: "State: 1"
```

### raw

Get the underlying reactive value (`WritableNode`) for advanced scenarios.

```dart
final surge = CounterSurge();
final rawValue = surge.raw;
rawValue.value = 43; // Directly set value
```

### stream

Get a stream of state changes.

```dart
final surge = CounterSurge();
surge.stream.listen((state) => print('State changed: $state'));

surge.emit(1); // Output: "State changed: 1"
surge.emit(2); // Output: "State changed: 2"
```

## State Updates

### emit

Emit new state and trigger change notifications.

```dart
final surge = CounterSurge();
surge.emit(1); // State changes from 0 to 1
surge.emit(1); // No change (same value)
surge.emit(2); // State changes from 1 to 2
```

**Note**:
- If the new state is the same as the current state (via `==` comparison), no update is triggered
- State is updated after `onChange` method is called
- If Surge is already disposed, calling `emit` throws an assertion error

## Lifecycle

### onChange

Called when state changes. Subclasses can override this method to add custom change handling logic.

```dart
class MySurge extends Surge<int> {
  MySurge() : super(0);

  @override
  void onChange(Change<int> change) {
    print('State changing from ${change.currentState} to ${change.nextState}');
    super.onChange(change);
  }
}
```

### onDispose

Called when Surge is disposed. Subclasses can override this method to add custom cleanup logic.

```dart
class MySurge extends Surge<int> {
  MySurge() : super(0);
  Timer? _timer;

  @override
  void onDispose() {
    _timer?.cancel();
    _timer = null;
    super.onDispose();
  }
}
```

### dispose

Dispose Surge and clean up resources. This method is idempotent—multiple calls have no side effects.

```dart
final surge = CounterSurge();
surge.dispose();
// surge.emit(1); // Throws assertion error
```

## Change

The `Change` class encapsulates state change information, containing the current state and next state.

```dart
final change = Change(currentState: 0, nextState: 1);
print('Changing from ${change.currentState} to ${change.nextState}');
```

## SurgeObserver

`SurgeObserver` is an abstract observer class for monitoring Surge lifecycle events.

### Creating Observer

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
```

### Setting Global Observer

```dart
SurgeObserver.observer = MyObserver();

// Now all Surge lifecycle events will be observed
final surge = CounterSurge();
// onCreate is called

surge.emit(1);
// onChange is called

surge.dispose();
// onDispose is called
```

## Complete Example

```dart
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  void reset() => emit(0);
}

// Usage
void main() {
  final counter = CounterSurge();
  
  // Listen to state changes
  counter.stream.listen((state) {
    print('Counter: $state');
  });
  
  counter.increment(); // Output: "Counter: 1"
  counter.increment(); // Output: "Counter: 2"
  counter.decrement(); // Output: "Counter: 1"
  counter.reset();     // Output: "Counter: 0"
  
  counter.dispose();
}
```

## Important Notes

1. **State Immutability**: Although Surge allows updating state through `emit`, it's recommended to keep state immutable, creating new state on each `emit`.

2. **Lifecycle Management**: When using `SurgeProvider`, Surge lifecycle is automatically managed. When creating manually, remember to call `dispose()`.

3. **Performance Considerations**: Surge internally uses Signal, providing efficient reactive update mechanisms.

4. **Type Safety**: Surge provides complete type safety with compile-time type checking.

5. **Test-Friendly**: Surge's design makes it easy to test, allowing easy mocking and verification of state changes.

