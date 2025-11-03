---
---

# Async Signal

> **Note**: Async signals are experimental features, and the API may change.

Async signals are used in the reactive system to handle asynchronous operations, including Future and Stream. Jolt provides `AsyncSignal`, `FutureSignal`, and `StreamSignal` to manage the state of asynchronous operations (loading, success, error, etc.) and automatically notify subscribers when state changes. Suitable for data loading, real-time data streams, and similar scenarios.

```dart
import 'package:jolt/jolt.dart';

void main() {
  final userSignal = AsyncSignal.fromFuture(fetchUser());
  
  Effect(() {
    final state = userSignal.value;
    if (state.isLoading) {
      print('Loading...');
    } else if (state.isSuccess) {
      print('User: ${state.data}');
    } else if (state.isError) {
      print('Error: ${state.error}');
    }
  });
}
```

## Creation

### AsyncSignal

Create from a Future:

```dart
Future<String> fetchUser() async {
  await Future.delayed(Duration(seconds: 1));
  return 'John Doe';
}

final userSignal = AsyncSignal.fromFuture(fetchUser());
```

Create from a Stream:

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final dataSignal = AsyncSignal.fromStream(stream);
```

### FutureSignal

`FutureSignal` is specifically designed for handling Futures and is a convenience wrapper for `AsyncSignal`:

```dart
final future = Future.delayed(Duration(seconds: 1), () => 'Hello');
final futureSignal = FutureSignal(future);
```

Using extension methods:

```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Data';
}

final signal = fetchData().toAsyncSignal();
```

### StreamSignal

`StreamSignal` is specifically designed for handling Streams and is a convenience wrapper for `AsyncSignal`:

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final streamSignal = StreamSignal(stream);
```

Using extension methods:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();
```

## Basic Usage

### State Checking

The value of `AsyncSignal` is `AsyncState`, which has four states:

```dart
final asyncSignal = AsyncSignal.fromFuture(fetchUser());

Effect(() {
  final state = asyncSignal.value;
  
  if (state.isLoading) {
    print('Loading...');
  } else if (state.isSuccess) {
    print('Success: ${state.data}');
  } else if (state.isError) {
    print('Error: ${state.error}');
  } else if (state.isRefreshing) {
    print('Refreshing, data: ${state.data}');
  }
});
```

### Data Access

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

Effect(() {
  final state = signal.value;
  
  // Get data (may be null)
  final data = state.data;
  
  // Get error (may be null)
  final error = state.error;
  final stackTrace = state.stackTrace;
});
```

You can also access data directly:

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

// Directly access data (may be null)
final user = signal.data;
```

