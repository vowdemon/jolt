---
---

# Watcher

Watcher is similar to Effect, but only collects dependencies from the `sources` function and executes side effects when the `sources` value changes. Unlike Effect, Watcher can control execution through a `when` condition, and the callback function receives both the new and old values as parameters.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a signal
  final count = Signal(0);
  
  // Watch for signal changes
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

### Immediate Execution

Use `immediately: true` to make Watcher execute immediately upon creation:

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Value: $newValue');
  },
  immediately: true,
);

count.value = 10;
```

### Non-Immediate Execution

By default, Watcher does not execute immediately; it only executes when the `sources` value changes:

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
);

count.value = 10;
```

## Execution Condition

By default, Watcher uses `==` equality comparison to determine whether to execute the side effect. It's recommended to use Record or direct objects with equality comparison as sources. You can also pass a custom `when` condition:

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

**Note**: For mutable value signals (such as collection signals), Watcher's `when` may not work correctly because the collection object reference may not have changed. It's recommended to extract specific values from mutable values for comparison, or use `when: () => true` to allow any change:

```dart
final items = ListSignal([1, 2, 3]);

Watcher(
  () => items.value,
  (newValue, oldValue) {
    print('List changed (any)');
  },
  when: (_, _) => true, // Accept any change
);

Watcher(
  () => items.length, // () => items.value.length
  (newValue, oldValue) {
    print('List changed (length)');
  },
)

Watcher(
  () => items.value,
  (newValue, oldValue) {
    print('List cannot be watched');
  },
)

items.add(4);
```

## Disposal

When a Watcher is no longer needed, you should call the `dispose()` method to destroy it and clean up dependencies:

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
);

count.value = 10;

watcher.dispose();

count.value = 20;
```

A disposed Watcher will no longer respond to dependency changes.

