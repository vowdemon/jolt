---
---

# Signal

Signal 是响应式系统的基础。它可以随时修改，并且在响应式系统中可以订阅它的更新。当 Signal 的值改变时，所有订阅它的响应式节点（如 Computed、Effect）会自动更新。

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建一个信号
  final count = Signal(0);

  // 订阅信号的变化
  Effect(() {
    print('Count: ${count.value}');
  });

  // 修改信号的值
  count.value = 5; // 输出: "Count: 5"
}
```


## 读取

### `.value` / `.get()`

使用 `.value` 属性读取信号的值，**这会创建响应式依赖**。当信号的值改变时，任何通过 `.value` 访问它的响应式节点都会自动更新。

```dart
final count = Signal(0);

Effect(() {
  print(count.value);
});

count.value = 10;
```

也可以通过 `.get()` 方法访问，效果相同：

```dart
final count = Signal(0);

Effect(() {
  print(count.get());
});

count.value = 10;
```

### `.peek`

使用 `.peek` 属性可以在**不创建响应式依赖**的情况下读取值。这在只需要读取当前值而不想订阅更新时很有用。

```dart
final signalA = Signal(0);
final signalB = Signal(0);

Effect(() {
  final tracked = signalA.value;
  final untracked = signalB.peek;
  
  print('Tracked: $tracked, Untracked: $untracked');
});

signalB.value = 10; // 无输出
signalA.value = 10; // 输出: "Tracked: 10, Untracked: 10"
```

## 写入

### `.value` / `.set()`

直接给 `.value` 属性赋值或使用 `.set()` 方法来更新信号的值。两种方式都会更新值并通知所有订阅者。

```dart
final count = Signal(0);

count.value = 10;

count.set(20);
```

## 手动通知

如果需要手动告诉依赖它的订阅者它更新了，可以使用 `notify()` 方法。即使值没有改变，也会通知所有订阅者。

```dart
final count = Signal(0);

Effect(() {
  print('Count updated: ${count.value}');
});

count.value = 10; // 首次输出: "Count updated: 10"

// 不改变值，但手动通知订阅者
count.notify(); // 再次输出: "Count updated: 10"
```

这在某些场景下很有用，比如对象的内部属性改变了，但对象引用本身没有改变：

```dart
final user = Signal(User(name: 'Alice', age: 30));

Effect(() {
  print('User: ${user.value.name}, Age: ${user.value.age}');
});

user.value.age = 31;
user.notify();
```