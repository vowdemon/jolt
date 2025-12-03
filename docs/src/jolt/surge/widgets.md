---
---

# Surge Widgets

Surge provides multiple Widgets for using Surge state management in Flutter. These Widgets are based on Jolt's reactive system, providing BLoC-like APIs while maintaining compatibility with the Jolt ecosystem.

## SurgeProvider

`SurgeProvider` is used to provide Surge instances in the Widget tree, similar to how `Provider` works. It supports two constructors: `create` and `.value`.

### Using create Constructor

When using the `create` constructor, Surge lifecycle is automatically managed. When the Widget is removed, `surge.dispose()` is automatically called.

```dart
SurgeProvider<CounterSurge>(
  create: (_) => CounterSurge(), // Automatically disposed on unmount
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, surge) => Text('count: $state'),
  ),
);
```

### Using .value Constructor

When using the `.value` constructor, Surge lifecycle needs manual management. Surge will not be automatically disposed when the Widget is removed.

```dart
// Singleton Surge, managed elsewhere
final surge = CounterSurge();

SurgeProvider<CounterSurge>.value(
  value: surge, // Not automatically disposed
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, s) => Text('count: $state'),
  ),
);
```

### Accessing from Descendant Widgets

```dart
// Get Surge instance
final surge = context.read<CounterSurge>();

// Trigger state changes
ElevatedButton(
  onPressed: () => surge.increment(),
  child: const Text('Increment'),
);
```

### Parameters

- `create`: Function to create Surge instance (when using `create` constructor)
- `value`: Surge instance (when using `.value` constructor)
- `lazy`: Whether to lazy create (default true)
- `child`: Child Widget

## SurgeBuilder

`SurgeBuilder` is a convenient Widget for building UI based on Surge state changes. It's a simplified version of `SurgeConsumer`, providing only `builder` functionality.

### Cubit-Compatible API

```dart
// 100% compatible API with BlocBuilder
SurgeBuilder<CounterSurge, int>(
  builder: (context, state) => Text('Count: $state'),
  buildWhen: (prev, next) => next.isEven, // Only rebuild on even numbers
);
```

### Full API

```dart
SurgeBuilder<CounterSurge, int>.full(
  builder: (context, state, surge) => Text('Count: ${surge.state}'),
  buildWhen: (prev, next, s) => next.isEven, // Only rebuild on even numbers
);
```

### Parameters

- `builder`: Function to build UI, receives `(context, state)` or `(context, state, surge)`
- `buildWhen`: Conditional function to control rebuilding (optional)
- `surge`: Surge instance (optional, defaults to getting from context)

## SurgeListener

`SurgeListener` is a convenient Widget for listening to Surge state changes and executing side effects. It does not rebuild child Widgets, only executes the `listener` function.

### Cubit-Compatible API

```dart
// 100% compatible API with BlocListener
SurgeListener<CounterSurge, int>(
  listenWhen: (prev, next) => next > prev, // Only listen on increase
  listener: (context, state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count increased to: $state')),
    );
  },
  child: const SizedBox.shrink(),
);
```

### Full API

```dart
SurgeListener<CounterSurge, int>.full(
  listenWhen: (prev, next, s) => next > prev, // Only listen on increase
  listener: (context, state, surge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count increased to: $state')),
    );
  },
  child: const SizedBox.shrink(),
);
```

### Parameters

- `listener`: Function to handle side effects, receives `(context, state)` or `(context, state, surge)`
- `listenWhen`: Conditional function to control listener execution (optional)
- `child`: Child Widget (not rebuilt)
- `surge`: Surge instance (optional, defaults to getting from context)

## SurgeConsumer

`SurgeConsumer` is a unified Widget that provides both `builder` and `listener` functionality. It offers fine-grained control, allowing separate control over when to rebuild UI and when to execute side effects.

### How It Works

- **builder**: Builds UI, default behavior is untracked (does not create reactive dependencies), only rebuilds when `buildWhen` returns true
- **listener**: Handles side effects (such as showing SnackBar, sending analytics events, etc.), default behavior is untracked, only executes when `listenWhen` returns true
- **buildWhen**: Controls whether to rebuild, default is tracked (can depend on external signals)
- **listenWhen**: Controls whether to execute listener, default is tracked (can depend on external signals)

