---
---

# SetupWidget

`SetupWidget` 是一个基于组合式 API 的 Flutter Widget 系统，类似于 Vue 的 Composition API。在 `setup` 函数中，你可以使用各种 Hooks 来管理状态和生命周期，`setup` 函数只会在 Widget 创建时执行一次。

> **⚠️ 重要说明**
>
> Setup Widget 及其 Hooks **不是** `flutter_hooks` 生态系统的一部分。如果你需要 `flutter_hooks` 兼容的 API，请使用 [`jolt_hooks`](https://pub.dev/packages/jolt_hooks) 包。
>
> **关键执行差异：**
> - **Setup Widget**：`setup` 函数在 Widget 创建时**只执行一次**（类似 Vue / SolidJS），然后重建由响应式系统驱动
> - **flutter_hooks**：Hook 函数在**每次构建时**都会执行（类似 React Hooks）
>
> 这是两种根本不同的模型。避免混合使用它们以防止混淆。

## 基本概念

`SetupWidget` 的核心思想是将 Widget 的构建逻辑分离为两部分：
1. **setup 函数**：在 Widget 创建时执行一次，用于初始化状态、创建 Hooks 等
2. **返回的构建函数**：用于构建实际的 Widget，可以访问 setup 中创建的状态

## SetupBuilder

`SetupBuilder` 是使用 Setup Widget 的最简单方式，适合快速原型、简单组件或内联响应式 Widget：

```dart
import 'package:jolt_flutter/setup.dart';

SetupBuilder(
  setup: (context) {
    final count = useSignal(0);
    
    return () => Column(
      children: [
        Text('Count: ${count.value}'),
        ElevatedButton(
          onPressed: () => count.value++,
          child: Text('Click'),
        ),
      ],
    );
  },
)
```

**何时使用 SetupBuilder：**
- 快速原型或实验响应式状态
- 创建简单的、自包含的组件
- 不需要自定义 Widget 属性
- 组件逻辑简单直接

**何时使用 SetupWidget 子类：**
- 需要自定义属性（title、count、callback 等）
- 构建可复用的组件，具有清晰的 API
- 组件复杂或将在多个地方使用
- 需要更好的 IDE 支持和属性类型检查

## SetupWidget vs SetupMixin

在深入了解每个 API 之前，先了解它们的区别：

| 特性 | SetupWidget | SetupMixin |
|------|-------------|------------|
| 基类 | 继承 `Widget` | 用于 `State<T>` 的 Mixin |
| 可变性 | 类似 `StatelessWidget`，不可变 | 可变的 State 类 |
| `this` 引用 | ❌ 不可用 | ✅ 完全访问 |
| 实例方法/字段 | ❌ 不应使用 | ✅ 可以自由定义 |
| Setup 签名 | `setup(context, props)` | `setup(context)` |
| 响应式 props 访问 | `props().property` | `props.property` |
| 非响应式 props 访问 | `props.peek.property` | `widget.property` |
| 生命周期方法 | 仅通过 hooks | Hooks + State 方法 |
| 使用场景 | 简单的不可变 Widget | 需要 State 能力 |

## SetupWidget

通过继承 `SetupWidget` 创建自定义 Widget：

```dart
class CounterWidget extends SetupWidget<CounterWidget> {
  final int initialValue;
  
  const CounterWidget({super.key, this.initialValue = 0});

  @override
  setup(context, props) {
    // 使用 props.peek 进行一次性初始化（非响应式）
    final count = useSignal(props.peek.initialValue);
    
    // 使用 props() 进行响应式访问
    final displayText = useComputed(() => 
      'Count: ${count.value}, Initial: ${props().initialValue}'
    );
    
    return () => Column(
      children: [
        Text(displayText.value),
        ElevatedButton(
          onPressed: () => count.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

**重要说明：**

- `setup` 接收两个参数：
  - `context`：标准的 Flutter `BuildContext`
  - `props`：`PropsReadonlyNode<YourWidgetType>`，提供对 Widget 实例的响应式访问

- **Props 访问方法：**
  - `props()` / `props.value` / `props.get()` - 响应式访问，建立依赖关系
  - `props.peek` - 非响应式访问，用于一次性初始化

- **类似 `StatelessWidget`**：Widget 类应该是不可变的，不应持有可变状态或定义实例方法

### 响应式属性访问

通过 `props()` 可以响应式地访问 Widget 属性：

```dart
class UserCard extends SetupWidget<UserCard> {
  final String name;
  final int age;

  const UserCard({super.key, required this.name, required this.age});

  @override
  setup(context, props) {
    // 响应式访问 props - 当 name 改变时会重建
    final displayName = useComputed(() => 'User: ${props().name}');

    return () => Text(displayName.value);
  }
}
```

## SetupMixin

在现有的 `StatefulWidget` 中添加组合式 API 支持：

```dart
class CounterWidget extends StatefulWidget {
  final int initialValue;
  
  const CounterWidget({super.key, this.initialValue = 0});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget>
    with SetupMixin<CounterWidget> {
  
  @override
  setup(context) {
    // 使用 widget.property 进行一次性初始化（非响应式）
    final count = useSignal(widget.initialValue);
    
    // 使用 props.property 进行响应式访问
    final displayText = useComputed(() => 
      'Count: ${count.value}, Initial: ${props.initialValue}'
    );
    
    return () => Column(
      children: [
        Text(displayText.value),
        ElevatedButton(
          onPressed: () => count.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

**关键区别：**

- `setup` 只接收一个参数：`context`（没有 `props` 参数）
- 提供 `props` getter 用于响应式访问 Widget 属性
- 兼容传统的 `State` 生命周期方法（`initState`、`dispose` 等）

**两种访问 Widget 属性的方式：**

```dart
setup(context) {
  // 1. widget.property - 非响应式（相当于 SetupWidget 中的 props.peek）
  //    用于一次性初始化，不会在变化时触发更新
  final initial = widget.initialValue;
  
  // 2. props.property - 响应式（相当于 SetupWidget 中的 props()）
  //    在 computed/effects 中使用以响应属性变化
  final reactive = useComputed(() => props.initialValue * 2);
  
  return () => Text('${reactive.value}');
}
```

**State 上下文和 `this` 引用：**

与 `SetupWidget`（类似 `StatelessWidget`）不同，`SetupMixin` 在 `State` 类中运行，让你可以完全访问 `this` 和可变状态：

```dart
class _CounterWidgetState extends State<CounterWidget>
    with SetupMixin<CounterWidget> {
  
  // ✅ 允许：在 State 中定义实例字段
  final _controller = TextEditingController();
  int _tapCount = 0;
  
  // ✅ 允许：定义实例方法
  void _handleTap() {
    setState(() => _tapCount++);
  }
  
  @override
  void initState() {
    super.initState();
    // 传统的 State 初始化
  }
  
  @override
  setup(context) {
    final count = useSignal(0);
    
    // ✅ 访问 'this' 和实例成员
    onMounted(() {
      _controller.text = 'Initial: ${widget.initialValue}';
    });
    
    return () => Column(
      children: [
        TextField(controller: _controller),
        Text('Taps: $_tapCount'),
        ElevatedButton(
          onPressed: _handleTap,
          child: Text('Count: ${count.value}'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

**关键点**：`SetupWidget` 类似 `StatelessWidget` - Widget 类本身应该是不可变的。`SetupMixin` 在 `State` 类中工作，你可以自由使用 `this`、定义方法、维护字段，并利用有状态 Widget 的全部能力。

## 选择正确的模式

> **💡 没有对错之分**
>
> 在 Jolt 中没有单一的"正确"方式来构建 Widget。SetupWidget、SetupMixin 和传统的 Flutter 模式（StatelessWidget、StatefulWidget）都是一等公民。每种模式在不同场景下都有优势——重要的是知道何时使用哪种，保持代码清晰和可维护。
>
> Setup API 本身是完全可选的。如果你的团队熟悉标准的 Flutter 模式并且它们工作良好，就没有必要改变。你也可以使用 Riverpod、flutter_hooks 或任何其他你喜欢的状态管理解决方案，甚至可以在同一个项目中混合使用它们。
>
> 当你需要基于组合的逻辑、响应式状态或 Vue/Solid 风格的模式时，Setup API 可以为你提供额外的能力——而不会强迫你重写现有代码。

**何时使用 SetupWidget：**
- 创建简单的、不可变的 Widget（类似 `StatelessWidget`）
- 想要纯组合式 API
- 不需要实例方法、可变字段或 `this` 引用
- 偏好更简洁、更简洁的代码
- 所有逻辑都可以通过响应式 hooks 表达

**何时使用 SetupMixin：**
- 需要实例方法、字段或访问 `this`
- 需要使用现有的 State mixins、特殊的 State 基类或 State 扩展
- 想要将组合式 API 与命令式逻辑结合
- 需要完全控制 `State` 生命周期方法（`initState`、`dispose`、`didUpdateWidget` 等）
- 处理复杂的 Widget 逻辑，可以从两种方法中受益

## 可用的 Hooks

Setup Widget 为所有 Jolt 响应式原语提供 hooks：

> **💡 关于使用 Hooks**
>
> 对于像 `Signal` 和 `Computed` 这样的响应式对象，如果它们会在 widget unmount 时被垃圾回收（例如，setup 函数中的局部变量），你可以直接创建它们而不使用 hooks。Hooks 的主要目的是确保在 widget unmount 或热重载期间正确清理和保持状态。
>
> ```dart
> setup(context, props) {
>   // 使用 hooks - 推荐，自动生命周期管理
>   final count = useSignal(0);
>   
>   // 不使用 hooks - 也可以，在 widget unmount 后会被 GC
>   final temp = Signal(0);
>   
>   return () => Text('Count: ${count.value}');
> }
> ```

### 响应式状态 Hooks

| Hook | 描述 |
|------|------|
| `useSignal(initial)` | 创建响应式 Signal |
| `useSignal.lazy<T>()` | 创建懒加载 Signal |
| `useSignal.list(initial)` | 创建响应式列表 |
| `useSignal.map(initial)` | 创建响应式 Map |
| `useSignal.set(initial)` | 创建响应式 Set |
| `useSignal.iterable(getter)` | 创建响应式 Iterable |
| `useSignal.async(source)` | 创建异步 Signal |
| `useSignal.persist(...)` | 创建持久化 Signal |

### 计算值 Hooks

| Hook | 描述 |
|------|------|
| `useComputed(fn)` | 创建计算值 |
| `useComputed.withPrevious(getter)` | 创建可访问前一个值的计算值 |
| `useComputed.writable(getter, setter)` | 创建可写计算值 |
| `useComputed.writableWithPrevious(getter, setter)` | 创建可访问前一个值的可写计算值 |
| `useComputed.convert(source, decode, encode)` | 创建类型转换计算值 |

### Effect Hooks

| Hook | 描述 |
|------|------|
| `useEffect(fn)` | 创建副作用 |
| `useEffect.lazy(fn)` | 创建立即执行的副作用 |
| `useWatcher(sourcesFn, fn)` | 创建观察者 |
| `useWatcher.immediately(...)` | 创建立即执行的观察者 |
| `useWatcher.once(...)` | 创建一次性观察者 |

### 生命周期 Hooks

| Hook | 描述 |
|------|------|
| `onMounted(fn)` | Widget 挂载时回调 |
| `onUnmounted(fn)` | Widget 卸载时回调 |
| `onDidUpdateWidget(fn)` | Widget 更新时回调 |
| `onDidChangeDependencies(fn)` | 依赖变化时回调 |
| `onActivated(fn)` | Widget 激活时回调 |
| `onDeactivated(fn)` | Widget 停用时回调 |

### 工具 Hooks

| Hook | 描述 |
|------|------|
| `useContext()` | 获取 BuildContext |
| `useSetupContext()` | 获取 JoltSetupContext |
| `useEffectScope()` | 创建 effect scope |
| `useJoltStream(value)` | 从响应式值创建流 |
| `useMemoized(creator, [disposer])` | 记忆化值，带可选的清理函数 |
| `useAutoDispose(creator)` | 自动清理资源 |
| `useHook(hook)` | 使用自定义 hook |

**使用示例：**

```dart
setup: (context) {
  // Signals
  final count = useSignal(0);
  final name = useSignal('Flutter');
  
  // Computed values
  final doubled = useComputed(() => count.value * 2);
  
  // Reactive collections
  final items = useSignal.list(['apple', 'banana']);
  final userMap = useSignal.map({'name': 'John', 'age': 30});
  
  // Effects
  useEffect(() {
    print('Count changed: ${count.value}');
  });
  
  // Lifecycle callbacks
  onMounted(() {
    print('Widget mounted');
  });
  
  onUnmounted(() {
    print('Widget unmounted');
  });
  
  return () => Text('Count: ${count.value}');
}
```

### Flutter 资源 Hooks

可以使用 `jolt_flutter_hooks` 包提供的 Hooks：

```dart
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';

setup(context, props) {
  final controller = useTextEditingController('Initial text');
  final focusNode = useFocusNode();
  final scrollController = useScrollController();

  return () => TextField(
    controller: controller,
    focusNode: focusNode,
  );
}
```

## 自动资源清理

所有 hooks 在 Widget 卸载时自动清理其资源，确保正确清理并防止内存泄漏：

```dart
setup: (context) {
  final timer = useSignal<Timer?>(null);
  
  onMounted(() {
    timer.value = Timer.periodic(Duration(seconds: 1), (_) {
      print('Tick');
    });
  });
  
  onUnmounted(() {
    timer.value?.cancel();
  });
  
  return () => Text('Timer running');
}
```

## 响应式更新

当在返回的构建函数中访问响应式值时，Widget 会自动在依赖变化时重建：

```dart
setup(context, props) {
  final count = useSignal(0);
  final doubled = useComputed(() => count.value * 2);

  return () => Column(
    children: [
      Text('Count: ${count.value}'),      // 当 count 改变时重建
      Text('Doubled: ${doubled.value}'),  // 当 doubled 改变时重建
    ],
  );
}
```

## 完整示例

### 计数器示例

```dart
class CounterWidget extends SetupWidget<CounterWidget> {
  const CounterWidget({super.key});

  @override
  setup(context, props) {
    final count = useSignal(0);

    onMounted(() {
      print('Counter widget mounted');
    });

    onUnmounted(() {
      print('Counter widget unmounted');
    });

    return () => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Count: ${count.value}'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => count.value--,
              child: Text('-'),
            ),
            SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => count.value++,
              child: Text('+'),
            ),
          ],
        ),
      ],
    );
  }
}
```

### 表单示例

```dart
class LoginForm extends SetupWidget<LoginForm> {
  const LoginForm({super.key});

  @override
  setup(context, props) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useSignal(false);

    final canSubmit = useComputed(() {
      return emailController.text.isNotEmpty &&
             passwordController.text.isNotEmpty &&
             !isLoading.value;
    });

    return () => Column(
      children: [
        TextField(
          controller: emailController,
          decoration: InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        ElevatedButton(
          onPressed: canSubmit.value ? () {
            isLoading.value = true;
            // 处理登录
          } : null,
          child: isLoading.value
              ? CircularProgressIndicator()
              : Text('Login'),
        ),
      ],
    );
  }
}
```

## 注意事项

1. **setup 只执行一次**：`setup` 函数只在 Widget 创建时执行一次，不会在每次重建时执行。

2. **Hook 顺序**：Hooks 的调用顺序必须保持一致，不能在条件语句中调用 Hooks。

3. **自动清理**：所有通过 Hooks 创建的资源会在 Widget 卸载时自动清理。

4. **响应式更新**：在返回的构建函数中访问响应式值时，Widget 会自动在依赖变化时重建。

5. **类型安全**：`SetupWidget` 提供完整的类型安全，编译时会进行类型检查。

6. **热重载支持**：`SetupWidget` 支持热重载，Hooks 的状态会在热重载时保持。
