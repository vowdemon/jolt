---
---

# Flutter Widgets

When building reactive UIs in Flutter, Jolt provides core Widgets: `JoltBuilder`, `JoltSelector`, and `JoltWatchBuilder`. These Widgets are all implemented based on `FlutterEffect`, triggering only one rebuild per frame, automatically tracking dependency changes, and rebuilding Widgets when dependencies change, keeping the UI synchronized with data state.

When you access signals (Signal), computed values (Computed), or reactive collections in the `builder` function, these Widgets **automatically establish dependencies**. When tracked dependencies change, Widgets automatically rebuild, keeping the UI synchronized with data state.

This design eliminates the need for developers to manually manage subscriptions and unsubscriptions, or worry about when Widgets need to rebuild. You just naturally access reactive data in `builder`, and the rest is handled automatically. Each Widget has its specific use cases—let's explore them one by one.

## JoltBuilder

`JoltBuilder` is the most general-purpose reactive Widget, automatically tracking all signals accessed in the `builder` function. When any tracked signal changes, the Widget automatically rebuilds.

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

`JoltBuilder` can track multiple signals simultaneously, triggering rebuilds when any of them change:

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

`JoltSelector` provides finer-grained rebuild control, using a `selector` function to select the value to track. The Widget only rebuilds when the value returned by `selector` changes (via `==` comparison). This is particularly useful for complex objects or scenarios requiring data filtering, avoiding unnecessary rebuilds and improving performance.

### Basic Usage

```dart
final user = Signal(User(name: 'John', age: 30));

// Only listen to name, not age
JoltSelector(
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
);

// Rebuilds when user.name changes
// Does not rebuild when user.age changes
```

### Multiple Signal Selection

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

JoltSelector(
  selector: (prev) => '${firstName.value} ${lastName.value}',
  builder: (context, fullName) => Text('Hello $fullName'),
);
```

### Using Previous Value

The `selector` function receives the previously selected value (null on first call), which can be used for comparison or optimization:

```dart
JoltSelector(
  selector: (prev) {
    final current = computeValue();
    // If value is the same, return the same instance to avoid rebuild
    if (prev != null && prev == current) {
      return prev;
    }
    return current;
  },
  builder: (context, value) => Text('$value'),
);
```

## JoltWatchBuilder

`JoltWatchBuilder` is a reactive Widget that tracks a single `Readable` value and rebuilds when that value changes. It's particularly useful when you want to watch a specific signal or computed value.

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return JoltWatchBuilder<int>(
      readable: counter,
      builder: (context, value) => Text('Count: $value'),
    );
  }
}
```

### Using the watch Extension

For convenience, you can use the `watch` extension method directly on a `Readable`:

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/extension.dart';

final counter = Signal(0);

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        counter.watch((value) => Text('Count: $value')),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### When to Use JoltWatchBuilder vs JoltBuilder

- **JoltWatchBuilder**: Use when you want to track a single specific `Readable` value. More explicit and easier to understand dependencies.
- **JoltBuilder**: Use when you want to track multiple signals or when dependencies are complex and dynamic.

## JoltProvider

> **⚠️ Deprecated**: `JoltProvider` is deprecated and will be removed in a future version. For dependency injection, use Flutter's built-in solutions like `Provider`, `Riverpod`, or other DI packages.

`JoltProvider` was used to provide and manage reactive resources in the Widget tree, supporting complete lifecycle management. It combined dependency injection patterns with reactive programming, allowing you to share state in the component tree while automatically handling resource creation and disposal.

### Migration Guide

Replace `JoltProvider` with Flutter's dependency injection solutions:

```dart
// Before
JoltProvider<MyStore>(
  create: (context) => MyStore(),
  builder: (context, store) => Text('${store.counter.value}'),
)

// After - Using Provider package
Provider<MyStore>(
  create: (_) => MyStore(),
  child: Builder(
    builder: (context) {
      final store = Provider.of<MyStore>(context);
      return Text('${store.counter.value}');
    },
  ),
)
```

### Using create

Using the `create` constructor automatically manages resource lifecycle, automatically calling `onUnmount` and `dispose()` when the Widget is unmounted:

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

### Using .value

When using the `.value` constructor, resource lifecycle needs manual management. Provider will not call `onMount`, `onUnmount`, or `dispose()`:

```dart
final store = MyStore();

JoltProvider<MyStore>.value(
  value: store,
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

## JoltState

`JoltState` is an abstract class for resources that need lifecycle management. When resources are used in `JoltProvider` with the `create` constructor, if the resource implements `JoltState`, lifecycle callbacks are automatically called.

### Lifecycle

- **onMount**: Called after resource creation and Widget mounting, used for resource initialization (such as starting timers, subscribing to streams, etc.)
- **onUnmount**: Called when Widget is unmounted or resource is replaced, used for resource cleanup (such as canceling timers, unsubscribing, etc.)

### Example

```dart
class MyStore extends JoltState {
  final counter = Signal(0);
  Timer? _timer;

  @override
  void onMount(BuildContext context) {
    super.onMount(context);
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      counter.value++;
    });
  }

  @override
  void onUnmount(BuildContext context) {
    super.onUnmount(context);
    _timer?.cancel();
    _timer = null;
  }
}
```

If resources don't need lifecycle management, you don't need to extend `JoltState`:

```dart
class SimpleStore {
  final counter = Signal(0);
}
```
