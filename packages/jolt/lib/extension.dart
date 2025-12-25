/// Extension methods for Jolt reactive values.
///
/// This library provides convenient extension methods for working with
/// [Readable] and [Writable] values, including:
///
/// - **Readable extensions**: `call()`, `get()`, `derived()`, `until()`, `stream`, `listen()`
/// - **Writable extensions**: `update()`, `set()`, `readonly()`
///
/// ## Usage
///
/// ```dart
/// import 'package:jolt/extension.dart';
///
/// final count = Signal(5);
///
/// // Callable syntax
/// final value = count(); // Same as count.value
///
/// // Derived computed
/// final doubled = count.derived((value) => value * 2);
///
/// // Update value
/// count.update((value) => value + 1);
///
/// // Wait until condition
/// await count.until((value) => value >= 10);
///
/// // Stream integration
/// count.stream.listen((value) => print('Count: $value'));
/// ```
library;

export "src/utils/until.dart";
export "src/utils/readable.dart";
export "src/utils/writable.dart";
export "src/utils/stream.dart" show JoltUtilsStreamExtension;
