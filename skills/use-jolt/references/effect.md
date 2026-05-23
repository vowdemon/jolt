# Effect Reference

Use this reference when the task is about reactive side effects, cleanup,
lazy effects, disposal, or work that should follow current signal values.

## Core Idea

`Effect` runs a callback, tracks the Jolt values read during that run, and
runs again when those dependencies change.

```dart
import 'package:jolt/jolt.dart';

final count = Signal(0);

final effect = Effect(() {
  print('count = ${count.value}');
});

count.value = 1;
effect.dispose();
```

Use effects for work:

- logging
- analytics
- persistence
- timers and debounced work
- network calls
- imperative synchronization
- subscriptions that depend on reactive values

## Cleanup

Use cleanup for resources created by one effect run. Cleanup runs before the
next run and when the effect is disposed.

```dart
import 'dart:async';
import 'package:jolt/jolt.dart';

final query = Signal('');

final searchEffect = Effect(() {
  final text = query.value.trim();
  if (text.isEmpty) return;

  final timer = Timer(const Duration(milliseconds: 300), () {
    search(text);
  });

  onEffectCleanup(timer.cancel);
});
```

`onEffectCleanup(...)` registers cleanup on the active effect or watcher. When
you already have the effect object, `effect.onCleanup(...)` registers cleanup
on that object directly.

```dart
final count = Signal(0);

final effect = Effect.lazy(() {
  print(count.value);
});

effect.onCleanup(() {
  print('effect disposed or rerun');
});
```

Register cleanup close to the resource it owns. Use the method form when there
is no active effect context or when explicit ownership is clearer.

## Lazy Effect

Use `Effect.lazy` when the first run should be explicit.

```dart
final effect = Effect.lazy(() {
  print(count.value);
});

effect.run();
```

The first `run()` collects dependencies.

## Incidental Reads

Use `peek` or `untracked` for values that should not become dependencies.

```dart
final query = Signal('');
final requestId = Signal('local');

final effect = Effect(() {
  final text = query.value;
  final id = untracked(() => requestId.value);
  print('$id: $text');
});
```

Changing `requestId` alone does not re-run the effect.

## Detached Effects

An effect created inside an active `EffectScope` joins that scope by default.
Use `detach: true` only when another owner will dispose it.

```dart
final appLogger = Effect(
  () => print(appState.value),
  detach: true,
);

appLogger.dispose();
```

Detached work without an explicit disposal path leaks lifecycle ownership.

## Manual Run

`run()` marks the effect dirty and executes it with dependency tracking.

```dart
final effect = Effect.lazy(() {
  print(settings.value);
});

effect.run();
```

Avoid using `run()` as a general event bus. If ordinary commands need to
change state, write signals and let the graph react.

## Effect Or Computed

Use `Computed` when the result is a value.
Use `Effect` when something happens.

```dart
final total = Computed(() => items.value.length);

final logger = Effect(() {
  print('total = ${total.value}');
});
```

## Avoid

- Creating an effect without storing it or putting it in a scope.
- Writing signal values in an effect without a clear guard against loops.
- Doing pure derivation in an effect.
- Using cleanup for resources that outlive a single effect run; put those in an
  `EffectScope` or explicit owner instead.
