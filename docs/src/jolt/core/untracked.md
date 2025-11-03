---
---

# Untracked

Untracked is used in the reactive system to access values within a reactive context without creating reactive dependencies. This is very useful when you need to read values without triggering updates, or to avoid circular dependencies.

```dart
import 'package:jolt/jolt.dart';

void main() {
  final count = Signal(0);
  final name = Signal('Alice');
  
  Effect(() {
    final tracked = count.value; // Create dependency
    final untrackedValue = untracked(() => name.value); // Don't create dependency
    
    print('Count: $tracked, Name: $untrackedValue');
  });
  
  count.value = 10; // Triggers update
  name.value = 'Bob'; // Doesn't trigger update (untracked)
}
```

## Basic Usage

Use the `untracked` function to access values without creating dependencies:

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);

Effect(() {
  final tracked = signal1.value; // Create dependency
  final untracked = untracked(() => signal2.value); // Don't create dependency
  
  print('$tracked + $untracked');
});

signal1.value = 10; // Side effect runs
signal2.value = 20; // Side effect doesn't run (signal2 is not tracked)
```

## Comparison with peek

Both `untracked` and `peek` can read values without creating reactive dependencies, but they differ in usage:

| Feature | untracked | peek |
|---------|-----------|------|
| Form | Function call | Property access |
| Use case | Use within functions | Direct property access |
| Return value | Any type | Value type |

```dart
final signal = Signal(0);

Effect(() {
  // Use peek
  final value1 = signal.peek;
  
  // Use untracked
  final value2 = untracked(() => signal.value);
  
  print('peek: $value1, untracked: $value2');
});
```

Both can read values without creating dependencies. `peek` is more concise and direct, while `untracked` is more flexible and can execute arbitrary code within a function.

