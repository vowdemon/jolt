---
---

# Jolt

Jolt 是一个轻量级的响应式状态管理库，适用于 Dart 和 Flutter。

## 什么是响应式系统？

响应式系统是一种自动追踪数据依赖并自动更新的编程范式。当你访问响应式数据时，系统会**自动建立依赖关系**。当数据发生变化时，所有依赖它的计算值和副作用会**自动重新执行**，无需手动管理订阅和取消订阅。

例如：

```dart
final count = Signal(0);  // 响应式状态
final doubled = Computed(() => count.value * 2);  // 自动追踪 count

Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');  // 自动追踪依赖
});

count.value = 5;  // 自动触发 Effect 和 Computed 更新
```

这种机制让状态管理变得自动化和高效，你只需要关注数据的变化，系统会自动处理更新。


## 为什么选择 Jolt？

### 强大的响应式信号系统

Jolt 的核心响应式系统移植自 [alien_signals](https://github.com/alien-signals/alien_signals)，这是一个经过实战验证的高性能响应式信号库。基于细粒度的响应式依赖图，Jolt 构建了一个高效、精确的状态管理系统。这个系统的核心是**自动依赖追踪**机制：

**依赖图的自动构建**：当你访问响应式值时，Jolt 会自动在依赖图中建立连接。系统维护一个双向的依赖图，记录哪些 Signal 被哪些 Computed 和 Effect 依赖，以及每个 Computed 和 Effect 依赖哪些 Signal。

```dart
final count = Signal(0);
final name = Signal('Alice');

// 访问时自动建立依赖关系
final display = Computed(() => '${name.value}: ${count.value}');
// 系统记录：display 依赖于 name 和 count

Effect(() {
  print('Display: ${display.value}');
  // 系统记录：Effect 依赖于 display（间接依赖 name 和 count）
});

// 修改 count 时，系统自动：
// 1. 检测到 count 变化
// 2. 找到依赖 count 的 display
// 3. 重新计算 display
// 4. 找到依赖 display 的 Effect
// 5. 执行 Effect
count.value = 5; // 整个更新链自动执行
```

**细粒度的更新传播**：Jolt 使用高效的更新传播算法，只更新真正变化的部分。当一个 Signal 改变时，系统会沿着依赖图向上传播，但只更新那些真正需要更新的节点。这避免了不必要的计算和重建，确保最佳性能。

**智能的批处理机制**：Jolt 内置批处理功能，可以将同一帧内的多个更新合并。这意味着即使你快速修改多个 Signal，系统也只会触发一次更新，避免中间状态的闪烁和不必要的计算。

```dart
final signal1 = Signal(1);
final signal2 = Signal(2);
final sum = Computed(() => signal1.value + signal2.value);

Effect(() => print('Sum: ${sum.value}'));

// 不使用批处理：会触发两次更新
signal1.value = 10; // 输出: "Sum: 12"
signal2.value = 20; // 输出: "Sum: 30"

// 使用批处理：只触发一次更新
batch(() {
  signal1.value = 100;
  signal2.value = 200;
}); // 只输出: "Sum: 300"
```

**缓存和懒计算**：Computed 值会自动缓存，只有在依赖变化时才重新计算。你可以使用 `peekCached` 访问缓存值而不触发重新计算，或者使用 `peek` 重新计算而不建立依赖关系。这种设计在保证正确性的同时，最大化了性能。

### 极少的样板代码

Jolt 的核心优势是极少的样板代码。你无需定义类、方法或事件，直接使用 Signal、Computed 和 Effect 即可：

```dart
// 创建响应式状态
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

// 响应变化
Effect(() {
  print('Count: ${count.value}, Doubled: ${doubled.value}');
});

// 修改状态
count.value = 5; // 自动触发更新
```

无需手动管理订阅和取消订阅，依赖关系自动建立和清理。这显著减少了代码量，提高了开发效率和可维护性。

### 丰富的工具和功能

Jolt 提供了完整的工具集，覆盖了响应式编程的各个方面：

#### 核心响应式原语

- **Signal**：可变的响应式状态容器，支持延迟初始化、只读视图、手动通知等
- **Computed**：自动计算的派生值，支持缓存、懒计算、非依赖访问
- **WritableComputed**：可写的计算值，支持双向绑定
- **Effect**：副作用函数，支持懒执行、清理回调、作用域管理
- **Watcher**：值变化监听器，支持立即执行、单次执行、条件触发
- **EffectScope**：副作用作用域，用于管理多个 Effect 的生命周期

#### 响应式集合

- **ListSignal**：响应式列表，所有修改操作自动触发更新
- **MapSignal**：响应式映射，键值对的增删改自动触发更新
- **SetSignal**：响应式集合，元素的增删自动触发更新
- **IterableSignal**：响应式可迭代对象，支持动态生成

```dart
final items = ListSignal(['apple', 'banana']);
items.add('cherry'); // 自动触发更新
items.insert(0, 'orange'); // 自动触发更新

final userMap = MapSignal({'name': 'Alice', 'age': 30});
userMap['city'] = 'New York'; // 自动触发更新
```

#### 异步状态管理

- **AsyncSignal**：统一的异步状态管理，自动处理 loading、success、error 状态
- **AsyncSignal.fromFuture**：从 Future 创建异步信号
- **AsyncSignal.fromStream**：从 Stream 创建异步信号

```dart
final userSignal = AsyncSignal.fromFuture(fetchUser());

Effect(() {
  final state = userSignal.value;
  if (state.isLoading) print('Loading...');
  if (state.isSuccess) print('User: ${state.data}');
  if (state.isError) print('Error: ${state.error}');
});
```

#### 扩展方法

- **stream / listen**：将响应式值转换为流
- **until / untilWhen**：等待响应式值满足条件
- **readonly**：获取只读视图
- **update**：使用更新函数修改值
- **derived**：从 Readable 创建计算值
- **call / get**：读取值的替代语法

```dart
// 转换为流
final stream = counter.stream;
stream.listen((value) => print(value));

// 等待条件满足
final data = await isLoading.until((value) => !value);

// 创建派生计算值
final doubled = count.derived((value) => value * 2);
```

#### 高级工具

- **ConvertComputed**：类型转换计算值，支持双向转换
- **PersistSignal**：持久化信号，自动保存和恢复状态
- **batch**：批处理多个更新
- **untracked**：非依赖访问，读取值但不建立依赖
- **trackWithEffect**：手动控制依赖追踪
- **notifyAll**：手动触发所有订阅者更新

```dart
// 类型转换
final count = Signal(0);
final textCount = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

// 持久化
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () => SharedPreferences.getInstance()
    .then((prefs) => prefs.getString('theme') ?? 'light'),
  write: (value) => SharedPreferences.getInstance()
    .then((prefs) => prefs.setString('theme', value)),
);
```

#### Flutter 集成工具

- **JoltBuilder**：自动响应式 UI 更新
- **JoltSelector**：细粒度选择器更新
- **JoltWatchBuilder**：监听单个 Readable 值并重建
- **JoltValueNotifier**：与 Flutter ValueNotifier 系统集成
- **SetupWidget / SetupBuilder**：组合式 API（来自 `jolt_setup` 包）
- **FlutterEffect**：Flutter 特定的副作用，帧结束时执行

#### Hooks 支持

- **jolt_hooks**：基于 flutter_hooks 的 Hooks API
- **jolt_setup**：Setup Widget API，包含 Flutter 资源 Hooks（控制器、焦点节点等）

#### Surge 模式

- **Surge**：类似 BLoC Cubit 的状态容器
- **SurgeProvider / SurgeConsumer / SurgeBuilder**：Flutter Widget 集成
- **SurgeObserver**：状态变化监控

#### 开发工具

- **jolt_lint**：代码转换辅助和规则检查，支持 Signal 转换、Widget 包装等

### 简洁的 API

Jolt 只有三个核心概念：Signal（状态）、Computed（计算值）、Effect（副作用）。学习曲线平缓，易于上手，同时功能强大。所有高级功能都基于这三个核心概念构建，保持了 API 的一致性和可预测性。

### 类型安全

充分利用 Dart 的类型系统，提供完整的类型安全和编译时检查。编译时就能发现错误，减少运行时问题。所有响应式值都是强类型的，类型信息在依赖图中完整保留。

### 性能优化

内置批处理、缓存和懒计算机制，确保在复杂场景下也能保持高性能。Computed 值会自动缓存，只在依赖变化时重新计算。更新传播算法经过优化，避免不必要的计算。

### 热重载友好

状态在热重载时保持，开发体验流畅，无需重新初始化状态。这大大提高了开发效率，让你可以快速迭代和调试。

### 调试友好

清晰的依赖关系图，易于追踪问题。当某个值意外更新时，可以快速定位依赖链，理解数据流向。Jolt 还提供了调试工具，可以帮助你可视化依赖关系。

### 渐进式采用

可以逐步迁移现有代码，无需重写整个应用。Jolt 与 Flutter 原生 API 兼容，可以与 StatefulWidget、Provider 等现有方案共存。你可以从一个小模块开始，逐步扩展到整个应用。

### 跨平台支持

纯 Dart 核心，可以在 Dart CLI 和 Flutter 中使用。Flutter 深度集成，提供 `JoltBuilder`、`JoltWatchBuilder`、`SetupWidget`（来自 `jolt_setup` 包）等专门的 Widget，以及 `FlutterEffect` 等 Flutter 特定的功能。

### 适用于各种规模

无论是个人项目、创业公司还是大型企业应用，Jolt 都能胜任。其简洁的 API 适合快速开发，强大的功能也能支撑复杂场景。从快速原型到大型企业应用，Jolt 都能提供优秀的开发体验和性能。

## 快速开始

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建响应式状态
  final count = Signal(0);
  final doubled = Computed(() => count.value * 2);

  // 响应变化
  Effect(() {
    print('Count: ${count.value}, Doubled: ${doubled.value}');
  });

  count.value = 5; // 输出: "Count: 5, Doubled: 10"
}
```

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](https://github.com/vowdemon/jolt/blob/main/LICENSE) 文件了解详情。
