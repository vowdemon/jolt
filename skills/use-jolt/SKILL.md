---
name: use-jolt
description: Use when modeling reactive state in Dart with Jolt — owning mutable state with signals, deriving values from other reactive reads, reacting to changes with effects or watchers, or bridging reactive state with Future / Stream / async loading.
---

# Use Jolt

Jolt state models are ordinary Dart objects built from a small reactive core:
own state with `Signal`, derive values with `Computed`, react with `Effect` or
`Watcher`, and bind related lifetimes with `EffectScope`.

## When to Use

- The user wants reactive signals with automatic dependency tracking.
- The user wants to derive values from signals with `Computed` or `derived`.
- The user wants side effects, transition callbacks, cleanup, or lifecycle with
  `Effect`, `Watcher`, or `EffectScope`.
- The user wants to extend signal behavior with collection signals, readonly
  views, read/write helpers, conversion wrappers, or storage-backed state.
- The user wants signals to interact with `Future`, `Stream`, async loading
  state, or imperative waits.
- The user wants compact state management without code generation, global
  containers, or manual subscription wiring.
- The task mentions `Signal`, `Computed`, `Effect`, `Watcher`, `EffectScope`,
  `Readable`, `Writable`, `Readonly`, `WritableComputed`, `AsyncSignal`,
  `ListSignal`, `MapSignal`, `SetSignal`, `IterableSignal`, `PersistSignal`,
  `ConvertComputed`, `batch`, `untracked`, `triggerTracked`, `peek`, `stream`,
  or `until`.

## Quick Start

Start with the smallest model that expresses the state and derivations. Use
`Signal` for source state, `Computed` for values that follow from other reads,
and ordinary methods for writes.

```dart
import 'package:jolt/jolt.dart';

class CounterModel {
  final _count = Signal(0);

  late final isEven = Computed(() => _count.value.isEven);

  int get count => _count.value;

  void increment() {
    _count.value++;
  }
}
```

## Core Choice Table

| Need | Use |
| --- | --- |
| Owned mutable state | `Signal<T>` |
| Lazy mutable state | `Signal.lazy<T>()` |
| Read interface | `Readable<T>` |
| Read/write interface | `Writable<T>` |
| Read-only wrapper or constant value | `Readonly<T>` |
| Derived read-only value | `Computed<T>` or `readable.derived(...)` |
| Derived value with write-back | `WritableComputed<T>` |
| Reversible conversion over writable state | `ConvertComputed<T, U>` |
| Reactive mutable collection | `ListSignal`, `MapSignal`, `SetSignal` |
| Derived iterable view | `IterableSignal<T>` |
| Run work after reactive values change | `Effect` |
| Compare previous and next values | `Watcher<T>` |
| Dispose related reactions together | `EffectScope` |
| Update multiple signals as one settled change | `batch(...)` |
| Read without subscribing | `peek` or `untracked(...)` |
| Touch tracked values without keeping the caller subscribed | `triggerTracked(...)` |
| Async source and loading/success/error state | `AsyncSignal<T>`, `AsyncState<T>`, `FutureSource`, `StreamSource` |
| Stream-style output from a readable | `readable.stream` or `readable.listen(...)` |
| Await a reactive condition | `Until<T>`, `readable.until(...)`, `untilWhen(...)`, `untilChanged(...)` |
| Storage-backed signal | `PersistSignal<T>` |
| Debug metadata and hooks | `JoltDebugOption`, `JoltDebug` |

## Reference Files

Read the focused reference that matches the user's task:

