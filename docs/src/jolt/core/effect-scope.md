---
---

# EffectScope

EffectScope serves as a side effect lifecycle management tool in the reactive system, and it is itself a type of side effect. It provides a scope context for managing multiple side effects (EffectScope, Effect, and Watcher) uniformly. Side effects created within this context are automatically tracked, and when the scope is disposed, all related side effects are automatically cleaned up. This avoids manually managing each side effect's lifecycle, simplifies code, and prevents memory leaks.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create a scope
  final scope = EffectScope()
    ..run(() {
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

After creating an EffectScope, use the `run()` method to execute code within the scope context:

```dart
final scope = EffectScope()
  ..run(() {
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

You can also create the scope first and use the `run()` method later:

```dart
final scope = EffectScope();

scope.run(() {
  // Execute code within the scope
});
```

## Usage

### Context Execution

You can use the `scope.run()` method to run a function within the scope context. Side effects and watchers created within this context will be managed by the scope:

```dart
final scope = EffectScope();

scope.run(() {
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
final scope = EffectScope();

final result = scope.run(() {
  final signal = Signal(42);
  return signal.value;
});

print(result); // Output: 42
```

## Cleanup Functions

EffectScope supports registering cleanup functions that are executed when the scope is disposed.

### onScopeDispose

Use `onScopeDispose` to register a cleanup function:

```dart
final scope = EffectScope()
  ..run(() {
    final subscription = someStream.listen((data) {
      print('Data: $data');
    });
    
    // Register cleanup function, executed when scope is disposed
    onScopeDispose(() => subscription.cancel());
  });

// Cleanup function will be executed automatically when scope is disposed
scope.dispose();
```

**Note**: `onScopeDispose` must be called in a synchronous context. If you need to use cleanup functions in asynchronous operations (such as `Future`, `async/await`), you should directly use the `scope.onCleanUp()` method:

```dart
final scope = EffectScope()
  ..run(() async {
    final subscription = await someAsyncOperation();
    
    // In async context, use scope.onCleanUp() directly
    scope.onCleanUp(() => subscription.cancel());
  });
```

## Disposal

When an EffectScope is no longer needed, you should call the `dispose()` method to destroy it. All side effects and watchers within the scope will be automatically cleaned up:

```dart
final scope = EffectScope()
  ..run(() {
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

