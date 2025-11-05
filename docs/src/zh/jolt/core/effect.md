---
---

# Effect

Effect 是响应式系统中最重要的一环。它总是积极收集依赖，并在依赖更新时主动运行。通常可以在这里监听信号变化，执行副作用操作。

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建一个信号
  final count = Signal(0);
  
  // 订阅信号的变化
  final effect = Effect(() {
    print('Count: ${count.value}');
  });
  
  // 修改信号的值
  count.value = 5; // 输出: "Count: 5"

  // 停止监听
  effect.dispose();
}
```

## 创建

### 立即执行

默认情况下，Effect 会在创建时立即执行一次并立即收集依赖：

```dart
final count = Signal(0);

Effect(() {
  print('Count: ${count.value}');
});

count.value = 10;
```

### 延迟执行

使用 `immediately: false` 可以延迟收集依赖，稍后手动调用 `run()` 方法时才开始收集依赖：

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}, immediately: false);

effect.run();

count.value = 10;
```

## 销毁

当 Effect 不再需要时，应该调用 `dispose()` 方法销毁它，以清理依赖关系：

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
});

count.value = 10;

effect.dispose();

count.value = 20;
```

销毁后的 Effect 不会再响应依赖的变化。

## 清理函数

Effect 支持注册清理函数，这些函数会在 Effect 重新运行前或被销毁时执行。这对于清理订阅、取消定时器等场景非常有用。

### onEffectCleanup

使用 `onEffectCleanup` 注册清理函数：

```dart
Effect(() {
  final timer = Timer.periodic(Duration(seconds: 1), (_) {
    print('Tick');
  });
  
  // 注册清理函数，在 Effect 重新运行或销毁时执行
  onEffectCleanup(() => timer.cancel());
});
```

清理函数会在以下情况执行：
- Effect 重新运行前（依赖变化时）
- Effect 被销毁时（调用 `dispose()`）

**注意**：`onEffectCleanup` 必须在同步上下文中调用。如果在异步操作（如 `Future`、`async/await`）中需要使用清理函数，应该直接使用 `effect.onCleanUp()` 方法：

```dart
final effect = Effect(() async {
  final subscription = await someAsyncOperation();
  
  // 在异步中，直接使用 effect.onCleanUp()
  effect.onCleanUp(() => subscription.cancel());
});
```

## 使用注意

### 不要无限循环

确保 Effect 内部不会修改它依赖的信号，否则可能导致无限循环：

```dart
final count = Signal(0);

Effect(() {
  print(count.value);
  count.value++; // 修改自己依赖的信号，导致无限循环
});
```
