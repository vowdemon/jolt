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

## 读取

### `.value`

使用 `.value` 属性读取计算值，**这会创建响应式依赖并触发计算**。如果依赖已经改变，会重新计算；否则返回缓存的值。

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

Effect(() {
  print(doubled.value);
});

count.value = 5;
```

### `.peek`

使用 `.peek` 属性可以读取**缓存的 computed 值**，不会触发重新计算。如果依赖已经改变但未被访问过，返回的值可能是过时的。

```dart
final signalA = Signal(0);
final computedA = Computed(() => signalA.value * 2);

final signalB = Signal(0);
final computedB = Computed(() => signalB.value * 2);

Effect(() {
  final tracked = computedA.value;
  final cached = computedB.peek;
  
  print('Tracked: $tracked, Cached: $cached');
});

signalB.value = 10; // 无输出
signalA.value = 10; // 输出: "Tracked: 20, Cached: 0"
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

也可以通过 `.set()` 方法写入，效果相同：

```dart
doubled.set(20); // 与 doubled.value = 20 相同
```
