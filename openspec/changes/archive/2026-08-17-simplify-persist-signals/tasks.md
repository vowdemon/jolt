## 1. Persistence Write Semantics

- [x] 1.1 Remove built-in write scheduling and multi-Future tracking; invoke each eligible write immediately and retain only the latest callback Future.
- [x] 1.2 Keep write failures non-reporting while preserving optimistic state and disposal safety.
- [x] 1.3 Cover overlapping writes, latest-write completion, callback failures, and disposal for synchronous persistence.

## 2. Synchronous PersistSignal

- [x] 2.1 Expose eager callback construction through the unnamed `PersistSignal<T>` constructor.
- [x] 2.2 Preserve immediate `Signal<T>` assignment and `FutureOr<void>` writes without built-in scheduling policy.
- [x] 2.3 Remove synchronous lazy construction and migrate tests to the final callback API.

## 3. AsyncState-Valued AsyncPersistSignal

- [x] 3.1 Change `AsyncPersistSignal<T>` and its implementation to `Signal<AsyncState<T>>`, starting in loading and publishing the initial read as success or error without writing it back.
- [x] 3.2 Implement `set(T)` and direct AsyncState assignment so success persists while loading and error remain state-only.
- [x] 3.3 Implement `setFuture(Future<T>)` with loading, success, error, and current-operation token semantics.
- [x] 3.4 Ensure every explicit assignment supersedes the initial read or pending Future and stale completion cannot update state or write.
- [x] 3.5 Make `ensureWrite()` wait for the current explicit Future assignment and latest resulting write, but not the initial read or older writes.
- [x] 3.6 Cover read outcomes, all assignment forms, races, write eligibility, barriers, write failures, and disposal with focused tests.

## 4. Typed Storage Integration

- [x] 4.1 Add `PersistSignalStorage<K>` with generic `FutureOr` read/write operations, strongly typed keys, and a storage-controlled optional initial callback.
- [x] 4.2 Add static storage factories and equivalent `PersistSignalStorageX<K>.sync<T>` and `.async<T>` convenience methods.
- [x] 4.3 Require an immediate read from synchronous storage and fail fast on a Future result.
- [x] 4.4 Normalize synchronous values, Futures, synchronous throws, and asynchronous failures from async storage into AsyncState transitions.
- [x] 4.5 Update async storage and extension tests for loading, success, error, key forwarding, optional initial values, debug forwarding, and persistence writes.
- [x] 4.6 Mark `_readStorageSync` with supported prefer-inline pragmas.

## 5. Public API And Documentation

- [x] 5.1 Remove legacy persistence factories, lazy construction, initialization flags, temporary initial values, and initialization helper APIs.
- [x] 5.2 Keep public exports for both persistence signals, typed storage, and its extension without changing `SignalImpl` or adding collection variants.
- [x] 5.3 Update Dartdoc and advanced-techniques documentation for AsyncState reads, `set`, `setFuture`, direct state assignment, races, and callback-owned write scheduling.
- [x] 5.4 Update the `use-jolt` skill and persistence reference to the final AsyncState-valued API and storage extension construction.
- [x] 5.5 Coordinate examples with the separately planned `AsyncStateReadableX<T>` helpers without coupling persistence to `AsyncSignalImpl`.

## 6. Verification

- [x] 6.1 Format and analyze the affected Jolt sources and tests.
- [x] 6.2 Run focused persistence tests and the full `packages/jolt` test suite.
- [x] 6.3 Strictly validate this OpenSpec change and validate the modified skill package after implementation.
