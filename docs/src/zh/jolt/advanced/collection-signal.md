---
---

# 合集信号

合集信号在响应式系统中提供响应式的集合类型，包括 `ListSignal`、`SetSignal`、`MapSignal` 和 `IterableSignal`。所有修改操作都会自动触发响应式更新，适用于需要响应式集合操作的场景，如动态列表、标签集合、配置映射等。

```dart
import 'package:jolt/jolt.dart';

void main() {
  final items = ListSignal(['a', 'b', 'c']);
  
  Effect(() {
    print('列表: ${items.value}');
  });
  
  items.add('d'); // 输出: "列表: [a, b, c, d]"
}
```

## 创建

### ListSignal

```dart
final items = ListSignal(['a', 'b', 'c']);
```

使用扩展方法：

```dart
final normalList = [1, 2, 3];
final reactiveList = normalList.toListSignal();
```

### SetSignal

```dart
final tags = SetSignal({'dart', 'flutter'});
```

使用扩展方法：

```dart
final normalSet = {'dart', 'flutter'};
final reactiveSet = normalSet.toSetSignal();
```

### MapSignal

```dart
final user = MapSignal({'name': 'Alice', 'age': 30});
```

使用扩展方法：

```dart
final normalMap = {'key': 'value'};
final reactiveMap = normalMap.toMapSignal();
```

### IterableSignal

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final evenNumbers = IterableSignal(() => 
  numbers.value.where((n) => n.isEven)
);
```

## 基本用法

### ListSignal

所有列表操作都会自动触发更新：

```dart
final items = ListSignal([1, 2, 3]);

Effect(() {
  print('列表长度: ${items.length}');
});

items.add(4); // 触发更新
items.insert(0, 0); // 触发更新
items.removeAt(2); // 触发更新
items.clear(); // 触发更新
```

直接替换整个列表：

```dart
final items = ListSignal([1, 2, 3]);

items.value = [4, 5, 6]; // 替换整个列表，触发更新
```

### SetSignal

所有集合操作都会自动触发更新：

```dart
final tags = SetSignal({'a', 'b'});

Effect(() {
  print('标签数量: ${tags.length}');
});

tags.add('c'); // 触发更新
tags.remove('a'); // 触发更新
tags.addAll({'d', 'e'}); // 触发更新
tags.clear(); // 触发更新
```

### MapSignal

所有映射操作都会自动触发更新：

```dart
final user = MapSignal({'name': 'Alice'});

Effect(() {
  print('用户信息: ${user.value}');
});

user['age'] = 30; // 触发更新
user.addAll({'city': 'NYC', 'country': 'USA'}); // 触发更新
user.remove('city'); // 触发更新
user.clear(); // 触发更新
```

### IterableSignal

可以使用所有迭代器操作：

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final doubled = IterableSignal(() => 
  numbers.value.map((n) => n * 2)
);

Effect(() {
  print('翻倍: ${doubled.toList()}');
});
```
