---
---

# Track

Track 模块提供了控制响应式依赖跟踪的函数，包括 `untracked`、`trackWithEffect` 和 `notifyAll`。这些函数允许你精细控制何时收集依赖、何时不收集依赖，以及如何手动触发更新。

## untracked

`untracked` 用于在响应式上下文中执行函数而不创建响应式依赖。当需要读取值但不想触发更新，或者避免循环依赖时非常有用。

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

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

### 基本用法

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

### 在 Computed 中使用

在 Computed 中使用 `untracked` 可以避免某些值触发重新计算：

```dart
final count = Signal(0);
final name = Signal('Alice');

final computed = Computed(() {
  final currentCount = count.value; // 跟踪依赖
  final currentName = untracked(() => name.value); // 不跟踪依赖
  return 'Count: $currentCount, Name: $currentName';
});

count.value = 1; // 触发重新计算
name.value = 'Bob'; // 不触发重新计算
```

### 避免循环依赖

`untracked` 可以用于避免循环依赖：

```dart
final count = Signal(0);

Effect(() {
  print('Count: ${count.value}');
  
  // 使用 untracked 避免循环依赖
  untracked(() {
    if (count.value > 5) {
      count.value = 0; // 不会触发无限循环
    }
  });
});
```

### 对比 peek

`untracked` 和 `peek` 都可以在不创建响应式依赖的情况下读取值，但使用方式不同：

| 特性 | untracked | peek |
|------|-----------|------|
| 形式 | 函数调用 | 属性访问 |
| 使用场景 | 在函数中使用，可以执行任意代码 | 直接访问属性 |
| 返回值 | 任意类型 | 值类型 |
| 灵活性 | 更灵活，可以执行复杂逻辑 | 更简洁直接 |

```dart
final signal = Signal(0);

Effect(() {
  // 使用 peek
  final value1 = signal.peek;
  
  // 使用 untracked
  final value2 = untracked(() => signal.value);
  
  // untracked 可以执行更复杂的逻辑
  final value3 = untracked(() {
    final a = signal.value;
    final b = anotherSignal.value;
    return a + b;
  });
  
  print('peek: $value1, untracked: $value2, complex: $value3');
});
```

## trackWithEffect

`trackWithEffect` 用于使用指定的 effect node 作为活动订阅者来执行函数，允许手动控制依赖跟踪。这在高级场景中很有用，比如延迟收集依赖或自定义依赖跟踪逻辑。

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

final count = Signal(0);

// 创建 lazy effect
final effect = Effect(() {
  print('Count: ${count.value}');
}, lazy: true);

// 使用 trackWithEffect 手动收集依赖
trackWithEffect(() {
  count.value; // 这个访问会被 effect 跟踪
}, effect);

count.value = 10; // 触发 effect
```

### 基本用法

`trackWithEffect` 接受一个函数和一个 effect node，在函数执行期间，该 effect node 会成为活动订阅者：

```dart
final signal = Signal(0);

final effect = Effect(() {
  // effect 函数体
}, lazy: true);

// 手动收集依赖
trackWithEffect(() {
  final value = signal.value; // 被 effect 跟踪
  print('Value: $value');
}, effect);
```

### purge 参数

`trackWithEffect` 的第三个参数 `purge` 控制是否在执行前清除现有依赖：

```dart
// purge: true（默认）- 清除现有依赖后重新收集
trackWithEffect(() {
  signal1.value; // 只跟踪 signal1
}, effect, purge: true);

// purge: false - 保留现有依赖，追加新的依赖
trackWithEffect(() {
  signal2.value; // 跟踪 signal1 和 signal2
}, effect, purge: false);
```

### 使用场景

#### 延迟收集依赖

`trackWithEffect` 可以用于延迟收集依赖，配合 `lazy: true` 的 Effect：

```dart
final count = Signal(0);
final name = Signal('Alice');

final effect = Effect(() {
  print('Count: ${count.value}, Name: ${name.value}');
}, lazy: true);

// 稍后手动收集依赖
trackWithEffect(() {
  count.value;
  name.value;
}, effect);

count.value = 10; // 触发 effect
name.value = 'Bob'; // 触发 effect
```

#### 自定义依赖跟踪

`trackWithEffect` 可以用于实现自定义的依赖跟踪逻辑。注意：`trackWithEffect` 只能用于 `EffectNode`（如 `Effect`、`Watcher`、`EffectScope`），不能用于 `Computed`：

```dart
final data = Signal<List<int>>([]);
final filter = Signal(true);

