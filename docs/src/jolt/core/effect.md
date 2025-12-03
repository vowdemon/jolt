---
---

# Effect

Effect is the most important part of the reactive system. It always actively collects dependencies and proactively runs when dependencies update. You can typically listen to signal changes here and execute side-effect operations.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a signal
  final count = Signal(0);
  
  // Subscribe to signal changes
  final effect = Effect(() {
    print('Count: ${count.value}');
  });
  
  // Modify the signal's value
  count.value = 5; // Output: "Count: 5"

  // Stop listening
  effect.dispose();
}
```

## Creation

### Immediate Execution (Default)

By default, Effect executes immediately upon creation and immediately collects dependencies:

```dart
final count = Signal(0);

Effect(() {
  print('Count: ${count.value}');
}); // Immediately outputs: "Count: 0" and collects dependencies

count.value = 10; // Output: "Count: 10"
```

### Lazy Dependency Collection

Using `lazy: true` delays dependency collection. Effect does not execute immediately and does not collect dependencies—you must manually call `run()` to start collecting dependencies. This is suitable for "define first, use later" scenarios:

```dart
final count = Signal(0);

// Define Effect first, but don't collect dependencies
final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true); // Does not execute immediately, does not collect dependencies

// Manually start collecting dependencies later
effect.run(); // Now starts collecting dependencies and executes, outputs: "Count: 0"

count.value = 10; // Output: "Count: 10"
```

You can also use the `Effect.lazy` factory method:

```dart
final effect = Effect.lazy(() {
  print('Count: ${count.value}');
});
```

**Use Cases**: Lazy dependency collection is mainly used when you need to define an Effect first and activate it later, such as defining it during component initialization and activating it at a specific time.

## Manual Execution

You can use the `run()` method to manually trigger Effect execution. For Effects with `lazy: true`, `run()` starts collecting dependencies and executes:

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true);

effect.run(); // Starts collecting dependencies and executes, outputs: "Count: 0"

count.value = 10; // Output: "Count: 10"
```

For non-lazy Effects, `run()` re-executes and updates dependencies:

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}); // Already executed and collected dependencies

effect.run(); // Re-executes, outputs: "Count: 0"
```

## Collecting Dependencies with trackWithEffect

In addition to using the `run()` method, you can manually collect dependencies through the `trackWithEffect` function:

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true);

// Manually collect dependencies using trackWithEffect
trackWithEffect(() {
  count.value;
}, effect);
```

`trackWithEffect` allows you to manually control the dependency collection process, which is useful in certain advanced scenarios.

## Cleanup Functions

Effect supports registering cleanup functions that execute before Effect re-runs or when it's disposed. This is very useful for cleaning up subscriptions, canceling timers, and similar scenarios.

### onEffectCleanup

Use `onEffectCleanup` to register cleanup functions:

```dart
Effect(() {
  final timer = Timer.periodic(Duration(seconds: 1), (_) {
    print('Tick');
  });
  
  // Register cleanup function, executes when Effect re-runs or is disposed
  onEffectCleanup(() => timer.cancel());
});
```

Cleanup functions execute in the following situations:
- Before Effect re-runs (when dependencies change)
- When Effect is disposed (when `dispose()` is called)

**Note**: `onEffectCleanup` must be called in a synchronous context. If you need to use cleanup functions in async operations (such as `Future`, `async/await`), you should directly use the `effect.onCleanUp()` method:

```dart
final effect = Effect(() async {
  final subscription = await someAsyncOperation();
  
  // In async context, directly use effect.onCleanUp()
  effect.onCleanUp(() => subscription.cancel());
});
```

### onCleanUp

Directly use the Effect instance's `onCleanUp()` method to register cleanup functions:

```dart
final effect = Effect(() {
  // Side effect logic
});

effect.onCleanUp(() {
  // Cleanup logic
});
```

## Lifecycle Management

Effect implements the `EffectNode` interface and has lifecycle management capabilities:

- **`dispose()`**: Dispose Effect, clean up all dependencies and cleanup functions
- **`isDisposed`**: Check if Effect is disposed

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
});

count.value = 10;

effect.dispose(); // Dispose Effect

count.value = 20; // No longer responds
```

Disposed Effects no longer respond to dependency changes.

## Use Cases

### Logging

Effect is perfect for logging:

```dart
final user = Signal<User?>(null);

Effect(() {
  if (user.value != null) {
    print('User logged in: ${user.value!.name}');
  } else {
    print('User logged out');
  }
});
```

### Synchronizing State

Effect can be used to synchronize different states:

```dart
final theme = Signal('light');
final darkMode = Signal(false);

Effect(() {
  darkMode.value = theme.value == 'dark';
});
```

### Side Effect Operations

Effect can execute various side effect operations:

```dart
final count = Signal(0);

Effect(() {
  // Update DOM
  document.getElementById('count')?.textContent = count.value.toString();
  
  // Send analytics event
  analytics.track('count_changed', {'value': count.value});
});
```

## Important Notes

1. **Avoid Infinite Loops**: Ensure that Effect does not modify signals it depends on internally, otherwise it may cause infinite loops:

```dart
final count = Signal(0);

Effect(() {
  print(count.value);
  count.value++; // ❌ Modifying signal it depends on, causes infinite loop
});
```

2. **Clean Up Resources**: Resources created in Effect (such as timers, subscriptions) should be released through cleanup functions to avoid memory leaks.

3. **Async Operations**: Effect functions can be async, but you need to pay attention to how cleanup functions are registered.

4. **Dependency Tracking**: Effect automatically tracks reactive values accessed through `.value`, `.get()`, or `call()` in the function.

## Related APIs

- [Watcher](./watcher.md) - More precise side effect control
- [EffectScope](./effect-scope.md) - Effect scope management
- [Signal](./signal.md) - Learn about signal usage
- [Computed](./computed.md) - Learn about computed property usage
