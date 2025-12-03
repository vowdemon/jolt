---
---

# 扩展 Jolt

Jolt 提供了丰富的扩展能力，让你可以基于核心接口创建自己的实用工具、响应式节点和高级使用技巧。本指南将帮助你理解 Jolt 的扩展机制，并展示如何创建自定义的响应式原语。

## 核心接口理解

### ReadonlyNode 基础

`Signal`、`Computed` 等都是 `ReadonlyNode` 的实现。理解 `ReadonlyNode` 是扩展 Jolt 的基础。

```dart
abstract interface class ReadonlyNode<T>
    implements Readonly<T>, Disposable {
  /// 是否已释放
  bool get isDisposed;

  /// 释放资源
  @mustCallSuper
  void dispose();
}
```

`ReadonlyNode` 接口提供了以下核心能力：

- **`.value` / `.get()`**: 读取值并建立响应式依赖（来自 `Readonly<T>`）
- **`.peek`**: 读取值但不建立依赖（来自 `Readonly<T>`）
- **`.notify()`**: 手动通知订阅者（来自 `Readonly<T>`）
- **`.isDisposed`**: 检查是否已释放
- **`.dispose()`**: 释放资源

### ReadonlyNodeMixin

如果你需要实现 `ReadonlyNode` 并需要自定义清理逻辑，可以使用 `ReadonlyNodeMixin`：

```dart
mixin ReadonlyNodeMixin<T> implements ReadonlyNode<T>, ChainedDisposable {
  @override
  bool get isDisposed => _isDisposed;
  @protected
  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    onDispose(); // 调用自定义清理逻辑
    JFinalizer.disposeObject(this);
  }

  /// 重写此方法以提供自定义清理逻辑
  @protected
  void onDispose();
}
```

使用 `ReadonlyNodeMixin` 时，你可以重写 `onDispose()` 方法来自定义清理逻辑。

### Readonly 接口

`Readonly<T>` 接口定义了只读响应式值的基本操作：

```dart
abstract interface class Readonly<T> {
  T get value;
  T get();
  T get peek;
  void notify();
}
```

### Writable 接口

`Writable<T>` 接口扩展了 `Readonly<T>`，添加了写入能力：

```dart
abstract interface class Writable<T> implements Readonly<T> {
  set value(T value);
  T set(T value);
}
```

## 类型设计原则

### 接受任意响应式值

当你需要创建一个函数或类，接收任意响应式值时，应该使用 `ReadonlyNode<T>` 或 `Readonly<T>` 作为参数类型：

```dart
// ✅ 正确：接受任意响应式值
void processReactiveValue(ReadonlyNode<int> value) {
  print('Value: ${value.value}');
}

// ✅ 也可以使用 Readonly<T>
void processReactiveValue2(Readonly<int> value) {
  print('Value: ${value.value}');
}

// 使用
final signal = Signal(42);
final computed = Computed(() => signal.value * 2);

processReactiveValue(signal);    // OK
processReactiveValue(computed);  // OK
```

### 扩展方法的最佳实践

如果需要对 `Computed` 或 `Signal` 写通用扩展，应该在它们共同的接口上定义：

```dart
// ✅ 正确：在 ReadonlyNode 上定义扩展
extension MyExtension<T> on ReadonlyNode<T> {
  String get displayValue => 'Value: ${value}';
}

// ✅ 正确：在 Signal 上定义扩展
extension SignalExtension<T> on Signal<T> {
  void reset() => value = null as T;
}

// ✅ 正确：在 Computed 上定义扩展
extension ComputedExtension<T> on Computed<T> {
  ReadonlyNode<T> get readonly => this;
}
```

## 扩展 Signal

### Signal 接口与实现

`Signal` 是一个接口，具体实现是 `SignalImpl`。你可以通过两种方式扩展 Signal：

