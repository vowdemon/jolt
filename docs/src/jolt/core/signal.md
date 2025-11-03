---
---

# Signal

Signal is the foundation of the reactive system. It can be modified at any time and can be subscribed to for updates within the reactive system. When a Signal's value changes, all reactive nodes that subscribe to it (such as Computed, Effect) are automatically updated.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a signal
  final count = Signal(0);

  // Subscribe to signal changes
  Effect(() {
    print('Count: ${count.value}');
  });

  // Modify the signal's value
  count.value = 5; // Output: "Count: 5"
}
```

## Reading

### `.value` / `.get()`

Use the `.value` property to read a signal's value, **which creates a reactive dependency**. When the signal's value changes, any reactive nodes that access it via `.value` will be automatically updated.

```dart
final count = Signal(0);

Effect(() {
  print(count.value);
});

count.value = 10;
```

You can also access it via the `.get()` method with the same effect:

```dart
final count = Signal(0);

Effect(() {
  print(count.get());
});

count.value = 10;
```

### `.peek`

Use the `.peek` property to read the value **without creating a reactive dependency**. This is useful when you only need to read the current value without subscribing to updates.

```dart
final signalA = Signal(0);
final signalB = Signal(0);

Effect(() {
  final tracked = signalA.value;
  final untracked = signalB.peek;
  
  print('Tracked: $tracked, Untracked: $untracked');
});

signalB.value = 10; // No output
signalA.value = 10; // Output: "Tracked: 10, Untracked: 10"
```

## Writing

### `.value` / `.set()`

Assign directly to the `.value` property or use the `.set()` method to update the signal's value. Both approaches will update the value and notify all subscribers.

```dart
final count = Signal(0);

count.value = 10;

count.set(20);
```

## Manual Notification

If you need to manually notify subscribers that the signal has updated, you can use the `notify()` method. This will notify all subscribers even if the value hasn't changed.

```dart
final count = Signal(0);

Effect(() {
  print('Count updated: ${count.value}');
});

count.value = 10; // First output: "Count updated: 10"

// Don't change the value, but manually notify subscribers
count.notify(); // Output again: "Count updated: 10"
```

This is useful in scenarios where an object's internal properties have changed but the object reference itself remains unchanged:

```dart
final user = Signal(User(name: 'Alice', age: 30));

Effect(() {
  print('User: ${user.value.name}, Age: ${user.value.age}');
});

user.value.age = 31;
user.notify();
```

