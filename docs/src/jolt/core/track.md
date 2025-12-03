---
---

# Track

The Track module provides functions for controlling reactive dependency tracking, including `untracked`, `trackWithEffect`, and `notifyAll`. These functions allow you to finely control when to collect dependencies, when not to collect dependencies, and how to manually trigger updates.

## untracked

`untracked` is used to execute functions in reactive contexts without creating reactive dependencies. It's very useful when you need to read values but don't want to trigger updates, or to avoid circular dependencies.

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

void main() {
  final count = Signal(0);
  final name = Signal('Alice');
  
  Effect(() {
    final tracked = count.value; // Creates dependency
    final untrackedValue = untracked(() => name.value); // Does not create dependency
    
    print('Count: $tracked, Name: $untrackedValue');
  });
  
  count.value = 10; // Triggers update
  name.value = 'Bob'; // Does not trigger update (because not tracked)
}
```

### Basic Usage

Use the `untracked` function to access values without creating dependencies:

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);

Effect(() {
  final tracked = signal1.value; // Creates dependency
  final untracked = untracked(() => signal2.value); // Does not create dependency
  
  print('$tracked + $untracked');
});

signal1.value = 10; // Side effect runs
signal2.value = 20; // Side effect does not run (because signal2 is not tracked)
```

### Using in Computed

Using `untracked` in Computed can prevent certain values from triggering recomputation:

```dart
final count = Signal(0);
final name = Signal('Alice');

final computed = Computed(() {
  final currentCount = count.value; // Tracks dependency
  final currentName = untracked(() => name.value); // Does not track dependency
  return 'Count: $currentCount, Name: $currentName';
});

count.value = 1; // Triggers recomputation
name.value = 'Bob'; // Does not trigger recomputation
```

### Avoiding Circular Dependencies

`untracked` can be used to avoid circular dependencies:

```dart
final count = Signal(0);

Effect(() {
  print('Count: ${count.value}');
  
  // Use untracked to avoid circular dependency
  untracked(() {
    if (count.value > 5) {
      count.value = 0; // Won't trigger infinite loop
    }
  });
});
```

### Comparison with peek

Both `untracked` and `peek` can read values without creating reactive dependencies, but they differ in usage:

| Feature | untracked | peek |
|---------|-----------|------|
| Form | Function call | Property access |
| Use Case | Use in functions, can execute arbitrary code | Direct property access |
| Return Value | Any type | Value type |
| Flexibility | More flexible, can execute complex logic | More concise and direct |

```dart
final signal = Signal(0);

Effect(() {
  // Using peek
  final value1 = signal.peek;
  
  // Using untracked
  final value2 = untracked(() => signal.value);
  
  // untracked can execute more complex logic
  final value3 = untracked(() {
    final a = signal.value;
    final b = anotherSignal.value;
    return a + b;
  });
  
  print('peek: $value1, untracked: $value2, complex: $value3');
});
```

## trackWithEffect

`trackWithEffect` is used to execute a function using the specified effect node as the active subscriber, allowing manual control of dependency tracking. This is useful in advanced scenarios, such as delayed dependency collection or custom dependency tracking logic.

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

final count = Signal(0);

// Create lazy effect
final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true);

// Manually collect dependencies using trackWithEffect
trackWithEffect(() {
  count.value; // This access will be tracked by effect
}, effect);

count.value = 10; // Triggers effect
```

### Basic Usage

`trackWithEffect` accepts a function and an effect node. During function execution, that effect node becomes the active subscriber:

```dart
final signal = Signal(0);

final effect = Effect(() {
  // Effect function body
}, lazy: true);

// Manually collect dependencies
trackWithEffect(() {
  final value = signal.value; // Tracked by effect
  print('Value: $value');
}, effect);
```

### purge Parameter

The third parameter `purge` of `trackWithEffect` controls whether to clear existing dependencies before execution:

```dart
// purge: true (default) - Clear existing dependencies then re-collect
trackWithEffect(() {
  signal1.value; // Only tracks signal1
}, effect, purge: true);

// purge: false - Keep existing dependencies, append new dependencies
trackWithEffect(() {
  signal2.value; // Tracks signal1 and signal2
}, effect, purge: false);
```

### Use Cases

#### Delayed Dependency Collection

`trackWithEffect` can be used for delayed dependency collection, combined with Effects with `lazy: true`:

```dart
final count = Signal(0);
final name = Signal('Alice');

final effect = Effect(() {
  print('Count: ${count.value}, Name: ${name.value}');
}, lazy: true);

// Manually collect dependencies later
trackWithEffect(() {
  count.value;
  name.value;
}, effect);

