/// Jolt Hooks - Flutter hooks integration for Jolt reactive system.
///
/// This library provides Flutter hooks that integrate with Jolt's reactive
/// state management system, enabling reactive programming in Flutter widgets.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:jolt_hooks/jolt_hooks.dart';
/// import 'package:flutter_hooks/flutter_hooks.dart';
///
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final count = useSignal(0);
///
///     return ElevatedButton(
///       onPressed: () => count.value++,
///       child: Text('Count: ${count.value}'),
///     );
///   }
/// }
/// ```
///
/// ## Integration with JoltBuilder
///
/// Use `JoltBuilder` from `jolt_flutter` package to reactively rebuild widgets:
///
/// ```dart
/// Widget build(BuildContext context) {
///   final count = useSignal(0);
///
///   return JoltBuilder(
///     builder: (context) => Text('Count: ${count.value}'),
///   );
/// }
/// ```
library;

export 'src/hook.dart';
export 'src/base.dart';
