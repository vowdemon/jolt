# Watcher Reference

Use this reference when the task needs previous/next transitions, custom
triggering rules, immediate or one-shot reactions, pause/resume, or ignored
updates.

## Core Idea

`Watcher<T>` tracks a source snapshot and runs a callback when the visible
snapshot changes.

```dart
import 'package:jolt/jolt.dart';

final query = Signal('');

final watcher = Watcher<String>(
  () => query.value,
  (next, previous) {
    print('$previous -> $next');
  },
);

query.value = 'signal';
watcher.dispose();
```

Use `Effect` for ordinary current-value work. Use `Watcher` when the transition
itself matters.

## Multiple Sources

Return a record, list, or model object when a transition depends on multiple
values.

```dart
final first = Signal('Ada');
final last = Signal('Lovelace');

final watcher = Watcher<({String first, String last})>(
  () => (first: first.value, last: last.value),
  (next, previous) {
    print('${previous?.first} -> ${next.first}');
  },
);
```

Prefer records for typed source snapshots.

## Custom Triggering

Use `when` to decide whether a candidate transition should notify.

```dart
final count = Signal(0);

final watcher = Watcher<int>(
  () => count.value,
  (next, previous) => print('jumped to $next'),
  when: (next, previous) => (next - previous).abs() >= 10,
);
```

Keep `when` cheap and deterministic.

## Immediate And Once

Use `Watcher.immediately` when the callback should receive the initial value.

```dart
final watcher = Watcher.immediately<String>(
  () => query.value,
  (next, previous) {
    print('current = $next, previous = $previous');
  },
);
```

Use `Watcher.once` for the first qualifying transition.

```dart
Watcher.once<bool>(
  () => isReady.value,
  (ready, _) => start(),
  when: (next, previous) => next && !previous,
);
```

## Pause And Resume

Use `pause()` to stop responding temporarily and clear current dependencies.
Use `resume()` to collect dependencies again.

```dart
watcher.pause();
query.value = 'internal change';
watcher.resume();
```

If the source changed while paused, `resume()` can invoke the callback once
with the latest visible value.

## Ignore Updates

Use `ignoreUpdates` for writes that should not count as watcher transitions.

```dart
final count = Signal(0);
final watcher = Watcher<int>(
  () => count.value,
  (next, previous) => print('$previous -> $next'),
);

watcher.ignoreUpdates(() {
  count.value = 10;
});
```

The signal still changes. The watcher keeps its previous visible state for the
next normal transition.

## Cleanup

`Watcher` supports `onCleanup` and `onEffectCleanup`.

```dart
final watcher = Watcher<String>(
  () => query.value,
  (next, _) {
    final subscription = searchStream(next).listen(print);
    onEffectCleanup(subscription.cancel);
  },
);
```

Cleanup runs before the watcher callback runs again and when the watcher is
disposed.

## Avoid

- Using `Watcher` when only current values matter.
- Returning mutable source snapshots that are later changed in place.
- Forgetting to dispose or scope the watcher.
- Putting expensive comparison logic in `when`.
