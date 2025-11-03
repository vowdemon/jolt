---
---

# Flutter Widgets

在 Flutter 中构建响应式 UI 时，Jolt 提供了三个核心 Widget：`JoltBuilder`、`JoltSelector` 和 `JoltProvider`。这些 Widget 基于 Jolt 的响应式系统，通过在 Flutter 中创建 **Effect** 作用域来追踪依赖变化。

当你访问 `builder` 函数中的信号（Signal）、计算值（Computed）或响应式集合时，这些 Widget 会**自动建立依赖关系**。当被追踪的依赖发生改变时，内部的 Effect 会被触发，并通知 Flutter 框架进行 Widget 重建，从而让 UI 与数据状态保持同步。

这种设计让开发者无需手动管理订阅和取消订阅，也无需关心何时需要重建 Widget。你只需要在 `builder` 中自然地访问响应式数据，剩下的工作都会自动完成。每个 Widget 都有其特定的使用场景，让我们逐一了解它们。

## JoltBuilder

`JoltBuilder` 是最通用的响应式 Widget，它会自动追踪 `builder` 函数中访问的所有信号。当任何一个被追踪的信号发生变化时，Widget 就会自动重建。

### 工作原理

`JoltBuilder` 内部创建了一个 `EffectScope` 和 `Effect`，在 `builder` 函数执行时，所有被访问的信号都会被自动追踪。当这些信号的值发生改变时，Effect 会触发重建请求，确保 UI 始终反映最新的数据状态。多个信号的批量更新会被自动合并，保证每个帧只进行一次重建，从而优化性能。

### 基本用法

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return JoltBuilder(
      builder: (context) => Column(
        children: [
          Text('Count: ${counter.value}'),
          ElevatedButton(
            onPressed: () => counter.value++,
            child: Text('Increment'),
          ),
        ],
      ),
    );
  }
}
```

### 多信号追踪

`JoltBuilder` 可以同时追踪多个信号，当其中任何一个改变时都会触发重建：

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

JoltBuilder(
  builder: (context) => Text(
    'Hello ${firstName.value} ${lastName.value}',
  ),
);
```

## JoltSelector

`JoltSelector` 提供更精细的重建控制，它使用一个 `selector` 函数来选择要追踪的值。只有当 `selector` 返回的值发生变化时，Widget 才会重建。这对于复杂对象或需要过滤数据的场景特别有用，可以避免不必要的重建，提升性能。

### 工作原理

`JoltSelector` 在内部同样使用 `EffectScope` 和 `Effect` 来追踪依赖。不同的是，它会在 `selector` 函数中执行依赖追踪，然后将 `selector` 的返回值与上一次的值进行比较。只有当返回值发生变化时（使用相等性比较），才会触发 Widget 重建。这样即使信号的其他属性改变了，只要选择的值没变，Widget 就不会重建。

### 基本用法

```dart
final user = Signal(User(name: 'John', age: 30));

// 只监听 name，不监听 age
JoltSelector(
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
);

// user.name 改变时重建
// user.age 改变时不重建
```

### 多信号选择

```dart
final firstName = Signal('John');
final lastName = Signal('Doe');

JoltSelector(
  selector: (prev) => '${firstName.value} ${lastName.value}',
  builder: (context, fullName) => Text('Hello $fullName'),
);
```

## JoltProvider

`JoltProvider` 用于在 Widget 树中提供和管理响应式资源，支持完整的生命周期管理。它结合了依赖注入模式和响应式编程，让你可以在组件树中共享状态，同时自动处理资源的创建和销毁。

### 工作原理

`JoltProvider` 内部使用 `JoltBuilder` 来实现响应式更新，这意味着在 `builder` 中访问的信号会被自动追踪。同时，它还通过 `InheritedWidget` 将资源提供给整个子树，让后代 Widget 可以通过 `JoltProvider.of<T>(context)` 访问资源。如果资源实现了 `JoltState` 接口，`JoltProvider` 还会自动调用 `onMount` 和 `onUnmount` 生命周期回调，方便进行资源初始化和清理。

### 基本用法

```dart
class MyStore extends JoltState {
  final counter = Signal(0);
  
  @override
  void onMount(BuildContext context) {
    print('Store mounted');
  }
  
  @override
  void onUnmount(BuildContext context) {
    print('Store unmounted');
  }
}

JoltProvider<MyStore>(
  create: (context) => MyStore(),
  builder: (context, store) => Text('${store.counter.value}'),
);
```

### 从后代 Widget 访问

```dart
JoltProvider<MyStore>(
  create: (context) => MyStore(),
  builder: (context, store) => ChildWidget(),
);

// 在 ChildWidget 中
class ChildWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = JoltProvider.of<MyStore>(context);
    return Text('Count: ${store.counter.value}');
  }
}
```

### 可选访问

```dart
final store = JoltProvider.maybeOf<MyStore>(context);
if (store != null) {
  // 使用 store
}
```