1. **继承 `SignalImpl`**：适用于需要修改内部行为的场景
2. **实现 `Signal` 接口**：适用于需要完全自定义实现的场景

### 方式一：继承 SignalImpl

`SignalImpl` 使用了 `ReadonlyNodeMixin`，所以继承 `SignalImpl` 的类可以重写 `onDispose()` 来自定义清理逻辑。

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';
import 'dart:async';

/// 防抖信号：在值改变后等待一段时间才通知订阅者
class DebouncedSignal<T> extends SignalImpl<T> {
  final Duration delay;
  Timer? _timer;

  DebouncedSignal(
    super.value, {
    required this.delay,
    super.onDebug,
  });

  @override
  T set(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.set(value);
    });
    return value;
  }

  // SignalImpl 使用了 ReadonlyNodeMixin，所以可以重写 onDispose()
  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}

// 使用
final searchQuery = DebouncedSignal(
  '',
  delay: Duration(milliseconds: 300),
);

searchQuery.value = 'j';
searchQuery.value = 'jo';
searchQuery.value = 'jolt';
// 300ms 后才会通知订阅者，值为 'jolt'
```

### 方式二：实现 Signal 接口

如果你需要完全自定义实现，可以实现 `Signal` 接口：

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/core/reactive.dart';
import 'package:jolt/src/jolt/base.dart';

/// 自定义 Signal 实现
class CustomSignal<T> extends SignalReactiveNode<T>
    with ReadonlyNodeMixin<T>
    implements Signal<T> {
  CustomSignal(T? value, {super.onDebug})
      : super(flags: ReactiveFlags.mutable, pendingValue: value);

  @override
  T get peek => pendingValue as T;

  @override
  T get value => get();

  @override
  T get() {
    assert(!isDisposed, "Signal is disposed");
    return getSignal(this);
  }

  @override
  T set(T value) {
    assert(!isDisposed, "Signal is disposed");
    // 自定义设置逻辑
    return setSignal(this, value);
  }

  @override
  void notify() {
    assert(!isDisposed, "Signal is disposed");
    notifySignal(this);
  }

  @override
  void onDispose() {
    disposeNode(this);
  }
}
```

### 从核心类继承

你也可以直接从核心类继承，创建更底层的自定义节点：

```dart
import 'package:jolt/src/core/reactive.dart';

/// 自定义响应式节点
class CustomReactiveNode<T> extends SignalReactiveNode<T> {
  CustomReactiveNode(T? initialValue)
      : super(flags: ReactiveFlags.mutable, pendingValue: initialValue);

  // 实现必要的接口方法
  // ...
}
```

## 扩展 Computed

### 继承 WritableComputed

`ConvertComputed` 是一个很好的例子，展示了如何通过继承 `WritableComputed` 来扩展功能：

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/computed.dart';

/// 类型转换计算值
class ConvertComputedImpl<T, U> extends WritableComputedImpl<T>
    implements ConvertComputed<T, U> {
  ConvertComputedImpl(
    this.source, {
    required this.decode,
    required this.encode,
    super.onDebug,
  }) : super(
          () => decode(source.value),
          (value) => source.value = encode(value),
        );

  final WritableNode<U> source;
  final T Function(U value) decode;
  final U Function(T value) encode;
}

// 使用
final count = Signal(42);
final countText = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

print(countText.value); // "42"
countText.value = "100"; // count.value 变为 100
```

## 扩展 Hooks

### useAutoDispose 基础

在 SetupWidget 中，`useAutoDispose` 是一个关键 Hook，用于自动管理资源的生命周期。所有通过 `useAutoDispose` 创建的资源会在 Widget 卸载时自动调用 `dispose()`：

```dart
import 'package:jolt_flutter/setup.dart';

