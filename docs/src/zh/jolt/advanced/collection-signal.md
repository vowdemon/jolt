---
---

# 预置合集信号

Jolt 提供了预置的响应式集合类型，包括 `ListSignal`、`SetSignal`、`MapSignal` 和 `IterableSignal`。这些预置合集信号基于对应的 Mixin 实现，所有修改操作都会自动触发响应式更新，适用于需要响应式集合操作的场景，如动态列表、标签集合、配置映射等。

```dart
import 'package:jolt/jolt.dart';

void main() {
  final items = ListSignal(['a', 'b', 'c']);
  
  Effect(() {
    print('列表: ${items.value}');
  });
  
  items.add('d'); // 输出: "列表: [a, b, c, d]"
}
```

## 预置合集信号

### ListSignal

`ListSignal` 提供响应式的列表操作：

```dart
final items = ListSignal(['a', 'b', 'c']);
```

使用扩展方法：

```dart
final normalList = [1, 2, 3];
final reactiveList = normalList.toListSignal();
```

所有列表操作都会自动触发更新：

```dart
final items = ListSignal([1, 2, 3]);

Effect(() {
  print('列表长度: ${items.length}');
});

items.add(4); // 触发更新
items.insert(0, 0); // 触发更新
items.removeAt(2); // 触发更新
items.clear(); // 触发更新
```

直接替换整个列表：

```dart
final items = ListSignal([1, 2, 3]);
items.value = [4, 5, 6]; // 替换整个列表，触发更新
```

### SetSignal

`SetSignal` 提供响应式的集合操作：

```dart
final tags = SetSignal({'dart', 'flutter'});
```

使用扩展方法：

```dart
final normalSet = {'dart', 'flutter'};
final reactiveSet = normalSet.toSetSignal();
```

所有集合操作都会自动触发更新：

```dart
final tags = SetSignal({'a', 'b'});

Effect(() {
  print('标签数量: ${tags.length}');
});

tags.add('c'); // 触发更新
tags.remove('a'); // 触发更新
tags.addAll({'d', 'e'}); // 触发更新
tags.clear(); // 触发更新
```

### MapSignal

`MapSignal` 提供响应式的映射操作：

```dart
final user = MapSignal({'name': 'Alice', 'age': 30});
```

使用扩展方法：

```dart
final normalMap = {'key': 'value'};
final reactiveMap = normalMap.toMapSignal();
```

所有映射操作都会自动触发更新：

```dart
final user = MapSignal({'name': 'Alice'});

Effect(() {
  print('用户信息: ${user.value}');
});

user['age'] = 30; // 触发更新
user.addAll({'city': 'NYC', 'country': 'USA'}); // 触发更新
user.remove('city'); // 触发更新
user.clear(); // 触发更新
```

### IterableSignal

`IterableSignal` 提供响应式的迭代器操作，它基于 `Computed` 实现：

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final evenNumbers = IterableSignal(() => 
  numbers.value.where((n) => n.isEven)
);
```

可以使用所有迭代器操作：

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final doubled = IterableSignal(() => 
  numbers.value.map((n) => n * 2)
);

Effect(() {
  print('翻倍: ${doubled.toList()}');
});
```

## 合集信号的 Mixin

Jolt 为每种集合类型提供了对应的 Mixin，这些 Mixin 实现了集合的所有操作，并在修改时自动触发响应式更新：

- **`ListSignalMixin<E>`**: 提供响应式列表功能
- **`SetSignalMixin<E>`**: 提供响应式集合功能
- **`MapSignalMixin<K, V>`**: 提供响应式映射功能
- **`IterableSignalMixin<E>`**: 提供响应式迭代器功能

这些 Mixin 实现了对应集合类型的所有接口方法，并在修改操作后调用 `notify()` 来通知订阅者。

### Mixin 的工作原理

以 `ListSignalMixin` 为例：

```dart
mixin ListSignalMixin<E>
    implements ListBase<E>, Readonly<List<E>>, IMutableCollection {
  // 实现所有 List 接口方法
  @override
  int get length => value.length;
  
  @override
  void add(E element) {
    peek.add(element);
    notify(); // 修改后通知订阅者
  }
  
  @override
  void removeAt(int index) {
    peek.removeAt(index);
    notify(); // 修改后通知订阅者
  }
  
  // ... 其他方法
}
```

Mixin 通过 `value` 访问底层的集合值，通过 `peek` 进行修改操作，修改后调用 `notify()` 触发响应式更新。

## 创建自定义合集信号

你可以基于这些 Mixin 创建自定义的合集信号，添加额外的功能或约束。

### 示例：带验证的 ListSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/list_signal.dart';
import 'package:jolt/src/jolt/signal.dart';

/// 带验证的列表信号：只允许添加满足条件的元素
class ValidatedListSignal<E> extends SignalImpl<List<E>>
    with ListSignalMixin<E>
    implements ListSignal<E> {
  final bool Function(E element) validator;

  ValidatedListSignal(
    List<E>? value, {
    required this.validator,
    super.onDebug,
  }) : super(value ?? []);

  @override
  void add(E element) {
    if (!validator(element)) {
      throw ArgumentError('Element does not pass validation: $element');
    }
    super.add(element);
  }

  @override
  void insert(int index, E element) {
    if (!validator(element)) {
      throw ArgumentError('Element does not pass validation: $element');
    }
    super.insert(index, element);
  }
}

