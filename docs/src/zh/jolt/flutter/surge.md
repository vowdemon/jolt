---
---

# Jolt Surge

## Overview

`jolt_surge` 受 [BLoC](https://bloclibrary.dev/) 的 [Cubit](https://bloclibrary.dev/#/coreconcepts?id=cubit) 模式启发，提供了一个基于信号的轻量级状态管理模式。它将 Jolt 的响应式信号系统与 Flutter 的状态管理相结合，通过封装状态容器和提供便捷的 Widget，让状态管理变得简洁而强大。

与 Cubit 类似，Surge 是一个状态容器，通过 `emit` 方法修改状态，通过 `state` 属性获取当前状态。不同的是，Surge 的内部实现基于 Jolt Signals，这意味着状态是可追踪的响应式值，能够自动建立依赖关系，并在状态变化时触发相应的副作用和 UI 重建。

这种设计既保持了 Cubit 模式的可预测性和简洁性，又充分利用了 Jolt Signals 的响应式能力，让你在 Flutter 中构建高效、可维护的状态管理解决方案。

## Surge

`Surge<State>` 是一个状态容器，封装了状态管理的核心逻辑。它通过内部的信号来维护状态，并提供 `emit` 方法来修改状态、`state` 属性来获取当前状态。

### 创建 Surge

继承 `Surge` 类并实现你的业务逻辑：

```dart
import 'package:jolt_surge/jolt_surge.dart';

class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);
  
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  
  @override
  void onChange(Change<int> change) {
    // 可选：观察状态转换
    print('State changed from ${change.currentState} to ${change.nextState}');
  }
}
```

### 自定义 Create

默认情况下，Surge 使用 `Signal` 来存储状态。你可以通过构造函数中的 `creator` 参数来自定义状态的存储方式：

```dart
class CustomSurge extends Surge<int> {
  CustomSurge() : super(
    0,
    creator: (state) => WritableComputed(
      () => baseSignal.value,
      (value) => baseSignal.value = value,
    ),
  );
}
```

这对于需要将状态与其他信号关联的场景非常有用，比如将状态基于其他计算值派生。

### Surge 规范

- **状态修改**：通过 `emit(nextState)` 方法修改状态。`emit` 会自动比较新旧状态，如果值相同则不会触发更新，保证性能优化。
- **状态获取**：通过 `state` 属性获取当前状态。访问 `state` 会追踪依赖（相当于访问 `signal.value`），所有依赖它的计算值和副作用都会自动建立依赖关系。
- **状态追踪**：`state` 是可追踪的响应式值，这意味着你可以在 Effect、Computed 等响应式上下文中使用它，依赖关系会自动建立。

```dart
final counterSurge = CounterSurge();

// 在 Effect 中使用，会自动追踪
Effect(() {
  print('Counter: ${counterSurge.state}');  // 自动追踪依赖
});

// 修改状态
counterSurge.increment();  // 触发 Effect 重新执行
```

## SurgeProvider

`SurgeProvider` 用于在 Widget 树中提供 Surge 实例，类似于 `Provider` 的用法。它支持两种方式：`create` 构造函数和 `.value` 构造函数。

### 使用 create

使用 `create` 构造函数会自动管理 Surge 的生命周期，当 Widget 卸载时会自动调用 `dispose()`：

```dart
SurgeProvider<CounterSurge>(
  create: (_) => CounterSurge(),  // 卸载时自动释放
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, surge) => Text('count: $state'),
  ),
);
```

### 使用 .value

使用 `.value` 构造函数时，Surge 的生命周期需要手动管理：

```dart
final surge = CounterSurge();

SurgeProvider<CounterSurge>.value(
  value: surge,  // 不会自动释放，需要手动管理
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, s) => Text('count: $state'),
  ),
);
```

### 从后代 Widget 访问

```dart
// 获取 Surge 实例
final surge = context.read<CounterSurge>();

// 触发状态修改
ElevatedButton(
  onPressed: () => surge.increment(),
  child: const Text('Increment'),
);
```

## SurgeConsumer

`SurgeConsumer` 是一个统一的消费点，同时支持 `builder` 和 `listener`，并提供了精细的重建和监听控制。

- **builder**：构建 UI，默认不追踪（untracked），只在 `buildWhen` 返回 `true` 时重建
- **listener**：处理副作用（如显示 SnackBar、发送分析事件等），默认不追踪，只在 `listenWhen` 返回 `true` 时执行
- **buildWhen**：控制是否重建，默认追踪（可以依赖外部信号）
- **listenWhen**：控制是否执行监听器，默认追踪（可以依赖外部信号）

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next, s) => next.isEven,  // 只在偶数时重建
  listenWhen: (prev, next, s) => next > prev,  // 只在增加时监听
  builder: (context, state, s) => Text('count: $state'),
  listener: (context, state, s) {
    // 副作用：显示 SnackBar 或发送分析事件
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count is now: $state')),
    );
  },
);
```

### 禁用追踪

如果需要在条件中使用外部信号但不想追踪它，可以使用 `untracked`：

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
  // ...
);
```

## SurgeBuilder

`SurgeBuilder` 是 `SurgeConsumer` 的便捷版本，只提供 `builder` 功能：

```dart
SurgeBuilder<CounterSurge, int>(
  builder: (context, state, surge) => Text('count: $state'),
  buildWhen: (prev, next, s) => next.isEven,  // 可选：条件重建
);
```

## SurgeListener

`SurgeListener` 是 `SurgeConsumer` 的便捷版本，只提供 `listener` 功能，用于处理副作用：

```dart
SurgeListener<CounterSurge, int>(
  listenWhen: (prev, next, s) => next > prev,  // 可选：条件监听
  listener: (context, state, surge) {
    // 只处理副作用，不构建 UI
    print('Count increased to: $state');
  },
  child: const SizedBox.shrink(),
);
```

## SurgeSelector

`SurgeSelector` 提供精细的重建控制，只有当 `selector` 返回的值发生变化时才会重建（通过 `==` 比较）：

```dart
SurgeSelector<CounterSurge, int, String>(
  selector: (state, s) => state.isEven ? 'even' : 'odd',  // 默认追踪
  builder: (context, selected, s) => Text(selected),
);
```

`selector` 函数默认是追踪的，可以依赖外部信号。如果需要在选择器中使用外部信号但不想追踪，可以使用 `untracked`：

```dart
SurgeSelector<CounterSurge, int, String>(
  selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  builder: (context, selected, s) => Text(selected),
);
```
