---
---

# Signal

Signal is the foundation of the reactive system. It can be modified at any time, and reactive nodes in the system can subscribe to its updates. When a Signal's value changes, all reactive nodes that subscribe to it (such as Computed and Effect) automatically update.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a signal
  final count = Signal(0);

  // Subscribe to signal changes
  Effect(() {
    print('Count: ${count.value}');
  });

  // Modify the signal's value
  count.value = 5; // Output: "Count: 5"
}
```

## Creating Signals

### Standard Creation

Create a signal using the `Signal` constructor, providing an initial value:

```dart
final count = Signal(0);
final name = Signal('Alice');
final items = Signal<List<int>>([]);
```

### Lazy Initialization

Use `Signal.lazy()` to create a lazily initialized signal with an initial value of `null`:

```dart
final data = Signal.lazy<String>();

// Set value later
data.value = 'loaded data';
```

Lazy initialization is suitable for scenarios where the initial value cannot be determined at creation time, such as asynchronous data loading.

```dart
final userData = Signal.lazy<Map<String, dynamic>>();

// Load data asynchronously
loadUserData().then((data) {
  userData.value = data;
});
```

### Read-Only View

Get a read-only view of a writable signal through the `.readonly()` extension method. This is only a compile-time restriction—the underlying signal remains the same:

```dart
final counter = Signal(0);
final readonlyCounter = counter.readonly();

print(readonlyCounter.value); // OK
// readonlyCounter.value = 1; // Compile error

// But can still modify through the original signal
counter.value = 1; // OK, readonlyCounter.value also becomes 1
```

This is useful when you need to expose a signal but restrict write access:

```dart
class Counter {
  final _count = Signal(0);

  ReadonlySignal<int> get count => _count.readonly();

  void increment() => _count.value++;
}
```

**Note**: The read-only view returned by `.readonly()` is essentially the same signal, just with compile-time write restrictions. If you modify the value through the original signal, the read-only view will also see the change.

### Constant Signals

Use the `ReadonlySignal` constructor to create constant read-only signals. Constant signals are simple instances that implement the `ReadonlyNode` interface—**they have no reactive capability, cannot be written to, and do not need disposal**:

```dart
final constant = ReadonlySignal(42);
print(constant.value); // Always 42
// constant.value = 100; // Compile error, constant signals cannot be modified
```

Characteristics of constant signals:

1. **No reactivity**: Constant signals do not trigger any reactive updates because they are just simple value wrappers
2. **Cannot be written**: The value is fixed at creation and cannot be modified
3. **No disposal needed**: Constant signals have no resources to clean up—`dispose()` is a no-op

```dart
final constant = ReadonlySignal(42);

// Does not establish reactive dependencies
Effect(() {
  print(constant.value); // Executes only once, does not react to changes
});

// Constant signal values never change
// constant.value = 100; // Compile error

// No need to call dispose()
// constant.dispose(); // Can be called, but it's a no-op
```

Constant signals are suitable for scenarios where you need to wrap regular values into `ReadonlySignal` type to maintain API consistency:

```dart
class Config {
  // Use constant signals to provide fixed configuration
  static final apiVersion = ReadonlySignal('v1.0');
  static final maxRetries = ReadonlySignal(3);
}

// Use in places that require ReadonlySignal type
void processConfig(ReadonlySignal<String> version) {
  print('Version: ${version.value}');
}

processConfig(Config.apiVersion); // OK
```

**Difference from `.readonly()`**:

- `.readonly()`: Returns a read-only view of the original signal, still reactive, can be modified through the original signal
- `ReadonlySignal()`: Creates a constant signal, no reactivity, value never changes, cannot be modified

## Reading Values

### `.value`

Use the `.value` property to read values—**this creates reactive dependencies**. When the signal's value changes, any reactive nodes that access it will automatically update.

```dart
final count = Signal(0);

Effect(() {
  print(count.value); // Using .value
});

count.value = 10; // Effect will update
```

You can also use the `call()` extension method for a function-like syntax:

```dart
final count = Signal(0);

Effect(() {
  print(count()); // Using call() extension, equivalent to .value
});

count.value = 10; // Effect will update
```

### `.peek`

Use the `.peek` property to read values **without creating reactive dependencies**. This is useful when you only need to read the current value without subscribing to updates.

```dart
final signalA = Signal(0);
final signalB = Signal(0);

Effect(() {
  final tracked = signalA.value;    // Establishes dependency
  final untracked = signalB.peek;    // Does not establish dependency
  
  print('Tracked: $tracked, Untracked: $untracked');
});

