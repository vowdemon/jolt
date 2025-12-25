---
---

# Extension Methods

Jolt provides rich extension methods that make reactive programming more convenient. These extension methods allow you to easily manipulate reactive values and integrate with Flutter.

## Readable Extension Methods

Extension methods for the `Readable<T>` interface, applicable to all read-only reactive values (such as `Signal`, `Computed`, etc.).

### stream

Convert reactive values to broadcast streams.

```dart
final counter = Signal(0);
final stream = counter.stream;

stream.listen((value) => print('Counter: $value'));
// Output: "Counter: 0"

counter.value = 1; // Output: "Counter: 1"
counter.value = 2; // Output: "Counter: 2"
```

### listen

Create a stream subscription to listen for changes in reactive values.

```dart
final counter = Signal(0);

final subscription = counter.listen(
  (value) => print('Counter: $value'),
  immediately: true, // Immediately output current value
);

counter.value = 1; // Output: "Counter: 1"

subscription.cancel(); // Stop listening
```

### until

Wait for a reactive value to satisfy a condition.

```dart
final count = Signal(0);

// Wait for count to reach 5
final future = count.until((value) => value >= 5);

count.value = 1; // Still waiting
count.value = 3; // Still waiting
count.value = 5; // Future completes, value is 5

final result = await future; // result is 5
```

Async scenario example:

```dart
final isLoading = Signal(true);

// Wait for loading to complete
final data = await isLoading.until((value) => !value);
print('Loading complete');
```

## Writable Extension Methods

Extension methods for the `Writable<T>` interface, applicable to all writable reactive values (such as `Signal`, `WritableComputed`, etc.).

### update

Update values using an update function based on the current value.

```dart
final count = Signal(5);
count.update((value) => value + 1); // count.value is now 6
count.update((value) => value * 2); // count.value is now 12
```

This is equivalent to:

```dart
count.value = count.peek + 1;
count.value = count.peek * 2;
```

### readonly

Return a read-only view of a signal or writable computed value.

```dart
final counter = Signal(0);
final readonlyCounter = counter.readonly();

print(readonlyCounter.value); // OK
// readonlyCounter.value = 1; // Compile error
```

For writable computed values:

```dart
final writableComputed = WritableComputed(getter, setter);
final readonlyComputed = writableComputed.readonly();

print(readonlyComputed.value); // OK
// readonlyComputed.value = 1; // Compile error
```

### untilWhen

Wait for a reactive value to satisfy a condition, with access to the previous value.

```dart
final count = Signal(0);

// Wait for count to reach 5, with previous value tracking
final future = count.untilWhen((value, previous) => value >= 5);

count.value = 1; // Still waiting, previous is 0
count.value = 3; // Still waiting, previous is 1
count.value = 5; // Future completes, value is 5, previous is 3

final result = await future; // result is 5
```

### call

Call a Readable as a function to get its value (creates reactive dependency).

```dart
final counter = Signal(0);

// These are equivalent:
final value1 = counter.value;
final value2 = counter(); // Using call extension
```

### get

Get the value of a Readable (creates reactive dependency).

```dart
final counter = Signal(0);

// These are equivalent:
final value1 = counter.value;
final value2 = counter.get(); // Using get extension
```

### derived

Create a computed value derived from this Readable.

```dart
final count = Signal(5);
final doubled = count.derived((value) => value * 2);

print(doubled.value); // 10
count.value = 6;
print(doubled.value); // 12
```

## Flutter Extension Methods

### watch (Flutter only)

Create a widget that rebuilds when this Readable value changes. This extension is available in the `jolt_flutter` package.

```dart
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/extension.dart';

final counter = Signal(0);

// Use watch extension to create a reactive widget
counter.watch((value) => Text('Count: $value'))
```

## Important Notes

1. **Performance Considerations**: Extension methods create new reactive objects. For scenarios with frequent creation, consider using constructors directly.

2. **Lifecycle**: Reactive objects created through extension methods need manual lifecycle management. Remember to call `dispose()` when done.

3. **Type Safety**: Extension methods maintain complete type safety with compile-time type checking.

4. **Stream Subscriptions**: Subscriptions created using `listen` or `stream` need manual cancellation to avoid memory leaks.

