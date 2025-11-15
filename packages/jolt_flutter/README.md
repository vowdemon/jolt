# Jolt Flutter

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_flutter](https://img.shields.io/pub/v/jolt_flutter?label=jolt_flutter)](https://pub.dev/packages/jolt_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A Flutter integration package for [Jolt](https://pub.dev/packages/jolt) reactive state management. Jolt Flutter provides Flutter-specific widgets and utilities for working with Jolt signals, computed values, and reactive state. It includes widgets like `JoltBuilder` for reactive UI updates and seamless integration with Flutter's ValueNotifier system.

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
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
)
```

The `selector` function receives the previous selected value (or `null` on first run) and returns the new value to watch. Rebuilds occur only when the returned value changes.

### JoltProvider

A widget that provides resources with lifecycle management:

```dart
class CounterStore extends JoltState {
  final counter = Signal(0);
  Timer? _timer;

  @override
  void onMount(BuildContext context) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      counter.value++;
    });
  }

  @override
  void onUnmount(BuildContext context) {
    _timer?.cancel();
  }
}

JoltProvider<CounterStore>(
  create: (context) => CounterStore(),
  builder: (context, store) => Text('Count: ${store.counter.value}'),
)
```

Access the resource from descendant widgets:

```dart
Builder(
  builder: (context) {
    final store = JoltProvider.of<CounterStore>(context);
    return Text('Count: ${store.counter.value}');
  },
)
```

## Setup Widget

> **⚠️ Important Note for `flutter_hooks` Users:**
>
> If you are already using or prefer the `flutter_hooks` package and its ecosystem, **do not import `jolt_flutter/setup.dart`**. Setup Widget follows a fundamentally different execution model:
>
> - **Setup Widget**: The `setup` function runs **once** when the widget is created
> - **flutter_hooks**: Hook functions run **on every build** (similar to React hooks)
>
> These different models can cause confusion if mixed. Instead, if you want to use Jolt with the `flutter_hooks` pattern, import `jolt_hooks`, which provides hooks that work seamlessly with `HookWidget` and integrate perfectly with the existing `flutter_hooks` ecosystem.

Setup Widget provides a composition-based API for Flutter widgets, similar to Vue's Composition API. The key difference from React hooks is that the `setup` function executes only once when the widget is first created, not on every rebuild. This provides better performance and a more predictable execution model.

### SetupBuilder

The simplest way to use Setup Widget is with `SetupBuilder`:

```dart
import 'package:jolt_flutter/setup.dart';

SetupBuilder(
  setup: (context) {
    final count = useSignal(0);
    
    onMounted(() {
      print('Widget mounted');
    });
    
    onUnmounted(() {
      print('Widget unmounted');
    });
    
    return (context) => Column(
      children: [
        Text('Count: ${count.value}'),
        ElevatedButton(
          onPressed: () => count.value++,
          child: Text('Increment'),
        ),
      ],
    );
  },
)
```

### Custom SetupWidget

You can also create your own SetupWidget by extending `SetupWidget`:

```dart
class CounterWidget extends SetupWidget {
  const CounterWidget({super.key});

