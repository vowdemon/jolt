---
---

# 扩展方法

Jolt 提供了丰富的扩展方法，让响应式编程更加便捷。这些扩展方法可以让你轻松地操作响应式值，或者将普通值转换为响应式信号。

## Readonly 扩展方法

`Readonly<T>` 接口的扩展方法，适用于所有只读响应式值（如 `Signal`、`Computed` 等）。

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
count.set(count.peek + 1);
count.set(count.peek * 2);
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

## 转换信号方法

将普通值转换为响应式信号的扩展方法。

### toSignal

将任何对象转换为响应式信号。

```dart
import 'package:jolt/jolt.dart';

final nameSignal = 'Alice'.toSignal();
final countSignal = 42.toSignal();
final listSignal = [1, 2, 3].toSignal();
```

### 集合转换方法

#### toListSignal

将普通列表转换为响应式列表信号。

```dart
final normalList = [1, 2, 3];
final reactiveList = normalList.toListSignal();

Effect(() => print('Length: ${reactiveList.length}'));

reactiveList.add(4); // 触发更新
```

#### toSetSignal

将普通集合转换为响应式集合信号。

```dart
final normalSet = {'dart', 'flutter'};
final reactiveSet = normalSet.toSetSignal();

Effect(() => print('Tags: ${reactiveSet.join(', ')}'));

reactiveSet.add('reactive'); // 触发更新
```

#### toMapSignal

将普通映射转换为响应式映射信号。

```dart
final normalMap = {'name': 'Alice', 'age': 30};
final reactiveMap = normalMap.toMapSignal();

Effect(() => print('User: ${reactiveMap['name']}'));

reactiveMap['name'] = 'Bob'; // 触发更新
```

#### toIterableSignal

将普通迭代器转换为响应式迭代器信号。

```dart
final range = Iterable.generate(5).toIterableSignal();

Effect(() => print('Items: ${range.toList()}'));
```

### 异步转换方法

#### toAsyncSignal

将 Future 转换为响应式异步信号。

```dart
Future<String> fetchUser() async {
  await Future.delayed(Duration(seconds: 1));
  return 'John Doe';
}

final signal = fetchUser().toAsyncSignal();

Effect(() {
  if (signal.value.isSuccess) {
    print('Data: ${signal.data}');
  }
});
```

#### toStreamSignal

将 Stream 转换为响应式异步信号。

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final signal = stream.toStreamSignal();

Effect(() {
  if (signal.value.isSuccess) {
    print('Data: ${signal.data}');
  }
});
```

## 注意事项

1. **性能考虑**：扩展方法创建新的响应式对象，对于频繁创建的场景，考虑直接使用构造函数。

2. **生命周期**：通过扩展方法创建的响应式对象需要手动管理生命周期，使用完毕后记得调用 `dispose()`。

3. **类型安全**：扩展方法保持了完整的类型安全，编译时会进行类型检查。

4. **流订阅**：使用 `listen` 或 `stream` 创建的订阅需要手动取消，避免内存泄漏。
