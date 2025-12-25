---
---

# Computed

Computed 是响应式系统中的惰性派生值。它只在被订阅并且依赖改变时重新计算，具有自动缓存机制，能够高效处理昂贵的计算。

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建依赖的信号
  final firstName = Signal('John');
  final lastName = Signal('Doe');
  
  // 创建计算值
  final fullName = Computed(() => '${firstName.value} ${lastName.value}');
  
  // 订阅计算值的变化
  Effect(() {
    print('Full name: ${fullName.value}');
  });
  
  // 修改依赖
  firstName.value = 'Jane'; // 输出: "Full name: Jane Doe"
}
```

## 创建

使用 `Computed` 构造函数创建一个计算值，传入一个 getter 函数：

```dart
final count = Signal(0);

final doubled = Computed(() => count.value * 2);
```

Computed 是惰性的，只有在被访问时才会计算。如果没有任何订阅者，getter 函数可能永远不会执行。

## 读取

### `.value`

使用 `.value` 属性来读取值，**这会创建响应式依赖并触发计算**。如果依赖已经改变，会重新计算；否则返回缓存的值。

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled.value); // 使用 .value
});

count.value = 5; // 触发重新计算
```

你也可以使用 `call()` 扩展方法，获得类似函数调用的语法：

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled()); // 使用 call() 扩展，等价于 .value
});

count.value = 5; // 触发重新计算
```

### `.peek`

使用 `.peek` 属性可以读取计算值，**不会建立响应式依赖，但会重新计算**（如果依赖已改变）。这确保你获得最新的计算结果，但不会创建依赖关系。

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  final tracked = doubled.value; // 建立依赖
  final untracked = doubled.peek; // 不建立依赖，但会重新计算
});

count.value = 10; // tracked 会更新，untracked 不会触发 Effect
```

### `.peekCached`

使用 `.peekCached` 属性可以读取**缓存的 computed 值**，不会建立响应式依赖，也不会重新计算。如果依赖已经改变但未被访问过，返回的值可能是过时的。

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

print(doubled.peekCached); // 返回缓存值，如果不存在则计算一次

count.value = 10; // 依赖改变

print(doubled.peekCached); // 仍然返回旧值（0），因为未重新计算
print(doubled.value); // 触发重新计算，返回新值（20）
```

**`peek` vs `peekCached` 的区别**：

- **`peek`**：总是重新计算（如果需要），确保获得最新结果，但不建立依赖
- **`peekCached`**：只返回缓存值，如果缓存不存在才计算，更高效但可能返回过时值

```dart
final expensive = Computed(() => heavyCalculation());

// 需要最新值但不建立依赖
final latest = expensive.peek; // 会重新计算

// 只需要快速检查缓存值
final cached = expensive.peekCached; // 立即返回缓存，不重新计算
```

## 手动通知

如果需要手动告诉依赖它的订阅者它更新了，可以使用 `notify()` 方法。即使依赖没有改变，也会通知所有订阅者。

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print('Doubled: ${doubled.value}');
});

count.value = 5; // 首次输出: "Doubled: 10"

doubled.notify(); // 再次输出: "Doubled: 10"
```

## 生命周期管理

Computed 实现了 `ReadonlyNode` 接口，具有生命周期管理能力：

- **`dispose()`**：释放资源（与 Signal 类似）
- **`isDisposed`**：检查是否已释放（与 Signal 类似）

不再使用的 Computed 应该调用 `dispose()` 释放资源。

## 可写计算值

`WritableComputed` 允许你创建一个既可以读取又可以写入的计算值。写入时会调用 setter 函数来更新底层依赖。**setter 函数会在 batch 中执行**，这意味着 setter 中的所有信号更新会被批量处理，订阅者只会在所有更新完成后收到一次通知。

### 创建可写计算值

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

final fullName = WritableComputed(
  () => '${firstName.value} ${lastName.value}',
  (value) {
    final parts = value.split(' ');
    firstName.value = parts[0];
    lastName.value = parts[1];
  },
);
```

### 读取和写入

```dart
final count = Signal(0);

final doubled = WritableComputed(
  () => count.value * 2,
  (value) => count.value = value ~/ 2,
);

Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');
});

doubled.value = 10; // 输出: "Count: 5, Doubled: 10"
```


### Batch 执行

`WritableComputed` 的 setter 在 batch 中执行，这意味着所有依赖更新会被批量处理：

```dart
final a = Signal(0);
final b = Signal(0);

final sum = WritableComputed(
  () => a.value + b.value,
  (value) {
    a.value = value ~/ 2;
    b.value = value ~/ 2;
  },
);

var effectCount = 0;
Effect(() {
  sum.value;
  effectCount++;
});

sum.value = 10; // effectCount 只增加 1，而不是 2
// 因为 a 和 b 的更新在同一个 batch 中
```

### 类型系统

`WritableComputed<T>` 同时实现了 `Computed<T>` 和 `Signal<T>` 接口，因此可以使用所有 Signal 和 Computed 的方法。

## 使用场景

### 派生状态

Computed 最常用于派生状态：

```dart
class TodoApp {
  final todos = Signal<List<Todo>>([]);
  final filter = Signal<TodoFilter>(TodoFilter.all);

  // 派生：过滤后的待办事项
  final filteredTodos = Computed(() {
    final all = todos.value;
    switch (filter.value) {
      case TodoFilter.all:
        return all;
      case TodoFilter.active:
        return all.where((t) => !t.completed).toList();
      case TodoFilter.completed:
        return all.where((t) => t.completed).toList();
    }
  });

  // 派生：统计信息
  final stats = Computed(() {
    final all = todos.value;
    return TodoStats(
      total: all.length,
      active: all.where((t) => !t.completed).length,
      completed: all.where((t) => t.completed).length,
    );
  });
}
```

### 双向绑定

`WritableComputed` 适用于需要双向绑定的场景：

```dart
class FormField {
  final _value = Signal('');

  // 可写计算值：格式化显示
  final displayValue = WritableComputed(
    () => _value.value.toUpperCase(),
    (value) => _value.value = value.toLowerCase(),
  );
}
```

### 昂贵计算

Computed 的缓存机制使其非常适合昂贵的计算：

```dart
final data = Signal<List<Data>>([]);

// 昂贵的计算会被缓存
final processed = Computed(() {
  return data.value.map((item) {
    // 复杂的处理逻辑
    return expensiveProcessing(item);
  }).toList();
});

// 多次访问不会重复计算
print(processed.value); // 计算一次
print(processed.value); // 使用缓存
data.value = newData; // 依赖改变
print(processed.value); // 重新计算
```

## 注意事项

1. **惰性计算**：Computed 只在被访问时才会计算。如果没有任何订阅者，getter 函数可能永远不会执行。

2. **缓存机制**：Computed 会自动缓存计算结果，只有在依赖改变时才会重新计算。

3. **依赖追踪**：在 getter 函数中使用 `.value` 或 `call()` 访问其他响应式值会建立依赖关系。使用 `.peek` 不会建立依赖。

4. **`peek` vs `peekCached`**：
   - 需要最新值但不建立依赖时使用 `peek`
   - 只需要快速检查缓存值时使用 `peekCached`

5. **WritableComputed 的 Batch**：setter 中的所有更新会在同一个 batch 中执行，订阅者只会收到一次通知。

6. **生命周期**：不再使用的 Computed 应该调用 `dispose()` 释放资源。

## 相关 API

- [Signal](./signal.md) - 了解基础信号的使用
- [Effect](./effect.md) - 响应式副作用
- [Batch](./batch.md) - 批量更新机制
- [扩展方法](./extensions.md) - Computed 的扩展方法
