# Advanced Reference

Use this reference for batching, untracked reads, readable streams, debugging,
manual notifications, and lower-level extension decisions.

## Batch

Use `batch` when one command writes several signals and observers should see
one settled result.

```dart
final firstName = Signal('Ada');
final lastName = Signal('Lovelace');

batch(() {
  firstName.value = 'Grace';
  lastName.value = 'Hopper';
});
```

Only the synchronous body before the first `await` belongs to the batch.

```dart
batch(() {
  first.value = 1;
  second.value = 2;
});
```

Do not put `async` control flow inside `batch` and expect later writes to stay
batched.

## Untracked Reads

Use `untracked` when a read is incidental to the current reactive computation.

```dart
final query = Signal('');
final requestId = Signal('local');

final effect = Effect(() {
  final text = query.value;
  final id = untracked(() => requestId.value);
  print('$id: $text');
});
```

Use `peek` for a single value and `untracked` for a block.

## Trigger Tracked

`triggerTracked` touches the values read in a callback for notification
purposes without keeping the current caller subscribed after the callback.

```dart
triggerTracked(() {
  source.value;
});
```

This is an advanced integration tool. Prefer normal signal writes and `notify`
unless building a bridge.

## Readable Streams

`readable.stream` is a broadcast stream of later visible changes. It does not
emit the current value on listen.

```dart
final count = Signal(0);
final subscription = count.stream.listen(print);

count.value = 1;
await subscription.cancel();
```

Use `listen(immediately: true)` when the current snapshot should be delivered
first.

```dart
final subscription = count.listen(
  print,
  immediately: true,
);
```

Cancel stream subscriptions when the bridge ends.

## Manual Notify

Use `notify()` when a value changed without assignment through `.value`.

```dart
final tags = Signal(<String>[]);

tags.peek.add('jolt');
tags.notify();
```

Prefer collection signals when in-place mutation is the normal API.

## Debug Options

Public APIs accept `JoltDebugOption? debug` in many constructors. Use debug
metadata when diagnosing graph behavior or exposing state to tooling.

```dart
final count = Signal(
  0,
  debug: const JoltDebugOption.type('Counter.count'),
);
```

Do not make application correctness depend on debug hooks.

## Extension Decisions

Before writing a custom abstraction, check whether an existing core helper
already covers the need:

- `Computed` for derived state.
- `WritableComputed` for write-back derived state.
- `ConvertComputed` for reversible conversion.
- `ListSignal`, `MapSignal`, `SetSignal`, `IterableSignal` for collections.
- `AsyncSignal` for loading/success/error.
- `EffectScope` for lifecycle.
- `readable.stream`, `readable.listen`, and `Until` for interop.

Reach into `package:jolt/core.dart` only when maintaining Jolt or building a
new integration layer. Application code should normally import
`package:jolt/jolt.dart`.

## Avoid

- Using `batch` as an async transaction.
- Using `untracked` to hide real dependencies.
- Forgetting to cancel `stream`/`listen` subscriptions.
- Depending on debug hooks for runtime behavior.
- Importing `src/` from application examples.
