---
---

# Surge

Surge 是一个基于 Jolt Signals 的轻量级状态管理库，灵感来自 [BLoC](https://bloclibrary.dev/) 库中的 [Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit) 模式。它结合了 Jolt 的响应式信号系统和 Flutter 的状态管理能力，提供了可预测且简单的状态管理解决方案。

## 安装

```bash
flutter pub add jolt_surge
```

## 核心概念

### Surge

`Surge` 是状态容器类，用于管理状态并响应式地通知变化。它内部使用 Jolt 的 `Signal` 来管理状态，提供了 `emit` 方法来更新状态。

### 基本用法

```dart
import 'package:jolt_surge/jolt_surge.dart';

// 创建一个 Surge
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// 使用
final counter = CounterSurge();
print(counter.state); // 0
counter.increment();
print(counter.state); // 1
```

## 创建 Surge

### 基本创建

```dart
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);
  
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}
```

### 自定义状态创建器

你可以通过 `creator` 参数自定义状态的管理方式：

```dart
class CustomSurge extends Surge<int> {
  CustomSurge(int initial) : super(
    initial,
    creator: (state) => WritableComputed(
      () => state,
      (value) => state = value,
    ),
  );
}
```

## 状态访问

### state

获取当前状态值。当在响应式上下文中访问时，会自动建立依赖关系。

```dart
final surge = CounterSurge();
print(surge.state); // 0

Effect(() => print('State: ${surge.state}'));
surge.emit(1); // Effect 输出: "State: 1"
```

### raw

获取底层的响应式值（`WritableNode`），用于高级场景。

```dart
final surge = CounterSurge();
final rawValue = surge.raw;
rawValue.value = 43; // 直接设置值
```

### stream

获取状态变化的流。

```dart
final surge = CounterSurge();
surge.stream.listen((state) => print('State changed: $state'));

surge.emit(1); // 输出: "State changed: 1"
surge.emit(2); // 输出: "State changed: 2"
```

## 状态更新

### emit

发出新状态并触发变更通知。

```dart
final surge = CounterSurge();
surge.emit(1); // 状态从 0 变为 1
surge.emit(1); // 无变化（值相同）
surge.emit(2); // 状态从 1 变为 2
```

**注意**：
- 如果新状态与当前状态相同（通过 `==` 比较），不会触发更新
- 在 `onChange` 方法调用后才会更新状态
- 如果 Surge 已被释放，调用 `emit` 会抛出断言错误

## 生命周期

### onChange

当状态改变时调用。子类可以重写此方法来添加自定义的变更处理逻辑。

```dart
class MySurge extends Surge<int> {
  MySurge() : super(0);

  @override
  void onChange(Change<int> change) {
    print('State changing from ${change.currentState} to ${change.nextState}');
    super.onChange(change);
  }
}
```

### onDispose

当 Surge 被释放时调用。子类可以重写此方法来添加自定义的清理逻辑。

```dart
class MySurge extends Surge<int> {
  MySurge() : super(0);
  Timer? _timer;

  @override
  void onDispose() {
    _timer?.cancel();
    _timer = null;
    super.onDispose();
  }
}
```

### dispose

释放 Surge 并清理资源。此方法是幂等的，多次调用不会有副作用。

```dart
final surge = CounterSurge();
surge.dispose();
// surge.emit(1); // 抛出断言错误
```

## Change

`Change` 类封装了状态变更信息，包含当前状态和下一个状态。

```dart
final change = Change(currentState: 0, nextState: 1);
print('Changing from ${change.currentState} to ${change.nextState}');
```

## SurgeObserver

`SurgeObserver` 是一个抽象观察者类，用于监控 Surge 的生命周期事件。

### 创建观察者

```dart
class MyObserver extends SurgeObserver {
  @override
  void onCreate(Surge surge) {
    print('Surge created: $surge');
  }

  @override
  void onChange(Surge surge, Change change) {
    print('State changed: ${change.currentState} -> ${change.nextState}');
  }

  @override
  void onDispose(Surge surge) {
    print('Surge disposed: $surge');
  }
}
```

### 设置全局观察者

```dart
SurgeObserver.observer = MyObserver();

// 现在所有 Surge 的生命周期事件都会被观察
final surge = CounterSurge();
// onCreate 被调用

surge.emit(1);
// onChange 被调用

surge.dispose();
// onDispose 被调用
```

## 完整示例

```dart
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  void reset() => emit(0);
}

// 使用
void main() {
  final counter = CounterSurge();
  
  // 监听状态变化
  counter.stream.listen((state) {
    print('Counter: $state');
  });
  
  counter.increment(); // 输出: "Counter: 1"
  counter.increment(); // 输出: "Counter: 2"
  counter.decrement(); // 输出: "Counter: 1"
  counter.reset();     // 输出: "Counter: 0"
  
  counter.dispose();
}
```

## 注意事项

1. **状态不可变**：虽然 Surge 允许通过 `emit` 更新状态，但建议保持状态的不可变性，每次 `emit` 时创建新状态。

2. **生命周期管理**：使用 `SurgeProvider` 时，Surge 的生命周期会自动管理。手动创建时，记得调用 `dispose()`。

3. **性能考虑**：Surge 内部使用 Signal，具有高效的响应式更新机制。

4. **类型安全**：Surge 提供完整的类型安全，编译时会进行类型检查。

5. **测试友好**：Surge 的设计使其易于测试，可以轻松模拟和验证状态变化。

