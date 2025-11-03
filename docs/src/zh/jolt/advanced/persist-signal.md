---
---

# PersistSignal

PersistSignal 在响应式系统中用于创建自动持久化到存储的信号。它会在值变化时自动写入存储，并在需要时从存储加载值，适用于保存用户设置、主题偏好、缓存数据等需要持久化的场景。

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';
import 'package:shared_preferences/shared_preferences.dart';

final theme = PersistSignal(
  initialValue: () => 'light',
  read: () => SharedPreferences.getInstance()
    .then((prefs) => prefs.getString('theme') ?? 'light'),
  write: (value) => SharedPreferences.getInstance()
    .then((prefs) => prefs.setString('theme', value)),
);

// 设置值会自动保存
theme.value = 'dark'; // 自动保存到 SharedPreferences

// 读取值会自动从存储加载
print(theme.value); // 输出保存的值
```

## 创建

使用 `PersistSignal` 构造函数创建持久化信号：

```dart
final signal = PersistSignal(
  initialValue: () => defaultValue,
  read: () async => loadFromStorage(),
  write: (value) async => saveToStorage(value),
  lazy: false, // 是否延迟加载
  writeDelay: Duration(milliseconds: 100), // 防抖写入延迟
);
```

参数说明：
- `initialValue`: 初始值的获取函数
- `read`: 从存储读取值的异步函数
- `write`: 写入值到存储的异步函数
- `lazy`: 是否延迟加载（默认为 false，立即加载）
- `writeDelay`: 写入防抖延迟（可选）

## 懒加载

默认情况下，PersistSignal 会立即从存储加载值。使用 `lazy: true` 可以延迟加载值，直到首次访问时才从存储加载：

```dart
// 立即加载（默认）
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () async => loadTheme(),
  write: (value) async => saveTheme(value),
  lazy: false, // 立即加载
);

// 延迟加载
final settings = PersistSignal(
  initialValue: () => Settings(),
  read: () async => loadSettings(),
  write: (value) async => saveSettings(value),
  lazy: true, // 延迟加载，直到首次访问时才加载
);
```

## 防抖

使用 `writeDelay` 可以防抖写入操作，避免频繁写入。当值在短时间内多次变化时，只有最后一次变化会被写入存储：

```dart
final text = PersistSignal(
  initialValue: () => '',
  read: () async => loadText(),
  write: (value) async => saveText(value),
  writeDelay: Duration(milliseconds: 500), // 500ms 防抖
);

text.value = 'a';
text.value = 'ab';
text.value = 'abc';
// 只会在最后一次变化后等待 500ms 写入 'abc'
```

## 保证读取

使用 `getEnsured()` 方法可以确保值已经从存储加载完成后再返回：

```dart
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () async => loadTheme(),
  write: (value) async => saveTheme(value),
  lazy: true, // 延迟加载
);

// 确保值已从存储加载
final value = await theme.getEnsured();
print(value); // 保证是存储中的值
```

## 保证写入

使用 `setEnsured()` 方法可以确保值被写入存储后再返回，可以配合 `optimistic` 参数使用：

```dart
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () async => loadTheme(),
  write: (value) async => saveTheme(value),
);

// 立即更新值，然后异步写入存储
final success = await theme.setEnsured('dark', optimistic: true);
if (success) {
  print('保存成功');
} else {
  print('保存失败');
}

// 等待写入完成后再更新值
await theme.setEnsured('dark', optimistic: false);
```
