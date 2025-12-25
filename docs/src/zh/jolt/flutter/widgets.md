---
---

# Flutter Widgets

在 Flutter 中构建响应式 UI 时，Jolt 提供了核心 Widget：`JoltBuilder`、`JoltSelector` 和 `JoltWatchBuilder`。这些 Widget 都基于 `FlutterEffect` 实现，同一帧内只会触发一次重建，自动追踪依赖变化，并在依赖改变时重建 Widget，让 UI 与数据状态保持同步。

当你访问 `builder` 函数中的信号（Signal）、计算值（Computed）或响应式集合时，这些 Widget 会**自动建立依赖关系**。当被追踪的依赖发生改变时，Widget 会自动重建，从而让 UI 与数据状态保持同步。

这种设计让开发者无需手动管理订阅和取消订阅，也无需关心何时需要重建 Widget。你只需要在 `builder` 中自然地访问响应式数据，剩下的工作都会自动完成。每个 Widget 都有其特定的使用场景，让我们逐一了解它们。

## JoltBuilder

`JoltBuilder` 是最通用的响应式 Widget，它会自动追踪 `builder` 函数中访问的所有信号。当任何一个被追踪的信号发生变化时，Widget 就会自动重建。

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

`JoltSelector` 提供更精细的重建控制，它使用一个 `selector` 函数来选择要追踪的值。只有当 `selector` 返回的值发生变化时（通过 `==` 比较），Widget 才会重建。这对于复杂对象或需要过滤数据的场景特别有用，可以避免不必要的重建，提升性能。

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

### 使用前一个值

`selector` 函数接收前一个选择的值（首次为 `null`），可以用于比较或优化：

```dart
JoltSelector(
  selector: (prev) {
    final current = computeValue();
    // 如果值相同，返回同一个实例以避免重建
    if (prev != null && prev == current) {
      return prev;
    }
    return current;
  },
  builder: (context, value) => Text('$value'),
);
```

## JoltWatchBuilder

`JoltWatchBuilder` 是一个响应式 Widget，它追踪单个 `Readable` 值，并在该值改变时重建。当你想要监听特定的信号或计算值时特别有用。

### 基本用法

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return JoltWatchBuilder<int>(
      readable: counter,
      builder: (context, value) => Text('Count: $value'),
    );
  }
}
```

### 使用 watch 扩展方法

为了方便，你可以直接在 `Readable` 上使用 `watch` 扩展方法：

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/extension.dart';

final counter = Signal(0);

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        counter.watch((value) => Text('Count: $value')),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### 何时使用 JoltWatchBuilder vs JoltBuilder

- **JoltWatchBuilder**：当你想要追踪单个特定的 `Readable` 值时使用。更明确，更容易理解依赖关系。
- **JoltBuilder**：当你想要追踪多个信号或依赖关系复杂且动态时使用。

## JoltProvider

> **⚠️ 已废弃**：`JoltProvider` 已废弃，将在未来版本中移除。对于依赖注入，请使用 Flutter 的内置解决方案，如 `Provider`、`Riverpod` 或其他 DI 包。

`JoltProvider` 曾用于在 Widget 树中提供和管理响应式资源，支持完整的生命周期管理。它结合了依赖注入模式和响应式编程，让你可以在组件树中共享状态，同时自动处理资源的创建和销毁。

### 迁移指南

使用 Flutter 的依赖注入解决方案替换 `JoltProvider`：

```dart
// 之前
JoltProvider<MyStore>(
  create: (context) => MyStore(),
  builder: (context, store) => Text('${store.counter.value}'),
)

// 之后 - 使用 Provider 包
Provider<MyStore>(
  create: (_) => MyStore(),
  child: Builder(
    builder: (context) {
      final store = Provider.of<MyStore>(context);
      return Text('${store.counter.value}');
    },
  ),
)
```

### 使用 create

使用 `create` 构造函数会自动管理资源的生命周期，当 Widget 卸载时会自动调用 `onUnmount` 和 `dispose()`：

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

### 使用 .value

使用 `.value` 构造函数时，资源的生命周期需要手动管理，Provider 不会调用 `onMount`、`onUnmount` 或 `dispose()`：

```dart
final store = MyStore();

JoltProvider<MyStore>.value(
  value: store,
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

## JoltState

`JoltState` 是一个抽象类，用于需要生命周期管理的资源。当资源在 `JoltProvider` 中使用 `create` 构造函数时，如果资源实现了 `JoltState`，会自动调用生命周期回调。

### 生命周期

- **onMount**：在资源创建后、Widget 挂载后调用，用于初始化资源（如启动定时器、订阅流等）
- **onUnmount**：在 Widget 卸载时或资源被替换时调用，用于清理资源（如取消定时器、取消订阅等）

### 示例

```dart
class MyStore extends JoltState {
  final counter = Signal(0);
  Timer? _timer;

  @override
  void onMount(BuildContext context) {
    super.onMount(context);
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      counter.value++;
    });
  }

  @override
  void onUnmount(BuildContext context) {
    super.onUnmount(context);
    _timer?.cancel();
    _timer = null;
  }
}
```

如果资源不需要生命周期管理，可以不继承 `JoltState`：

```dart
class SimpleStore {
  final counter = Signal(0);
}
```
