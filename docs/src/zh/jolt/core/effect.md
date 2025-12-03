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

### 立即执行（默认）

默认情况下，Effect 会在创建时立即执行一次并立即收集依赖：

```dart
final count = Signal(0);

Effect(() {
  print('Count: ${count.value}');
}); // 立即输出: "Count: 0"，并收集依赖

count.value = 10; // 输出: "Count: 10"
```

### 延迟收集依赖

使用 `lazy: true` 可以延迟收集依赖，Effect 不会立即执行，也不会收集依赖，必须手动调用 `run()` 才开始收集依赖。这适用于"先定义后使用"的场景：

```dart
final count = Signal(0);

// 先定义 Effect，但不收集依赖
final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true); // 不会立即执行，也不会收集依赖

// 稍后手动开始收集依赖
effect.run(); // 现在才开始收集依赖并执行，输出: "Count: 0"

count.value = 10; // 输出: "Count: 10"
```

也可以使用 `Effect.lazy` 工厂方法：

```dart
final effect = Effect.lazy(() {
  print('Count: ${count.value}');
});
```

**使用场景**：延迟收集依赖主要用于需要先定义 Effect，稍后再让它开始工作的场景，比如在组件初始化时定义，在特定时机才激活。

## 手动运行

可以使用 `run()` 方法手动触发 Effect 的执行。对于 `lazy: true` 的 Effect，`run()` 会开始收集依赖并执行：

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true);

effect.run(); // 开始收集依赖并执行，输出: "Count: 0"

count.value = 10; // 输出: "Count: 10"
```

对于非 lazy 的 Effect，`run()` 会重新执行并更新依赖：

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}); // 已执行并收集依赖

effect.run(); // 重新执行，输出: "Count: 0"
```

## 使用 trackWithEffect 收集依赖

除了使用 `run()` 方法，还可以通过 `trackWithEffect` 函数来手动收集依赖：

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true);

// 使用 trackWithEffect 手动收集依赖
trackWithEffect(() {
  count.value;
}, effect);
```

`trackWithEffect` 允许你手动控制依赖收集的过程，这在某些高级场景中很有用。

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

### onCleanUp

直接使用 Effect 实例的 `onCleanUp()` 方法注册清理函数：

```dart
final effect = Effect(() {
  // 副作用逻辑
});

effect.onCleanUp(() {
  // 清理逻辑
});
```

## 生命周期管理

Effect 实现了 `EffectNode` 接口，具有生命周期管理能力：

- **`dispose()`**：销毁 Effect，清理所有依赖和清理函数
- **`isDisposed`**：检查 Effect 是否已销毁

```dart
final count = Signal(0);

final effect = Effect(() {
  print('Count: ${count.value}');
});

count.value = 10;

effect.dispose(); // 销毁 Effect

count.value = 20; // 不再响应
```

销毁后的 Effect 不会再响应依赖的变化。

## 使用场景

### 日志记录

Effect 非常适合用于日志记录：

```dart
final user = Signal<User?>(null);

Effect(() {
  if (user.value != null) {
    print('User logged in: ${user.value!.name}');
  } else {
    print('User logged out');
  }
});
```

### 同步状态

Effect 可以用于同步不同状态：

```dart
final theme = Signal('light');
final darkMode = Signal(false);

Effect(() {
  darkMode.value = theme.value == 'dark';
});
```

### 副作用操作

Effect 可以执行各种副作用操作：

```dart
final count = Signal(0);

Effect(() {
  // 更新 DOM
  document.getElementById('count')?.textContent = count.value.toString();
  
  // 发送分析事件
  analytics.track('count_changed', {'value': count.value});
});
```

## 注意事项

1. **不要无限循环**：确保 Effect 内部不会修改它依赖的信号，否则可能导致无限循环：

```dart
final count = Signal(0);

Effect(() {
  print(count.value);
  count.value++; // ❌ 修改自己依赖的信号，导致无限循环
});
```

2. **清理资源**：在 Effect 中创建的资源（如定时器、订阅）应该通过清理函数释放，避免内存泄漏。

3. **异步操作**：Effect 函数可以是异步的，但需要注意清理函数的注册方式。

4. **依赖追踪**：Effect 会自动追踪在函数中通过 `.value`、`.get()` 或 `call()` 访问的响应式值。

## 相关 API

- [Watcher](./watcher.md) - 更精确的副作用控制
- [EffectScope](./effect-scope.md) - 副作用作用域管理
- [Signal](./signal.md) - 了解信号的使用
- [Computed](./computed.md) - 了解计算属性的使用