setup(context, props) {
  // useAutoDispose 会在 Widget 卸载时自动调用 dispose()
  final signal = useAutoDispose(() => Signal(0));
  final computed = useAutoDispose(() => Computed(() => signal.value * 2));

  return () => Text('${computed.value}');
}
```

### JoltSignalHookCreator 模式

`useSignal` 实际上是 `JoltSignalHookCreator` 的实例。你可以通过扩展这个类来添加自己的信号创建方法：

```dart
import 'package:jolt_flutter/setup.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';
import 'dart:async';

/// 扩展 useSignal 添加防抖信号方法
extension DebouncedSignalExtension on JoltSignalHookCreator {
  /// 创建防抖信号 Hook
  Signal<T> debounce<T>(
    T value, {
    required Duration delay,
    JoltDebugFn? onDebug,
  }) {
    // useAutoDispose 确保在 Widget 卸载时自动释放资源
    return useAutoDispose(() => DebouncedSignal(
      value,
      delay: delay,
      onDebug: onDebug,
    ));
  }
}

// 使用
setup(context, props) {
  final searchQuery = useSignal.debounce(
    '',
    delay: Duration(milliseconds: 300),
  );

  return () => TextField(
    onChanged: (value) => searchQuery.value = value,
  );
}
```

### 扩展 useComputed

类似地，你也可以扩展 `useComputed`：

```dart
extension ComputedExtension on JoltUseComputed {
  /// 创建防抖计算值
  Computed<T> debounced<T>(
    T Function() getter, {
    required Duration delay,
    JoltDebugFn? onDebug,
  }) {
    final source = useSignal.lazy<T>();
    Timer? timer;

    useEffect(() {
      final value = getter();
      timer?.cancel();
      timer = Timer(delay, () {
        source.value = value;
      });

      onEffectCleanup(() => timer?.cancel());
    });

    return useComputed(() => source.value);
  }
}
```

## 创建自定义响应式节点

### 使用 CustomReactiveNode

对于需要完全自定义行为的场景，可以使用 `CustomReactiveNode`：

```dart
import 'package:jolt/src/core/reactive.dart';

/// 自定义响应式节点示例
class CustomWidgetPropsNode<T extends Widget>
    extends CustomReactiveNode<T> {
  CustomWidgetPropsNode(this._context)
      : super(flags: ReactiveFlags.mutable);

  final BuildContext _context;
  bool _dirty = false;

  @override
  T get() {
    // 建立依赖关系
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(this, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }

    return _context.widget as T;
  }

  @override
  void notify() {
    _dirty = true;
    notifyCustom(this);
  }

  @override
  T get peek => _context.widget as T;

  @override
  T get value => get();

  @override
  bool updateNode() {
    if (_dirty) {
      _dirty = false;
      return true; // 值已改变，通知订阅者
    }
    return false; // 无变化
  }

  @override
  bool get isDisposed => !_context.mounted;

  @override
  void onDispose() {
    disposeNode(this);
  }
}
```

## 实际扩展示例

### 示例 1：节流信号

```dart
import 'dart:async';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';

/// 节流信号：在指定时间间隔内最多通知一次
class ThrottledSignal<T> extends SignalImpl<T> {
  final Duration interval;
  Timer? _timer;
  T? _pendingValue;
  bool _hasPendingValue = false;

  ThrottledSignal(
    super.value, {
    required this.interval,
    super.onDebug,
  });

  @override
  T set(T value) {
    _pendingValue = value;
    _hasPendingValue = true;

    if (_timer == null) {
      _timer = Timer.periodic(interval, (_) {
        if (_hasPendingValue) {
          super.set(_pendingValue as T);
          _hasPendingValue = false;
        } else {
          _timer?.cancel();
          _timer = null;
        }
      });
    }

    return value;
  }

  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}
