---
---

# 异步信号

异步信号在响应式系统中用于处理异步操作，包括 Future 和 Stream。Jolt 提供了 `AsyncSignal` 来管理异步操作的状态（加载中、成功、错误等），并在状态变化时自动通知订阅者。适用于数据加载、实时数据流等场景。

```dart
import 'package:jolt/jolt.dart';

void main() {
  final userSignal = AsyncSignal.fromFuture(fetchUser());
  
  Effect(() {
    final state = userSignal.value;
    if (state.isLoading) {
      print('加载中...');
    } else if (state.isSuccess) {
      print('用户: ${state.data}');
    } else if (state.isError) {
      print('错误: ${state.error}');
    }
  });
}
```

## AsyncState

`AsyncState` 是一个密封类，表示异步操作的不同状态：

- **`AsyncLoading<T>`**: 加载中状态
- **`AsyncSuccess<T>`**: 成功状态，包含数据
- **`AsyncError<T>`**: 错误状态，包含错误信息

### 状态判断

```dart
final state = asyncSignal.value;

if (state.isLoading) {
  print('加载中...');
} else if (state.isSuccess) {
  print('成功: ${state.data}');
} else if (state.isError) {
  print('错误: ${state.error}');
}
```

### 数据访问

```dart
final state = asyncSignal.value;

// 获取数据（可能为 null）
final data = state.data;

// 获取错误（可能为 null）
final error = state.error;
final stackTrace = state.stackTrace;
```

### map 方法

使用 `map` 方法可以根据状态返回不同的值：

```dart
final message = state.map(
  loading: () => '加载中...',
  success: (data) => '成功: $data',
  error: (error, stackTrace) => '错误: $error',
);
```

## 创建 AsyncSignal

### 从 Future 创建

使用 `AsyncSignal.fromFuture` 从 Future 创建：

```dart
Future<String> fetchUser() async {
  await Future.delayed(Duration(seconds: 1));
  return 'John Doe';
}

final userSignal = AsyncSignal.fromFuture(fetchUser());
```

### 从 Stream 创建

使用 `AsyncSignal.fromStream` 从 Stream 创建：

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final dataSignal = AsyncSignal.fromStream(stream);
```

### 使用扩展方法创建

Jolt 提供了扩展方法，可以更方便地创建异步信号：

从 Future 创建：

```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Data';
}

final signal = fetchData().toAsyncSignal();
```

从 Stream 创建：

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();
```

### 使用 AsyncSource 创建

可以使用自定义的 `AsyncSource` 创建：

```dart
final signal = AsyncSignal(
  source: FutureSource(future),
  initialValue: AsyncLoading(),
);
```

## 基本用法

### 状态判断

`AsyncSignal` 的值是 `AsyncState`，有三种状态：

```dart
final asyncSignal = AsyncSignal.fromFuture(fetchUser());

Effect(() {
  final state = asyncSignal.value;
  
  if (state.isLoading) {
    print('加载中...');
  } else if (state.isSuccess) {
    print('成功: ${state.data}');
  } else if (state.isError) {
    print('错误: ${state.error}');
  }
});
```

### 直接访问数据

`AsyncSignal` 提供了 `data` 属性，可以直接访问数据（可能为 null）：

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

// 直接访问数据（可能为 null）
final user = signal.data;
```

### 重新获取数据

要重新获取数据，可以创建新的 `AsyncSignal` 或使用新的 `AsyncSource`：

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

// 方式 1：创建新的 AsyncSignal
final newSignal = AsyncSignal.fromFuture(fetchUser());

// 方式 2：使用新的 AsyncSource
final newSource = FutureSource(fetchUser());
final reloadedSignal = AsyncSignal(source: newSource);
```

## AsyncSource

`AsyncSource` 是一个抽象接口，用于定义异步数据源。你可以实现自定义的 `AsyncSource` 来创建特殊的异步行为。

### 实现自定义 AsyncSource

