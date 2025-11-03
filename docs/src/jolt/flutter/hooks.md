---
---

# Flutter Hooks

`jolt_hooks` is built on top of [flutter_hooks](https://pub.dev/packages/flutter_hooks), providing a deeply integrated Hook API for Flutter with Jolt's reactive system. It enables developers to elegantly use all of Jolt's reactive features in `HookWidget` while enjoying the automatic lifecycle management benefits that Flutter Hooks provide.

By encapsulating Jolt's reactive primitives (such as Signal, Computed, Effect, etc.) as Hooks, developers can directly create and manage reactive state in functional components. These Hooks automatically clean up resources when widgets are disposed, eliminating the need to manually handle dispose logic and greatly simplifying state management work.

## Basic Hooks

### useSignal

Creates a reactive signal. Usage is the same as `Signal`.

```dart
import 'package:jolt_hooks/jolt_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
    return Column(
      children: [
        Text('Count: ${count.value}'),
        ElevatedButton(
          onPressed: () => count.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### useComputed

Creates a computed value. Usage is the same as `Computed`.

```dart
final firstName = useSignal('John');
final lastName = useSignal('Doe');
final fullName = useComputed(() => '${firstName.value} ${lastName.value}');
```

### useWritableComputed

Creates a writable computed value. Usage is the same as `WritableComputed`.

```dart
final count = useSignal(0);
final doubled = useWritableComputed(
  () => count.value * 2,
  (value) => count.value = value ~/ 2,
);
```

### useJoltEffect

Creates an effect. Usage is the same as `Effect`.

```dart
final count = useSignal(0);

useJoltEffect(() {
  print('Count changed to: ${count.value}');
});
```

### useJoltWatcher

Creates a watcher. Usage is the same as `Watcher`.

```dart
final count = useSignal(0);

useJoltWatcher(
  () => count.value,
  (newValue, oldValue) {
    print('Changed from $oldValue to $newValue');
  },
  when: (new, old) => new > old,
);
```

### useJoltEffectScope

Creates an effect scope. Usage is the same as `EffectScope`.

```dart
useJoltEffectScope((scope) {
  final count = Signal(0);
  final name = Signal('User');
  final isActive = Computed(() => count.value > 0);
});
```

## Collection Hooks

### useListSignal

Creates a reactive list. Usage is the same as `ListSignal`.

```dart
final items = useListSignal(['Apple', 'Banana']);

items.add('Orange'); // Automatically updates
```

### useMapSignal

Creates a reactive map. Usage is the same as `MapSignal`.

```dart
final settings = useMapSignal({'theme': 'light'});

settings['theme'] = 'dark'; // Automatically updates
```

### useSetSignal

Creates a reactive set. Usage is the same as `SetSignal`.

```dart
final tags = useSetSignal({'urgent', 'important'});

tags.add('new'); // Automatically updates
```

### useIterableSignal

Creates a reactive iterable. Usage is the same as `IterableSignal`.

```dart
final numbers = useSignal([1, 2, 3, 4, 5]);
final evens = useIterableSignal(() => numbers.value.where((n) => n.isEven));
```

## Utility Hooks

### useJoltStream

Converts a signal to a stream. Usage is the same as the `stream` extension.

```dart
final count = useSignal(0);
final stream = useJoltStream(count);

return StreamBuilder<int>(
  stream: stream,
  builder: (context, snapshot) => Text('Count: ${snapshot.data ?? 0}'),
);
```

### useConvertComputed

Creates a type-converting signal. Usage is the same as `ConvertComputed`.

```dart
final count = useSignal(42);
final countText = useConvertComputed(
  count,
  (int value) => 'Count: $value',
  (String value) => int.parse(value.split(': ')[1]),
);
```

### usePersistSignal

Creates a persistent signal. Usage is the same as `PersistSignal`.

```dart
final theme = usePersistSignal(
  () => 'light',
  () async => await storage.read('theme') ?? 'light',
  (value) async => await storage.write('theme', value),
);
```

### useAsyncSignal

Creates an async signal. Usage is the same as `AsyncSignal`.

```dart
final userData = useAsyncSignal(
  FutureSource(() async => fetchUser()),
);

// Usage
userData.value.map(
  loading: () => CircularProgressIndicator(),
  success: (user) => Text('Welcome, ${user.name}'),
  error: (error, _) => Text('Error: $error'),
);
```

## Component Hooks

### useJoltWidget

Creates a reactive widget within `HookBuilder`. The widget automatically rebuilds when signals accessed in the widget's build function change.

```dart
final counter = Signal(0);

Widget build(BuildContext context) {
  return HookBuilder(
    builder: (context) {
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

