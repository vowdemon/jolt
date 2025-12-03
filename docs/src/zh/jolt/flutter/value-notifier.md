---
---

# ValueNotifier 集成

Jolt 提供了与 Flutter 的 `ValueNotifier` 系统的无缝集成，让你可以在 Jolt 信号和 Flutter 的 `ValueNotifier` 之间进行双向转换。

## JoltValueNotifier

`JoltValueNotifier` 是一个 `ValueNotifier` 实现，它包装了 Jolt 响应式值，提供了 Flutter 的 `ValueNotifier` 接口。这允许你无缝地将 Jolt 信号与 Flutter Widget 和状态管理系统集成。

### 基本用法

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

final signal = Signal(42);
final notifier = JoltValueNotifier(signal);

// 使用 with AnimatedBuilder
AnimatedBuilder(
  animation: notifier,
  builder: (context, child) => Text('${notifier.value}'),
)
```

### 扩展方法

Jolt 提供了扩展方法，让你可以直接从响应式值获取 `ValueNotifier`：

```dart
final counter = Signal(0);
final notifier = counter.notifier;

// 使用 with Flutter widgets
ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('$value'),
)
```

### 缓存机制

扩展方法 `notifier` 会返回一个缓存的实例，多次调用返回同一个实例，确保性能优化：

```dart
final counter = Signal(0);
final notifier1 = counter.notifier;
final notifier2 = counter.notifier;

print(identical(notifier1, notifier2)); // true
```

## 双向同步

### 从 ValueNotifier 到 Signal

Jolt 提供了扩展方法，可以将 `ValueNotifier` 转换为响应式信号，并保持双向同步：

```dart
final notifier = ValueNotifier(0);
final signal = notifier.toNotifierSignal();

// 双向同步
notifier.value = 1; // signal.value 变为 1
signal.value = 2;   // notifier.value 变为 2
```

### 使用场景

这个功能在以下场景特别有用：

1. **集成现有代码**：如果你有使用 `ValueNotifier` 的现有代码，可以轻松转换为 Jolt 信号。

2. **第三方库集成**：某些第三方库可能使用 `ValueNotifier`，你可以将其转换为 Jolt 信号以利用响应式系统的优势。

3. **渐进式迁移**：在从 `ValueNotifier` 迁移到 Jolt 时，可以逐步转换，同时保持兼容性。

## 完整示例

### 使用 JoltValueNotifier

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notifier = counter.notifier;

    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Count: $value'),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: Text('Increment'),
            ),
          ],
        );
      },
    );
  }
}
```

### 使用 AnimatedBuilder

```dart
final opacity = Signal(1.0);
final notifier = opacity.notifier;

AnimatedBuilder(
  animation: notifier,
  builder: (context, child) {
    return Opacity(
      opacity: notifier.value,
      child: child,
    );
  },
  child: Text('Fade in/out'),
);
```

### 双向转换

```dart
// 从 ValueNotifier 创建 Signal
final notifier = ValueNotifier<String>('Hello');
final signal = notifier.toNotifierSignal();

// 现在可以在 Jolt 响应式系统中使用
Effect(() {
  print('Signal value: ${signal.value}');
});

// 修改任一方向都会同步
notifier.value = 'World'; // Signal 也会更新
signal.value = 'Jolt';    // ValueNotifier 也会更新
```

## 注意事项

1. **生命周期管理**：`JoltValueNotifier` 会自动管理与 Jolt 信号的同步。当 `ValueNotifier` 被释放时，同步也会自动停止。

2. **性能考虑**：`notifier` 扩展方法使用缓存机制，多次调用返回同一个实例，不会创建多个监听器。

3. **集合信号**：对于可变集合信号（如 `ListSignal`、`MapSignal` 等），`JoltValueNotifier` 会监听所有变化，包括内部修改。

4. **类型安全**：所有转换都保持完整的类型安全，编译时会进行类型检查。

5. **自动清理**：当 Jolt 信号被释放时，`JoltValueNotifier` 会自动清理资源，无需手动管理。

