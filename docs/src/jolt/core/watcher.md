---
---

# Watcher

Watcher is similar to Effect, but only collects dependencies in the sources function and executes side effects only when the sources' values change. Unlike Effect, Watcher can control execution through the `when` condition, and the callback function receives new and old values as parameters.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a signal
  final count = Signal(0);
  
  // Watch signal changes
  final watcher = Watcher(
    () => count.value,
    (newValue, oldValue) {
      print('Changed from $oldValue to $newValue');
    },
  );
  
  // Modify the signal's value
  count.value = 5; // Output: "Changed from 0 to 5"

  // Stop watching
  watcher.dispose();
}
```

## Creation

### Non-Immediate Execution (Default)

By default, Watcher does not execute immediately and only executes when the sources' values change:

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
);

count.value = 10; // Output: "Changed from 0 to 10"
```

### Immediate Execution

Using `immediately: true` makes Watcher execute once immediately upon creation:

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Value: $newValue');
  },
  immediately: true,
); // Immediately outputs: "Value: 0"

count.value = 10; // Output: "Value: 10"
```

You can also use the `Watcher.immediately` factory method:

```dart
final watcher = Watcher.immediately(
  () => count.value,
  (newValue, oldValue) {
    print('Value: $newValue');
  },
);
```

### Auto-Dispose After One Execution

Using `Watcher.once` creates a Watcher that automatically disposes after one execution:

```dart
final count = Signal(0);

final watcher = Watcher.once(
  () => count.value,
  (newValue, oldValue) {
    print('First change: $newValue');
  },
);

count.value = 1; // Output: "First change: 1", then auto-disposes
count.value = 2; // No longer responds
```

## Execution Conditions

By default, Watcher uses `==` for equality comparison to decide whether to execute side effects. It's recommended to use Records or direct objects with equality comparison as sources. You can also pass `when` to customize conditions:

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Value increased: $oldValue -> $newValue');
  },
  when: (newValue, oldValue) => newValue > oldValue,
);

count.value = 1; // Output: "Value increased: 0 -> 1"
count.value = 0; // No output (value decreased, condition not met)
count.value = 2; // Output: "Value increased: 0 -> 2"
```

**Note**: For mutable value signals (such as collection signals), Watcher's `when` may not work correctly because the collection object reference may not have changed. It's recommended to extract specific values from mutable values for comparison, or directly use `when: (_, _) => true` to allow any changes:

```dart
final items = ListSignal([1, 2, 3]);

Watcher(
  () => items.value,
  (newValue, oldValue) {
    print('List changed (any)');
  },
  when: (_, _) => true, // Accept any changes
);

Watcher(
  () => items.length, // Extract specific value
  (newValue, oldValue) {
    print('List length changed: $oldValue -> $newValue');
  },
);

items.add(4); // Both Watchers trigger
```

## Multiple Source Values

Watcher can watch multiple source values using Records or Lists as sources:

```dart
final count = Signal(0);
final name = Signal('Alice');

Watcher(
  () => (count.value, name.value), // Using Record
  (newValues, oldValues) {
    print('Count: ${newValues.$1}, Name: ${newValues.$2}');
  },
);

Watcher(
  () => [count.value, name.value], // Using List
  (newValues, oldValues) {
    print('Count: ${newValues[0]}, Name: ${newValues[1]}');
  },
);
```

## Manual Execution

You can use the `run()` method to manually trigger Watcher checks:

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Value: $newValue');
  },
);

watcher.run(); // Manually trigger check
```

## Pause and Resume

Watcher supports pause and resume functionality to temporarily stop responding to changes:

### pause

Pause Watcher, stop responding to changes:

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Value: $newValue');
  },
);

count.value = 1; // Output: "Value: 1"

watcher.pause(); // Pause

count.value = 2; // No longer responds
count.value = 3; // No longer responds

watcher.resume(); // Resume

count.value = 4; // Output: "Value: 4"
```

### resume

Resume Watcher, start responding to changes again:

```dart
watcher.resume(); // Only resume, don't execute immediately

watcher.resume(tryRun: true); // Resume and try to execute immediately
```

### isPaused

