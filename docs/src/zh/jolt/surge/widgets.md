---
---

# Surge Widgets

Surge 提供了多个 Widget 来在 Flutter 中使用 Surge 状态管理。这些 Widget 基于 Jolt 的响应式系统，提供了类似 BLoC 的 API，同时保持了与 Jolt 生态系统的兼容性。

## SurgeProvider

`SurgeProvider` 用于在 Widget 树中提供 Surge 实例，类似于 `Provider` 的工作方式。它支持两种构造函数：`create` 和 `.value`。

### 使用 create 构造函数

使用 `create` 构造函数时，Surge 的生命周期会自动管理。当 Widget 被移除时，会自动调用 `surge.dispose()`。

```dart
SurgeProvider<CounterSurge>(
  create: (_) => CounterSurge(), // 自动在卸载时释放
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, surge) => Text('count: $state'),
  ),
);
```

### 使用 .value 构造函数

使用 `.value` 构造函数时，Surge 的生命周期需要手动管理。Surge 不会在 Widget 移除时自动释放。

```dart
// 单例 Surge，在其他地方管理
final surge = CounterSurge();

SurgeProvider<CounterSurge>.value(
  value: surge, // 不会自动释放
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, s) => Text('count: $state'),
  ),
);
```

### 从后代 Widget 访问

```dart
// 获取 Surge 实例
final surge = context.read<CounterSurge>();

// 触发状态变化
ElevatedButton(
  onPressed: () => surge.increment(),
  child: const Text('Increment'),
);
```

### 参数

- `create`: 创建 Surge 实例的函数（使用 `create` 构造函数时）
- `value`: Surge 实例（使用 `.value` 构造函数时）
- `lazy`: 是否延迟创建（默认 true）
- `child`: 子 Widget

## SurgeBuilder

`SurgeBuilder` 是一个便捷的 Widget，用于根据 Surge 状态变化构建 UI。它是 `SurgeConsumer` 的简化版本，只提供 `builder` 功能。

### Cubit 兼容 API

```dart
// 与 BlocBuilder 100% 兼容的 API
SurgeBuilder<CounterSurge, int>(
  builder: (context, state) => Text('Count: $state'),
  buildWhen: (prev, next) => next.isEven, // 只在偶数时重建
);
```

### 完整 API

```dart
SurgeBuilder<CounterSurge, int>.full(
  builder: (context, state, surge) => Text('Count: ${surge.state}'),
  buildWhen: (prev, next, s) => next.isEven, // 只在偶数时重建
);
```

### 参数

- `builder`: 构建 UI 的函数，接收 `(context, state)` 或 `(context, state, surge)`
- `buildWhen`: 控制是否重建的条件函数（可选）
- `surge`: Surge 实例（可选，默认从 context 获取）

## SurgeListener

`SurgeListener` 是一个便捷的 Widget，用于监听 Surge 状态变化并执行副作用。它不会重建子 Widget，只执行 `listener` 函数。

### Cubit 兼容 API

```dart
// 与 BlocListener 100% 兼容的 API
SurgeListener<CounterSurge, int>(
  listenWhen: (prev, next) => next > prev, // 只在增加时监听
  listener: (context, state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count increased to: $state')),
    );
  },
  child: const SizedBox.shrink(),
);
```

### 完整 API

```dart
SurgeListener<CounterSurge, int>.full(
  listenWhen: (prev, next, s) => next > prev, // 只在增加时监听
  listener: (context, state, surge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count increased to: $state')),
    );
  },
  child: const SizedBox.shrink(),
);
```

### 参数

- `listener`: 处理副作用的函数，接收 `(context, state)` 或 `(context, state, surge)`
- `listenWhen`: 控制是否执行 listener 的条件函数（可选）
- `child`: 子 Widget（不会被重建）
- `surge`: Surge 实例（可选，默认从 context 获取）

## SurgeConsumer

`SurgeConsumer` 是一个统一的 Widget，同时提供 `builder` 和 `listener` 功能。它提供了精细的控制，可以分别控制何时重建 UI 和何时执行副作用。

### 工作原理

- **builder**: 构建 UI，默认行为是未追踪的（不创建响应式依赖），只在 `buildWhen` 返回 true 时重建
- **listener**: 处理副作用（如显示 SnackBar、发送分析事件等），默认行为是未追踪的，只在 `listenWhen` 返回 true 时执行
- **buildWhen**: 控制是否重建，默认是追踪的（可以依赖外部信号）
- **listenWhen**: 控制是否执行 listener，默认是追踪的（可以依赖外部信号）

