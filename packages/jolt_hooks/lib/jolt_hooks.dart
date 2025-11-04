/// A Flutter hooks integration package for [Jolt](https://pub.dev/packages/jolt) reactive state management.
///
/// Jolt Hooks provides a comprehensive Hooks API built on [flutter_hooks](https://pub.dev/packages/flutter_hooks),
/// enabling you to use Jolt's reactive primitives seamlessly within Flutter's hook system.
/// All hooks automatically dispose their resources when the widget is removed from the tree,
/// ensuring memory safety and preventing leaks.
///
/// ## Documentation
///
/// [Official Documentation](https://jolt.vowdemon.com)
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:flutter_hooks/flutter_hooks.dart';
/// import 'package:jolt_hooks/jolt_hooks.dart';
///
/// class CounterWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final count = useSignal(0);
///     final doubled = useComputed(() => count.value * 2);
///
///     return Scaffold(
///       body: HookBuilder(
///         builder: (context) => useJoltWidget(() {
///           return Column(
///             mainAxisAlignment: MainAxisAlignment.center,
///             children: [
///               Text('Count: ${count.value}'),
///               Text('Doubled: ${doubled.value}'),
///               ElevatedButton(
///                 onPressed: () => count.value++,
///                 child: Text('Increment'),
///               ),
///             ],
///           );
///         }),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Integration with JoltBuilder
///
/// You can also use `JoltBuilder` from `jolt_flutter` package for reactive UI updates:
///
/// ```dart
/// import 'package:jolt_flutter/jolt_flutter.dart';
///
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
