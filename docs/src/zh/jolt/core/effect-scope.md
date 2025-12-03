---
---

# EffectScope

EffectScope 在响应式系统中作为副作用生命周期管理工具，它本身也是副作用的一种。它提供了一个作用域上下文，用于统一管理多个副作用（EffectScope、Effect 和 Watcher）。在该上下文中创建的副作用会被自动追踪，当作用域释放时，所有相关的副作用都会被自动清理。这样可以避免手动管理每个副作用的生命周期，简化代码并防止内存泄漏。

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建作用域
  final scope = EffectScope()
    ..run(() {
      final count = Signal(0);
      
      // 在作用域内创建副作用
      Effect(() {
        print('Count: ${count.value}');
      });
      
      // 在作用域内创建观察器
      Watcher(
        () => count.value,
        (newValue, oldValue) {
          print('从 $oldValue 变为 $newValue');
        },
      );
      
      // 作用域内的副作用会在 scope 释放时自动清理
    });
  
  // 释放作用域
  scope.dispose();
}
```

## 创建

创建 EffectScope 后，使用 `run()` 方法在作用域上下文中执行代码：

```dart
final scope = EffectScope()
  ..run(() {
    Effect(() {
      print('副作用');
    });
    
    Watcher(
      () => signal.value,
      (newValue, oldValue) {
        print('值改变');
      },
    );
  });
```

也可以先创建作用域，稍后使用 `run()` 方法：

```dart
final scope = EffectScope();

scope.run(() {
  // 在作用域内执行代码
});
```

### 分离作用域

使用 `detach: true` 可以创建一个与父作用域分离的作用域，它不会被父作用域自动清理：

```dart
final parentScope = EffectScope()
  ..run(() {
    // 创建分离的作用域
    final detachedScope = EffectScope(detach: true)
      ..run(() {
        Effect(() {
          print('独立的作用域');
        });
      });
    
    // 父作用域销毁时，分离的作用域不会被自动清理
  });

parentScope.dispose(); // detachedScope 仍然存在
```

## 上下文执行

可以使用 `scope.run()` 方法在作用域上下文中运行函数，在该上下文中创建的副作用和观察器会被作用域管理：

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

`run()` 方法会返回函数执行的结果：

```dart
final scope = EffectScope();

final result = scope.run(() {
  final signal = Signal(42);
  return signal.value;
});

print(result); // 输出: 42
```

## 清理函数

EffectScope 支持注册清理函数，这些函数会在作用域被销毁时执行。

### onScopeDispose

使用 `onScopeDispose` 注册清理函数：

```dart
final scope = EffectScope()
  ..run(() {
    final subscription = someStream.listen((data) {
      print('Data: $data');
    });
    
    // 注册清理函数，在作用域销毁时执行
    onScopeDispose(() => subscription.cancel());
  });

// 销毁作用域时，清理函数会自动执行
scope.dispose();
```

**注意**：`onScopeDispose` 必须在同步上下文中调用。如果在异步操作（如 `Future`、`async/await`）中需要使用清理函数，应该直接使用 `scope.onCleanUp()` 方法：

```dart
final scope = EffectScope()
  ..run(() async {
    final subscription = await someAsyncOperation();
    
    // 在异步中，直接使用 scope.onCleanUp()
    scope.onCleanUp(() => subscription.cancel());
  });
```

### onCleanUp

直接使用 EffectScope 实例的 `onCleanUp()` 方法注册清理函数：

```dart
final scope = EffectScope();

scope.onCleanUp(() {
  // 清理逻辑
});

scope.run(() {
  // 作用域内的代码
});
```

## 生命周期管理

EffectScope 实现了 `EffectNode` 接口，具有生命周期管理能力：

- **`dispose()`**：销毁作用域，自动清理所有相关的副作用和清理函数
- **`isDisposed`**：检查作用域是否已销毁

```dart
final scope = EffectScope()
  ..run(() {
    Effect(() {
      print('副作用');
    });
    
    Watcher(
      () => signal.value,
      (newValue, oldValue) {
        print('值改变');
      },
    );
  });

scope.dispose(); // 所有副作用和清理函数都会被自动清理
```

销毁后的作用域内的副作用和观察器不会再响应依赖的变化。

## 使用场景

### 组件生命周期

EffectScope 非常适合用于管理组件的生命周期：

```dart
class MyComponent {
  late final EffectScope scope;
  
  void mount() {
    scope = EffectScope()
      ..run(() {
        // 组件内的所有副作用
        final state = Signal(0);
        
        Effect(() {
          print('State: ${state.value}');
        });
        
        // 注册组件卸载时的清理逻辑
        onScopeDispose(() {
          print('Component unmounted');
        });
      });
  }
  
  void unmount() {
    scope.dispose(); // 清理所有副作用
  }
}
```

### 批量管理副作用

EffectScope 可以批量管理多个相关的副作用：

```dart
void setupUserProfile(User user) {
  final scope = EffectScope()
    ..run(() {
      // 用户相关的所有副作用
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

// 用户退出时，清理所有相关副作用
void cleanupUserProfile(EffectScope scope) {
  scope.dispose();
}
```

### 嵌套作用域

EffectScope 支持嵌套使用，子作用域会自动链接到父作用域：

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
    
    // 销毁父作用域时，子作用域也会被自动清理
  });

parentScope.dispose(); // 所有作用域都被清理
```

## 注意事项

1. **自动链接**：在作用域内创建的子作用域会自动链接到父作用域，父作用域销毁时会自动清理子作用域。

2. **分离作用域**：使用 `detach: true` 创建的作用域不会被父作用域自动清理，需要手动管理。

3. **清理顺序**：清理函数按照注册的顺序执行，先注册的先执行。

4. **资源管理**：在作用域内创建的资源应该通过清理函数释放，避免内存泄漏。

## 相关 API

- [Effect](./effect.md) - 了解副作用的使用
- [Watcher](./watcher.md) - 了解观察器的使用
- [Signal](./signal.md) - 了解信号的使用
