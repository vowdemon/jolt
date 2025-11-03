---
---

# Flutter Widgets

When building reactive UIs in Flutter, Jolt provides three core widgets: `JoltBuilder`, `JoltSelector`, and `JoltProvider`. These widgets are based on Jolt's reactive system and track dependency changes by creating **Effect** scopes within Flutter.

When you access signals, computed values, or reactive collections in the `builder` function, these widgets **automatically establish dependencies**. When tracked dependencies change, the internal Effect is triggered and notifies the Flutter framework to rebuild the widget, keeping the UI in sync with data state.

This design eliminates the need for developers to manually manage subscriptions and unsubscriptions, or worry about when widgets need to rebuild. You simply access reactive data naturally in the `builder`, and the rest happens automatically. Each widget has its specific use cases, which we'll explore one by one.

## JoltBuilder

`JoltBuilder` is the most versatile reactive widget that automatically tracks all signals accessed in its `builder` function. The widget rebuilds automatically when any tracked signal changes.

### How It Works

`JoltBuilder` internally creates an `EffectScope` and `Effect`. When the `builder` function executes, all accessed signals are automatically tracked. When these signals' values change, the Effect triggers a rebuild request, ensuring the UI always reflects the latest data state. Batch updates from multiple signals are automatically merged, ensuring only one rebuild per frame for optimal performance.

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return JoltBuilder(
      builder: (context) => Column(
        children: [
          Text('Count: ${counter.value}'),
          ElevatedButton(
            onPressed: () => counter.value++,
            child: Text('Increment'),
          ),
        ],
      ),
    );
  }
}
```

### Multiple Signal Tracking

`JoltBuilder` can track multiple signals simultaneously, triggering a rebuild when any of them changes:

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

JoltBuilder(
  builder: (context) => Text(
    'Hello ${firstName.value} ${lastName.value}',
  ),
);
```

## JoltSelector

`JoltSelector` provides fine-grained rebuild control by using a `selector` function to choose which value to track. The widget only rebuilds when the value returned by `selector` changes. This is particularly useful for complex objects or scenarios where data filtering is needed, avoiding unnecessary rebuilds and improving performance.

### How It Works

`JoltSelector` also uses `EffectScope` and `Effect` internally to track dependencies. The difference is that it executes dependency tracking within the `selector` function, then compares the selector's return value with the previous value. Rebuilds only occur when the return value changes (using equality comparison). This means even if other properties of the signal change, as long as the selected value remains unchanged, the widget won't rebuild.

### Basic Usage

```dart
final user = Signal(User(name: 'John', age: 30));

// Only track name, not age
JoltSelector(
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
);

// Rebuilds when user.name changes
// Doesn't rebuild when user.age changes
```

### Multi-Signal Selection

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

JoltSelector(
  selector: (prev) => '${firstName.value} ${lastName.value}',
  builder: (context, fullName) => Text('Hello $fullName'),
);
```

## JoltProvider

`JoltProvider` is used to provide and manage reactive resources in the widget tree, supporting complete lifecycle management. It combines the dependency injection pattern with reactive programming, allowing you to share state across the component tree while automatically handling resource creation and disposal.

### How It Works

`JoltProvider` internally uses `JoltBuilder` to implement reactive updates, meaning signals accessed in the `builder` are automatically tracked. It also provides resources to the entire subtree via `InheritedWidget`, allowing descendant widgets to access resources through `JoltProvider.of<T>(context)`. If the resource implements the `JoltState` interface, `JoltProvider` automatically calls `onMount` and `onUnmount` lifecycle callbacks, facilitating resource initialization and cleanup.

### Basic Usage

```dart
class MyStore extends JoltState {
  final counter = Signal(0);
  
  @override
  void onMount(BuildContext context) {
    print('Store mounted');
  }
  
  @override
  void onUnmount(BuildContext context) {
    print('Store unmounted');
  }
}

JoltProvider<MyStore>(
  create: (context) => MyStore(),
  builder: (context, store) => Text('${store.counter.value}'),
);
```

### Accessing from Descendant Widgets

```dart
JoltProvider<MyStore>(
  create: (context) => MyStore(),
  builder: (context, store) => ChildWidget(),
);

// In ChildWidget
class ChildWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = JoltProvider.of<MyStore>(context);
    return Text('Count: ${store.counter.value}');
  }
}
```

### Optional Access

```dart
final store = JoltProvider.maybeOf<MyStore>(context);
if (store != null) {
  // Use store
}
```

