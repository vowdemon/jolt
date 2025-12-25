# Jolt

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt](https://img.shields.io/pub/v/jolt?label=jolt)](https://pub.dev/packages/jolt)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Jolt is a lightweight reactive state management library for Dart and Flutter. It provides signals, computed values, effects, async states, and reactive collections with automatic dependency tracking and efficient updates.

## Documentation

[Official Documentation](https://jolt.vowdemon.com)

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

## Core Concepts

### Signals

Reactive containers that hold values and notify subscribers when changed:

```dart
final counter = Signal(0);
counter.value = 1; // Automatically notifies subscribers

// Access without creating dependency
final currentValue = counter.peek;

// Force notification without changing value
counter.notify();

// Update using updater function
counter.update((value) => value + 1);

// Get read-only view
final readonlyCounter = counter.readonly();
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

// Access cached value without recomputing
final cached = fullName.peekCached;
```

### WritableComputed

Computed values that can be written to, converting the write to source updates:

```dart
final count = Signal(0);
final doubled = WritableComputed(
  () => count.value * 2,
  (value) => count.value = value ~/ 2,
);

doubled.value = 10; // Automatically updates count to 5
print(count.value); // 5
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

// Effects run immediately by default
// Use lazy: true to defer execution
Effect(() {
  print('Deferred effect');
}, lazy: true);
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

## Async Operations

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

## Reactive Collections

Work with reactive lists, sets, maps, and iterables:

```dart
final items = ListSignal(['apple', 'banana']);
final tags = SetSignal({'dart', 'flutter'});
final userMap = MapSignal({'name': 'Alice', 'age': 30});
final range = IterableSignal(() => Iterable.generate(5));

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

## Extension Methods

### Converting to Signals

Convert existing types to reactive equivalents:

```dart
// Convert any value to Signal
final nameSignal = 'Alice'.toSignal();
final countSignal = 42.toSignal();

// Convert collections
final reactiveList = [1, 2, 3].toListSignal();
final reactiveMap = {'key': 'value'}.toMapSignal();
final reactiveSet = {1, 2, 3}.toSetSignal();
final reactiveIterable = Iterable.generate(5).toIterableSignal();

// Convert async sources
final asyncSignal = someFuture.toAsyncSignal();
final streamSignal = someStream.toStreamSignal();
```

### Stream Integration

Convert reactive values to streams:

```dart
final counter = Signal(0);

// Get stream
final stream = counter.stream;
stream.listen((value) => print('Counter: $value'));

// Or use listen convenience method
final subscription = counter.listen(
  (value) => print('Counter: $value'),
  immediately: true, // Call immediately with current value
);

subscription.cancel(); // Stop listening
```

### Conditional Waiting

Wait until a reactive value satisfies a condition:

```dart
final count = Signal(0);

// Wait until count reaches 5
final future = count.until((value) => value >= 5);

count.value = 1; // Still waiting
count.value = 3; // Still waiting
count.value = 5; // Future completes with value 5

final result = await future; // result is 5
```

## Advanced Features

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

### Type-Converting Signals

Create signals that convert between different types:

```dart
import 'package:jolt/tricks.dart';

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

Signals that automatically persist to storage with efficient write queuing and throttling:

```dart
import 'package:jolt/tricks.dart';

// Async persistent signal (for SharedPreferences, etc.)
final theme = PersistSignal.async(
  read: () async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme') ?? 'light';
  },
  write: (value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', value);
  },
  initialValue: () => 'light', // Show while loading
  lazy: false, // Load immediately
  throttle: Duration(milliseconds: 100), // Debounce writes
);

theme.value = 'dark'; // Automatically saved to storage

// Wait for write to complete
await theme.ensureWrite();

// Sync persistent signal (for in-memory storage, etc.)
final counter = PersistSignal.sync(
  read: () => storage.getInt('counter') ?? 0,
  write: (value) => storage.setInt('counter', value),
);

// Lazy initialization - load only when accessed
final settings = PersistSignal.lazySync(
  read: () => loadSettings(),
  write: (value) => saveSettings(value),
);

// Check initialization status
if (settings.isInitialized) {
  print('Settings loaded: ${settings.value}');
}
```

## Important Notes

### Extension Methods
- Import `package:jolt/extension.dart` to use convenience methods
- `call()`, `get()`, `derived()` work on any `Readable<T>`
- `update()`, `set()` work on any `Writable<T>`
- `readonly()` creates type-safe read-only views

### Collection Signals
- Collection signals automatically notify on mutations
- Direct collection access (`signal.value.add()`) requires manual `notify()` call
- Use collection methods (`signal.add()`) for automatic notifications

### Async Signals
- Use `AsyncSignal.fromFuture()` for single async operations
- Use `AsyncSignal.fromStream()` for continuous data streams
- Always handle all states: loading, success, error

### Effect Dependencies
- Effects only re-run when tracked dependencies change
- Use `untracked()` to access values without creating dependencies
- Effects run immediately when created (unless `lazy: true`)

### Memory Management
- Always dispose signals and effects when no longer needed
- Use `EffectScope` for automatic cleanup of multiple effects
- Disposed signals throw `AssertionError` when accessed

### Computed Values
- Computed values are cached and only recompute when dependencies change
- Use `peekCached` to access cached value without recomputing
- Use `peek` to recompute without creating dependencies
- Use `derived()` extension method for concise computed creation

## Related Packages

Jolt is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt_flutter](https://pub.dev/packages/jolt_flutter) | Flutter widgets: JoltBuilder, JoltSelector, JoltProvider, SetupWidget |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_flutter_hooks](https://pub.dev/packages/jolt_flutter_hooks) | Declarative hooks for Flutter: useTextEditingController, useScrollController, useFocusNode, etc. |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |
| [jolt_lint](https://pub.dev/packages/jolt_lint) | Custom lint and code assists: Wrap widgets, convert to/from Signals, Hook conversions |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