### Cubit 兼容 API

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next) => next.isEven, // 只在偶数时重建
  listenWhen: (prev, next) => next > prev, // 只在增加时监听
  builder: (context, state) => Text('count: $state'),
  listener: (context, state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count is now: $state')),
    );
  },
);
```

### 完整 API

```dart
SurgeConsumer<CounterSurge, int>.full(
  buildWhen: (prev, next, s) => next.isEven, // 只在偶数时重建
  listenWhen: (prev, next, s) => next > prev, // 只在增加时监听
  builder: (context, state, surge) => Text('count: $state'),
  listener: (context, state, surge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Count is now: $state')),
    );
  },
);
```

### 使用外部信号

`buildWhen` 和 `listenWhen` 默认是追踪的，可以依赖外部信号。如果需要在未追踪的情况下使用外部信号，使用 `untracked`：

```dart
SurgeConsumer<CounterSurge, int>.full(
  buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
  // ...
);
```

### 参数

- `builder`: 构建 UI 的函数，接收 `(context, state)` 或 `(context, state, surge)`
- `listener`: 处理副作用的函数，接收 `(context, state)` 或 `(context, state, surge)`
- `buildWhen`: 控制是否重建的条件函数（可选，默认追踪）
- `listenWhen`: 控制是否执行 listener 的条件函数（可选，默认追踪）
- `surge`: Surge 实例（可选，默认从 context 获取）

## SurgeSelector

`SurgeSelector` 提供精细的重建控制，使用 `selector` 函数来选择要追踪的值。只有当 `selector` 返回的值发生变化时，Widget 才会重建。

### 工作原理

`SurgeSelector` 在内部使用 `EffectScope` 和 `Effect` 来追踪依赖。它会在 `selector` 函数中执行依赖追踪，然后将 `selector` 的返回值与上一次的值进行比较。只有当返回值发生变化时（使用相等性比较），才会触发 Widget 重建。

### Cubit 兼容 API

```dart
// 与 BlocSelector 100% 兼容的 API
SurgeSelector<CounterSurge, int, String>(
  selector: (state) => state.isEven ? 'even' : 'odd',
  builder: (context, selected) => Text('Number is $selected'),
);
// 只在状态在偶数和奇数之间切换时重建
```

### 完整 API

```dart
SurgeSelector<CounterSurge, int, String>.full(
  selector: (state, surge) => state.isEven ? 'even' : 'odd',
  builder: (context, selected, surge) => Text('Number is $selected'),
);
```

### 使用外部信号

`selector` 函数默认是追踪的，可以依赖外部信号。如果需要在未追踪的情况下使用外部信号，使用 `untracked`：

```dart
SurgeSelector<CounterSurge, int, String>.full(
  selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
  builder: (context, selected, s) => Text(selected),
);
```

### 参数

- `builder`: 构建 UI 的函数，接收 `(context, selected)` 或 `(context, selected, surge)`
- `selector`: 从状态中提取值的函数，接收 `(state)` 或 `(state, surge)`
- `surge`: Surge 实例（可选，默认从 context 获取）

## 完整示例

```dart
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

class CounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SurgeProvider<CounterSurge>(
      create: (_) => CounterSurge(),
      child: MaterialApp(
        home: CounterPage(),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final surge = context.read<CounterSurge>();

    return Scaffold(
      body: Center(
        child: SurgeBuilder<CounterSurge, int>(
          builder: (context, state) => Text('Count: $state'),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => surge.increment(),
            child: Icon(Icons.add),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => surge.decrement(),
            child: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
```

## 注意事项

1. **API 兼容性**：Surge Widgets 提供了与 BLoC 100% 兼容的 API，可以轻松从 Bloc/Cubit 迁移。

2. **性能优化**：使用 `buildWhen`、`listenWhen` 和 `SurgeSelector` 可以精确控制重建和副作用执行，优化性能。

3. **响应式追踪**：`buildWhen`、`listenWhen` 和 `selector` 默认是追踪的，可以依赖外部信号。使用 `untracked` 来避免追踪。

4. **生命周期管理**：使用 `create` 构造函数时，Surge 的生命周期会自动管理。使用 `.value` 构造函数时，需要手动管理。

5. **类型安全**：所有 Widget 都提供完整的类型安全，编译时会进行类型检查。

