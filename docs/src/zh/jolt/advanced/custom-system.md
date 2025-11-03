---
---

# 自定义系统


当 Jolt 预设的 `Signal`、`Computed` 等响应式原语无法满足特殊需求时，可以通过 **继承这些基础类** 来实现自定义行为。

在大多数情况下，**组合现有原语** 就能构建出所需功能。例如，`ConvertComputed` 与 `PersistSignal` 分别通过继承 `WritableComputed` 与 `Signal` 来实现扩展。

对于更底层的定制场景，Jolt 还提供了 **开放的响应式原语扩展能力**，允许开发者创建 **完全自定义的响应式节点**，以满足复杂或特定的响应式逻辑需求。


## 防抖信号

继承 `Signal` 来实现一个防抖信号，在值改变后等待一段时间才通知订阅者，如果在这段时间内又有新的值更新，则重置计时器：

```dart
import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

class DebouncedSignal<T> extends Signal<T> {
  final Duration delay;
  Timer? _timer;

  DebouncedSignal(
    super.value, {
    required this.delay,
    super.onDebug,
  });

  @override
  void set(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.set(value);
    });
  }

  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}

// 使用
void main(){
  test('debounce signal', () async {
    final searchQuery = DebouncedSignal('', delay: Duration(milliseconds: 300));

    final results = <String>[];
    final effect = Effect(() {
      final query = searchQuery.value;
      if (query.isNotEmpty) {
        results.add('Results for: $query');
      }
    });

    searchQuery.value = 'j';
    await Future.delayed(Duration(milliseconds: 10));
    searchQuery.value = 'jo';
    await Future.delayed(Duration(milliseconds: 10));
    searchQuery.value = 'jol';
    await Future.delayed(Duration(milliseconds: 10));
    searchQuery.value = 'jolt';

    expect(results, isEmpty);

    await Future.delayed(Duration(milliseconds: 350));

    expect(results, equals(['Results for: jolt']));
    expect(searchQuery.value, equals('jolt'));
  });
}
```

