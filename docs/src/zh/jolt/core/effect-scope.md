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

## 用法

### 上下文执行

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

## 销毁

当 EffectScope 不再需要时，应该调用 `dispose()` 方法销毁它，作用域内的所有副作用和观察器会被自动清理：

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

scope.dispose();
```

销毁后的作用域内的副作用和观察器不会再响应依赖的变化。