signalB.value = 10; // No output, because peek did not establish dependency
signalA.value = 10; // Output: "Tracked: 10, Untracked: 10"
```

Common use cases:

```dart
// Read but don't subscribe in Effect
Effect(() {
  if (someCondition.value) {
    // Use peek to avoid creating unnecessary dependencies
    print('Other value: ${otherSignal.peek}');
  }
});

// Read current value in event handlers
button.onTap = () {
  final current = count.peek;
  print('Current count: $current');
};
```

## Writing Values

### `.value`

Assign directly to the `.value` property to update the signal's value. This updates the value and notifies all subscribers.

```dart
final count = Signal(0);

count.value = 10;  // Update value
count.value = 20;  // Update value again
```

### Update Function

For scenarios that need to update based on the current value, you can use the `.update()` extension method:

```dart
final count = Signal(5);
count.update((value) => value + 1); // count.value is now 6
count.update((value) => value * 2); // count.value is now 12
```

This is equivalent to:

```dart
count.value = count.peek + 1;
count.value = count.peek * 2;
```

## Manual Notification

If you need to manually tell subscribers that it has updated, you can use the `notify()` method. This notifies all subscribers even if the value hasn't changed.

```dart
final count = Signal(0);

Effect(() {
  print('Count updated: ${count.value}');
});

count.value = 10; // First output: "Count updated: 10"

// Don't change value, but manually notify subscribers
count.notify(); // Output again: "Count updated: 10"
```

This is useful in certain scenarios, such as when an object's internal properties change but the object reference itself hasn't changed:

```dart
final user = Signal(User(name: 'Alice', age: 30));

Effect(() {
  print('User: ${user.value.name}, Age: ${user.value.age}');
});

user.value.age = 31; // Object reference didn't change, need manual notification
user.notify(); // Triggers Effect update
```

## Lifecycle Management

### dispose

When a signal is no longer needed, you should call the `dispose()` method to release resources:

```dart
final count = Signal(0);

// Use signal...

// Release when no longer needed
count.dispose();
```

Disposed signals can no longer be used:

```dart
count.dispose();
// count.value = 10; // Runtime error: Signal is disposed
```

### isDisposed

Check if a signal has been disposed:

```dart
final count = Signal(0);
print(count.isDisposed); // false

count.dispose();
print(count.isDisposed); // true
```

## Type System

### Signal Interface

`Signal<T>` is a writable interface that implements:
- `Writable<T>` - Writable interface
- `WritableNode<T>` - Writable node interface
- `ReadonlyNode<T>` - Read-only node interface
- `ReadonlySignal<T>` - Read-only signal interface

### ReadonlySignal Interface

`ReadonlySignal<T>` is a read-only interface that implements:
- `Readonly<T>` - Read-only interface
- `ReadonlyNode<T>` - Read-only node interface

## Use Cases

### State Management

Signals are most commonly used for managing application state:

```dart
class TodoApp {
  final todos = Signal<List<Todo>>([]);
  final filter = Signal<TodoFilter>(TodoFilter.all);

  void addTodo(String text) {
    todos.value = [...todos.value, Todo(text: text)];
  }

  void toggleTodo(int id) {
    todos.value = todos.value.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(completed: !todo.completed);
      }
      return todo;
    }).toList();
  }
}
```

### Form State

Signals are perfect for managing form state:

```dart
class LoginForm {
  final email = Signal('');
  final password = Signal('');
  final isLoading = Signal(false);

  Future<void> submit() async {
    isLoading.value = true;
    try {
      await login(email.value, password.value);
    } finally {
      isLoading.value = false;
    }
  }
}
```

### Configuration and Settings

Use Signals to manage configuration:

```dart
class AppConfig {
  final theme = Signal('light');
  final language = Signal('zh');
  final notifications = Signal(true);
}
```

## Important Notes

1. **Reactive Dependencies**: Using `.value` or `call()` in reactive contexts (such as `Computed`, `Effect`) establishes dependencies. Using `.peek` does not establish dependencies.

2. **Lifecycle**: Signals that are no longer used should call `dispose()` to release resources and avoid memory leaks.

3. **Read-Only Views**: When you need to expose a signal but restrict writes, use `.readonly()` to get a read-only view.

4. **Object Internal Changes**: If you modify an object's internal properties, you need to manually call `notify()` to notify subscribers.

5. **Lazy Initialization**: When using `Signal.lazy()` to create a lazily initialized signal, the initial value is `null`. Ensure the type allows `null` or set the value before use.

## Related APIs

- [Computed](./computed.md) - Computed properties based on Signals
- [Effect](./effect.md) - Reactive side effects
- [Extensions](./extensions.md) - Signal extension methods
- [ReadonlyNode](../advanced/extending-jolt.md#readonlynode-basics) - Learn about Signal's underlying interfaces
