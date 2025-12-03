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

## Reading Values

### `.value` / `.get()` / `call()`

Use the `.value` property, `.get()` method, or call the computed object directly to read values—**this creates reactive dependencies and triggers computation**. If dependencies have changed, it recomputes; otherwise, it returns the cached value.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled.value); // Using .value
  print(doubled.get()); // Using .get()
  print(doubled()); // Direct call
});

count.value = 5; // All methods trigger recomputation
```

These three methods are completely equivalent—choose based on your coding style.

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

## Manual Notification

If you need to manually tell subscribers that it has updated, you can use the `notify()` method. This notifies all subscribers even if dependencies haven't changed.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print('Doubled: ${doubled.value}');
});

count.value = 5; // First output: "Doubled: 10"

doubled.notify(); // Output again: "Doubled: 10"
```

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

You can also write using the `.set()` method with the same effect:

```dart
doubled.set(20); // Same as doubled.value = 20
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

3. **Dependency Tracking**: Using `.value`, `.get()`, or `call()` in the getter function to access other reactive values establishes dependencies. Using `.peek` does not establish dependencies.

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
