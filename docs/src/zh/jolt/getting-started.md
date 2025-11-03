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

如果使用 Hooks，可以安装 `jolt_hooks`：

```bash
# 可选：Hooks 集成
flutter pub add jolt_hooks
```

如果喜欢 Cubit 模式，可以安装 `jolt_surge`：

```bash
# 可选：Surge 模式（类似 BLoC 的 Cubit）
flutter pub add jolt_surge
```

## 下一步

- 查看 [信号](./core/signal.md) 了解信号的基础用法
- 阅读 [计算属性](./core/computed.md) 学习派生值
- 探索 [副作用](./core/effect.md) 处理副作用