  @override
  WidgetBuilder setup(BuildContext context) {
    final count = useSignal(0);
    
    useJoltEffect(() {
      print('Count changed: ${count.value}');
    });
    
    return (context) => Column(
      children: [
        Text('Count: ${count.value}'),
        ElevatedButton(
          onPressed: () => count.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### Available Hooks

Setup Widget provides hooks for all Jolt reactive primitives:

```dart
setup: (context) {
  // Signals
  final count = useSignal(0);
  final name = useSignal('Flutter');
  
  // Computed values
  final doubled = useComputed(() => count.value * 2);
  
  // Reactive collections
  final items = useListSignal(['apple', 'banana']);
  final userMap = useMapSignal({'name': 'John', 'age': 30});
  
  // Effects
  useJoltEffect(() {
    print('Count changed: ${count.value}');
  });
  
  // Lifecycle callbacks
  onMounted(() {
    print('Widget mounted');
  });
  
  onUnmounted(() {
    print('Widget unmounted');
  });
  
  onUpdated(() {
    print('Widget updated');
  });
  
  onChangedDependencies(() {
    print('Dependencies changed');
  });
  
  // Watch widget parameters
  final props = useProps();
  
  return (context) => Text('Count: ${count.value}');
}
```

### Watching Widget Parameters

Since the `setup` function executes only once, you cannot directly access widget parameters in the builder function to react to changes. Use `useProps()` to create a reactive reference to the widget instance, which is the **only way** to watch for widget parameter changes in SetupWidget.

```dart
class UserCard extends SetupWidget {
  final String name;
  final int age;
  
  const UserCard({
    super.key,
    required this.name,
    required this.age,
  });

  @override
  WidgetBuilder setup(BuildContext context) {
    // useProps() returns a reactive ReadonlyNode that tracks widget changes
    final props = useProps();
    
    // Create a computed that reacts to prop changes
    final displayText = useComputed(() => 
      '${props.value.name} (${props.value.age})'
    );
    
    // The builder will rebuild when props change
    return (context) => Text(displayText.value);
  }
}

// Usage
UserCard(name: 'Alice', age: 30)  // Initial render
UserCard(name: 'Bob', age: 25)    // Widget updates, builder rebuilds
```

**Important:** `useProps()` returns a `ReadonlyNode<YourWidgetType>`, allowing you to access widget properties reactively. When the parent widget updates the SetupWidget with new parameters, the `props.value` will reflect the new widget instance, triggering reactive updates in any Computed or Effect that depends on it.

### Lifecycle Management

All hooks automatically dispose their resources when the widget is unmounted. This ensures proper cleanup and prevents memory leaks:

```dart
setup: (context) {
  final timer = useSignal<Timer?>(null);
  
  onMounted(() {
    timer.value = Timer.periodic(Duration(seconds: 1), (_) {
      print('Tick');
    });
  });
  
  onUnmounted(() {
    timer.value?.cancel();
  });
  
  return (context) => Text('Timer running');
}
```

### Setup Execution Model

Unlike React hooks where the component function runs on every render, Setup Widget's `setup` function executes only once when the widget is first created. This provides several benefits:

- **Performance**: Setup logic doesn't re-run unnecessarily
- **Stability**: Hook instances persist across rebuilds
- **Predictability**: Initialization happens once, making state management clearer

The returned builder function is called on each rebuild, allowing the UI to react to signal changes while keeping the setup logic stable.

### Hot Reload Support

Setup Widget supports Flutter's hot reload feature with intelligent state preservation. The hot reload mechanism works as follows:

**State Storage via `useHook()`:**
All hooks created through `useHook()` (which is used internally by hooks like `useSignal`, `useComputed`, etc.) store their state in a type-indexed cache. Each hook state is stored based on its type and the order it appears in the setup function, creating a type sequence that uniquely identifies each hook.

**Hot Reload Process:**
1. When hot reload occurs, Flutter calls `reassemble()` on the widget
2. Setup Widget detects the reassembly and marks the context for reload
3. The setup function is re-executed with the same type sequence
4. As each hook is called, `useHook()` matches the hook by its type and position in the sequence
5. If a matching state exists in the cache, it's reused; otherwise, a new state is created
6. Unused hooks (removed from the setup function) are automatically cleaned up

**Important Notes:**
- Hot reload is the **only** way to make setup re-execute for the same widget instance
- In release builds, all hot reload code is stripped out (assert blocks), so setup executes only once
- Hook state preservation depends on maintaining the same type sequence in your setup function
- If you change the order or types of hooks, state may not be preserved correctly

```dart
setup: (context) {
  // These hooks will preserve state during hot reload
  // as long as their types and order remain the same
  final count = useSignal(0);        // Type: Signal<int>, Index: 0
  final name = useSignal('Flutter'); // Type: Signal<String>, Index: 1
  
  // After hot reload, count and name will retain their values
  // if the setup function structure remains unchanged
  return (context) => Text('${name.value}: ${count.value}');
}
```

## ValueNotifier Integration

### Converting Jolt Signals to ValueNotifier

Bridge Jolt signals with Flutter's ValueNotifier system using the extension:

```dart
final counter = Signal(0);
final notifier = counter.notifier; // Returns JoltValueNotifier

// Use with AnimatedBuilder
AnimatedBuilder(
  animation: notifier,
  builder: (context, child) => Text('Count: ${notifier.value}'),
)

// Use with ValueListenableBuilder
ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('Count: $value'),
)
```

### Converting ValueNotifier to Jolt Signal

Convert Flutter's ValueNotifier to Jolt signals for bidirectional sync:

```dart
final notifier = ValueNotifier(0);
final signal = notifier.toNotifierSignal();

// Changes sync bidirectionally
notifier.value = 1; // signal.value becomes 1
signal.value = 2;   // notifier.value becomes 2
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
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
)
```

### Batch Updates

Batch multiple signal updates to avoid unnecessary rebuilds:

```dart
batch(() {
  counter.value++;
  name.value = 'New Name';
  // Only one rebuild occurs
});
```

## Important Notes

### Widget Lifecycle
- `JoltBuilder` automatically tracks signal dependencies
- Widgets rebuild only when tracked signals change
- Use `JoltSelector` for performance optimization

### Memory Management
- Signals are automatically disposed when widgets are disposed
- `JoltProvider` manages resource lifecycle with `JoltState`
- ValueNotifier integration handles cleanup automatically

### Performance Tips
- Use `JoltSelector` for fine-grained updates
- Batch multiple signal updates with `batch()`
- Avoid accessing signals in widget constructors
- Use `JoltProvider` for resources that need lifecycle management

## Related Packages

Jolt Flutter is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_flutter_hooks](https://pub.dev/packages/jolt_flutter_hooks) | Declarative hooks for Flutter: useTextEditingController, useScrollController, useFocusNode, etc. |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.