Check if Watcher is paused:

```dart
print(watcher.isPaused); // false

watcher.pause();
print(watcher.isPaused); // true

watcher.resume();
print(watcher.isPaused); // false
```

## Ignore Updates

Using `ignoreUpdates()` can temporarily ignore updates—during function execution, Watcher won't respond to changes:

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Value: $newValue');
  },
);

count.value = 1; // Output: "Value: 1"

watcher.ignoreUpdates(() {
  count.value = 2; // Callback not triggered
  count.value = 3; // Callback not triggered
});

count.value = 4; // Output: "Value: 4"
```

**Note**: `ignoreUpdates()` only prevents callback execution—source values still update normally. Changes during the ignore period don't update `oldValue`, but `newValue` reflects the latest state.

## Cleanup Functions

Watcher supports registering cleanup functions that execute before Watcher re-runs or when it's disposed. This is very useful for cleaning up subscriptions, canceling timers, and similar scenarios.

### onEffectCleanup

Use `onEffectCleanup` to register cleanup functions:

```dart
Watcher(
  () => count.value,
  (newValue, oldValue) {
    final timer = Timer.periodic(Duration(seconds: 1), (_) {
      print('Tick: $newValue');
    });
    
    // Register cleanup function, executes when Watcher re-runs or is disposed
    onEffectCleanup(() => timer.cancel());
  },
);
```

Cleanup functions execute in the following situations:
- Before Watcher re-runs (when sources values change)
- When Watcher is disposed (when `dispose()` is called)

**Note**: `onEffectCleanup` must be called in a synchronous context. If you need to use cleanup functions in async operations (such as `Future`, `async/await`), you should directly use the `watcher.onCleanUp()` method:

```dart
final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) async {
    final subscription = await someAsyncOperation();
    
    // In async context, directly use watcher.onCleanUp()
    watcher.onCleanUp(() => subscription.cancel());
  },
);
```

### onCleanUp

Directly use the Watcher instance's `onCleanUp()` method to register cleanup functions:

```dart
final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    // Side effect logic
  },
);

watcher.onCleanUp(() {
  // Cleanup logic
});
```

## Lifecycle Management

Watcher implements the `EffectNode` interface and has lifecycle management capabilities:

- **`dispose()`**: Dispose Watcher, clean up all dependencies and cleanup functions
- **`isDisposed`**: Check if Watcher is disposed

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
);

count.value = 10;

watcher.dispose(); // Dispose Watcher

count.value = 20; // No longer responds
```

Disposed Watchers no longer respond to dependency changes.

## Use Cases

### Value Change Monitoring

Watcher is perfect for monitoring specific value changes:

```dart
final user = Signal<User?>(null);

Watcher(
  () => user.value?.id,
  (newId, oldId) {
    if (newId != null && newId != oldId) {
      loadUserProfile(newId);
    }
  },
);
```

### Conditional Triggering

Using the `when` condition enables more precise trigger logic:

```dart
final score = Signal(0);

Watcher(
  () => score.value,
  (newScore, oldScore) {
    if (newScore >= 100) {
      showAchievement('Perfect score!');
    }
  },
  when: (newScore, oldScore) => newScore >= 100 && oldScore < 100,
);
```

### One-Time Monitoring

Using `Watcher.once` enables one-time monitoring:

```dart
final isLoading = Signal(true);

Watcher.once(
  () => isLoading.value,
  (isLoading, _) {
    if (!isLoading) {
      showWelcomeMessage();
    }
  },
);
```

## Important Notes

1. **Equality Comparison**: Watcher uses `==` for equality comparison—ensure values returned by sources have correct equality implementation.

2. **Mutable Values**: For mutable values (such as collections), it's recommended to extract specific values for comparison or use `when: (_, _) => true`.

3. **Paused State**: Paused Watchers clear dependencies and re-collect them when resumed.

4. **Ignore Updates**: `ignoreUpdates()` only prevents callback execution and does not prevent value updates.

## Related APIs

- [Effect](./effect.md) - Learn about side effect usage
- [EffectScope](./effect-scope.md) - Effect scope management
- [Signal](./signal.md) - Learn about signal usage
