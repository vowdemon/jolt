## Context

See `proposal.md` for motivation and `specs/persist-signals/spec.md` for the behavioral contract. Synchronous persistence is an ordinary `Signal<T>`, but asynchronous persistence must represent a pending read and read failures. Modeling those conditions as private initialization flags beside a `T` value makes the public value and the actual lifecycle diverge.

The asynchronous signal will instead expose `AsyncState<T>` directly. Loading, success, and error become ordinary reactive values. Persistence remains storage-agnostic through `read` and `write` callbacks, with typed storage factories and receiver extensions for keyed integrations.

## Goals / Non-Goals

**Goals:**

- Keep synchronous persistence as an eager, optimistic `Signal<T>`.
- Represent asynchronous read and assignment lifecycle explicitly as `AsyncState<T>`.
- Persist successful explicit assignments, but never write an initial read result back automatically.
- Prevent stale reads and assigned Futures from replacing state or writing data.
- Keep write scheduling outside the signal and expose only a last-write barrier.
- Support generic-key storage whose `read` owns missing-value and optional-fallback behavior.

**Non-Goals:**

- Reusing or subclassing `AsyncSignalImpl` and its source lifecycle.
- Reporting write failures through `AsyncError<T>` or `ensureWrite()`.
- Adding codec, subscription, migration, transaction, retry, throttle, debounce, serialization, or coalescing APIs.
- Adding persistence behavior to `SignalImpl` or collection-signal variants.

## Decisions

### Use separate signal value contracts

Synchronous persistence exposes `T`:

```dart
abstract interface class PersistSignal<T> implements Signal<T> {
  factory PersistSignal({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    JoltDebugOption? debug,
  });

  static PersistSignal<T> storage<K, T>({
    required K key,
    T Function()? initial,
    required PersistSignalStorage<K> storage,
    JoltDebugOption? debug,
  });

  Future<void> ensureWrite();
}
```

Asynchronous persistence exposes `AsyncState<T>`:

```dart
abstract interface class AsyncPersistSignal<T>
    implements Signal<AsyncState<T>> {
  factory AsyncPersistSignal({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    JoltDebugOption? debug,
  });

  static AsyncPersistSignal<T> storage<K, T>({
    required K key,
    T Function()? initial,
    required PersistSignalStorage<K> storage,
    JoltDebugOption? debug,
  });

  void set(T value);
  void setFuture(Future<T> value);
  Future<void> ensureWrite();
}
```

Both read eagerly during construction. The removed lazy constructors, initialization flags, temporary values, and initialization helpers are unnecessary because the asynchronous lifecycle is visible in `value`.

### Make AsyncState the complete asynchronous state machine

`_AsyncPersistSignalImpl<T>` extends `SignalImpl<AsyncState<T>>` and begins with `AsyncLoading<T>`. It immediately starts the read callback. A current read publishes `AsyncSuccess<T>` or `AsyncError<T>` through an internal state update that does not invoke `write`.

Explicit assignments have these semantics:

- `set(T value)` immediately publishes `AsyncSuccess<T>` and invokes `write(value)`.
- `setFuture(Future<T>)` immediately publishes `AsyncLoading<T>`. A current success publishes `AsyncSuccess<T>` and writes the result; a current failure publishes `AsyncError<T>` and does not write.
- Directly assigning `AsyncSuccess<T>` publishes it and writes its data.
- Directly assigning `AsyncLoading<T>` or `AsyncError<T>` publishes it without writing.

Every explicit assignment supersedes the initial read and any pending `setFuture`. Internal completion updates must bypass the public persistence-aware setter so read results are never mistaken for local assignments.

The separately planned `AsyncStateReadableX<T>` extension can provide `data`, status, error, and `map` helpers to any `Readable<AsyncState<T>>`. Persistence composes with that helper layer but does not depend on `AsyncSignalImpl`.

### Use one current-operation token

The implementation creates a fresh identity token when starting the initial read or accepting `setFuture`. A direct state/value assignment or disposal clears the current token. A read or assigned Future may update state and invoke write only if its captured token is still identical to the current token and the signal is not disposed.

Each assignment receives a distinct token even when callers submit the same Future object more than once. This gives local assignment precedence without attempting to cancel Futures or relying on Future identity. Callers that retained a superseded Future can still observe its result, but it has no later effect on the signal or storage.