// 使用 Effect 而不是 Computed
final effect = Effect(() {
  final items = data.value;
  if (filter.value) {
    print('Filtered: ${items.where((x) => x > 0).toList()}');
  } else {
    print('All: $items');
  }
}, lazy: true);

// 手动控制哪些依赖被跟踪
trackWithEffect(() {
  data.value; // 只跟踪 data，不跟踪 filter
}, effect);

data.value = [1, 2, 3]; // 触发 effect
filter.value = false; // 不触发 effect（因为 filter 没有被跟踪）
```

### 重要说明

**依赖持久性**：即使通过 `trackWithEffect` 收集了依赖，并且依赖更新后触发了 effect，也不保证这些依赖会持久存在。依赖的持久性是由 effect 的具体实现决定的。当 effect 重新运行时，它会重新收集依赖，之前通过 `trackWithEffect` 收集的依赖可能会被清除或替换。

```dart
final count = Signal(0);

final effect = Effect(() {
  // effect 函数体可能会重新收集依赖
  print('Count: ${count.value}');
}, lazy: true);

// 手动收集依赖
trackWithEffect(() {
  count.value; // 收集依赖
}, effect);

count.value = 10; // 触发 effect

// effect 重新运行时，会重新收集依赖
// 之前通过 trackWithEffect 收集的依赖可能不再存在
```

因此，`trackWithEffect` 主要用于初始化依赖收集，而不是用于长期维护依赖关系。对于需要持久依赖的场景，应该在 effect 函数体内直接访问响应式值。

## notifyAll

`notifyAll` 用于执行函数并通知所有被访问的依赖的订阅者。这在需要触发更新而不实际改变值的情况下很有用。

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/track.dart';

final signal = Signal(0);

Effect(() {
  print('Value: ${signal.value}');
});

// 不改变值，但触发订阅者更新
notifyAll(() {
  signal.value; // 访问信号，触发订阅者
});
```

### 基本用法

`notifyAll` 创建一个临时的响应式上下文，执行函数，然后通知所有在函数执行期间被访问的依赖的订阅者：

```dart
final count = Signal(0);
final name = Signal('Alice');

Effect(() {
  print('Count: ${count.value}');
});

Effect(() {
  print('Name: ${name.value}');
});

// 触发所有订阅者，即使值没有改变
notifyAll(() {
  count.value;
  name.value;
});
```

### 使用场景

#### 手动触发更新

当对象的内部状态改变但对象引用没有改变时，可以使用 `notifyAll` 手动触发更新：

```dart
final user = Signal(User(name: 'Alice', age: 30));

Effect(() {
  print('User: ${user.value.name}, Age: ${user.value.age}');
});

// 修改内部属性
user.value.age = 31;

// 手动触发更新
notifyAll(() {
  user.value; // 触发订阅者
});
```

#### 批量通知

`notifyAll` 可以用于批量通知多个依赖的订阅者：

```dart
final a = Signal(0);
final b = Signal(0);
final c = Signal(0);

Effect(() {
  print('A: ${a.value}, B: ${b.value}, C: ${c.value}');
});

// 批量通知所有订阅者
notifyAll(() {
  a.value;
  b.value;
  c.value;
});
```

## 注意事项

1. **`untracked` 的使用**：
   - 在 `untracked` 内部访问的响应式值不会创建依赖
   - 适用于需要读取值但不希望触发更新的场景
   - 可以执行任意代码，比 `peek` 更灵活

2. **`trackWithEffect` 的使用**：
   - 用于手动控制依赖收集过程
   - `purge: true` 会清除现有依赖后重新收集
   - `purge: false` 会保留现有依赖并追加新的依赖
   - 适用于延迟收集依赖或自定义依赖跟踪逻辑

3. **`notifyAll` 的使用**：
   - 不改变值，只触发订阅者更新
   - 适用于对象内部状态改变但引用未变的场景
   - 可以批量通知多个依赖的订阅者

4. **性能考虑**：
   - `untracked` 可以避免不必要的依赖，提高性能
   - `trackWithEffect` 提供了更精细的控制，但需要谨慎使用
   - `notifyAll` 会触发所有订阅者，可能影响性能

## 相关 API

- [Effect](./effect.md) - 了解副作用的使用
- [Computed](./computed.md) - 了解计算属性的使用
- [Signal](./signal.md) - 了解信号的使用

