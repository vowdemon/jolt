# Until Reference

Use this reference when imperative code must wait for a reactive value to
reach a condition.

## Core Idea

`Until<T>` is a cancellable future backed by a reactive effect. It completes
when a `Readable<T>` satisfies a predicate.

```dart
import 'package:jolt/jolt.dart';

final status = Signal('idle');
final ready = status.untilWhen('ready');

status.value = 'ready';
print(await ready);
```

Use `Until` for one-off waits, not for long-running reactions. Use `Effect` or
`Watcher` when code should keep responding.

## Predicate Wait

```dart
final count = Signal(0);

final reachedFive = count.until((value) => value >= 5);

count.value = 5;
print(await reachedFive);
```

If the predicate is already true, the future completes immediately.

## Equality Wait

```dart
await status.untilWhen('ready');
```

`untilWhen` compares with `==`.

## Change Wait

```dart
final nextValue = await count.untilChanged();
```

This captures the value when called and completes on the first later value that
differs by `!=`.

## Cancellation

Calling `cancel()` disposes the underlying effect. The future remains pending,
so do not await a cancelled wait.

```dart
final wait = status.untilWhen('ready');

if (shouldStop) {
  wait.cancel();
  return;
}
```

Track cancellation explicitly when the caller can abandon the wait.

## Scope Attachment

By default `Until` is detached from the active scope. Pass `detach: false` when
scope disposal should stop the wait.

```dart
final scope = EffectScope();

scope.run(() {
  final wait = status.untilWhen('ready', detach: false);
  wait.then(print);
});

scope.dispose();
```

Use this when the wait belongs to a screen, route, request, or test lifecycle.

## Command Flow Example

```dart
class ConnectionModel {
  final Signal<String> _status = Signal('idle');

  late final Readable<String> status = _status;

  Future<void> connect() async {
    _status.value = 'connecting';
    startConnection();
    await status.untilWhen('connected');
  }
}
```

Use timeouts at the call site if the wait should fail after a duration.

```dart
await status
    .untilWhen('ready')
    .timeout(const Duration(seconds: 5));
```

## Avoid

- Using `Until` for repeated callbacks.
- Awaiting a wait after calling `cancel()`.
- Leaving detached waits around when they should be tied to an owner.
- Modeling ordinary async loading with `Until` when `AsyncSignal` is the state.
