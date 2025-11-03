---
---

# Effect

Effect is the most important component in the reactive system. It actively collects dependencies and proactively runs when dependencies are updated. Typically, you can use it to listen for signal changes and execute side effects.

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

### Immediate Execution

By default, Effect executes immediately upon creation and collects dependencies right away:

```dart
final count = Signal(0);

Effect(() {
  print('Count: ${count.value}');
});

count.value = 10;
```

### Deferred Execution

Use `immediately: false` to defer dependency collection. Dependencies will only be collected when you manually call the `run()` method later:

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}, immediately: false);

effect.run();

count.value = 10;
```

## Disposal

When an Effect is no longer needed, you should call the `dispose()` method to destroy it and clean up dependencies:

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
});

count.value = 10;

effect.dispose();

count.value = 20;
```

A disposed Effect will no longer respond to dependency changes.

## Usage Notes

### Avoid Infinite Loops

Ensure that an Effect does not modify signals it depends on, as this may cause infinite loops:

```dart
final count = Signal(0);

Effect(() {
  print(count.value);
  count.value++; // Modifying the signal you depend on causes an infinite loop
});
```

