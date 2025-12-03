---
---

# Flutter Hooks

`jolt_hooks` 基于 [flutter_hooks](https://pub.dev/packages/flutter_hooks) 构建，为 Flutter 提供了与 Jolt 响应式系统深度集成的 Hook API。它让开发者能够在 `HookWidget` 中优雅地使用 Jolt 的所有响应式功能，同时享受 Flutter Hooks 带来的自动生命周期管理优势。

通过将 Jolt 的响应式原语（如 Signal、Computed、Effect 等）封装成 Hooks，开发者可以在函数式组件中直接创建和管理响应式状态。这些 Hooks 会在 Widget 卸载时自动清理资源，无需手动处理 dispose 逻辑，大大简化了状态管理的工作。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_hooks/jolt_hooks.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    final doubled = useComputed(() => count.value * 2);

    return Scaffold(
      body: HookBuilder(
        builder: (context) => useJoltWidget(() {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Count: ${count.value}'),
              Text('Doubled: ${doubled.value}'),
              ElevatedButton(
                onPressed: () => count.value++,
                child: Text('Increment'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
```

## useSignal

`useSignal` 是 `JoltSignalHookCreator` 的实例，用于创建响应式信号。用法与 `Signal` 相同，只是构造方式不同，并支持 `keys` 参数。

```dart
final count = useSignal(0);
final name = useSignal('Alice', keys: [userId]); // 当 userId 改变时重新创建
```

### 扩展方法

- **`useSignal.lazy()`**: 创建延迟初始化的信号
- **`useSignal.list()`**: 创建列表信号
- **`useSignal.map()`**: 创建映射信号
- **`useSignal.set()`**: 创建集合信号
- **`useSignal.iterable()`**: 创建迭代器信号
- **`useSignal.async()`**: 创建异步信号
- **`useSignal.persist()`**: 创建持久化信号

所有扩展方法都支持 `keys` 参数。

## useComputed

`useComputed` 是 `JoltComputedHookCreator` 的实例，用于创建计算值。用法与 `Computed` 相同，只是构造方式不同，并支持 `keys` 参数。

```dart
final firstName = useSignal('John');
final lastName = useSignal('Doe');
final fullName = useComputed(() => '${firstName.value} ${lastName.value}');
```

### 扩展方法

- **`useComputed.writable()`**: 创建可写计算值
- **`useComputed.convert()`**: 创建类型转换计算值

所有扩展方法都支持 `keys` 参数。

## useJoltEffect

`useJoltEffect` 是 `JoltEffectHookCreator` 的实例，用于创建副作用。用法与 `Effect` 相同，只是构造方式不同，并支持 `keys` 参数。

```dart
final count = useSignal(0);

useJoltEffect(() {
  print('Count changed to: ${count.value}');
});
```

### 扩展方法

- **`useJoltEffect.lazy()`**: 创建延迟收集依赖的副作用

## useWatcher

`useWatcher` 是 `JoltWatcherHookCreator` 的实例，用于创建观察器。用法与 `Watcher` 相同，只是构造方式不同，并支持 `keys` 参数。

```dart
final count = useSignal(0);

useWatcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
);
```

### 扩展方法

- **`useWatcher.immediately()`**: 创建立即执行的观察器
- **`useWatcher.once()`**: 创建执行一次后自动销毁的观察器

所有扩展方法都支持 `keys` 参数。

## useEffectScope

`useEffectScope` 是 `JoltEffectScopeHookCreator` 的实例，用于创建副作用作用域。用法与 `EffectScope` 相同，只是构造方式不同，并支持 `keys` 参数。

```dart
useEffectScope(fn: (scope) {
  scope.run(() {
    final count = Signal(0);
    Effect(() => print('Count: ${count.value}'));
  });
});
```

## useJoltStream

将响应式值转换为 Dart Stream。用法与 `stream` 扩展相同，只是构造方式不同，并支持 `keys` 参数。

```dart
final count = useSignal(0);
final stream = useJoltStream(count);
```

## useJoltWidget

在 `HookBuilder` 中使用响应式 Widget。当 Widget 构建函数中访问的信号发生变化时，Widget 会自动重建。

**重要**：此 Hook 必须在 `HookBuilder` 内使用。

```dart
Widget build(BuildContext context) {
  return HookBuilder(
    builder: (context) {
      final counter = useSignal(0);
      
      return useJoltWidget(() {
        return Column(
          children: [
            Text('Count: ${counter.value}'),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: Text('Increment'),
            ),
          ],
        );
      });
    },
  );
}
```

## keys 参数

所有 Hook 都支持 `keys` 参数用于 Hook 记忆化。当 keys 改变时，Hook 会被重新创建：

```dart
final count = useSignal(0, keys: [userId]); // 当 userId 改变时，Hook 会重新创建
```

## 生命周期管理

所有通过 Hooks 创建的响应式对象都会在 Widget 卸载时自动释放，无需手动调用 `dispose()`。

## 与 JoltBuilder 集成

你也可以使用 `JoltBuilder` 从 `jolt_flutter` 包来实现响应式 UI 更新：

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

Widget build(BuildContext context) {
  final count = useSignal(0);

  return JoltBuilder(
    builder: (context) => Text('Count: ${count.value}'),
  );
}
```

## 注意事项

1. **Hook 规则**：所有 Hooks 必须在 `HookWidget` 的 `build` 方法或 `HookBuilder` 的 `builder` 中调用，不能在条件语句或循环中调用。

2. **useJoltWidget 限制**：`useJoltWidget` 必须在 `HookBuilder` 内使用，不能在普通的 `HookWidget` 中直接使用。

3. **自动清理**：所有通过 Hooks 创建的资源会在 Widget 卸载时自动清理，无需手动管理。

4. **keys 参数**：使用 `keys` 参数可以控制 Hook 的重新创建时机，这对于依赖外部参数的场景很有用。

## 相关 API

- [Signal](../../core/signal.md) - 了解基础信号的使用
- [Computed](../../core/computed.md) - 了解计算属性的使用
- [Effect](../../core/effect.md) - 了解副作用的使用
- [SetupWidget](./setup-widget.md) - 了解 SetupWidget 和 Flutter 资源 Hooks
