---
---

# 快速开始

本指南将帮助你快速开始使用 Jolt 响应式状态管理库。

## 安装

使用 `pub add` 命令安装 Jolt：

```bash
# 安装核心包
dart pub add jolt
```

在 Flutter 项目中，推荐安装 `jolt_flutter`：

```bash
# 推荐：Flutter Widget 集成
flutter pub add jolt_flutter
```

如果需要组合式 API 和 Setup Widget 模式，可以安装 `jolt_setup`：

```bash
# 组合式 API，自动资源清理
flutter pub add jolt_setup
```

如果使用 Flutter Hooks，可以安装 `jolt_hooks`：

```bash
# 可选：flutter_hooks 集成
flutter pub add jolt_hooks
```

如果喜欢 Cubit 模式，可以安装 `jolt_surge`：

```bash
# 可选：Surge 模式（类似 BLoC 的 Cubit）
flutter pub add jolt_surge
```

## 下一步

### 核心概念

- 查看 [信号](./core/signal.md) 了解信号的基础用法
- 阅读 [计算属性](./core/computed.md) 学习派生值
- 探索 [副作用](./core/effect.md) 处理副作用
- 了解 [观察者](./core/watcher.md) 进行精细控制
- 学习 [副作用作用域](./core/effect-scope.md) 管理副作用生命周期
- 使用 [批处理](./core/batch.md) 优化批量更新性能
- 控制 [依赖追踪](./core/track.md) 精细管理响应式依赖
- 查看 [扩展方法](./core/extensions.md) 使用便捷的转换方法

### Flutter 集成

- 使用 [Flutter Widgets](./flutter/widgets.md) 构建响应式 UI
- 了解 [ValueNotifier 集成](./flutter/value-notifier.md) 与 Flutter 系统集成
- 使用 [FlutterEffect](./flutter/flutter-effect.md) 处理 UI 副作用
- 探索 [SetupWidget](./flutter/setup-widget.md) 使用组合式 API

### Hooks

- 使用 [Jolt Hooks](./flutter/flutter-hooks.md) 在 HookWidget 中使用响应式原语
- 在 [SetupWidget](./flutter/setup-widget.md) 中使用 Flutter 资源 Hooks

### Surge 模式

- 了解 [Surge](./surge/surge.md) 状态管理模式
- 使用 [Surge Widgets](./surge/widgets.md) 在 Flutter 中使用 Surge
- 配置 [SurgeObserver](./surge/observer.md) 监控状态变化

### 高级特性

- 处理 [异步信号](./advanced/async-signal.md) 管理异步操作
- 使用 [集合信号](./advanced/collection-signal.md) 处理响应式集合
- 了解 [转换计算值](./advanced/convert-computed.md) 进行类型转换
- 使用 [持久化信号](./advanced/persist-signal.md) 保存和恢复状态
- 集成 [流转换](./advanced/stream.md) 与流式 API 集成
- 学习 [扩展 Jolt](./advanced/extending-jolt.md) 创建自定义响应式原语和工具

### 开发工具

- 使用 [Jolt Lint](./lint/lint.md) 获得代码转换辅助和规则检查
