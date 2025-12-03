---
---

# Watcher

Watcher 类似于 Effect，但只收集 sources 函数中的依赖，并在 sources 的值发生变化时才执行副作用。与 Effect 不同的是，Watcher 可以通过 `when` 条件来控制是否执行，并且回调函数会接收到新旧值作为参数。

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建一个信号
  final count = Signal(0);
  
  // 监听信号的变化
  final watcher = Watcher(
    () => count.value,
    (newValue, oldValue) {
      print('从 $oldValue 变为 $newValue');
    },
  );
  
  // 修改信号的值
  count.value = 5; // 输出: "从 0 变为 5"

  // 停止监听
  watcher.dispose();
}
```

## 创建

### 非立即执行（默认）

默认情况下，Watcher 不会立即执行，只在 sources 的值发生变化时才执行：

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('从 $oldValue 变为 $newValue');
  },
);

count.value = 10; // 输出: "从 0 变为 10"
```

### 立即执行

使用 `immediately: true` 可以让 Watcher 在创建时立即执行一次：

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('值: $newValue');
  },
  immediately: true,
); // 立即输出: "值: 0"

count.value = 10; // 输出: "值: 10"
```

也可以使用 `Watcher.immediately` 工厂方法：

```dart
final watcher = Watcher.immediately(
  () => count.value,
  (newValue, oldValue) {
    print('值: $newValue');
  },
);
```

### 执行一次后自动销毁

使用 `Watcher.once` 可以创建一个执行一次后自动销毁的 Watcher：

```dart
final count = Signal(0);

final watcher = Watcher.once(
  () => count.value,
  (newValue, oldValue) {
    print('首次变化: $newValue');
  },
);

count.value = 1; // 输出: "首次变化: 1"，然后自动销毁
count.value = 2; // 不再响应
```

## 执行条件

默认情况下，Watcher 通过 `==` 进行相等性判断来决定是否执行副作用。推荐使用 Record 或具备相等判断的直接对象作为 sources。也可以传入 `when` 来自定义条件：

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('值增加: $oldValue -> $newValue');
  },
  when: (newValue, oldValue) => newValue > oldValue,
);

count.value = 1; // 输出: "值增加: 0 -> 1"
count.value = 0; // 无输出（值减少，不满足条件）
count.value = 2; // 输出: "值增加: 0 -> 2"
```

**注意**：对于可变值信号（如集合信号），Watcher 的 `when` 可能无法正常工作，因为集合对象的引用可能没有变化。推荐从可变值中提取具体的值进行比较，或者直接使用 `when: (_, _) => true` 来允许任意变化：

```dart
final items = ListSignal([1, 2, 3]);

Watcher(
  () => items.value,
  (newValue, oldValue) {
    print('列表改变（任意）');
  },
  when: (_, _) => true, // 接受任意变化
);

Watcher(
  () => items.length, // 提取具体值
  (newValue, oldValue) {
    print('列表长度改变: $oldValue -> $newValue');
  },
);

items.add(4); // 两个 Watcher 都会触发
```

## 多个源值

Watcher 可以监听多个源值，使用 Record 或 List 作为 sources：

```dart
final count = Signal(0);
final name = Signal('Alice');

Watcher(
  () => (count.value, name.value), // 使用 Record
  (newValues, oldValues) {
    print('Count: ${newValues.$1}, Name: ${newValues.$2}');
  },
);

Watcher(
  () => [count.value, name.value], // 使用 List
  (newValues, oldValues) {
    print('Count: ${newValues[0]}, Name: ${newValues[1]}');
  },
);
```

## 手动运行

可以使用 `run()` 方法手动触发 Watcher 的检查：

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('值: $newValue');
  },
);

watcher.run(); // 手动触发检查
```

## 暂停和恢复

Watcher 支持暂停和恢复功能，可以临时停止响应变化：

### pause

暂停 Watcher，停止响应变化：

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('值: $newValue');
  },
);

count.value = 1; // 输出: "值: 1"

watcher.pause(); // 暂停

count.value = 2; // 不再响应
count.value = 3; // 不再响应

watcher.resume(); // 恢复

count.value = 4; // 输出: "值: 4"
```

### resume

恢复 Watcher，重新开始响应变化：

```dart
watcher.resume(); // 只恢复，不立即执行

watcher.resume(tryRun: true); // 恢复并尝试立即执行
```

