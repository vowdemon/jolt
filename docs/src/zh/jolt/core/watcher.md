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
);

count.value = 10;
```

### 非立即执行

默认情况下，Watcher 不会立即执行，只在 sources 的值发生变化时才执行：

```dart
final count = Signal(0);

Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('从 $oldValue 变为 $newValue');
  },
);

count.value = 10;
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

**注意**：对于可变值信号（如集合信号），Watcher 的 `when` 可能无法正常工作，因为集合对象的引用可能没有变化。推荐从可变值中提取具体的值进行比较，或者直接使用 `when: () => true` 来允许任意变化：

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
  () => items.length, // () => items.value.length
  (newValue, oldValue) {
    print('列表改变（长度）');
  },
)

Watcher(
  () => items.value,
  (newValue, oldValue) {
    print('列表无法监听');
  },
)

items.add(4);
```

## 销毁

当 Watcher 不再需要时，应该调用 `dispose()` 方法销毁它，以清理依赖关系：

```dart
final count = Signal(0);

final watcher = Watcher(
  () => count.value,
  (newValue, oldValue) {
    print('从 $oldValue 变为 $newValue');
  },
);

count.value = 10;

watcher.dispose();

count.value = 20;
```

销毁后的 Watcher 不会再响应依赖的变化。

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
