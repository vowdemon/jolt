---
---

# 扩展方法

Jolt 提供了丰富的扩展方法，让响应式编程更加便捷。这些扩展方法可以让你轻松地操作响应式值，并与 Flutter 集成。

## Readable 扩展方法

`Readable<T>` 接口的扩展方法，适用于所有只读响应式值（如 `Signal`、`Computed` 等）。

### stream

将响应式值转换为广播流。

```dart
final counter = Signal(0);
final stream = counter.stream;

stream.listen((value) => print('Counter: $value'));
// 输出: "Counter: 0"

counter.value = 1; // 输出: "Counter: 1"
counter.value = 2; // 输出: "Counter: 2"
```

### listen

创建一个流订阅，监听响应式值的变化。

```dart
final counter = Signal(0);

final subscription = counter.listen(
  (value) => print('Counter: $value'),
  immediately: true, // 立即输出当前值
);

counter.value = 1; // 输出: "Counter: 1"

subscription.cancel(); // 停止监听
```

### until

等待响应式值满足某个条件。

```dart
final count = Signal(0);

// 等待 count 达到 5
final future = count.until((value) => value >= 5);

count.value = 1; // 仍在等待
count.value = 3; // 仍在等待
count.value = 5; // Future 完成，值为 5

final result = await future; // result 是 5
```

异步场景示例：

```dart
final isLoading = Signal(true);

// 等待加载完成
final data = await isLoading.until((value) => !value);
print('加载完成');
```

## Writable 扩展方法

`Writable<T>` 接口的扩展方法，适用于所有可写响应式值（如 `Signal`、`WritableComputed` 等）。

### update

使用更新函数基于当前值更新值。

```dart
final count = Signal(5);
count.update((value) => value + 1); // count.value 现在是 6
count.update((value) => value * 2); // count.value 现在是 12
```

这等价于：

```dart
count.value = count.peek + 1;
count.value = count.peek * 2;
```

### readonly

返回信号或可写计算值的只读视图。

```dart
final counter = Signal(0);
final readonlyCounter = counter.readonly();

print(readonlyCounter.value); // OK
// readonlyCounter.value = 1; // 编译错误
```

对于可写计算值：

```dart
final writableComputed = WritableComputed(getter, setter);
final readonlyComputed = writableComputed.readonly();

print(readonlyComputed.value); // OK
// readonlyComputed.value = 1; // 编译错误
```

### untilWhen

等待响应式值满足某个条件，可以访问前一个值。

```dart
final count = Signal(0);

// 等待 count 达到 5，同时追踪前一个值
final future = count.untilWhen((value, previous) => value >= 5);

count.value = 1; // 仍在等待，previous 是 0
count.value = 3; // 仍在等待，previous 是 1
count.value = 5; // Future 完成，值为 5，previous 是 3

final result = await future; // result 是 5
```

### call

将 Readable 作为函数调用以获取其值（创建响应式依赖）。

```dart
final counter = Signal(0);

// 这些是等价的：
final value1 = counter.value;
final value2 = counter(); // 使用 call 扩展
```

### get

获取 Readable 的值（创建响应式依赖）。

```dart
final counter = Signal(0);

// 这些是等价的：
final value1 = counter.value;
final value2 = counter.get(); // 使用 get 扩展
```

### derived

从此 Readable 创建一个计算值。

```dart
final count = Signal(5);
final doubled = count.derived((value) => value * 2);

print(doubled.value); // 10
count.value = 6;
print(doubled.value); // 12
```

## Flutter 扩展方法

### watch (仅限 Flutter)

创建一个在此 Readable 值改变时重建的 Widget。此扩展在 `jolt_flutter` 包中可用。

```dart
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/extension.dart';

final counter = Signal(0);

// 使用 watch 扩展创建响应式 Widget
counter.watch((value) => Text('Count: $value'))
```

## 注意事项

1. **性能考虑**：扩展方法创建新的响应式对象，对于频繁创建的场景，考虑直接使用构造函数。

2. **生命周期**：通过扩展方法创建的响应式对象需要手动管理生命周期，使用完毕后记得调用 `dispose()`。

3. **类型安全**：扩展方法保持了完整的类型安全，编译时会进行类型检查。

4. **流订阅**：使用 `listen` 或 `stream` 创建的订阅需要手动取消，避免内存泄漏。
