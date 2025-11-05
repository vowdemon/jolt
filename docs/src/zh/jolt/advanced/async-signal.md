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
