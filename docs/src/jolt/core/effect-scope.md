---
---

# EffectScope

EffectScope serves as a side effect lifecycle management tool in the reactive system, and it is itself a type of side effect. It provides a scope context for managing multiple side effects (EffectScope, Effect, and Watcher) uniformly. Side effects created within this context are automatically tracked, and when the scope is disposed, all related side effects are automatically cleaned up. This avoids manually managing each side effect's lifecycle, simplifies code, and prevents memory leaks.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a scope
  final scope = EffectScope((scope) {
    final count = Signal(0);
    
    // Create side effects within the scope
    Effect(() {
      print('Count: ${count.value}');
    });
    
    // Create a watcher within the scope
    Watcher(
      () => count.value,
      (newValue, oldValue) {
        print('Changed from $oldValue to $newValue');
      },
    );
    
    // Side effects within the scope will be automatically cleaned up when scope is disposed
  });
  
  // Dispose the scope
  scope.dispose();
}
```

## Creation

### Pass Execution Function Immediately

You can pass an execution function immediately when creating an EffectScope:

```dart
final scope = EffectScope((scope) {
  Effect(() {
    print('Side effect');
  });
  
  Watcher(
    () => signal.value,
    (newValue, oldValue) {
      print('Value changed');
    },
  );
});
```

### Without Execution Function

You can also create an EffectScope without passing an execution function and use the `run()` method later:

```dart
final scope = EffectScope();
```

## Usage

### Context Execution

You can use the `scope.run()` method to run a function within the scope context. Side effects and watchers created within this context will be managed by the scope:

```dart
final scope = EffectScope(null);

scope.run((scope) {
  final count = Signal(0);
  final name = Signal('Alice');
  
  Effect(() {
    print('Count: ${count.value}');
  });
  
  Watcher(
    () => name.value,
    (newValue, oldValue) {
      print('Name: $newValue');
    },
  );
});

count.value = 10;
name.value = 'Bob';
```

The `run()` method returns the result of the function execution:

```dart
final scope = EffectScope(null);

final result = scope.run((scope) {
  final signal = Signal(42);
  return signal.value;
});

print(result); // Output: 42
```

## Disposal

When an EffectScope is no longer needed, you should call the `dispose()` method to destroy it. All side effects and watchers within the scope will be automatically cleaned up:

```dart
final scope = EffectScope((scope) {
  Effect(() {
    print('Side effect');
  });
  
  Watcher(
    () => signal.value,
    (newValue, oldValue) {
      print('Value changed');
    },
  );
});

scope.dispose();
```

Side effects and watchers within a disposed scope will no longer respond to dependency changes.

