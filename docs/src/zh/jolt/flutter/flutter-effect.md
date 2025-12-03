---
---

# FlutterEffect

`FlutterEffect` 是专门为 Flutter 设计的副作用实现，它在当前 Flutter 帧结束时调度执行。这会将同一帧内的多个触发合并为单次执行，避免在帧渲染期间进行不必要的重复执行，这对于不应干扰帧渲染的 UI 相关副作用非常有用。

## 基本用法

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

final count = Signal(0);

// Effect 在当前帧结束时执行，即使 count 在同一帧内多次改变
final effect = FlutterEffect(() {
  print('Count is: ${count.value}');
});

count.value = 1;
count.value = 2;
count.value = 3;
// Effect 在当前帧结束时执行一次，输出: "Count is: 3"
```

## 创建 FlutterEffect

### 立即执行（默认）

默认情况下，`FlutterEffect` 会在创建时立即执行一次并立即收集依赖，然后在依赖变化时在当前帧结束时执行：

```dart
final signal = Signal(0);

// Effect 立即执行并收集依赖
final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}); // 立即输出: "Signal value: 0"

signal.value = 1; // Effect 在当前帧结束时执行
signal.value = 2; // Effect 在当前帧结束时执行（合并为一次）
```

### 延迟收集依赖

使用 `lazy: true` 可以延迟收集依赖，`FlutterEffect` 不会立即执行，也不会收集依赖，必须手动调用 `run()` 才开始收集依赖。这适用于"先定义后使用"的场景：

```dart
final signal = Signal(0);

// 先定义 FlutterEffect，但不收集依赖
final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}, lazy: true); // 不会立即执行，也不会收集依赖

// 稍后手动开始收集依赖
effect.run(); // 现在才开始收集依赖并执行，输出: "Signal value: 0"

signal.value = 1; // Effect 在当前帧结束时执行
```

也可以使用 `FlutterEffect.lazy` 工厂方法：

```dart
final effect = FlutterEffect.lazy(() {
  print('Signal value: ${signal.value}');
});
```

**使用场景**：延迟收集依赖主要用于需要先定义 FlutterEffect，稍后再让它开始工作的场景，比如在组件初始化时定义，在特定时机才激活。

## 手动执行

可以使用 `run()` 方法手动触发 FlutterEffect 的执行。对于 `lazy: true` 的 FlutterEffect，`run()` 会开始收集依赖并执行：

```dart
final signal = Signal(0);

final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}, lazy: true);

effect.run(); // 开始收集依赖并执行，输出: "Signal value: 0"

signal.value = 1; // Effect 在当前帧结束时执行
```

对于非 lazy 的 FlutterEffect，`run()` 会重新执行并更新依赖：

```dart
final signal = Signal(0);

final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}); // 已执行并收集依赖

effect.run(); // 重新执行，输出: "Signal value: 0"
```

## 清理函数

`FlutterEffect` 支持注册清理函数，这些函数会在 Effect 重新运行前或被销毁时执行：

```dart
final count = Signal(0);

FlutterEffect(() {
  print('Count changed: ${count.value}');

  final timer = Timer.periodic(Duration(seconds: 1), (_) {
    count.value++;
  });

  onEffectCleanup(() => timer.cancel());
});
```

### 在异步中使用

如果在异步操作中需要使用清理函数，应该直接使用 `effect.onCleanUp()` 方法：

```dart
final effect = FlutterEffect(() async {
  final subscription = await someAsyncOperation();

  // 在异步中，直接使用 effect.onCleanUp()
  effect.onCleanUp(() => subscription.cancel());
});
```

## 与 Effect 的区别

`FlutterEffect` 和 `Effect` 的主要区别在于执行时机：

- **Effect**：依赖变化时立即执行（在响应式更新周期内）
- **FlutterEffect**：依赖变化时在当前 Flutter 帧结束时执行（批量处理）

### 使用场景

**使用 FlutterEffect 当：**
- 需要执行 UI 相关的副作用（如更新 UI 状态、显示对话框等）
- 希望将同一帧内的多个更新合并为一次执行
- 不想在帧渲染期间执行副作用

**使用 Effect 当：**
- 需要立即响应依赖变化
- 执行非 UI 相关的副作用（如日志记录、数据同步等）
- 不需要帧级别的批量处理

## 完整示例

### 批量更新处理

```dart
final items = ListSignal([1, 2, 3]);

FlutterEffect(() {
  // 即使 items 在同一帧内多次修改，这里也只执行一次
  print('Items updated: ${items.value}');
});

// 在同一帧内多次修改
items.add(4);
items.add(5);
items.removeAt(0);
// Effect 在当前帧结束时执行一次
```

### UI 状态更新

```dart
final isLoading = Signal(false);
final error = Signal<String?>(null);

FlutterEffect(() {
  if (isLoading.value) {
    // 显示加载指示器
    showLoadingDialog();
  } else if (error.value != null) {
    // 显示错误消息
    showErrorSnackBar(error.value!);
  } else {
    // 隐藏对话框
    hideLoadingDialog();
  }
});
```

### 与清理函数结合

```dart
final count = Signal(0);
Timer? _timer;

FlutterEffect(() {
  _timer?.cancel();
  _timer = Timer.periodic(Duration(seconds: 1), (_) {
    count.value++;
  });

  onEffectCleanup(() {
    _timer?.cancel();
    _timer = null;
  });
});
```

## 注意事项

1. **帧调度**：`FlutterEffect` 使用 `SchedulerBinding.instance.endOfFrame` 来调度执行，确保在帧渲染完成后执行。

2. **批量处理**：同一帧内的多个触发会被自动合并为一次执行，提高性能。

3. **生命周期**：`FlutterEffect` 需要手动管理生命周期，使用完毕后记得调用 `dispose()`。

4. **依赖追踪**：`FlutterEffect` 会自动追踪依赖，当依赖变化时会调度执行。

5. **性能优化**：对于频繁更新的场景，使用 `FlutterEffect` 可以显著减少执行次数，提升性能。

