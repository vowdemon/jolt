---
---

# Stream

Stream 在响应式系统中提供了信号和流之间的双向转换功能。可以将信号转换为流以便与其他流式 API 集成，也可以将流转换为信号以便在响应式系统中使用。适用于与 StreamBuilder、流式数据处理、事件流等场景的集成。

## 信号转流

任何响应式值都可以通过 `.stream` 属性转换为流：

```dart
final count = Signal(0);
final stream = count.stream;

// 监听流
stream.listen((value) {
  print('值改变: $value');
});

count.value = 1; // 输出: "值改变: 1"
count.value = 2; // 输出: "值改变: 2"
```

使用 `listen` 方法：

```dart
final count = Signal(0);

final subscription = count.listen(
  (value) => print('值: $value'),
  immediately: true, // 立即执行一次
);

count.value = 1; // 输出: "值: 1"

subscription.cancel(); // 取消监听
```

在 Flutter 中使用 StreamBuilder：

```dart
final count = Signal(0);

StreamBuilder<int>(
  stream: count.stream,
  builder: (context, snapshot) {
    return Text('值: ${snapshot.data ?? 0}');
  },
);
```

## 流转信号

使用 `AsyncSignal.fromStream` 可以将流转换为信号：

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = AsyncSignal.fromStream(getDataStream());

Effect(() {
  final state = signal.value;
  if (state.isSuccess) {
    print('最新值: ${state.data}');
  }
});
```

使用扩展方法：

```dart
Stream<int> getDataStream() {
  return Stream.periodic(Duration(seconds: 1), (i) => i);
}

final signal = getDataStream().toStreamSignal();

Effect(() {
  final state = signal.value;
  if (state.isSuccess) {
    print('最新值: ${state.data}');
  }
});
```
