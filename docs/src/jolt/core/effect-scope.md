---
---

# EffectScope

EffectScope serves as a side effect lifecycle management tool in the reactive system, and it is itself a type of side effect. It provides a scope context for unified management of multiple side effects (EffectScope, Effect, and Watcher). Side effects created in this context are automatically tracked, and when the scope is disposed, all related side effects are automatically cleaned up. This avoids manually managing each side effect's lifecycle, simplifying code and preventing memory leaks.

```dart
import 'package:jolt/jolt.dart';

void main() {
  // Create scope
  final scope = EffectScope()
    ..run(() {
      final count = Signal(0);
      
      // Create side effects within scope
      Effect(() {
        print('Count: ${count.value}');
      });
      
      // Create watcher within scope
      Watcher(
        () => count.value,
        (newValue, oldValue) {
          print('Changed from $oldValue to $newValue');
        },
      );
      
      // Side effects within scope are automatically cleaned up when scope is disposed
    });
  
  // Dispose scope
  scope.dispose();
}
```

## Creation

After creating an EffectScope, use the `run()` method to execute code in the scope context:

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
  // Execute code within scope
});
```

### Detached Scope

Using `detach: true` creates a scope detached from the parent scope—it won't be automatically cleaned up by the parent scope:

```dart
final parentScope = EffectScope()
  ..run(() {
    // Create detached scope
    final detachedScope = EffectScope(detach: true)
      ..run(() {
        Effect(() {
          print('Independent scope');
        });
      });
    
    // When parent scope is disposed, detached scope is not automatically cleaned up
  });

parentScope.dispose(); // detachedScope still exists
```

## Context Execution

You can use the `scope.run()` method to run functions in the scope context. Side effects and watchers created in this context are managed by the scope:

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

The `run()` method returns the result of function execution:

```dart
final scope = EffectScope();

final result = scope.run(() {
  final signal = Signal(42);
  return signal.value;
});

print(result); // Output: 42
```

## Cleanup Functions

EffectScope supports registering cleanup functions that execute when the scope is disposed.

### onScopeDispose

Use `onScopeDispose` to register cleanup functions:

```dart
final scope = EffectScope()
  ..run(() {
    final subscription = someStream.listen((data) {
      print('Data: $data');
    });
    
    // Register cleanup function, executes when scope is disposed
    onScopeDispose(() => subscription.cancel());
  });

// When scope is disposed, cleanup function automatically executes
scope.dispose();
```

**Note**: `onScopeDispose` must be called in a synchronous context. If you need to use cleanup functions in async operations (such as `Future`, `async/await`), you should directly use the `scope.onCleanUp()` method:

```dart
final scope = EffectScope()
  ..run(() async {
    final subscription = await someAsyncOperation();
    
    // In async context, directly use scope.onCleanUp()
    scope.onCleanUp(() => subscription.cancel());
  });
```

### onCleanUp

Directly use the EffectScope instance's `onCleanUp()` method to register cleanup functions:

```dart
final scope = EffectScope();

scope.onCleanUp(() {
  // Cleanup logic
});

scope.run(() {
  // Code within scope
});
```

## Lifecycle Management

EffectScope implements the `EffectNode` interface and has lifecycle management capabilities:

- **`dispose()`**: Dispose scope, automatically clean up all related side effects and cleanup functions
- **`isDisposed`**: Check if scope is disposed

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

scope.dispose(); // All side effects and cleanup functions are automatically cleaned up
```

Side effects and watchers within disposed scopes no longer respond to dependency changes.

## Use Cases

### Component Lifecycle

EffectScope is perfect for managing component lifecycles:

```dart
class MyComponent {
  late final EffectScope scope;
  
  void mount() {
    scope = EffectScope()
      ..run(() {
        // All side effects within component
        final state = Signal(0);
        
        Effect(() {
          print('State: ${state.value}');
        });
        
        // Register cleanup logic when component unmounts
        onScopeDispose(() {
          print('Component unmounted');
        });
      });
  }
  
  void unmount() {
    scope.dispose(); // Clean up all side effects
  }
}
```

### Batch Side Effect Management

EffectScope can batch manage multiple related side effects:

```dart
void setupUserProfile(User user) {
  final scope = EffectScope()
    ..run(() {
      // All user-related side effects
      final profile = Signal(user.profile);
      final settings = Signal(user.settings);
      
      Effect(() {
        syncProfile(profile.value);
      });
      
      Effect(() {
        syncSettings(settings.value);
      });
      
      Watcher(
        () => profile.value.name,
        (newName, oldName) {
          updateDisplayName(newName);
        },
      );
    });
  
  return scope;
}

// When user logs out, clean up all related side effects
void cleanupUserProfile(EffectScope scope) {
  scope.dispose();
}
```

### Nested Scopes

EffectScope supports nested usage—child scopes are automatically linked to parent scopes:

```dart
final parentScope = EffectScope()
  ..run(() {
    Effect(() {
      print('Parent effect');
    });
    
    final childScope = EffectScope()
      ..run(() {
        Effect(() {
          print('Child effect');
        });
      });
    
    // When parent scope is disposed, child scope is also automatically cleaned up
  });

parentScope.dispose(); // All scopes are cleaned up
```

## Important Notes

1. **Automatic Linking**: Child scopes created within a scope are automatically linked to the parent scope. When the parent scope is disposed, child scopes are automatically cleaned up.

2. **Detached Scopes**: Scopes created with `detach: true` are not automatically cleaned up by parent scopes and need manual management.

3. **Cleanup Order**: Cleanup functions execute in the order they were registered—first registered, first executed.

4. **Resource Management**: Resources created within scopes should be released through cleanup functions to avoid memory leaks.

## Related APIs

- [Effect](./effect.md) - Learn about side effect usage
- [Watcher](./watcher.md) - Learn about watcher usage
- [Signal](./signal.md) - Learn about signal usage
