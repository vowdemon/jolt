---
---

# Stream

Stream provides bidirectional conversion functionality between signals and streams in the reactive system. You can convert signals to streams for integration with other streaming APIs, or convert streams to signals for use in the reactive system. Suitable for integration with StreamBuilder, stream-based data processing, event streams, and similar scenarios.

## Creation

### Signal to Stream

Any reactive value can be converted to a stream through the `.stream` property:

```dart
final count = Signal(0);
final stream = count.stream;
```

You can also use the `listen` method:

```dart
final count = Signal(0);

final subscription = count.listen(
  (value) => print('Value: $value'),
  immediately: true, // Execute immediately
);
```

### Stream to Signal

Use `StreamSignal` to convert a stream to a signal:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = StreamSignal(getDataStream());
```

Using extension methods:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();
```

## Signal to Stream

Any reactive value can be converted to a stream through the `.stream` property:

```dart
final count = Signal(0);
final stream = count.stream;

// Listen to stream
stream.listen((value) {
  print('Value changed: $value');
});

count.value = 1; // Output: "Value changed: 1"
count.value = 2; // Output: "Value changed: 2"
```

Using the `listen` method:

```dart
final count = Signal(0);

final subscription = count.listen(
  (value) => print('Value: $value'),
  immediately: true, // Execute once immediately
);

count.value = 1; // Output: "Value: 1"

subscription.cancel(); // Cancel listening
```

Using StreamBuilder in Flutter:

```dart
final count = Signal(0);

StreamBuilder<int>(
  stream: count.stream,
  builder: (context, snapshot) {
    return Text('Value: ${snapshot.data ?? 0}');
  },
);
```

## Stream to Signal

Use `StreamSignal` to convert a stream to a signal:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = StreamSignal(getDataStream());

Effect(() {
  final state = signal.value;
  if (state.isSuccess) {
    print('Latest value: ${state.data}');
  }
});
```

Using extension methods:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();

Effect(() {
  final state = signal.value;
  if (state.isSuccess) {
    print('Latest value: ${state.data}');
  }
});
```

