---
---

# Flutter Hooks

`jolt_hooks` 基于 [flutter_hooks](https://pub.dev/packages/flutter_hooks) 构建，为 Flutter 提供了与 Jolt 响应式系统深度集成的 Hook API。它让开发者能够在 `HookWidget` 中优雅地使用 Jolt 的所有响应式功能，同时享受 Flutter Hooks 带来的自动生命周期管理优势。

通过将 Jolt 的响应式原语（如 Signal、Computed、Effect 等）封装成 Hooks，开发者可以在函数式组件中直接创建和管理响应式状态。这些 Hooks 会在 Widget 卸载时自动清理资源，无需手动处理 dispose 逻辑，大大简化了状态管理的工作。

## 基本 Hooks

### useSignal

创建响应式信号，用法与 `Signal` 相同。

```dart
import 'package:jolt_hooks/jolt_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
    return Column(
      children: [
        Text('Count: ${count.value}'),
        ElevatedButton(
          onPressed: () => count.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### useComputed

创建计算值，用法与 `Computed` 相同。

```dart
final firstName = useSignal('John');
final lastName = useSignal('Doe');
final fullName = useComputed(() => '${firstName.value} ${lastName.value}');
```

### useWritableComputed

创建可写计算值，用法与 `WritableComputed` 相同。

```dart
final count = useSignal(0);
final doubled = useWritableComputed(
  () => count.value * 2,
  (value) => count.value = value ~/ 2,
);
```

### useJoltEffect

创建副作用，用法与 `Effect` 相同。

```dart
final count = useSignal(0);

useJoltEffect(() {
  print('Count changed to: ${count.value}');
});
```

### useJoltWatcher

创建观察器，用法与 `Watcher` 相同。

```dart
final count = useSignal(0);

useJoltWatcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
  when: (new, old) => new > old,
);
```

### useJoltEffectScope

创建副作用作用域，用法与 `EffectScope` 相同。

```dart
useJoltEffectScope((scope) {
  final count = Signal(0);
  final name = Signal('User');
  final isActive = Computed(() => count.value > 0);
});
```

## 合集 Hooks

### useListSignal

创建响应式列表，用法与 `ListSignal` 相同。

```dart
final items = useListSignal(['Apple', 'Banana']);

items.add('Orange'); // 自动更新
```

### useMapSignal

创建响应式映射，用法与 `MapSignal` 相同。

```dart
final settings = useMapSignal({'theme': 'light'});

settings['theme'] = 'dark'; // 自动更新
```

### useSetSignal

创建响应式集合，用法与 `SetSignal` 相同。

```dart
final tags = useSetSignal({'urgent', 'important'});

tags.add('new'); // 自动更新
```

### useIterableSignal

创建响应式可迭代对象，用法与 `IterableSignal` 相同。

```dart
final numbers = useSignal([1, 2, 3, 4, 5]);
final evens = useIterableSignal(() => numbers.value.where((n) => n.isEven));
```

## 工具 Hooks

### useJoltStream

将信号转换为流，用法与 `stream` 扩展相同。

```dart
final count = useSignal(0);
final stream = useJoltStream(count);

return StreamBuilder<int>(
  stream: stream,
  builder: (context, snapshot) => Text('Count: ${snapshot.data ?? 0}'),
);
```

### useConvertComputed

创建类型转换信号，用法与 `ConvertComputed` 相同。

```dart
final count = useSignal(42);
final countText = useConvertComputed(
  count,
  (int value) => 'Count: $value',
  (String value) => int.parse(value.split(': ')[1]),
);
```

### usePersistSignal

创建持久化信号，用法与 `PersistSignal` 相同。

```dart
final theme = usePersistSignal(
  () => 'light',
  () async => await storage.read('theme') ?? 'light',
  (value) async => await storage.write('theme', value),
);
```

### useAsyncSignal

创建异步信号，用法与 `AsyncSignal` 相同。

```dart
final userData = useAsyncSignal(
  FutureSource(() async => fetchUser()),
);

// 使用
userData.value.map(
  loading: () => CircularProgressIndicator(),
  success: (user) => Text('Welcome, ${user.name}'),
  error: (error, _) => Text('Error: $error'),
);
```

## 组件 Hooks

### useJoltWidget

在 `HookBuilder` 中使用响应式 Widget。当 Widget 构建函数中访问的信号发生变化时，Widget 会自动重建。

```dart
final counter = Signal(0);

Widget build(BuildContext context) {
  return HookBuilder(
    builder: (context) {
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
