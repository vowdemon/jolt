---
---

# 转换信号

转换信号在响应式系统中用于在不同类型的信号之间进行双向转换。它本质上是一个 WritableComputed，用于双向值转换或类型转换。它提供了一个可写的计算值，可以对数据进行编码和解码转换，适用于表单输入、API 数据转换等场景，其中需要在不同的数据表示之间进行转换。

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';

void main() {
  final count = Signal(0);
  
  // 创建将 int 转换为 String 的信号
  final textCount = ConvertComputed(
    count,
    decode: (int value) => value.toString(),
    encode: (String value) => int.parse(value),
  );
  
  // 通过 textCount 设置值，会自动更新 count
  textCount.value = "42";
  print(count.value); // 输出: 42
  
  // 通过 count 设置值，会自动更新 textCount
  count.value = 100;
  print(textCount.value); // 输出: "100"
}
```

## 创建

使用 `ConvertComputed` 构造函数创建转换计算值：

```dart
final source = Signal(0);

final converted = ConvertComputed(
  source,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);
```

参数说明：
- `source`: 源信号
- `decode`: 从源类型转换到目标类型的函数
- `encode`: 从目标类型转换到源类型的函数

## 基本用法

### 表单输入转换

```dart
final age = Signal(18);

final ageText = ConvertComputed(
  age,
  decode: (int value) => value.toString(),
  encode: (String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      throw FormatException('无效的年龄');
    }
    return parsed;
  },
);
```

### 价格格式化

```dart
final price = Signal(100);

final priceText = ConvertComputed(
  price,
  decode: (int value) => '\$${value.toStringAsFixed(2)}',
  encode: (String value) {
    final cleaned = value.replaceAll('\$', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      throw FormatException('无效的价格');
    }
    return parsed.toInt();
  },
);
```

### 双向同步

转换后的信号可以读写，会自动同步到源信号：

```dart
final count = Signal(0);
final textCount = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

// 通过转换信号写入
textCount.value = "42"; // count 自动变为 42

// 通过源信号写入
count.value = 100; // textCount 自动变为 "100"
```