### isPaused

检查 Watcher 是否处于暂停状态：

```dart
print(watcher.isPaused); // false

watcher.pause();
print(watcher.isPaused); // true

watcher.resume();
print(watcher.isPaused); // false
```

## 忽略更新

使用 `ignoreUpdates()` 可以临时忽略更新，在函数执行期间 Watcher 不会响应变化：

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('值: $newValue');
  },
);

count.value = 1; // 输出: "值: 1"

watcher.ignoreUpdates(() {
  count.value = 2; // 不触发回调
  count.value = 3; // 不触发回调
});

count.value = 4; // 输出: "值: 4"
```

**注意**：`ignoreUpdates()` 只阻止回调执行，源值仍然会正常更新。在忽略期间发生的变化不会更新 `oldValue`，但 `newValue` 会反映最新状态。

## 清理函数

Watcher 支持注册清理函数，这些函数会在 Watcher 重新运行前或被销毁时执行。这对于清理订阅、取消定时器等场景非常有用。

### onEffectCleanup

使用 `onEffectCleanup` 注册清理函数：

```dart
Watcher(
  () => count.value,
  (newValue, oldValue) {
    final timer = Timer.periodic(Duration(seconds: 1), (_) {
      print('Tick: $newValue');
    });
    
    // 注册清理函数，在 Watcher 重新运行或销毁时执行
    onEffectCleanup(() => timer.cancel());
  },
);
```

清理函数会在以下情况执行：
- Watcher 重新运行前（sources 值变化时）
- Watcher 被销毁时（调用 `dispose()`）

**注意**：`onEffectCleanup` 必须在同步上下文中调用。如果在异步操作（如 `Future`、`async/await`）中需要使用清理函数，应该直接使用 `watcher.onCleanUp()` 方法：

```dart
final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) async {
    final subscription = await someAsyncOperation();
    
    // 在异步中，直接使用 watcher.onCleanUp()
    watcher.onCleanUp(() => subscription.cancel());
  },
);
```

### onCleanUp

直接使用 Watcher 实例的 `onCleanUp()` 方法注册清理函数：

```dart
final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    // 副作用逻辑
  },
);

watcher.onCleanUp(() {
  // 清理逻辑
});
```

## 生命周期管理

Watcher 实现了 `EffectNode` 接口，具有生命周期管理能力：

- **`dispose()`**：销毁 Watcher，清理所有依赖和清理函数
- **`isDisposed`**：检查 Watcher 是否已销毁

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('从 $oldValue 变为 $newValue');
  },
);

count.value = 10;

watcher.dispose(); // 销毁 Watcher

count.value = 20; // 不再响应
```

销毁后的 Watcher 不会再响应依赖的变化。

## 使用场景

### 值变化监听

Watcher 非常适合监听特定值的变化：

```dart
final user = Signal<User?>(null);

Watcher(
  () => user.value?.id,
  (newId, oldId) {
    if (newId != null && newId != oldId) {
      loadUserProfile(newId);
    }
  },
);
```

### 条件触发

使用 `when` 条件可以实现更精确的触发逻辑：

```dart
final score = Signal(0);

Watcher(
  () => score.value,
  (newScore, oldScore) {
    if (newScore >= 100) {
      showAchievement('满分！');
    }
  },
  when: (newScore, oldScore) => newScore >= 100 && oldScore < 100,
);
```

### 一次性监听

使用 `Watcher.once` 可以实现一次性监听：

```dart
final isLoading = Signal(true);

Watcher.once(
  () => isLoading.value,
  (isLoading, _) {
    if (!isLoading) {
      showWelcomeMessage();
    }
  },
);
```

## 注意事项

1. **相等性判断**：Watcher 使用 `==` 进行相等性判断，确保 sources 返回的值具有正确的相等性实现。

2. **可变值**：对于可变值（如集合），推荐提取具体值进行比较，或使用 `when: (_, _) => true`。

3. **暂停状态**：暂停的 Watcher 会清除依赖，恢复时会重新收集依赖。

4. **忽略更新**：`ignoreUpdates()` 只阻止回调执行，不会阻止值更新。

## 相关 API

- [Effect](./effect.md) - 了解副作用的使用
- [EffectScope](./effect-scope.md) - 副作用作用域管理
- [Signal](./signal.md) - 了解信号的使用
