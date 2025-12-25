---
---

# Jolt

Jolt is a lightweight reactive state management library for Dart and Flutter.

## What is a Reactive System?

A reactive system is a programming paradigm that automatically tracks data dependencies and updates accordingly. When you access reactive data, the system **automatically establishes dependencies**. When data changes, all computed values and effects that depend on it **automatically re-execute**, eliminating the need for manual subscription management.

For example:

```dart
final count = Signal(0);  // Reactive state
final doubled = Computed(() => count.value * 2);  // Automatically tracks count

Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');  // Automatically tracks dependencies
});

count.value = 5;  // Automatically triggers Effect and Computed updates
```

This mechanism makes state management automated and efficient. You focus on data changes, and the system handles updates automatically.

## Why Choose Jolt?

### Powerful Reactive Signal System

Jolt's core reactive system is ported from [alien_signals](https://github.com/alien-signals/alien_signals), a battle-tested, high-performance reactive signal library. Built on a fine-grained reactive dependency graph, Jolt creates an efficient and precise state management system. The core of this system is the **automatic dependency tracking** mechanism:

**Automatic Dependency Graph Construction**: When you access reactive values, Jolt automatically establishes connections in the dependency graph. The system maintains a bidirectional dependency graph that records which Signals are depended upon by which Computed values and Effects, and which Signals each Computed and Effect depends on.

```dart
final count = Signal(0);
final name = Signal('Alice');

// Dependencies are automatically established when accessed
final display = Computed(() => '${name.value}: ${count.value}');
// System records: display depends on name and count

Effect(() {
  print('Display: ${display.value}');
  // System records: Effect depends on display (indirectly depends on name and count)
});

// When count changes, the system automatically:
// 1. Detects count change
// 2. Finds display that depends on count
// 3. Recomputes display
// 4. Finds Effect that depends on display
// 5. Executes Effect
count.value = 5; // The entire update chain executes automatically
```

**Fine-Grained Update Propagation**: Jolt uses an efficient update propagation algorithm that only updates what actually changed. When a Signal changes, the system propagates updates along the dependency graph, but only updates nodes that truly need updating. This avoids unnecessary computations and rebuilds, ensuring optimal performance.

**Smart Batching Mechanism**: Jolt has built-in batching that can merge multiple updates within the same frame. This means even if you rapidly modify multiple Signals, the system will only trigger one update, avoiding intermediate state flickering and unnecessary computations.

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);
final sum = Computed(() => signal1.value + signal2.value);

Effect(() => print('Sum: ${sum.value}'));

// Without batching: triggers two updates
signal1.value = 10; // Output: "Sum: 12"
signal2.value = 20; // Output: "Sum: 30"

// With batching: triggers only one update
batch(() {
  signal1.value = 100;
  signal2.value = 200;
}); // Only outputs: "Sum: 300"
```

**Caching and Lazy Computation**: Computed values are automatically cached and only recomputed when dependencies change. You can use `peekCached` to access cached values without triggering recomputation, or use `peek` to recompute without establishing dependencies. This design maximizes performance while ensuring correctness.

### Minimal Boilerplate

Jolt's core advantage is minimal boilerplate. You don't need to define classes, methods, or events—just use Signal, Computed, and Effect directly:

```dart
// Create reactive state
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

// React to changes
Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');
});

// Modify state
count.value = 5; // Automatically triggers update
```

No manual subscription management is needed—dependencies are automatically established and cleaned up. This significantly reduces code volume and improves development efficiency and maintainability.

### Rich Tools and Features

Jolt provides a comprehensive toolset covering all aspects of reactive programming:

#### Core Reactive Primitives

- **Signal**: Mutable reactive state containers supporting lazy initialization, read-only views, manual notifications, and more
- **Computed**: Automatically computed derived values supporting caching, lazy computation, and non-dependency access
- **WritableComputed**: Writable computed values supporting two-way binding
- **Effect**: Side-effect functions supporting lazy execution, cleanup callbacks, and scope management
- **Watcher**: Value change listeners supporting immediate execution, one-time execution, and conditional triggering
- **EffectScope**: Effect scopes for managing the lifecycle of multiple Effects

#### Reactive Collections

- **ListSignal**: Reactive lists where all mutation operations automatically trigger updates
- **MapSignal**: Reactive maps where key-value pair additions, deletions, and modifications automatically trigger updates
- **SetSignal**: Reactive sets where element additions and deletions automatically trigger updates
- **IterableSignal**: Reactive iterables supporting dynamic generation

```dart
final items = ListSignal(['apple', 'banana']);
items.add('cherry'); // Automatically triggers update
items.insert(0, 'orange'); // Automatically triggers update