| File | Use when |
| --- | --- |
| `references/signal.md` | Modeling owned state, read surfaces, lazy signals, notifications, and collection signals. |
| `references/computed.md` | Deriving values, equality, previous values, advanced computed variants, and pure getter rules. |
| `references/effect.md` | Running reactive work, lazy effects, cleanup, detach, and disposal. |
| `references/watcher.md` | Previous/next transitions, `when`, immediate/once watchers, pause/resume, and ignored updates. |
| `references/effect-scope.md` | Grouped lifecycle, scope cleanup, detached scopes, and ownership boundaries. |
| `references/async.md` | Async loading state, futures, streams, source replacement, and `AsyncState` mapping. |
| `references/until.md` | Awaiting reactive conditions with `Until`, cancellation, and scope attachment. |
| `references/tricks.md` | Persistence helpers, readonly views, conversion wrappers, and storage patterns. |
| `references/advanced.md` | `batch`, `untracked`, stream/listen utilities, debugging, and low-level extension points. |

## Automatic Tracking

Tracked reads happen through `.value` inside an active reactive context:

| Form | Behavior |
| --- | --- |
| `source.value` | Reads and subscribes the active reactive context. |
| `source.peek` | Reads without subscribing. |
| `untracked(() => source.value)` | Runs a block without recording dependencies. |

Use `batch` when one command mutates several signals and observers should see
one final state:

```dart
batch(() {
  firstName.value = 'Ada';
  lastName.value = 'Lovelace';
});
```

## Derive And React

Use `Computed` when a value follows from reactive reads. Keep computed getters
pure: no timers, requests, logging, persistence, controller mutations, or signal
writes.

Use `Effect` when something should happen because current reactive values
changed. Use cleanup for resources owned by one run, and dispose manually
created effects.

Use `Watcher` when the callback needs the previous and next values, custom
transition filtering, pause/resume, or once semantics.

Use `EffectScope` when a screen, request, route, test, or temporary workflow
owns several reactions and cleanup callbacks together.

## Integration Points

- Use collection signals when in-place `List`, `Map`, or `Set` mutation is the
  normal API and should notify dependents.
- Use `AsyncSignal` when loading, success, and error are part of the state.
- Use readable stream/listen utilities when an external API expects `Stream` or
  callback-style updates; cancel subscriptions when the bridge ends.
- Use `until` utilities when imperative code must wait for a reactive condition.
- Use persistence helpers when storage belongs to the signal model.
- Use `Readonly<T>` when an API needs a Jolt object that cannot write through
  the exposed surface.

## Common Mistakes

- Creating a signal for state that should be derived with `Computed`.
- Putting side effects inside `Computed`.
- Reading `.value` when the read is incidental; use `peek` or `untracked`.
- Forgetting to dispose effects, watchers, scopes, waits, or stream
  subscriptions.
- Using `Watcher` when an `Effect` only needs current values.
- Mutating ordinary `List`, `Map`, or `Set` in place inside a `Signal` without
  calling `notify` or using collection signals.

## Source Navigation

Read the current source before answering API-sensitive questions.

| Area | Files |
| --- | --- |
| Public exports | `packages/jolt/lib/jolt.dart`, `packages/jolt/lib/core.dart` |
| Read/write interfaces | `packages/jolt/lib/src/core/interface.dart`, `packages/jolt/lib/src/utils/readable.dart`, `packages/jolt/lib/src/utils/writable.dart` |
| Signal state | `packages/jolt/lib/src/jolt/signal.dart`, `packages/jolt/lib/src/jolt/readonly.dart` |
| Derived state | `packages/jolt/lib/src/jolt/computed.dart` |
| Effects and lifecycle | `packages/jolt/lib/src/jolt/effect.dart`, `packages/jolt/lib/src/jolt/watcher.dart`, `packages/jolt/lib/src/jolt/effect_scope.dart` |
| Tracking and batching | `packages/jolt/lib/src/jolt/track.dart`, `packages/jolt/lib/src/jolt/batch.dart` |
| Collections | `packages/jolt/lib/src/jolt/collection/` |
| Async, stream, wait, persistence | `packages/jolt/lib/src/jolt/async.dart`, `packages/jolt/lib/src/utils/`, `packages/jolt/lib/src/tricks/persist_signal.dart` |
| Tutorials | `packages/jolt/doc/en/` |
| Core tests | `packages/jolt/test/` |

For public examples, import `package:jolt/jolt.dart`. Use `src/` imports only
when maintaining package internals.
