---
---

# Extension Methods

Jolt provides rich extension methods that make reactive programming more convenient. These extension methods allow you to easily manipulate reactive values or convert regular values to reactive signals.

## Readonly Extension Methods

Extension methods for the `Readonly<T>` interface, applicable to all read-only reactive values (such as `Signal`, `Computed`, etc.).

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
count.set(count.peek + 1);
count.set(count.peek * 2);
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

## Signal Conversion Methods

Extension methods for converting regular values to reactive signals.

### toSignal

Convert any object to a reactive signal.

```dart
import 'package:jolt/jolt.dart';

final nameSignal = 'Alice'.toSignal();
final countSignal = 42.toSignal();
final listSignal = [1, 2, 3].toSignal();
```

### Collection Conversion Methods

#### toListSignal

Convert a regular list to a reactive list signal.

```dart
final normalList = [1, 2, 3];
final reactiveList = normalList.toListSignal();

Effect(() => print('Length: ${reactiveList.length}'));

reactiveList.add(4); // Triggers update
```

#### toSetSignal

Convert a regular set to a reactive set signal.

```dart
final normalSet = {'dart', 'flutter'};
final reactiveSet = normalSet.toSetSignal();

Effect(() => print('Tags: ${reactiveSet.join(', ')}'));

reactiveSet.add('reactive'); // Triggers update
```

#### toMapSignal

Convert a regular map to a reactive map signal.

```dart
final normalMap = {'name': 'Alice', 'age': 30};
final reactiveMap = normalMap.toMapSignal();

Effect(() => print('User: ${reactiveMap['name']}'));

reactiveMap['name'] = 'Bob'; // Triggers update
```

#### toIterableSignal

Convert a regular iterable to a reactive iterable signal.

```dart
final range = Iterable.generate(5).toIterableSignal();

Effect(() => print('Items: ${range.toList()}'));
```

### Async Conversion Methods

#### toAsyncSignal

Convert a Future to a reactive async signal.

```dart
Future<String> fetchUser() async {
  await Future.delayed(Duration(seconds: 1));
  return 'John Doe';
}

final signal = fetchUser().toAsyncSignal();

Effect(() {
  if (signal.value.isSuccess) {
    print('Data: ${signal.data}');
  }
});
```

#### toStreamSignal

Convert a Stream to a reactive async signal.

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final signal = stream.toStreamSignal();

Effect(() {
  if (signal.value.isSuccess) {
    print('Data: ${signal.data}');
  }
});
```

## Important Notes

1. **Performance Considerations**: Extension methods create new reactive objects. For scenarios with frequent creation, consider using constructors directly.

2. **Lifecycle**: Reactive objects created through extension methods need manual lifecycle management. Remember to call `dispose()` when done.

3. **Type Safety**: Extension methods maintain complete type safety with compile-time type checking.

4. **Stream Subscriptions**: Subscriptions created using `listen` or `stream` need manual cancellation to avoid memory leaks.

