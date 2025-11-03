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

## Jolt 系列

### [jolt](https://pub.dev/packages/jolt)

核心库，提供 Signal、Computed、Effect、响应式集合、异步状态和实用工具。可在纯 Dart 或 Flutter 项目中使用。

### [jolt_flutter](https://pub.dev/packages/jolt_flutter)

- **信号 (Signal)**: 可变的响应式状态容器
- **计算值 (Computed)**: 基于其他信号自动计算的派生值
- **副作用 (Effect)**: 响应式副作用函数
- **响应式集合**: ListSignal、MapSignal、SetSignal、IterableSignal
- **异步状态**: AsyncSignal、FutureSignal、StreamSignal
- **实用工具**: 类型转换、持久化、批处理等

### [jolt_hooks](https://pub.dev/packages/jolt_hooks)

基于 [flutter_hooks](https://pub.dev/packages/flutter_hooks)，提供 Hooks API：useSignal、useComputed、useJoltEffect、useJoltWidget。

### [jolt_surge](https://pub.dev/packages/jolt_surge)

受 BLoC 的 Cubit 模式启发，提供 Surge、SurgeProvider、SurgeConsumer、SurgeSelector，适合组件化状态管理。

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

## 文档导航

### 快速开始
- [快速开始](./getting-started.md) - 安装和基本使用

### 核心概念
- [Signal](./core/signal.md) - 响应式状态的基础
- [Computed](./core/computed.md) - 派生值
- [Effect](./core/effect.md) - 副作用处理
- [Watcher](./core/watcher.md) - 值变化监听
- [EffectScope](./core/effect-scope.md) - 副作用生命周期管理
- [Batch](./core/batch.md) - 批量更新
- [Untracked](./core/untracked.md) - 非跟踪访问

### 高级
- [异步信号](./advanced/async-signal.md) - AsyncSignal、FutureSignal、StreamSignal
- [合集信号](./advanced/collection-signal.md) - ListSignal、SetSignal、MapSignal、IterableSignal
- [ConvertComputed](./advanced/convert-computed.md) - 类型转换信号
- [PersistSignal](./advanced/persist-signal.md) - 持久化信号
- [Stream](./advanced/stream.md) - 信号和流之间的转换
- [自定义系统](./advanced/custom-system.md) - 自定义实现

### Flutter
- [Widgets](./flutter/widgets.md) - JoltProvider、JoltBuilder、JoltSelector
- [Hooks](./flutter/hooks.md) - flutter_hooks 集成
- [Surge](./flutter/surge.md) - 类似Cubit的状态容器

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](https://github.com/vowdemon/jolt/blob/main/LICENSE) 文件了解详情。
