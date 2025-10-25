# Jolt Flutter

A Flutter integration package for [Jolt](https://pub.dev/packages/jolt) reactive state management.

Jolt Flutter provides Flutter-specific widgets and utilities for working with Jolt signals, computed values, and reactive state. It includes widgets like `JoltBuilder` for reactive UI updates and seamless integration with Flutter's ValueNotifier system.

## Features

- **🎯 Reactive Widgets**: `JoltBuilder` and `JoltSelector` for automatic UI updates
- **🔄 ValueNotifier Integration**: Seamless bridge between Jolt signals and Flutter's ValueNotifier
- **⚡ Performance Optimized**: Fine-grained rebuilds with selector-based updates
- **🎨 Flutter Native**: Works with all Flutter widgets and animations
- **🛠️ Resource Management**: Automatic cleanup and disposal
- **📦 Collection Support**: Reactive List, Map, Set widgets
- **🔄 Async Support**: Built-in async state handling

> For full API reference and detailed usage examples, check the inline comments in the source code and the [Documentation](https://pub.dev/documentation/jolt_flutter/latest/).

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final counter = Signal(0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: JoltBuilder(
          builder: (context) => Text('Count: ${counter.value}'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => counter.value++,
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
```

## Core Widgets

### JoltBuilder

Automatically rebuilds when any signal accessed in its builder changes:

```dart
final counter = Signal(0);
final name = Signal('Flutter');

JoltBuilder(
  builder: (context) => Column(
    children: [
      Text('Hello ${name.value}'),
      Text('Count: ${counter.value}'),
      ElevatedButton(
        onPressed: () => counter.value++,
        child: Text('Increment'),
      ),
    ],
  ),
)
```

### JoltSelector

Rebuilds only when a specific selector function's result changes:

```dart
final user = Signal(User(name: 'John', age: 30));

// Only rebuilds when the user's name changes, not age
JoltSelector(
  selector: () => user.value.name,
  builder: (context) => Text('Hello ${user.value.name}'),
)
```

### JoltResource

A widget that provides local component state management with lifecycle callbacks:

```dart
class CounterStore implements JoltState {
  final counter = Signal(0);
  Timer? _timer;

  CounterStore(BuildContext context) : super(context);

  @override
  void onMount() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      counter.value++;
    });
  }

  @override
  void onUnmount() {
    _timer?.cancel();
  }
}

JoltResource<CounterStore>(
  create: (context) => CounterStore(context),
  builder: (context, store) => Text('Count: ${store.counter.value}'),
)
```

### Simple Builder

For cases without state management:

```dart
JoltResource.builder(
  builder: (context) => Text('Value: ${signal.value}'),
)
```

## ValueNotifier Integration

### JoltValueNotifier

Bridge Jolt signals with Flutter's ValueNotifier system:

```dart
final counter = Signal(0);
final notifier = counter.notifier; // Returns JoltValueNotifier

// Use with AnimatedBuilder
AnimatedBuilder(
  animation: notifier,
  builder: (context, child) => Text('Count: ${counter.value}'),
)

// Use with ValueListenableBuilder
ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('Count: $value'),
)
```

### Automatic Synchronization

ValueNotifier automatically syncs with Jolt signal changes:

```dart
final signal = Signal(0);
final notifier = signal.notifier;

// Changes to signal automatically update notifier
signal.value = 42; // notifier.value is now 42
```

## Flutter Integration Examples

### With Async Operations

```dart
final userSignal = AsyncSignal.fromFuture(fetchUser());

JoltBuilder(
  builder: (context) {
    final state = userSignal.value;
    if (state.isLoading) return CircularProgressIndicator();
    if (state.isError) return Text('Error: ${state.error}');
    return Text('User: ${state.data}');
  },
)
```

### With Collections

```dart
final items = ListSignal(['apple', 'banana']);

JoltBuilder(
  builder: (context) => ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(items[index]),
    ),
  ),
)
```

## Performance Tips

### Use JoltSelector for Fine-Grained Updates

```dart
final user = Signal(User(name: 'John', age: 30));

// Only rebuilds when name changes
JoltSelector(
  selector: () => user.value.name,
  builder: (context) => Text('Hello ${user.value.name}'),
)
```

## Flutter Widget Integration

### With AnimatedBuilder

```dart
final counter = Signal(0);

AnimatedBuilder(
  animation: counter.notifier,
  builder: (context, child) => Text('Count: ${counter.value}'),
)
```

### With ValueListenableBuilder

```dart
final counter = Signal(0);

ValueListenableBuilder<int>(
  valueListenable: counter.notifier,
  builder: (context, value, child) => Text('Count: $value'),
)
```

## Important Notes

### Widget Lifecycle
- `JoltBuilder` automatically tracks signal dependencies
- Widgets rebuild only when tracked signals change
- Use `JoltSelector` for performance optimization

### Memory Management
- Signals are automatically disposed when widgets are disposed
- Use `JoltResource` for manual resource management
- ValueNotifier integration handles cleanup automatically

### Performance Tips
- Use `JoltSelector` for fine-grained updates
- Batch multiple signal updates with `batch()`
- Avoid accessing signals in widget constructors

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.