```dart
class MyAsyncSource<T> implements AsyncSource<T> {
  @override
  FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) async {
    emit(AsyncLoading());
    try {
      final data = await fetchData();
      emit(AsyncSuccess(data));
    } catch (e, st) {
      emit(AsyncError(e, st));
    }
  }

  @override
  FutureOr<void> dispose() {
    // 清理资源
  }
}

// 使用自定义源
final signal = AsyncSignal(source: MyAsyncSource());
```

### FutureSource

`FutureSource` 是 Future 的包装，自动管理 Future 的状态转换：

```dart
final future = Future.delayed(Duration(seconds: 1), () => 'Hello');
final source = FutureSource(future);
final signal = AsyncSignal(source: source);
```

### StreamSource

`StreamSource` 是 Stream 的包装，自动管理 Stream 的状态转换：

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final source = StreamSource(stream);
final signal = AsyncSignal(source: source);
```

## 使用场景

### 数据加载

`AsyncSignal` 非常适合用于数据加载场景：

```dart
class UserService {
  Future<User> fetchUser(int id) async {
    await Future.delayed(Duration(seconds: 1));
    return User(id: id, name: 'User $id');
  }
}

final userService = UserService();
final userSignal = AsyncSignal.fromFuture(
  userService.fetchUser(1)
);

Effect(() {
  final state = userSignal.value;
  if (state.isLoading) {
    showLoadingIndicator();
  } else if (state.isSuccess) {
    displayUser(state.data!);
  } else if (state.isError) {
    showError(state.error);
  }
});
```

### 实时数据流

`AsyncSignal` 可以用于处理实时数据流：

```dart
final chatMessages = AsyncSignal.fromStream(
  chatService.messageStream()
);

Effect(() {
  final state = chatMessages.value;
  if (state.isSuccess) {
    displayMessage(state.data!);
  }
});
```

### 错误处理

`AsyncSignal` 提供了完整的错误处理能力：

```dart
final dataSignal = AsyncSignal.fromFuture(fetchData());

Effect(() {
  final state = dataSignal.value;
  if (state.isError) {
    print('错误: ${state.error}');
    print('堆栈跟踪: ${state.stackTrace}');
    // 处理错误
    handleError(state.error, state.stackTrace);
  }
});
```

### 重新加载

使用 `fetch` 方法可以实现重新加载功能：

```dart
final dataSignal = AsyncSignal.fromFuture(fetchData());

void reload() {
  dataSignal.fetch(FutureSource(fetchData()));
}

// 用户点击刷新按钮
refreshButton.onTap = reload;
```

## 生命周期管理

`AsyncSignal` 实现了 `Signal` 接口，具有生命周期管理能力：

- **`dispose()`**: 释放资源，包括取消正在进行的异步操作
- **`isDisposed`**: 检查是否已释放

```dart
final signal = AsyncSignal.fromFuture(fetchData());

// 使用信号...

// 不再需要时释放
signal.dispose();
```

## 注意事项

1. **状态转换**：`AsyncSignal` 会自动管理状态转换，从 `AsyncLoading` 到 `AsyncSuccess` 或 `AsyncError`。

2. **数据访问**：`data` 属性在 `AsyncLoading` 和 `AsyncError` 状态下返回 `null`，只有在 `AsyncSuccess` 状态下才返回实际数据。

3. **错误处理**：确保正确处理错误状态，包括错误信息和堆栈跟踪。

4. **资源清理**：`AsyncSignal` 会自动清理 `AsyncSource` 的资源，但如果你实现了自定义的 `AsyncSource`，需要确保正确实现 `dispose()` 方法。

5. **Stream 订阅**：对于 `StreamSource`，`AsyncSignal` 会自动管理 Stream 订阅的生命周期。

6. **重新获取**：使用 `fetch` 方法重新获取数据时，之前的异步操作会被自动取消。

## 相关 API

- [Signal](../core/signal.md) - 了解基础信号的使用
- [Effect](../core/effect.md) - 响应式副作用
- [扩展方法](../core/extensions.md) - 异步信号的扩展方法
