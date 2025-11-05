---
---

# Async Signal

Async signals are used in the reactive system to handle asynchronous operations, including Future and Stream. Jolt provides `AsyncSignal` to manage the state of asynchronous operations (loading, success, error, etc.) and automatically notify subscribers when state changes. Suitable for data loading, real-time data streams, and similar scenarios.

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

### Using Extension Methods

Jolt provides extension methods for more convenient creation of async signals:

Create from Future:

```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Data';
}

final signal = fetchData().toAsyncSignal();
```

Create from Stream:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();
```

## Basic Usage

### State Checking

The value of `AsyncSignal` is `AsyncState`, which has three states:

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

