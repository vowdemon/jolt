# Jolt

Jolt is a lightweight reactive state management library for Dart and Flutter.  
It offers signals, computed values, effects, async states, and reactive collections.

## Documentation

[Official Documentation](https://jolt.vowdemon.com)

## Features

- **⚡ Fine-Grained Reactive Updates**: Precisely track every dependency and update only what actually changed, delivering smooth, responsive applications
- **🎯 Clean and Elegant API**: Lightweight design with intuitive API, complete type safety, making your code more elegant and secure
- **🚀 Exceptional Performance**: Deeply optimized for exceptional performance, maintaining smooth operation even in large, complex applications
- **🧹 Intelligent Resource Management**: Automatic dependency tracking and smart resource cleanup. EffectScope provides unified lifecycle management, eliminating memory leaks
- **📦 Complete Ecosystem**: Rich ecosystem with reactive collections (List, Map, Set, Iterable), async operations (Future & Stream), type conversion, and persistence helpers
- **🔧 Zero-Cost Migration**: Comprehensive extension methods and utilities with clear API design, enabling smooth migration from other solutions

Jolt provides a complete reactive programming solution with signals, computed values, effects, and reactive collections. It's designed for building responsive applications with automatic dependency tracking and efficient updates.

> For full API reference and detailed usage examples, check the inline comments in the source code and the [Documentation](https://pub.dev/documentation/jolt/latest/).


## Quick Start

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create reactive state
  final count = Signal(0);
  final doubled = Computed(() => count.value * 2);

  // React to changes
  Effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });

  count.value = 5; // Prints: "Count: 5, Doubled: 10"
}
```

## Core Features

### Signals

Reactive containers that hold values and notify subscribers when changed:

```dart
final counter = Signal(0);
counter.value = 1; // Automatically notifies subscribers

// Access without creating dependency
final currentValue = counter.peek;

// Force notification without changing value
counter.notify();
```

### Computed Values

Derived values that update automatically when dependencies change:

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');
final fullName = Computed(() => '${firstName.value} ${lastName.value}');

// Computed values are cached and only recompute when dependencies change
print(fullName.value); // "John Doe"
firstName.value = 'Jane';
print(fullName.value); // "Jane Doe" - automatically updated
```

### Effects

Side-effect functions that run when their dependencies change:

```dart
final count = Signal(0);
final List<int> values = [];

Effect(() {
  values.add(count.value); // Creates dependency on count
});

count.value = 1; // Effect runs again
count.value = 2; // Effect runs again
// values = [0, 1, 2]
```

### Async Operations

Handle asynchronous operations with built-in state management:

```dart
// From Future
final userSignal = AsyncSignal.fromFuture(fetchUser());

// From Stream  
final dataSignal = AsyncSignal.fromStream(dataStream);

// Handle states
Effect(() {
  final state = userSignal.value;
  if (state.isLoading) print('Loading...');
  if (state.isSuccess) print('User: ${state.data}');
  if (state.isError) print('Error: ${state.error}');
});

// Using map for cleaner code
final displayText = Computed(() => 
  userSignal.value.map(
    loading: () => 'Loading...',
    success: (data) => 'User: $data',
    error: (error, stackTrace) => 'Error: $error',
  ) ?? 'Unknown'
);
```

### Reactive Collections

Work with reactive lists, sets, and maps:

```dart
final items = ListSignal(['apple', 'banana']);
final tags = SetSignal({'dart', 'flutter'});
final userMap = MapSignal({'name': 'Alice', 'age': 30});

// All mutations trigger reactive updates automatically
items.add('cherry');
items.insert(0, 'orange');
items.removeAt(1);

tags.add('reactive');
tags.remove('dart');

userMap['city'] = 'New York';
userMap.remove('age');

// Direct collection access
final list = items.value; // Get underlying List
items.value = ['new', 'list']; // Replace entire collection
```

### Batching Updates

Batch multiple updates to prevent intermediate notifications:

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);
final List<int> values = [];

Effect(() {
  values.add(signal1.value + signal2.value);
});

// Without batching: values = [3, 12, 30] (3 updates)
signal1.value = 10;
signal2.value = 20;

// With batching: values = [3, 30] (2 updates)
batch(() {
  signal1.value = 10;
  signal2.value = 20;
});
```

### Untracked Access

Access values without creating dependencies:

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);

Effect(() {
  final tracked = signal1.value; // Creates dependency
  final untracked = untracked(() => signal2.value); // No dependency
  print('$tracked + $untracked');
});

signal1.value = 10; // Effect runs
signal2.value = 20; // Effect doesn't run
```

### Effect Scopes

Manage effect lifecycles with automatic cleanup:

```dart
final scope = EffectScope((scope) {
  Effect(() => print('Reactive effect'));
  // Effects are automatically disposed when scope is disposed
});

scope.dispose(); // Cleans up all effects in scope
```

### Watchers

Watch for changes without creating effects:

```dart
final signal = Signal(0);
final List<int> changes = [];

Watcher(
  () => signal.value, // Source function
  (value, previousValue) {
    changes.add(value);
    print('Changed from $previousValue to $value');
  },
  immediately: true, // Run immediately
);
```

### Extension Methods

Convert existing types to reactive equivalents:

```dart
// Convert collections
final reactiveList = [1, 2, 3].toListSignal();
final reactiveMap = {'key': 'value'}.toMapSignal();
final reactiveSet = {1, 2, 3}.toSetSignal();

// Convert async sources
final asyncSignal = someFuture.toAsyncSignal();
final streamSignal = someStream.toStreamSignal();
```

## Advanced Features

### Type-Converting Signals

Create signals that convert between different types:

```dart
final count = Signal(0);
final textCount = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

textCount.value = "42"; // Updates count to 42
print(count.value); // 42
```

### Persistent Signals

Signals that automatically persist to storage:

```dart
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () => SharedPreferences.getInstance()
    .then((prefs) => prefs.getString('theme') ?? 'light'),
  write: (value) => SharedPreferences.getInstance()
    .then((prefs) => prefs.setString('theme', value)),
  lazy: false, // Load immediately
  writeDelay: Duration(milliseconds: 100), // Debounce writes
);

theme.value = 'dark'; // Automatically saved to storage
```

## Important Notes

### Collection Signals
- Collection signals automatically notify on mutations
- Direct collection access (`signal.value.add()`) requires manual `notify()` call
- Use collection methods (`signal.add()`) for automatic notifications

### Async Signals
- Use `AsyncSignal.fromFuture()` for single async operations
- Use `AsyncSignal.fromStream()` for continuous data streams
- Always handle all states: loading, success, error, refreshing

### Effect Dependencies
- Effects only re-run when tracked dependencies change
- Use `untracked()` to access values without creating dependencies
- Effects run immediately when created

### Memory Management
- Always dispose signals and effects when no longer needed
- Use `EffectScope` for automatic cleanup of multiple effects
- Disposed signals throw `AssertionError` when accessed

## Related Packages

Jolt is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.