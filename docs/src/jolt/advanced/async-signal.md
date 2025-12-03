---
---

# Async Signal

Async signals are used in the reactive system to handle async operations, including Futures and Streams. Jolt provides `AsyncSignal` to manage async operation states (loading, success, error, etc.) and automatically notify subscribers when states change. Suitable for data loading, real-time data streams, and similar scenarios.

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

## AsyncState

`AsyncState` is a sealed class representing different states of async operations:

- **`AsyncLoading<T>`**: Loading state
- **`AsyncSuccess<T>`**: Success state, contains data
- **`AsyncError<T>`**: Error state, contains error information

### State Checking

```dart
final state = asyncSignal.value;

if (state.isLoading) {
  print('Loading...');
} else if (state.isSuccess) {
  print('Success: ${state.data}');
} else if (state.isError) {
  print('Error: ${state.error}');
}
```

### Data Access

```dart
final state = asyncSignal.value;

// Get data (may be null)
final data = state.data;

// Get error (may be null)
final error = state.error;
final stackTrace = state.stackTrace;
```

### map Method

Use the `map` method to return different values based on state:

```dart
final message = state.map(
  loading: () => 'Loading...',
  success: (data) => 'Success: $data',
  error: (error, stackTrace) => 'Error: $error',
);
```

## Creating AsyncSignal

### From Future

Use `AsyncSignal.fromFuture` to create from a Future:

```dart
Future<String> fetchUser() async {
  await Future.delayed(Duration(seconds: 1));
  return 'John Doe';
}

final userSignal = AsyncSignal.fromFuture(fetchUser());
```

### From Stream

Use `AsyncSignal.fromStream` to create from a Stream:

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final dataSignal = AsyncSignal.fromStream(stream);
```

### Using Extension Methods

Jolt provides extension methods for more convenient async signal creation:

From Future:

```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Data';
}

final signal = fetchData().toAsyncSignal();
```

From Stream:

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();
```

### Using AsyncSource

You can create using a custom `AsyncSource`:

```dart
final signal = AsyncSignal(
  source: FutureSource(future),
  initialValue: AsyncLoading(),
);
```

## Basic Usage

### State Checking

`AsyncSignal`'s value is `AsyncState` with three states:

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

### Direct Data Access

`AsyncSignal` provides a `data` property for direct data access (may be null):

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

// Direct access to data (may be null)
final user = signal.data;
```

### Reloading Data

To reload data, you can create a new `AsyncSignal` or use a new `AsyncSource`:

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

// Method 1: Create new AsyncSignal
final newSignal = AsyncSignal.fromFuture(fetchUser());

// Method 2: Use new AsyncSource
final newSource = FutureSource(fetchUser());
final reloadedSignal = AsyncSignal(source: newSource);
```

## AsyncSource

`AsyncSource` is an abstract interface for defining async data sources. You can implement custom `AsyncSource` to create special async behaviors.

### Implementing Custom AsyncSource

```dart
class MyAsyncSource<T> implements AsyncSource<T> {
  @override
  FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) async {
    emit(AsyncLoading());
    try {
      final data = await fetchData();
      emit(AsyncSuccess(data));
    } catch (e, st) {
      emit(AsyncError(e, st));
    }
  }

  @override
  FutureOr<void> dispose() {
    // Clean up resources
  }
}

// Use custom source
final signal = AsyncSignal(source: MyAsyncSource());
```

### FutureSource

`FutureSource` is a wrapper for Futures, automatically managing Future state transitions:

```dart
final future = Future.delayed(Duration(seconds: 1), () => 'Hello');
final source = FutureSource(future);
final signal = AsyncSignal(source: source);
```

### StreamSource

`StreamSource` is a wrapper for Streams, automatically managing Stream state transitions:

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final source = StreamSource(stream);
final signal = AsyncSignal(source: source);
```

## Use Cases

### Data Loading

`AsyncSignal` is perfect for data loading scenarios:

```dart
class UserService {
  Future<User> fetchUser(int id) async {
    await Future.delayed(Duration(seconds: 1));
    return User(id: id, name: 'User $id');
  }
}

final userService = UserService();
final userSignal = AsyncSignal.fromFuture(
  userService.fetchUser(1)
);

Effect(() {
  final state = userSignal.value;
  if (state.isLoading) {
    showLoadingIndicator();
  } else if (state.isSuccess) {
    displayUser(state.data!);
  } else if (state.isError) {
    showError(state.error);
  }
});
```

### Real-Time Data Streams

`AsyncSignal` can be used to handle real-time data streams:

```dart
final chatMessages = AsyncSignal.fromStream(
  chatService.messageStream()
);

Effect(() {
  final state = chatMessages.value;
  if (state.isSuccess) {
    displayMessage(state.data!);
  }
});
```

### Error Handling

`AsyncSignal` provides complete error handling capabilities:

```dart
final dataSignal = AsyncSignal.fromFuture(fetchData());

Effect(() {
  final state = dataSignal.value;
  if (state.isError) {
    print('Error: ${state.error}');
    print('Stack trace: ${state.stackTrace}');
    // Handle error
    handleError(state.error, state.stackTrace);
  }
});
```

### Reloading

Using the `fetch` method enables reload functionality:

```dart
final dataSignal = AsyncSignal.fromFuture(fetchData());

void reload() {
  dataSignal.fetch(FutureSource(fetchData()));
}

// User clicks refresh button
refreshButton.onTap = reload;
```

## Lifecycle Management

`AsyncSignal` implements the `Signal` interface and has lifecycle management capabilities:

- **`dispose()`**: Release resources, including canceling ongoing async operations
- **`isDisposed`**: Check if disposed

```dart
final signal = AsyncSignal.fromFuture(fetchData());

// Use signal...

// Release when no longer needed
signal.dispose();
```

## Important Notes

1. **State Transitions**: `AsyncSignal` automatically manages state transitions from `AsyncLoading` to `AsyncSuccess` or `AsyncError`.

2. **Data Access**: The `data` property returns `null` in `AsyncLoading` and `AsyncError` states, only returning actual data in `AsyncSuccess` state.

3. **Error Handling**: Ensure proper handling of error states, including error information and stack traces.

4. **Resource Cleanup**: `AsyncSignal` automatically cleans up `AsyncSource` resources, but if you implement custom `AsyncSource`, ensure proper implementation of the `dispose()` method.

5. **Stream Subscriptions**: For `StreamSource`, `AsyncSignal` automatically manages Stream subscription lifecycles.

6. **Reloading**: When using the `fetch` method to reload data, previous async operations are automatically canceled.

## Related APIs

- [Signal](../core/signal.md) - Learn about basic signal usage
- [Effect](../core/effect.md) - Reactive side effects
- [Extensions](../core/extensions.md) - Async signal extension methods
