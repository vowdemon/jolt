---
---

# Jolt Lint

`jolt_lint` 是一个专为 Jolt 响应式状态管理生态系统设计的 lint 工具，提供代码转换辅助和规则检查功能。

## 安装

在 `analysis_options.yaml` 中添加：

```yaml
plugins:
  jolt_lint: ^3.0.0
```

## 要求

⚠️ **版本要求**：此 lint 工具仅支持 Jolt 2.0 及以上版本。

## 代码转换辅助

### 转换为 Signal

快速将普通变量转换为 `Signal`。此功能会：

- 将变量类型包装为 `Signal<T>`
- 将初始化表达式包装为 `Signal(...)`
- 自动在变量作用域内的所有引用处添加 `.value` 访问

**使用场景**：当你想要将普通变量转换为响应式信号时。

**示例**：
```dart
// 转换前
int count = 0;

// 转换后
Signal<int> count = Signal(0);
// 所有对 count 的引用都会自动改为 count.value
```

### 从 Signal 转换

将 `Signal` 转换回普通变量。此功能会：

- 将 `Signal<T>` 类型解包为 `T`
- 将 `Signal(...)` 初始化表达式解包为原始值
- 自动移除变量作用域内所有 `.value` 访问

**使用场景**：当你发现某个变量不需要响应式特性，想要简化代码时。

**示例**：
```dart
// 转换前
Signal<int> count = Signal(0);
print(count.value);

// 转换后
int count = 0;
print(count);
```

## Widget 包装辅助

多个快速辅助功能用于包装 Widget，帮助你快速集成 Jolt 的响应式组件。

### 使用 JoltBuilder 包装

使用 `JoltBuilder` 包装 Widget，自动响应所有访问的信号变化。

**使用场景**：当你需要 Widget 响应信号变化时。

**示例**：
```dart
// 转换前
Text('Hello')

// 转换后
JoltBuilder(builder: (context) => Text('Hello'))
```

### 使用 JoltProvider 包装

> **⚠️ 已废弃**：`JoltProvider` 已废弃。对于依赖注入，请使用 Flutter 的内置解决方案，如 `Provider`、`Riverpod` 或其他 DI 包。

使用 `JoltProvider` 包装 Widget，在 Widget 树中提供响应式状态。

**使用场景**：当你需要在 Widget 树中提供共享的响应式状态时。

**示例**：
```dart
// 转换前
MyWidget()

// 转换后（已废弃）
JoltProvider(
  create: (context) => null,  // 填入实际的创建逻辑
  builder: (context, provider) => MyWidget()
)

// 推荐：使用 Provider 或 Riverpod 代替
Provider(
  create: (_) => MyStore(),
  child: MyWidget(),
)
```

### 使用 JoltSelector 包装

使用 `JoltSelector` 包装 Widget，实现细粒度的状态选择更新。

**使用场景**：当你只想响应特定的状态变化，而不是所有信号时。

**示例**：
```dart
// 转换前
Text(counter.value.toString())

// 转换后
JoltSelector(
  selector: (prev) => null,  // 填入选择器逻辑
  builder: (context, state) => Text(counter.value.toString())
)
```

### 使用 SetupBuilder 包装

使用 `SetupBuilder` 包装 Widget，使用 Jolt 的 Setup 模式。

**使用场景**：当你想要使用 Setup 模式组织 Widget 的响应式逻辑时。

**示例**：
```dart
// 转换前
MyWidget()

// 转换后
SetupBuilder(setup: (context) { return ()=> MyWidget()})
```

## Lint 规则

### no_invalid_hook_call

限制 Hook 只能出现在合法的 Hook 上下文中。

**规则描述**：

此规则确保 `useXxx()` 调用和生命周期 Hook 只出现在 Jolt 能稳定维护
Hook 顺序的位置：

