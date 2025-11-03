---
---

# Batch

批处理（Batch）在响应式系统中用于优化更新性能。它可以将多个更新组合在一起，并一次性通知订阅者更新，避免连续多次更新导致的性能问题。当需要同时更新多个信号时，使用批处理可以减少不必要的中间更新，提高响应式系统的整体性能。

## 基本用法

使用 `batch` 函数将多个更新组合在一起：

```dart
import 'package:jolt/jolt.dart';

void main() {
  final signal1 = Signal(1);
  final signal2 = Signal(2);
  final List<int> values = [];
  
  Effect(() {
    values.add(signal1.value + signal2.value);
  });
  
  // 不批处理：会触发多次更新
  signal1.value = 10;
  signal2.value = 20;
  // values = [3, 12, 30]（3 次更新）
  
  // 批处理：只会触发一次更新
  batch(() {
    signal1.value = 10;
    signal2.value = 20;
  });
  // values = [3, 30]（2 次更新）
}
```

## 嵌套用法

批处理可以嵌套，内部批处理会在外部批处理结束时一起通知：

```dart
final signal = Signal(0);

Effect(() {
  print('更新: ${signal.value}');
});

batch(() {
  signal.value = 1;
  
  batch(() {
    signal.value = 2;
  });
  
  signal.value = 3;
});
// 只输出: "更新: 3"（所有更新批处理在一起）
```