```

### 示例 2：缓存信号

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';

/// 缓存信号：缓存最近 N 个值
class CachedSignal<T> extends SignalImpl<T> {
  final int cacheSize;
  final List<T> _cache = [];

  CachedSignal(
    super.value, {
    this.cacheSize = 10,
    super.onDebug,
  }) {
    if (value != null) {
      _cache.add(value as T);
    }
  }

  @override
  T set(T value) {
    _cache.add(value);
    if (_cache.length > cacheSize) {
      _cache.removeAt(0);
    }
    return super.set(value);
  }

  /// 获取缓存的历史值
  List<T> get history => List.unmodifiable(_cache);

  /// 获取第 N 个历史值
  T? getHistory(int index) {
    if (index < 0 || index >= _cache.length) return null;
    return _cache[_cache.length - 1 - index];
  }
}
```

### 示例 3：验证信号

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';

/// 验证信号：在设置值前进行验证
class ValidatedSignal<T> extends SignalImpl<T> {
  final bool Function(T value) validator;
  final T Function(T invalidValue)? onInvalid;

  ValidatedSignal(
    super.value, {
    required this.validator,
    this.onInvalid,
    super.onDebug,
  });

  @override
  T set(T value) {
    if (validator(value)) {
      return super.set(value);
    } else {
      if (onInvalid != null) {
        return super.set(onInvalid!(value));
      }
      // 验证失败，不更新值
      return peek;
    }
  }
}

// 使用
final age = ValidatedSignal<int>(
  0,
  validator: (value) => value >= 0 && value <= 150,
  onInvalid: (value) {
    print('Invalid age: $value');
    return 0; // 返回默认值
  },
);

age.value = 25;  // OK
age.value = 200; // 验证失败，值保持为 25
```

### 示例 4：扩展 useSignal 添加节流方法

```dart
import 'package:jolt_flutter/setup.dart';

extension ThrottledSignalExtension on JoltSignalHookCreator {
  /// 创建节流信号 Hook
  Signal<T> throttle<T>(
    T value, {
    required Duration interval,
    JoltDebugFn? onDebug,
  }) {
    // useAutoDispose 确保在 Widget 卸载时自动释放资源
    return useAutoDispose(() => ThrottledSignal(
      value,
      interval: interval,
      onDebug: onDebug,
    ));
  }
}

// 使用
setup(context, props) {
  final scrollPosition = useSignal.throttle(
    0.0,
    interval: Duration(milliseconds: 100),
  );

  return () => ListView(
    onScroll: (position) => scrollPosition.value = position,
  );
}
```

### 示例 5：创建自定义 Hook

你也可以创建完全自定义的 Hook：

```dart
import 'package:jolt_flutter/setup.dart';

/// 自定义 Hook：自动刷新的数据
class AutoRefreshHook<T> extends SetupHook<Signal<T>> {
  AutoRefreshHook({
    required this.fetch,
    required this.interval,
  });

  final Future<T> Function() fetch;
  final Duration interval;
  Timer? _timer;

  @override
  Signal<T> build() {
    final signal = useAutoDispose(() => Signal.lazy<T>());
    
    // 立即获取一次
    _refresh(signal);
    
    // 定时刷新
    _timer = Timer.periodic(interval, (_) => _refresh(signal));
    
    return signal;
  }

  Future<void> _refresh(Signal<T> signal) async {
    try {
      final data = await fetch();
      signal.value = data;
    } catch (e) {
      // 处理错误
    }
  }