- ✅ `setup` 方法体内
- ✅ 使用 `@DefineHook` 标注的函数内
- ✅ 作为其他 Hook 调用的参数
- ❌ `setup` 返回的函数内部
- ❌ `setup` 的直接返回表达式中
- ❌ 普通方法、普通回调或顶层函数中

**示例**：
```dart
class MyWidget extends SetupWidget {
  @override
  setup(BuildContext context, MyWidget props) {
    final count = useSignal(0); // 合法

    return () {
      // useSignal(1); // 非法：位于返回的 builder 内部
      return Text(count.value.toString());
    };
  }
}
```

### no_setup_this

禁止在 `SetupWidget` 的 `setup` 方法中直接或间接访问实例成员（通过 `this` 或隐式访问）。

**规则描述**：

此规则仅适用于 `SetupWidget`，确保在 `setup` 方法中只能通过 `props` 参数访问实例成员，保持 Setup 模式的纯度和可测试性。

⚠️ **注意**：此规则不适用于 `SetupMixin`。`SetupMixin` 在 `State` 类中使用，可以正常访问 `this` 和实例成员。

**检查项**：
- ❌ 显式使用 `this.field` 或 `this.method()`
- ❌ 隐式访问实例成员（例如，直接使用 `field` 或 `method()`）
- ❌ 将 `this` 赋值给变量
- ❌ 将 `this` 赋值给 setter

**正确示例**：
```dart
class MyWidget extends SetupWidget {
  int count = 0;
  
  @override
  Widget setup(BuildContext context, MyWidget props) {
    // ✅ 通过 props() 访问实例成员
    return Text(props().count.toString());
  }
}
```

**错误示例**：
```dart
class MyWidget extends SetupWidget {
  int count = 0;
  
  @override
  Widget setup(BuildContext context, MyWidget props) {
    // ❌ 不能直接访问 this.count
    return Text(this.count.toString());
    
    // ❌ 不能隐式访问 count
    return Text(count.toString());
  }
}
```

**SetupMixin 不受此规则限制**：

`SetupMixin` 在 `State` 类中使用，可以正常访问 `this` 和实例成员：

```dart
class _MyWidgetState extends State<MyWidget> with SetupMixin<MyWidget> {
  int count = 0;
  
  @override
  setup(BuildContext context) {
    // ✅ SetupMixin 中可以正常使用 this
    return Text(this.count.toString());
    
    // ✅ 也可以隐式访问
    return Text(count.toString());
  }
}
```

**快速修复支持**：

此规则提供自动修复功能，可以快速将错误的代码转换为正确形式：

- 🔧 **单个修复**：将光标放在有问题的代码上，按 `Ctrl+.`（或 `Cmd+.`）并选择 "Replace this with props()" 或 "Add props() to the member" 来自动修复
- 🔧 **批量修复**：修复菜单还提供 "Fix all setup this issues" 选项，可以一次性修复文件中的所有相关问题

**修复示例**：
```dart
// 修复前
Widget setup(BuildContext context, MyWidget props) {
  return Text(this.count.toString());
  // 或
  return Text(count.toString());
}

// 修复后
Widget setup(BuildContext context, MyWidget props) {
  return Text(props().count.toString());
}
```

## 使用方法

配置完成后，你的 IDE（如 VS Code、Android Studio）会自动提供：

- **代码辅助**：将光标放在变量或 Widget 上，按 `Ctrl+.`（或 `Cmd+.`）查看可用的转换选项
- **实时检查**：违反 `no_setup_this`、`no_invalid_hook_call` 等规则的代码会显示诊断信息，并在支持时提供修复建议

## 注意事项

1. **IDE 支持**：代码辅助功能需要 IDE 支持 Dart 分析服务器插件
2. **作用域限制**：代码转换功能会在变量的作用域内自动更新所有引用
3. **类型安全**：所有转换都保持类型安全，不会破坏代码的类型检查
4. **批量修复**：`no_setup_this` 规则支持批量修复，可以一次性修复文件中的所有相关问题
