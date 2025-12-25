---
---

# Signal

Signal 是响应式系统的基础。它可以随时修改，并且在响应式系统中可以订阅它的更新。当 Signal 的值改变时，所有订阅它的响应式节点（如 Computed、Effect）会自动更新。

```dart
import 'package:jolt/jolt.dart';

void main() {
  // 创建一个信号
  final count = Signal(0);

  // 订阅信号的变化
  Effect(() {
    print('Count: ${count.value}');
  });

  // 修改信号的值
  count.value = 5; // 输出: "Count: 5"
}
```

## 创建 Signal

### 标准创建

使用 `Signal` 构造函数创建信号，需要提供初始值：

```dart
final count = Signal(0);
final name = Signal('Alice');
final items = Signal<List<int>>([]);
```

### 延迟初始化

使用 `Signal.lazy()` 创建延迟初始化的信号，初始值为 `null`：

```dart
final data = Signal.lazy<String>();

// 稍后设置值
data.value = 'loaded data';
```

延迟初始化适用于需要在创建时无法确定初始值的场景，比如异步加载数据。

```dart
final userData = Signal.lazy<Map<String, dynamic>>();

// 异步加载数据
loadUserData().then((data) {
  userData.value = data;
});
```

### 只读视图

通过 `.readonly()` 扩展方法获取可写信号的只读视图。这只是编译时的限制，底层仍然是同一个信号：

```dart
final counter = Signal(0);
final readonlyCounter = counter.readonly();

print(readonlyCounter.value); // OK
// readonlyCounter.value = 1; // 编译错误

// 但通过原始信号仍然可以修改
counter.value = 1; // OK，readonlyCounter.value 也会变成 1
```

这在需要公开信号但限制修改权限时很有用：

```dart
class Counter {
  final _count = Signal(0);

  ReadonlySignal<int> get count => _count.readonly();

  void increment() => _count.value++;
}
```

**注意**：`.readonly()` 返回的只读视图本质上是同一个信号，只是编译时限制了写入。如果通过原始信号修改值，只读视图也会看到变化。

### 常量信号

使用 `ReadonlySignal` 构造函数创建常量只读信号。常量信号是一个实现了 `ReadonlyNode` 接口的简单实例，**没有响应式能力，无法写入，也不需要销毁**：

```dart
final constant = ReadonlySignal(42);
print(constant.value); // 总是 42
// constant.value = 100; // 编译错误，常量信号无法修改
```

常量信号的特点：

1. **没有响应式**：常量信号不会触发任何响应式更新，因为它只是一个简单的值包装器
2. **无法写入**：值在创建时就固定了，无法修改
3. **不需要销毁**：常量信号没有资源需要清理，`dispose()` 是空操作

```dart
final constant = ReadonlySignal(42);

// 不会建立响应式依赖
Effect(() {
  print(constant.value); // 只会执行一次，不会响应变化
});

// 常量信号的值永远不会改变
// constant.value = 100; // 编译错误

// 不需要调用 dispose()
// constant.dispose(); // 可以调用，但是空操作
```

常量信号适用于需要将普通值包装成 `ReadonlySignal` 类型以保持 API 一致性的场景：

```dart
class Config {
  // 使用常量信号提供固定配置
  static final apiVersion = ReadonlySignal('v1.0');
  static final maxRetries = ReadonlySignal(3);
}

// 在需要 ReadonlySignal 类型的地方使用
void processConfig(ReadonlySignal<String> version) {
  print('Version: ${version.value}');
}

processConfig(Config.apiVersion); // OK
```

**与 `.readonly()` 的区别**：

- `.readonly()`：返回原信号的只读视图，仍然是响应式的，可以通过原信号修改
- `ReadonlySignal()`：创建常量信号，没有响应式，值永远不变，无法修改

## 读取值

### `.value`

使用 `.value` 属性来读取值，**这会创建响应式依赖**。当信号的值改变时，任何访问它的响应式节点都会自动更新。

```dart
final count = Signal(0);

Effect(() {
  print(count.value); // 使用 .value
});

count.value = 10; // Effect 会更新
```

你也可以使用 `call()` 扩展方法，获得类似函数调用的语法：

```dart
final count = Signal(0);

Effect(() {
  print(count()); // 使用 call() 扩展，等价于 .value
});

count.value = 10; // Effect 会更新
```

### `.peek`

使用 `.peek` 属性可以在**不创建响应式依赖**的情况下读取值。这在只需要读取当前值而不想订阅更新时很有用。

```dart
final signalA = Signal(0);
final signalB = Signal(0);

Effect(() {
  final tracked = signalA.value;    // 建立依赖
  final untracked = signalB.peek;    // 不建立依赖
  
  print('Tracked: $tracked, Untracked: $untracked');
});

signalB.value = 10; // 无输出，因为 peek 没有建立依赖
signalA.value = 10; // 输出: "Tracked: 10, Untracked: 10"
```