final userMap = MapSignal({'name': 'Alice', 'age': 30});
userMap['city'] = 'New York'; // Automatically triggers update
```

#### Async State Management

- **AsyncSignal**: Unified async state management that automatically handles loading, success, and error states
- **AsyncSignal.fromFuture**: Create async signals from Futures
- **AsyncSignal.fromStream**: Create async signals from Streams

```dart
final userSignal = AsyncSignal.fromFuture(fetchUser());

Effect(() {
  final state = userSignal.value;
  if (state.isLoading) print('Loading...');
  if (state.isSuccess) print('User: ${state.data}');
  if (state.isError) print('Error: ${state.error}');
});
```

#### Extension Methods

- **stream / listen**: Convert reactive values to streams
- **until / untilWhen**: Wait for reactive values to satisfy conditions
- **readonly**: Get read-only views
- **update**: Modify values using update functions
- **derived**: Create computed values from Readable
- **call / get**: Alternative syntax for reading values

```dart
// Convert to streams
final stream = counter.stream;
stream.listen((value) => print(value));

// Wait for condition to be satisfied
final data = await isLoading.until((value) => !value);

// Create derived computed
final doubled = count.derived((value) => value * 2);
```

#### Advanced Tools

- **ConvertComputed**: Type-converting computed values supporting bidirectional conversion
- **PersistSignal**: Persistent signals that automatically save and restore state
- **batch**: Batch multiple updates
- **untracked**: Non-dependency access—read values without establishing dependencies
- **trackWithEffect**: Manually control dependency tracking
- **notifyAll**: Manually trigger all subscriber updates

```dart
// Type conversion
final count = Signal(0);
final textCount = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

// Persistence
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () => SharedPreferences.getInstance()
    .then((prefs) => prefs.getString('theme') ?? 'light'),
  write: (value) => SharedPreferences.getInstance()
    .then((prefs) => prefs.setString('theme', value)),
);
```

#### Flutter Integration Tools

- **JoltBuilder**: Automatic reactive UI updates
- **JoltSelector**: Fine-grained selector updates
- **JoltWatchBuilder**: Watch a single Readable value and rebuild
- **JoltValueNotifier**: Integration with Flutter's ValueNotifier system
- **SetupWidget / SetupBuilder**: Composition-based API (from `jolt_setup` package)
- **FlutterEffect**: Flutter-specific side effects that execute at frame end

#### Hooks Support

- **jolt_hooks**: Hooks API based on flutter_hooks
- **jolt_setup**: Setup Widget API with Flutter resource Hooks (controllers, focus nodes, etc.)

#### Surge Pattern

- **Surge**: State containers similar to BLoC Cubit
- **SurgeProvider / SurgeConsumer / SurgeBuilder**: Flutter Widget integration
- **SurgeObserver**: State change monitoring

#### Development Tools

- **jolt_lint**: Code transformation assists and rule checking, supporting Signal conversion, Widget wrapping, and more

### Concise API

Jolt has only three core concepts: Signal (state), Computed (computed values), and Effect (side effects). The learning curve is gentle and easy to pick up, while still being powerful. All advanced features are built on these three core concepts, maintaining API consistency and predictability.

### Type Safety

Fully leverages Dart's type system, providing complete type safety and compile-time checking. Errors can be caught at compile time, reducing runtime issues. All reactive values are strongly typed, with type information fully preserved in the dependency graph.

### Performance Optimization

Built-in batching, caching, and lazy computation mechanisms ensure high performance even in complex scenarios. Computed values are automatically cached and only recomputed when dependencies change. The update propagation algorithm is optimized to avoid unnecessary computations.

### Hot Reload Friendly

State persists during hot reload, providing a smooth development experience without needing to reinitialize state. This greatly improves development efficiency, allowing you to iterate and debug quickly.

### Debug Friendly

Clear dependency graphs make it easy to trace issues. When a value unexpectedly updates, you can quickly locate the dependency chain and understand data flow. Jolt also provides debugging tools to help visualize dependencies.

### Progressive Adoption

You can gradually migrate existing code without rewriting the entire application. Jolt is compatible with Flutter's native APIs and can coexist with existing solutions like StatefulWidget and Provider. You can start with a small module and gradually expand to the entire application.

### Cross-Platform Support

Pure Dart core that works in both Dart CLI and Flutter. Deep Flutter integration provides specialized Widgets like `JoltBuilder`, `JoltWatchBuilder`, `SetupWidget` (from `jolt_setup` package), and Flutter-specific features like `FlutterEffect`.

### Suitable for All Scales

Whether it's a personal project, startup, or large enterprise application, Jolt can handle it. Its concise API is suitable for rapid development, while its powerful features can support complex scenarios. From rapid prototypes to large enterprise applications, Jolt provides an excellent development experience and performance.

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

  count.value = 5; // Output: "Count: 5, Doubled: 10"
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/vowdemon/jolt/blob/main/LICENSE) file for details.
