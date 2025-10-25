# Jolt

A lightweight reactive state management library built on [alien_signals](https://github.com/stackblitz/alien-signals), focused on simple and efficient state handling.

Jolt provides a complete reactive programming solution for Dart and Flutter applications, including signals, computed values, effects, and reactive collections. It features fine-grained dependency tracking and efficient updates, enabling you to build responsive applications.

## 🚀 Core Features

- **🎯 Fine-Grained Reactivity**: Precise dependency tracking and updates
- **📦 Collection Support**: Reactive List, Map, Set, and Iterable
- **🔄 Async Operations**: Seamless Future and Stream handling
- **🛠️ Practical Utilities**: Type conversion and persistence helpers
- **🎨 Framework Agnostic**: Works with any Dart/Flutter application
- **🧹 Memory Efficient**: Automatic cleanup and disposal
- **🔧 Rich Extensions**: Comprehensive extension methods

## 📦 Packages

### [jolt](packages/jolt/) - Core Library

The core reactive state management library providing fundamental signals, computed values, effects, and reactive collections.

**Key Features:**
- `Signal<T>` - Reactive state containers
- `Computed<T>` - Automatically computed derived values
- `Effect` - Side-effect functions
- `AsyncSignal<T>` - Async state management
- Reactive collections: `ListSignal`, `MapSignal`, `SetSignal`, `IterableSignal`
- Batch updates and lifecycle management

**Quick Start:**
```dart
import 'package:jolt/jolt.dart';

void main() {
  final count = Signal(0);
  final doubled = Computed(() => count.value * 2);
  
  Effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });
  
  count.value = 5; // Prints: "Count: 5, Doubled: 10"
}
```

### [jolt_flutter](packages/jolt_flutter/) - Flutter Integration

Flutter-specific widgets and utilities for reactive UI support.

**Key Features:**
- `JoltBuilder` - Automatic reactive UI updates
- `JoltSelector` - Fine-grained selector updates
- `JoltResource` - Local component state management
- `JoltValueNotifier` - Integration with Flutter's ValueNotifier system

**Quick Start:**
```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

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

### [jolt_hooks](packages/jolt_hooks/) - Flutter Hooks Integration

Integration with Flutter Hooks for reactive state management in HookWidget.

**Key Features:**
- `useSignal()` - Reactive signal hooks
- `useComputed()` - Computed value hooks
- `useAsyncSignal()` - Async state hooks
- `useJoltEffect()` - Side-effect hooks
- `usePersistSignal()` - Persistent signal hooks
- Reactive collection hooks: `useListSignal()`, `useMapSignal()`, `useSetSignal()`

**Quick Start:**
```dart
import 'package:jolt_hooks/jolt_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
    return ElevatedButton(
      onPressed: () => count.value++,
      child: Text('Count: ${count.value}'),
    );
  }
}
```

## 🎯 Use Cases

### Basic State Management
```dart
final user = Signal(User(name: 'John', age: 30));
final isAdult = Computed(() => user.value.age >= 18);
```

### Async Data Fetching
```dart
final userData = AsyncSignal.fromFuture(fetchUser());
```

### Reactive Collections
```dart
final items = ListSignal(['apple', 'banana']);
final filteredItems = Computed(() => 
  items.value.where((item) => item.startsWith('a')).toList()
);
```

### Flutter UI Integration
```dart
JoltBuilder(
  builder: (context) => ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(items[index]),
    ),
  ),
)
```

### Hooks Integration
```dart
class TodoList extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final todos = useListSignal(<String>[]);
    final newTodo = useSignal('');
    
    return Column(
      children: [
        TextField(
          onChanged: (value) => newTodo.value = value,
          onSubmitted: (value) {
            todos.add(value);
            newTodo.value = '';
          },
        ),
        ...todos.value.map((todo) => ListTile(title: Text(todo))),
      ],
    );
  }
}
```

## 📚 Documentation

- [Jolt Core Library](packages/jolt/README.md)
- [Jolt Flutter Integration](packages/jolt_flutter/README.md)
- [API Reference](https://pub.dev/documentation/jolt/latest/)

## 🤝 Contributing

Contributions are welcome! Please check the individual package README files for detailed development guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Links

- [alien_signals](https://github.com/stackblitz/alien-signals) - Underlying reactive engine
- [Flutter Hooks](https://pub.dev/packages/flutter_hooks) - Flutter Hooks system
- [Pub.dev Package](https://pub.dev/packages/jolt)