常见使用场景：

```dart
// 在 Effect 中读取但不订阅
Effect(() {
  if (someCondition.value) {
    // 使用 peek 避免创建不必要的依赖
    print('Other value: ${otherSignal.peek}');
  }
});

// 在事件处理中读取当前值
button.onTap = () {
  final current = count.peek;
  print('Current count: $current');
};
```

## 写入值

### `.value`

直接给 `.value` 属性赋值来更新信号的值。这会更新值并通知所有订阅者。

```dart
final count = Signal(0);

count.value = 10;  // 更新值
count.value = 20;  // 再次更新值
```

### 更新函数

对于需要基于当前值进行更新的场景，可以使用 `.update()` 扩展方法：

```dart
final count = Signal(5);
count.update((value) => value + 1); // count.value 现在是 6
count.update((value) => value * 2); // count.value 现在是 12
```

这等价于：

```dart
count.value = count.peek + 1;
count.value = count.peek * 2;
```

## 手动通知

如果需要手动告诉依赖它的订阅者它更新了，可以使用 `notify()` 方法。即使值没有改变，也会通知所有订阅者。

```dart
final count = Signal(0);

Effect(() {
  print('Count updated: ${count.value}');
});

count.value = 10; // 首次输出: "Count updated: 10"

// 不改变值，但手动通知订阅者
count.notify(); // 再次输出: "Count updated: 10"
```

这在某些场景下很有用，比如对象的内部属性改变了，但对象引用本身没有改变：

```dart
final user = Signal(User(name: 'Alice', age: 30));

Effect(() {
  print('User: ${user.value.name}, Age: ${user.value.age}');
});

user.value.age = 31; // 对象引用没变，需要手动通知
user.notify(); // 触发 Effect 更新
```

## 生命周期管理

### dispose

当不再需要信号时，应该调用 `dispose()` 方法来释放资源：

```dart
final count = Signal(0);

// 使用信号...

// 不再需要时释放
count.dispose();
```

释放后的信号不能再使用：

```dart
count.dispose();
// count.value = 10; // 运行时错误：Signal is disposed
```

### isDisposed

检查信号是否已释放：

```dart
final count = Signal(0);
print(count.isDisposed); // false

count.dispose();
print(count.isDisposed); // true
```

## 类型系统

### Signal 接口

`Signal<T>` 是一个可写接口，实现了：
- `Writable<T>` - 可写接口
- `WritableNode<T>` - 可写节点接口
- `ReadonlyNode<T>` - 只读节点接口
- `ReadonlySignal<T>` - 只读信号接口

### ReadonlySignal 接口

`ReadonlySignal<T>` 是一个只读接口，实现了：
- `Readonly<T>` - 只读接口
- `ReadonlyNode<T>` - 只读节点接口

## 使用场景

### 状态管理

Signal 最常用于管理应用状态：

```dart
class TodoApp {
  final todos = Signal<List<Todo>>([]);
  final filter = Signal<TodoFilter>(TodoFilter.all);

  void addTodo(String text) {
    todos.value = [...todos.value, Todo(text: text)];
  }

  void toggleTodo(int id) {
    todos.value = todos.value.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(completed: !todo.completed);
      }
      return todo;
    }).toList();
  }
}
```

### 表单状态

Signal 非常适合管理表单状态：

```dart
class LoginForm {
  final email = Signal('');
  final password = Signal('');
  final isLoading = Signal(false);

  Future<void> submit() async {
    isLoading.value = true;
    try {
      await login(email.value, password.value);
    } finally {
      isLoading.value = false;
    }
  }
}
```

### 配置和设置

使用 Signal 管理配置：

```dart
class AppConfig {
  final theme = Signal('light');
  final language = Signal('zh');
  final notifications = Signal(true);
}
```

## 注意事项

1. **响应式依赖**：在响应式上下文（如 `Computed`、`Effect`）中使用 `.value` 或 `call()` 会建立依赖关系。使用 `.peek` 不会建立依赖。

2. **生命周期**：不再使用的信号应该调用 `dispose()` 释放资源，避免内存泄漏。

3. **只读视图**：需要公开信号但限制修改时，使用 `.readonly()` 获取只读视图。

4. **对象内部变化**：如果修改对象的内部属性，需要手动调用 `notify()` 来通知订阅者。

5. **延迟初始化**：使用 `Signal.lazy()` 创建延迟初始化的信号时，初始值为 `null`，需要确保类型允许 `null` 或在使用前设置值。

## 相关 API

- [Computed](./computed.md) - 基于 Signal 的计算属性
- [Effect](./effect.md) - 响应式副作用
- [扩展方法](./extensions.md) - Signal 的扩展方法
- [ReadonlyNode](../advanced/extending-jolt.md#readonlynode-基础) - 了解 Signal 的底层接口
