---
---

# Computed

Computed is a lazy derived value in the reactive system. It only recomputes when subscribed to and when dependencies change, with automatic caching that efficiently handles expensive computations.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create dependent signals
  final firstName = Signal('John');
  final lastName = Signal('Doe');
  
  // Create computed value
  final fullName = Computed(() => '${firstName.value} ${lastName.value}');
  
  // Subscribe to computed value changes
  Effect(() {
    print('Full name: ${fullName.value}');
  });
  
  // Modify dependencies
  firstName.value = 'Jane'; // Output: "Full name: Jane Doe"
}
```

## Creation

Create a computed value using the `Computed` constructor, passing a getter function:

```dart
final count = Signal(0);

final doubled = Computed(() => count.value * 2);
```

Computed is lazy—it only computes when accessed. If there are no subscribers, the getter function may never execute.

### Custom Equality Comparison

You can provide a custom equality function to control when the computed value is considered "changed". This is useful for complex types like lists or maps where you want to compare by value rather than reference:

```dart
final signal = Signal<List<int>>([1, 2, 3]);

final computed = Computed<List<int>>(
  () => List<int>.from(signal.value),
  equals: (a, b) {
    if (a is! List<int> || b is! List<int>) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  },
);

Effect(() {
  print('Computed: ${computed.value}');
});

signal.value = [1, 2, 3]; // Same values, different instance
// Effect won't trigger because equals returns true
```

When `equals` returns `true`, the computed value is considered unchanged and subscribers won't be notified, even if a new computation occurs.

## Reading Values

### `.value`

Use the `.value` property to read values—**this creates reactive dependencies and triggers computation**. If dependencies have changed, it recomputes; otherwise, it returns the cached value.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled.value); // Using .value
});

count.value = 5; // Triggers recomputation
```

You can also use the `call()` extension method for a function-like syntax:

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled()); // Using call() extension, equivalent to .value
});

count.value = 5; // Triggers recomputation
```

### `.peek`

Use the `.peek` property to read computed values—**does not establish reactive dependencies but will recompute** (if dependencies have changed). This ensures you get the latest computed result without creating dependencies.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  final tracked = doubled.value; // Establishes dependency
  final untracked = doubled.peek; // Does not establish dependency, but recomputes
});

count.value = 10; // tracked updates, untracked does not trigger Effect
```

### `.peekCached`

Use the `.peekCached` property to read **cached computed values**—does not establish reactive dependencies and does not recompute. If dependencies have changed but haven't been accessed, the returned value may be stale.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

print(doubled.peekCached); // Returns cached value, computes once if cache doesn't exist

count.value = 10; // Dependency changed

print(doubled.peekCached); // Still returns old value (0), because not recomputed
print(doubled.value); // Triggers recomputation, returns new value (20)
```

**Difference between `peek` and `peekCached`**:

- **`peek`**: Always recomputes (if needed), ensures latest result, but does not establish dependencies
- **`peekCached`**: Only returns cached value, computes only if cache doesn't exist, more efficient but may return stale values

```dart
final expensive = Computed(() => heavyCalculation());

// Need latest value but don't establish dependency
final latest = expensive.peek; // Will recompute

// Only need quick check of cached value
final cached = expensive.peekCached; // Returns cache immediately, no recomputation
```

### `Computed.getPeek<T>()`

The static method `Computed.getPeek<T>()` allows you to access the pending value (the value being computed) from within a computed getter function. This is useful for advanced scenarios where you need to compare with the previous value or perform mutations.

**Important:** This method can only be called from within a computed getter function. Calling it outside will throw a `StateError`.

```dart
final signal = Signal(0);
int? previousValue;

final computed = Computed<int>(() {
  signal.value; // Track dependency
  previousValue = Computed.getPeek<int>(); // Get previous pending value
  return signal.value * 2;
});

computed.value; // previousValue is null (first computation)
signal.value = 5;
computed.value; // previousValue is 0 (previous pending value)
```

This is particularly useful when implementing custom logic that needs to compare with the previous computed value or when working with mutable collections.

## Manual Notification

If you need to manually tell subscribers that it has updated, you can use the `notify()` method. The `notify()` method accepts an optional `force` parameter:

- **`notify(false)` or `notify()`** (soft update): Only notifies subscribers if the computed value actually changed during recomputation. This is the default behavior.
- **`notify(true)`** (force update): Always notifies subscribers, even if the value hasn't changed.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print('Doubled: ${doubled.value}');
});

count.value = 5; // First output: "Doubled: 10"

doubled.notify(false); // No output (value unchanged)
doubled.notify(true); // Output: "Doubled: 10" (force update)
```