// 使用
final positiveNumbers = ValidatedListSignal<int>(
  [],
  validator: (n) => n > 0,
);

positiveNumbers.add(5); // OK
positiveNumbers.add(-1); // 抛出异常
```

### 示例：带最大长度的 SetSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/set_signal.dart';
import 'package:jolt/src/jolt/signal.dart';

/// 带最大长度限制的集合信号
class BoundedSetSignal<E> extends SignalImpl<Set<E>>
    with SetSignalMixin<E>
    implements SetSignal<E> {
  final int maxLength;

  BoundedSetSignal(
    Set<E>? value, {
    required this.maxLength,
    super.onDebug,
  }) : super(value ?? {});

  @override
  bool add(E element) {
    if (value.length >= maxLength && !value.contains(element)) {
      throw StateError('Set has reached maximum length: $maxLength');
    }
    return super.add(element);
  }

  @override
  void addAll(Iterable<E> other) {
    final toAdd = other.where((e) => !value.contains(e));
    if (value.length + toAdd.length > maxLength) {
      throw StateError('Adding these elements would exceed maximum length');
    }
    super.addAll(other);
  }
}

// 使用
final tags = BoundedSetSignal<String>(
  {},
  maxLength: 5,
);

tags.add('dart'); // OK
tags.addAll({'flutter', 'web', 'mobile', 'desktop'}); // OK (共 5 个)
tags.add('server'); // 抛出异常
```

### 示例：只读视图的 MapSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/map_signal.dart';
import 'package:jolt/src/jolt/signal.dart';

/// 只读视图的映射信号：不允许修改，只能读取
class ReadonlyMapSignal<K, V> extends SignalImpl<Map<K, V>>
    with MapSignalMixin<K, V>
    implements MapSignal<K, V> {
  ReadonlyMapSignal(Map<K, V>? value, {super.onDebug}) : super(value ?? {});

  @override
  void operator []=(K key, V value) {
    throw UnsupportedError('Cannot modify readonly map');
  }

  @override
  V? remove(Object? key) {
    throw UnsupportedError('Cannot modify readonly map');
  }

  @override
  void clear() {
    throw UnsupportedError('Cannot modify readonly map');
  }

  @override
  void addAll(Map<K, V> other) {
    throw UnsupportedError('Cannot modify readonly map');
  }
}

// 使用
final config = ReadonlyMapSignal<String, dynamic>({
  'appName': 'MyApp',
  'version': '1.0.0',
});

print(config['appName']); // OK
config['newKey'] = 'value'; // 抛出异常
```

### 示例：自定义 IterableSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/iterable_signal.dart';
import 'package:jolt/src/jolt/computed.dart';

/// 带缓存的迭代器信号：缓存转换结果以提高性能
class CachedIterableSignal<E, R> extends ComputedImpl<Iterable<R>>
    with IterableMixin<R>, IterableSignalMixin<R>
    implements IterableSignal<R> {
  final Iterable<E> Function() sourceGetter;
  final R Function(E element) transform;
  List<R>? _cachedResult;
  Iterable<E>? _lastSource;

  CachedIterableSignal(
    this.sourceGetter,
    this.transform, {
    super.onDebug,
  }) : super(() => sourceGetter().map(transform));

  @override
  Iterable<R> get value {
    final source = sourceGetter();
    if (_cachedResult == null || _lastSource != source) {
      _cachedResult = source.map(transform).toList();
      _lastSource = source;
    }
    return _cachedResult!;
  }
}

// 使用
final numbers = Signal([1, 2, 3, 4, 5]);

final squared = CachedIterableSignal<int, int>(
  () => numbers.value,
  (n) => n * n,
);

print(squared.toList()); // [1, 4, 9, 16, 25]
```

## 最佳实践

1. **优先使用预置信号**：对于大多数场景，预置的 `ListSignal`、`SetSignal`、`MapSignal` 和 `IterableSignal` 已经足够使用。

2. **使用 Mixin 扩展功能**：如果需要添加验证、约束或特殊行为，继承 `SignalImpl<CollectionType>` 并使用对应的 Mixin。

3. **保持响应式语义**：自定义合集信号应该保持响应式语义，在修改操作后调用 `notify()`（Mixin 会自动处理）。

4. **实现必要的接口**：确保自定义信号实现了对应的集合接口（如 `ListBase`、`SetBase`、`MapBase`），以便与 Dart 标准库兼容。

5. **处理边界情况**：在自定义验证或约束逻辑时，考虑边界情况，如空集合、最大长度等。

## 相关 API

- [扩展 Jolt](./extending-jolt.md) - 了解如何扩展 Jolt 的核心功能
- [Signal](../core/signal.md) - 了解基础信号的使用
- [Computed](../core/computed.md) - 了解计算属性的使用
