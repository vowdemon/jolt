---
---

# Flutter Hooks

`jolt_hooks` is built on [flutter_hooks](https://pub.dev/packages/flutter_hooks), providing Flutter with a Hook API deeply integrated with the Jolt reactive system. It allows developers to elegantly use all of Jolt's reactive features in `HookWidget` while enjoying the automatic lifecycle management benefits of Flutter Hooks.

By encapsulating Jolt's reactive primitives (such as Signal, Computed, Effect, etc.) as Hooks, developers can directly create and manage reactive state in functional components. These Hooks automatically clean up resources when Widgets are unmounted, eliminating the need for manual dispose logic and greatly simplifying state management work.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_hooks/jolt_hooks.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    final doubled = useComputed(() => count.value * 2);

    return Scaffold(
      body: HookBuilder(
        builder: (context) => useJoltWidget(() {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Count: ${count.value}'),
              Text('Doubled: ${doubled.value}'),
              ElevatedButton(
                onPressed: () => count.value++,
                child: Text('Increment'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
```

## useSignal

`useSignal` is an instance of `JoltSignalHookCreator` for creating reactive signals. Usage is the same as `Signal`, only the construction method differs, and it supports the `keys` parameter.

```dart
final count = useSignal(0);
final name = useSignal('Alice', keys: [userId]); // Recreates when userId changes
```

### Extension Methods

- **`useSignal.lazy()`**: Create lazily initialized signal
- **`useSignal.list()`**: Create list signal
- **`useSignal.map()`**: Create map signal
- **`useSignal.set()`**: Create set signal
- **`useSignal.iterable()`**: Create iterable signal
- **`useSignal.async()`**: Create async signal
- **`useSignal.persist()`**: Create persistent signal

All extension methods support the `keys` parameter.

## useComputed

`useComputed` is an instance of `JoltComputedHookCreator` for creating computed values. Usage is the same as `Computed`, only the construction method differs, and it supports the `keys` parameter.

```dart
final firstName = useSignal('John');
final lastName = useSignal('Doe');
final fullName = useComputed(() => '${firstName.value} ${lastName.value}');
```

### Extension Methods

- **`useComputed.writable()`**: Create writable computed value
- **`useComputed.convert()`**: Create type-converting computed value

All extension methods support the `keys` parameter.

## useJoltEffect

`useJoltEffect` is an instance of `JoltEffectHookCreator` for creating side effects. Usage is the same as `Effect`, only the construction method differs, and it supports the `keys` parameter.

```dart
final count = useSignal(0);

useJoltEffect(() {
  print('Count changed to: ${count.value}');
});
```

### Extension Methods

- **`useJoltEffect.lazy()`**: Create side effect with lazy dependency collection

## useWatcher

`useWatcher` is an instance of `JoltWatcherHookCreator` for creating watchers. Usage is the same as `Watcher`, only the construction method differs, and it supports the `keys` parameter.

```dart
final count = useSignal(0);

useWatcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
);
```

### Extension Methods

- **`useWatcher.immediately()`**: Create immediately executing watcher
- **`useWatcher.once()`**: Create watcher that auto-disposes after one execution

All extension methods support the `keys` parameter.

## useEffectScope

`useEffectScope` is an instance of `JoltEffectScopeHookCreator` for creating effect scopes. Usage is the same as `EffectScope`, only the construction method differs, and it supports the `keys` parameter.

```dart
useEffectScope(fn: (scope) {
  scope.run(() {
    final count = Signal(0);
    Effect(() => print('Count: ${count.value}'));
  });
});
```

## useJoltStream

Convert reactive values to Dart Streams. Usage is the same as the `stream` extension, only the construction method differs, and it supports the `keys` parameter.

```dart
final count = useSignal(0);
final stream = useJoltStream(count);
```

## useJoltWidget

Use reactive Widgets in `HookBuilder`. When signals accessed in the Widget build function change, the Widget automatically rebuilds.

**Important**: This Hook must be used inside `HookBuilder`.

```dart
Widget build(BuildContext context) {
  return HookBuilder(
    builder: (context) {
      final counter = useSignal(0);
      
      return useJoltWidget(() {
        return Column(
          children: [
            Text('Count: ${counter.value}'),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: Text('Increment'),
            ),
          ],
        );
      });
    },
  );
}
```

## keys Parameter

All Hooks support the `keys` parameter for Hook memoization. When keys change, the Hook is recreated:

```dart
final count = useSignal(0, keys: [userId]); // Hook is recreated when userId changes
```

## Lifecycle Management

All reactive objects created through Hooks are automatically disposed when Widgets are unmounted, without needing to manually call `dispose()`.

## Integration with JoltBuilder

You can also use `JoltBuilder` from the `jolt_flutter` package to implement reactive UI updates:

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

Widget build(BuildContext context) {
  final count = useSignal(0);

  return JoltBuilder(
    builder: (context) => Text('Count: ${count.value}'),
  );
}
```

## Important Notes

1. **Hook Rules**: All Hooks must be called in the `build` method of `HookWidget` or the `builder` of `HookBuilder`, and cannot be called in conditional statements or loops.

2. **useJoltWidget Limitation**: `useJoltWidget` must be used inside `HookBuilder` and cannot be used directly in regular `HookWidget`.

3. **Automatic Cleanup**: All resources created through Hooks are automatically cleaned up when Widgets are unmounted, without manual management.

4. **keys Parameter**: Using the `keys` parameter can control when Hooks are recreated, which is useful for scenarios dependent on external parameters.

## Related APIs

- [Signal](../../core/signal.md) - Learn about basic signal usage
- [Computed](../../core/computed.md) - Learn about computed property usage
- [Effect](../../core/effect.md) - Learn about side effect usage
- [SetupWidget](./setup-widget.md) - Learn about SetupWidget and Flutter resource Hooks