  @override
  void unmount() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 扩展方法，方便使用
extension AutoRefreshExtension on JoltSignalHookCreator {
  Signal<T> autoRefresh<T>({
    required Future<T> Function() fetch,
    required Duration interval,
  }) {
    return useHook(AutoRefreshHook<T>(
      fetch: fetch,
      interval: interval,
    ));
  }
}

// 使用
setup(context, props) {
  final data = useSignal.autoRefresh(
    fetch: () => api.fetchData(),
    interval: Duration(seconds: 30),
  );

  return () => data.value.map(
    loading: () => CircularProgressIndicator(),
    success: (value) => Text('Data: $value'),
    error: (error, _) => Text('Error: $error'),
  ) ?? SizedBox();
}
```

## 最佳实践

### 1. 优先使用组合而非继承

在大多数情况下，组合现有的响应式原语比创建新的实现更简单：

```dart
// ✅ 推荐：使用 Computed 组合
final debouncedValue = Computed(() {
  // 使用现有的防抖逻辑
  return debounceFunction(source.value);
});

// ❌ 不推荐：除非真的需要自定义行为
class CustomDebouncedSignal extends SignalImpl<T> {
  // 复杂的自定义实现
}
```

### 2. 实现必要的生命周期方法

如果你使用 `ReadonlyNodeMixin` 或继承自使用了 `ReadonlyNodeMixin` 的类（如 `SignalImpl`），可以重写 `onDispose()` 来清理资源。`onDispose()` 是 `void` 类型，在 `dispose()` 方法中自动调用：

```dart
// 继承 SignalImpl（它使用了 ReadonlyNodeMixin）
class MySignal<T> extends SignalImpl<T> {
  Timer? _timer;
  
  @override
  void onDispose() {
    // 清理定时器、订阅等资源
    _timer?.cancel();
    super.onDispose(); // 调用父类的 onDispose
  }
}

// 或者使用 ReadonlyNodeMixin
class MyNode<T> with ReadonlyNodeMixin<T> implements ReadonlyNode<T> {
  Timer? _timer;
  
  @override
  T get value => throw UnimplementedError();
  
  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}
```

**注意**：
- `ReadonlyNode` 接口本身没有 `onDispose()` 方法
- 只有使用 `ReadonlyNodeMixin` 时才能重写 `onDispose()`
- `onDispose()` 是同步方法，如果需要异步清理，应该在 `onDispose()` 中启动异步操作，但不等待其完成

### 3. 保持类型安全

使用泛型保持类型安全：

```dart
// ✅ 正确：使用泛型
class MySignal<T> extends SignalImpl<T> { }

// ❌ 错误：丢失类型信息
class MySignal extends SignalImpl<dynamic> { }
```

### 4. 遵循接口约定

如果实现接口，确保遵循所有约定：

```dart
// Signal 接口要求实现这些方法
@override
T get value => get();

@override
T get() { /* ... */ }

@override
T set(T value) { /* ... */ }

@override
void notify() { /* ... */ }
```

### 5. 使用扩展方法增强功能

对于不需要修改核心行为的场景，使用扩展方法：

```dart
extension SignalHelpers<T> on Signal<T> {
  /// 重置为初始值
  void resetTo(T initialValue) => value = initialValue;

  /// 切换布尔值
  void toggle() {
    if (value is bool) {
      value = !(value as bool) as T;
    }
  }
}
```

## 参考实现

查看 Jolt 的现有实现可以学习扩展模式：

- **PersistSignal**: `packages/jolt/lib/src/tricks/persist_signal.dart` - 持久化信号实现
- **ConvertComputed**: `packages/jolt/lib/src/tricks/convert_computed.dart` - 类型转换计算值
- **AsyncSignal**: `packages/jolt/lib/src/jolt/async.dart` - 异步信号实现
- **ListSignal**: `packages/jolt/lib/src/jolt/collection/list_signal.dart` - 列表信号实现

这些实现展示了如何：
- 继承 `SignalImpl` 或 `WritableComputedImpl`
- 实现自定义的 `set` 和 `get` 逻辑
- 处理异步操作
- 管理资源生命周期

## 注意事项

1. **性能考虑**：自定义实现应该保持高效，避免不必要的计算或内存分配

2. **线程安全**：如果需要在多线程环境中使用，确保实现是线程安全的

3. **测试覆盖**：为自定义实现编写完整的测试，确保行为符合预期

4. **文档说明**：为自定义扩展编写清晰的文档，说明使用场景和注意事项

5. **向后兼容**：如果创建公共库，考虑向后兼容性，避免破坏性变更

