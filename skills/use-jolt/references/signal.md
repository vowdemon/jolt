# Signal Reference

Use this reference when the task is about owned state, public read surfaces,
manual notification, lazy initialization, or collection-backed state.

## Core Idea

`Signal<T>` is the owned writable value in Jolt. `Signal(value)` creates an
initialized signal. `Signal.lazy<T>()` creates the lazy version without an
initial value.

Reads through `.value` are tracked inside a reactive context. Writes through
`.value` notify dependents when the visible value changes.
For a non-nullable lazy signal, reading `.value` or `.peek` before the first
write throws because there is no initialized value to cast to `T`.

```dart
import 'package:jolt/jolt.dart';

final count = Signal(0);
final token = Signal.lazy<String>();

Effect(() {
  print('count = ${count.value}');
});

count.value++;
token.value = loadToken();
```

## Public State Pattern

Keep writable signals private when a model owns the write path. Expose
`Readable<T>` for public reads.

```dart
class Counter {
  final _count = Signal(0);

  late final Readable<int> count = _count;

  void increment() {
    _count.value++;
  }

  void setCount(int value) {
    if (value < 0) return;
    _count.value = value;
  }
}
```

This keeps validation, normalization, logging, persistence, and batching local
to the owner.

## Read Forms

| Form | Use |
| --- | --- |
| `signal.value` | Tracked read when a reactive context is active. |
| `signal.peek` | Snapshot read without dependency tracking. |
| `signal.readonly()` | Wrapper when an API needs a `Readonly<T>`. |
| `Readable<T>` | Narrow public type for callers that should not assign. |

Use `peek` for incidental reads:

```dart
final requestId = Signal('local');
final query = Signal('');

Effect(() {
  final text = query.value;
  final id = requestId.peek;
  print('$id: $text');
});
```

Changing `requestId` alone does not re-run the effect.

## Manual Notification

Use `notify()` after mutating the stored object in place.

```dart
final profile = Signal({'name': 'Ada'});

profile.peek['name'] = 'Grace';
profile.notify();
```

Prefer assigning a new immutable value when practical:

```dart
profile.value = {...profile.peek, 'name': 'Grace'};
```

## Collection Signals

Use collection signals when in-place mutation is the intended API.
`ListSignal`, `SetSignal`, and `MapSignal` implement `ListBase`, `SetBase`,
and `MapBase` through their mixins, so code can use normal collection methods
while Jolt tracks collection reads and notifies on mutating operations.

```dart
final items = ListSignal<String>([]);
final selected = SetSignal<int>({});
final cache = MapSignal<String, int>({});

Effect(() {
  print('items = ${items.length}');
});

items.add('first');
selected.add(1);
cache['answer'] = 42;
```

## Use Signal When

- The value is a source of truth.
- The owner has a real write path.
- Callers should observe changes.
- Writes may need validation, batching, or side effects later.

## Avoid

- Exposing `Signal<T>` publicly when callers should only read.
- Creating a signal for values that can be derived from other signals.
- Mutating a stored collection in place without `notify()` or a collection signal.