Only explicit `setFuture` work is tracked as an assignment barrier. The initial read is not a persistence assignment, so `ensureWrite()` must not wait for it. Superseding a pending explicit Future releases callers waiting on that assignment.

### Retain only the latest callback completion

Each accepted value invokes `write` immediately. The implementation converts the callback's `FutureOr<void>` into a non-reporting completion Future and stores only that latest Future. It does not queue, serialize, throttle, coalesce, or drain older callbacks.

For `AsyncPersistSignal`, `ensureWrite()` first waits for the current explicit Future assignment to settle or be superseded, then waits for the latest write Future selected after that settlement. For `PersistSignal`, it snapshots and waits for the latest write Future directly. Write failures do not roll back optimistic state, become `AsyncError<T>`, or escape through `ensureWrite()`.

### Keep a generic-key storage boundary

```dart
abstract interface class PersistSignalStorage<K> {
  FutureOr<T> read<T>(K key, [T Function()? initial]);
  FutureOr<void> write<T>(K key, T value);
}

extension PersistSignalStorageX<K> on PersistSignalStorage<K> {
  PersistSignal<T> sync<T>({
    required K key,
    T Function()? initial,
    JoltDebugOption? debug,
  });

  AsyncPersistSignal<T> async<T>({
    required K key,
    T Function()? initial,
    JoltDebugOption? debug,
  });
}
```

Storage owns key existence detection, fallback evaluation, nullable stored values, and missing-without-fallback behavior. `PersistSignal.storage` requires the read to return `T` immediately and fails fast if it receives a Future. `AsyncPersistSignal.storage` normalizes a synchronous value, a Future, or a synchronous throw into the same `AsyncLoading<T>` followed by `AsyncSuccess<T>` or `AsyncError<T>` lifecycle.

The static factories retain the independent key type `K` without adding it to the signal type. `storage.sync<T>` and `storage.async<T>` are equivalent convenience entry points and add no behavior.

### Implement async persistence independently from AsyncSignalImpl

Although both abstractions expose `AsyncState<T>`, their ownership differs. `AsyncSignalImpl` manages an asynchronous reactive source; `AsyncPersistSignal` must distinguish initial read results from explicit values because only the latter may write. Subclassing or forwarding through `AsyncSignalImpl` would require persistence-specific origin metadata and lifecycle hooks. A small dedicated `SignalImpl<AsyncState<T>>` keeps that distinction local and explicit.

## Risks / Trade-offs

- **Completion causes a second notification.** `setFuture` publishes loading and later success/error. Consumers should use AsyncState-aware rendering.
- **Loading has no previous data.** This change uses `AsyncLoading<T>` rather than retaining a stale successful value during a new Future assignment.
- **Direct state assignment has persistence semantics.** `AsyncSuccess` writes; loading and error do not. This must be prominent in Dartdoc.
- **Writes may overlap and finish out of order.** Ordering belongs to the callback or storage adapter.
- **The barrier ignores older writes.** `ensureWrite()` represents the latest accepted write, not a full flush of all in-flight callbacks.
- **Write failures remain non-reporting.** Read and assigned-Future failures are reactive state; persistence failures are deliberately outside that state channel.
- **Synchronous storage compatibility is runtime-checked.** `FutureOr` cannot statically guarantee an immediate read, so the synchronous factory fails fast on a Future result.

## Migration Plan

1. Keep the completed synchronous callback and typed-storage APIs.
2. Change `AsyncPersistSignal<T>` and its implementation to `Signal<AsyncState<T>>` with eager read transitions.
3. Add `setFuture`, direct AsyncState assignment semantics, current-operation race protection, and explicit-assignment barrier handling.
4. Adapt asynchronous storage construction so all `FutureOr` outcomes become AsyncState transitions.
5. Replace Future-valued persistence tests and examples with loading, success, error, supersession, and write-eligibility coverage.
6. Update Dartdoc, user documentation, and Jolt skill references; mention the separately planned AsyncState readable helpers where useful.
7. Format, analyze, run focused and full tests, then strictly validate the change and skill package.

This is a source-breaking library change but requires no persisted-data migration because storage keys and serialized values are unchanged.
