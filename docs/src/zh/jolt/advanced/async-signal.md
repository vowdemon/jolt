---
---

# 异步信号

> **注意**：异步信号是实验功能，API 可能会发生变化。

异步信号在响应式系统中用于处理异步操作，包括 Future 和 Stream。Jolt 提供了 `AsyncSignal`、`FutureSignal` 和 `StreamSignal` 来管理异步操作的状态（加载中、成功、错误等），并在状态变化时自动通知订阅者。适用于数据加载、实时数据流等场景。

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

## 创建

### AsyncSignal

从 Future 创建：

```dart
Future<String> fetchUser() async {
  await Future.delayed(Duration(seconds: 1));
  return 'John Doe';
}

final userSignal = AsyncSignal.fromFuture(fetchUser());
```

从 Stream 创建：

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final dataSignal = AsyncSignal.fromStream(stream);
```

### FutureSignal

`FutureSignal` 是专门用于处理 Future 的信号，是 `AsyncSignal` 的便捷封装：

```dart
final future = Future.delayed(Duration(seconds: 1), () => 'Hello');
final futureSignal = FutureSignal(future);
```

使用扩展方法：

```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Data';
}

final signal = fetchData().toAsyncSignal();
```

### StreamSignal

`StreamSignal` 是专门用于处理 Stream 的信号，是 `AsyncSignal` 的便捷封装：

```dart
final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
final streamSignal = StreamSignal(stream);
```

使用扩展方法：

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();
```

## 基本用法

### 状态判断

`AsyncSignal` 的值是 `AsyncState`，有四种状态：

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
  } else if (state.isRefreshing) {
    print('刷新中，数据: ${state.data}');
  }
});
```

### 数据访问

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

Effect(() {
  final state = signal.value;
  
  // 获取数据（可能为 null）
  final data = state.data;
  
  // 获取错误（可能为 null）
  final error = state.error;
  final stackTrace = state.stackTrace;
});
```

也可以直接访问数据：

```dart
final signal = AsyncSignal.fromFuture(fetchUser());

// 直接访问数据（可能为 null）
final user = signal.data;
```
