---
---

# Computed

Computed is a lazy derived value in the reactive system. It only recomputes when subscribed to and when its dependencies change, featuring automatic caching that efficiently handles expensive computations.

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

Use the `Computed` constructor to create a computed value by passing a getter function:

```dart
final count = Signal(0);

final doubled = Computed(() => count.value * 2);
```

## Reading

### `.value`

Use the `.value` property to read a computed value, **which creates a reactive dependency and triggers computation**. If dependencies have changed, it will recompute; otherwise, it returns the cached value.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled.value);
});

count.value = 5;
```

### `.peek`

Use the `.peek` property to read the **cached computed value** without triggering recomputation. If dependencies have changed but haven't been accessed, the returned value may be stale.

```dart
final signalA = Signal(0);
final computedA = Computed(() => signalA.value * 2);

final signalB = Signal(0);
final computedB = Computed(() => signalB.value * 2);

Effect(() {
  final tracked = computedA.value;
  final cached = computedB.peek;
  
  print('Tracked: $tracked, Cached: $cached');
});

signalB.value = 10; // No output
signalA.value = 10; // Output: "Tracked: 20, Cached: 0"
```

## Manual Notification

If you need to manually notify subscribers that the computed value has updated, you can use the `notify()` method. This will notify all subscribers even if dependencies haven't changed.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print('Doubled: ${doubled.value}');
});

count.value = 5; // First output: "Doubled: 10"

doubled.notify(); // Output again: "Doubled: 10"
```

## Writable Computed

`WritableComputed` allows you to create a computed value that can be both read and written. Writing will call the setter function to update underlying dependencies. **The setter function executes within a batch**, meaning all signal updates in the setter are batched together, and subscribers will only receive one notification after all updates are complete.

### Creating Writable Computed

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