**When to use force updates:**
- When you need to force subscribers to re-evaluate even if the value appears unchanged
- When working with mutable objects where internal state may have changed
- When using custom equality functions and you want to bypass the equality check

## Lifecycle Management

Computed implements the `ReadonlyNode` interface and has lifecycle management capabilities:

- **`dispose()`**: Release resources (similar to Signal)
- **`isDisposed`**: Check if disposed (similar to Signal)

Computed values that are no longer used should call `dispose()` to release resources.

## Writable Computed Values

`WritableComputed` allows you to create a computed value that can be both read and written. When written to, it calls the setter function to update underlying dependencies. **The setter function executes in a batch**, meaning all signal updates in the setter are batched together, and subscribers only receive one notification after all updates complete.

### Creating Writable Computed Values

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

final fullName = WritableComputed(
  () => '${firstName.value} ${lastName.value}',
  (value) {
    final parts = value.split(' ');
    firstName.value = parts[0];
    lastName.value = parts[1];
  },
);
```

### Reading and Writing

```dart
final count = Signal(0);

final doubled = WritableComputed(
  () => count.value * 2,
  (value) => count.value = value ~/ 2,
);

Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');
});

doubled.value = 10; // Output: "Count: 5, Doubled: 10"
```


### Batch Execution

`WritableComputed`'s setter executes in a batch, meaning all dependency updates are batched together:

```dart
final a = Signal(0);
final b = Signal(0);

final sum = WritableComputed(
  () => a.value + b.value,
  (value) {
    a.value = value ~/ 2;
    b.value = value ~/ 2;
  },
);

var effectCount = 0;
Effect(() {
  sum.value;
  effectCount++;
});

sum.value = 10; // effectCount only increases by 1, not 2
// Because a and b updates are in the same batch
```

### Type System

`WritableComputed<T>` implements both `Computed<T>` and `Signal<T>` interfaces, so you can use all methods from Signal and Computed.

## Use Cases

### Derived State

Computed is most commonly used for derived state:

```dart
class TodoApp {
  final todos = Signal<List<Todo>>([]);
  final filter = Signal<TodoFilter>(TodoFilter.all);

  // Derived: filtered todos
  final filteredTodos = Computed(() {
    final all = todos.value;
    switch (filter.value) {
      case TodoFilter.all:
        return all;
      case TodoFilter.active:
        return all.where((t) => !t.completed).toList();
      case TodoFilter.completed:
        return all.where((t) => t.completed).toList();
    }
  });

  // Derived: statistics
  final stats = Computed(() {
    final all = todos.value;
    return TodoStats(
      total: all.length,
      active: all.where((t) => !t.completed).length,
      completed: all.where((t) => t.completed).length,
    );
  });
}
```

### Two-Way Binding

`WritableComputed` is suitable for scenarios requiring two-way binding:

```dart
class FormField {
  final _value = Signal('');

  // Writable computed value: formatted display
  final displayValue = WritableComputed(
    () => _value.value.toUpperCase(),
    (value) => _value.value = value.toLowerCase(),
  );
}
```

### Expensive Computations

Computed's caching mechanism makes it perfect for expensive computations:

```dart
final data = Signal<List<Data>>([]);

// Expensive computation will be cached
final processed = Computed(() {
  return data.value.map((item) {
    // Complex processing logic
    return expensiveProcessing(item);
  }).toList();
});

// Multiple accesses won't recompute
print(processed.value); // Computes once
print(processed.value); // Uses cache
data.value = newData; // Dependency changed
print(processed.value); // Recomputes
```

## Important Notes

1. **Lazy Computation**: Computed only computes when accessed. If there are no subscribers, the getter function may never execute.

2. **Caching Mechanism**: Computed automatically caches computation results and only recomputes when dependencies change.

3. **Dependency Tracking**: Using `.value` or `call()` in the getter function to access other reactive values establishes dependencies. Using `.peek` does not establish dependencies.

4. **`peek` vs `peekCached`**:
   - Use `peek` when you need the latest value but don't want to establish dependencies
   - Use `peekCached` when you only need a quick check of the cached value

5. **WritableComputed Batch**: All updates in the setter execute in the same batch, and subscribers only receive one notification.

6. **Lifecycle**: Computed values that are no longer used should call `dispose()` to release resources.

## Related APIs

- [Signal](./signal.md) - Learn about basic signal usage
- [Effect](./effect.md) - Reactive side effects
- [Batch](./batch.md) - Batch update mechanism
- [Extensions](./extensions.md) - Computed extension methods
