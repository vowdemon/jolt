---
---

# Untracked

Untracked 在响应式系统中用于在响应式上下文中访问值而不创建响应式依赖。当需要读取值但不想触发更新，或者避免循环依赖时非常有用。

```dart
import 'package:jolt/jolt.dart';

void main() {
  final count = Signal(0);
  final name = Signal('Alice');
  
  Effect(() {
    final tracked = count.value; // 创建依赖
    final untrackedValue = untracked(() => name.value); // 不创建依赖
    
    print('Count: $tracked, Name: $untrackedValue');
  });
  
  count.value = 10; // 触发更新
  name.value = 'Bob'; // 不触发更新（因为未跟踪）
}
```

## 基本用法

使用 `untracked` 函数来访问值而不创建依赖：

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);

Effect(() {
  final tracked = signal1.value; // 创建依赖
  final untracked = untracked(() => signal2.value); // 不创建依赖
  
  print('$tracked + $untracked');
});

signal1.value = 10; // 副作用运行
signal2.value = 20; // 副作用不运行（因为 signal2 没有被跟踪）
```

## 对比 peek

`untracked` 和 `peek` 都可以在不创建响应式依赖的情况下读取值，但使用方式不同：

| 特性 | untracked | peek |
|------|-----------|------|
| 形式 | 函数调用 | 属性访问 |
| 使用场景 | 在函数中使用 | 直接访问属性 |
| 返回值 | 任意类型 | 值类型 |

```dart
final signal = Signal(0);

Effect(() {
  // 使用 peek
  final value1 = signal.peek;
  
  // 使用 untracked
  final value2 = untracked(() => signal.value);
  
  print('peek: $value1, untracked: $value2');
});
```

两者都可以在不创建依赖的情况下读取值，`peek` 更简洁直接，`untracked` 更灵活，可以在函数内部执行任意代码。