### Cubit-Compatible API

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next) => next.isEven, // Only rebuild on even numbers
  listenWhen: (prev, next) => next > prev, // Only listen on increase
  builder: (context, state) => Text('count: $state'),
  listener: (context, state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count is now: $state')),
    );
  },
);
```

### Full API

```dart
SurgeConsumer<CounterSurge, int>.full(
  buildWhen: (prev, next, s) => next.isEven, // Only rebuild on even numbers
  listenWhen: (prev, next, s) => next > prev, // Only listen on increase
  builder: (context, state, surge) => Text('count: $state'),
  listener: (context, state, surge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count is now: $state')),
    );
  },
);
```

### Using External Signals

`buildWhen` and `listenWhen` are tracked by default and can depend on external signals. If you need to use external signals in an untracked manner, use `untracked`:

```dart
SurgeConsumer<CounterSurge, int>.full(
  buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
  // ...
);
```

### Parameters

- `builder`: Function to build UI, receives `(context, state)` or `(context, state, surge)`
- `listener`: Function to handle side effects, receives `(context, state)` or `(context, state, surge)`
- `buildWhen`: Conditional function to control rebuilding (optional, tracked by default)
- `listenWhen`: Conditional function to control listener execution (optional, tracked by default)
- `surge`: Surge instance (optional, defaults to getting from context)

## SurgeSelector

`SurgeSelector` provides fine-grained rebuild control, using a `selector` function to select the value to track. The Widget only rebuilds when the value returned by `selector` changes.

### How It Works

`SurgeSelector` internally uses `EffectScope` and `Effect` to track dependencies. It executes dependency tracking in the `selector` function, then compares the `selector`'s return value with the previous value. Only when the return value changes (using equality comparison) does it trigger Widget rebuild.

### Cubit-Compatible API

```dart
// 100% compatible API with BlocSelector
SurgeSelector<CounterSurge, int, String>(
  selector: (state) => state.isEven ? 'even' : 'odd',
  builder: (context, selected) => Text('Number is $selected'),
);
// Only rebuilds when state switches between even and odd
```

### Full API

```dart
SurgeSelector<CounterSurge, int, String>.full(
  selector: (state, surge) => state.isEven ? 'even' : 'odd',
  builder: (context, selected, surge) => Text('Number is $selected'),
);
```

### Using External Signals

The `selector` function is tracked by default and can depend on external signals. If you need to use external signals in an untracked manner, use `untracked`:

```dart
SurgeSelector<CounterSurge, int, String>.full(
  selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  builder: (context, selected, s) => Text(selected),
);
```

### Parameters

- `builder`: Function to build UI, receives `(context, selected)` or `(context, selected, surge)`
- `selector`: Function to extract value from state, receives `(state)` or `(state, surge)`
- `surge`: Surge instance (optional, defaults to getting from context)

## Complete Example

```dart
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

class CounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SurgeProvider<CounterSurge>(
      create: (_) => CounterSurge(),
      child: MaterialApp(
        home: CounterPage(),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final surge = context.read<CounterSurge>();

    return Scaffold(
      body: Center(
        child: SurgeBuilder<CounterSurge, int>(
          builder: (context, state) => Text('Count: $state'),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => surge.increment(),
            child: Icon(Icons.add),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => surge.decrement(),
            child: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
```

## Important Notes

1. **API Compatibility**: Surge Widgets provide 100% compatible APIs with BLoC, making it easy to migrate from Bloc/Cubit.

2. **Performance Optimization**: Using `buildWhen`, `listenWhen`, and `SurgeSelector` allows precise control over rebuilds and side effect execution, optimizing performance.

3. **Reactive Tracking**: `buildWhen`, `listenWhen`, and `selector` are tracked by default and can depend on external signals. Use `untracked` to avoid tracking.

4. **Lifecycle Management**: When using the `create` constructor, Surge lifecycle is automatically managed. When using the `.value` constructor, manual management is required.

5. **Type Safety**: All Widgets provide complete type safety with compile-time type checking.