count.value = 10; // Triggers effect
name.value = 'Bob'; // Triggers effect
```

#### Custom Dependency Tracking

`trackWithEffect` can be used to implement custom dependency tracking logic. Note: `trackWithEffect` can only be used with `EffectNode` (such as `Effect`, `Watcher`, `EffectScope`), not with `Computed`:

```dart
final data = Signal<List<int>>([]);
final filter = Signal(true);

// Use Effect instead of Computed
final effect = Effect(() {
  final items = data.value;
  if (filter.value) {
    print('Filtered: ${items.where((x) => x > 0).toList()}');
  } else {
    print('All: $items');
  }
}, lazy: true);

// Manually control which dependencies are tracked
trackWithEffect(() {
  data.value; // Only tracks data, does not track filter
}, effect);

data.value = [1, 2, 3]; // Triggers effect
filter.value = false; // Does not trigger effect (because filter is not tracked)
```

### Important Note

**Dependency Persistence**: Even if dependencies are collected through `trackWithEffect` and the effect is triggered after dependencies update, there's no guarantee that these dependencies will persist. Dependency persistence is determined by the effect's specific implementation. When the effect re-runs, it re-collects dependencies, and dependencies previously collected through `trackWithEffect` may be cleared or replaced.

```dart
final count = Signal(0);

final effect = Effect(() {
  // Effect function body may re-collect dependencies
  print('Count: ${count.value}');
}, lazy: true);

// Manually collect dependencies
trackWithEffect(() {
  count.value; // Collects dependencies
}, effect);

count.value = 10; // Triggers effect

// When effect re-runs, it re-collects dependencies
// Dependencies previously collected through trackWithEffect may no longer exist
```

Therefore, `trackWithEffect` is mainly used for initializing dependency collection, not for long-term dependency maintenance. For scenarios requiring persistent dependencies, you should directly access reactive values within the effect function body.

## notifyAll

`notifyAll` is used to execute a function and notify subscribers of all accessed dependencies. This is useful when you need to trigger updates without actually changing values.

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

final signal = Signal(0);

Effect(() {
  print('Value: ${signal.value}');
});

// Don't change value, but trigger subscriber updates
notifyAll(() {
  signal.value; // Access signal, triggers subscribers
});
```

### Basic Usage

`notifyAll` creates a temporary reactive context, executes the function, then notifies subscribers of all dependencies accessed during function execution:

```dart
final count = Signal(0);
final name = Signal('Alice');

Effect(() {
  print('Count: ${count.value}');
});

Effect(() {
  print('Name: ${name.value}');
});

// Trigger all subscribers, even if values haven't changed
notifyAll(() {
  count.value;
  name.value;
});
```

### Use Cases

#### Manual Update Triggering

When an object's internal state changes but the object reference hasn't changed, you can use `notifyAll` to manually trigger updates:

```dart
final user = Signal(User(name: 'Alice', age: 30));

Effect(() {
  print('User: ${user.value.name}, Age: ${user.value.age}');
});

// Modify internal properties
user.value.age = 31;

// Manually trigger update
notifyAll(() {
  user.value; // Triggers subscribers
});
```

#### Batch Notification

`notifyAll` can be used to batch notify subscribers of multiple dependencies:

```dart
final a = Signal(0);
final b = Signal(0);
final c = Signal(0);

Effect(() {
  print('A: ${a.value}, B: ${b.value}, C: ${c.value}');
});

// Batch notify all subscribers
notifyAll(() {
  a.value;
  b.value;
  c.value;
});
```

## Important Notes

1. **Using `untracked`**:
   - Reactive values accessed inside `untracked` do not create dependencies
   - Suitable for scenarios where you need to read values but don't want to trigger updates
   - Can execute arbitrary code, more flexible than `peek`

2. **Using `trackWithEffect`**:
   - Used for manually controlling the dependency collection process
   - `purge: true` clears existing dependencies then re-collects
   - `purge: false` keeps existing dependencies and appends new ones
   - Suitable for delayed dependency collection or custom dependency tracking logic

3. **Using `notifyAll`**:
   - Does not change values, only triggers subscriber updates
   - Suitable for scenarios where object internal state changes but reference hasn't changed
   - Can batch notify subscribers of multiple dependencies

4. **Performance Considerations**:
   - `untracked` can avoid unnecessary dependencies, improving performance
   - `trackWithEffect` provides finer control but needs careful use
   - `notifyAll` triggers all subscribers and may affect performance

## Related APIs

- [Effect](./effect.md) - Learn about side effect usage
- [Computed](./computed.md) - Learn about computed property usage
- [Signal](./signal.md) - Learn about signal usage

