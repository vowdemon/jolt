/// Flutter hooks integration for [Jolt](https://pub.dev/packages/jolt) reactive state.
///
/// Built on [flutter_hooks](https://pub.dev/packages/flutter_hooks). Hooks dispose
/// their reactive resources automatically when the widget unmounts.
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
library;

export 'src/hook.dart';
export 'src/base.dart';
