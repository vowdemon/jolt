## Why

`PersistSignal` currently combines synchronous state, asynchronous initialization, temporary values, stale-read protection, and persistence writes in one abstraction. Separating asynchronous persistence into an `AsyncState<T>`-valued signal makes loading and failure explicit reactive values instead of parallel initialization flags while preserving direct `read` and `write` integration.

## What Changes

- Keep synchronous persistence on `PersistSignal<T>` and expose direct callbacks through its unnamed constructor.
- Add `AsyncPersistSignal<T>` as a `Signal<AsyncState<T>>` with direct callbacks through its unnamed constructor.
- Start asynchronous persistence in `AsyncLoading<T>`, publish initial read completion as `AsyncSuccess<T>` or `AsyncError<T>`, and never write the initial read result back automatically.
- Support immediate local values through `set(T)`, asynchronous local values through `setFuture(Future<T>)`, and direct `AsyncState<T>` assignment with explicit persistence rules.
- Persist `AsyncSuccess<T>` assignments, keep `AsyncLoading<T>` and `AsyncError<T>` assignments state-only, and prevent superseded reads or assignments from replacing state or writing stale data.
- Add static `PersistSignal.storage<K, T>` and `AsyncPersistSignal.storage<K, T>` factories backed by `PersistSignalStorage<K>`, plus equivalent `storage.sync<T>(...)` and `storage.async<T>(...)` extension methods.
- Let storage own missing-value detection and optional fallback evaluation while allowing reads and writes to complete through `FutureOr`.
- Invoke each eligible `write` immediately and retain only the most recent callback-returned Future so `ensureWrite()` remains a last-write barrier without imposing scheduling policy.
- **BREAKING** Replace `PersistSignal.async` and `PersistSignal.lazyAsync` with `AsyncPersistSignal`.
- **BREAKING** Remove synchronous lazy initialization, including `PersistSignal.lazySync` and the `lazy` option; the unnamed callback constructor and synchronous storage factory always read during construction.
- **BREAKING** Remove the `throttle` option and built-in write serialization/coalescing; callers that need scheduling policy implement it inside `write` or storage.
- **BREAKING** Remove `initialValue`, `isInitialized`, `version`, `ensure()`, and `getEnsured()`; asynchronous state is represented directly by `AsyncState<T>`.
- **BREAKING** Replace `PersistSignal.sync` with the unnamed callback constructor `PersistSignal(...)`.
- Preserve callback-based persistence alongside typed storage integration; do not add codec, collection-signal, or `SignalImpl` extensions.

## Capabilities

### New Capabilities

- `persist-signals`: Defines callback-backed synchronous and AsyncState-valued persistent signals, typed storage integration, write barriers, and asynchronous race semantics.

### Modified Capabilities

None.

## Impact

- Affects `packages/jolt/lib/src/tricks/persist_signal.dart`, persistence tests, exports, advanced-techniques documentation, and Jolt skill references.
- Existing eager synchronous callback call sites migrate from `PersistSignal.sync` to `PersistSignal(...)`.
- Existing asynchronous persistence call sites migrate to `AsyncPersistSignal<T>` and inspect `signal.value` as `AsyncLoading`, `AsyncSuccess`, or `AsyncError` rather than awaiting a Future or calling initialization helpers.
- Storage-backed call sites use the static typed factories or equivalent storage extension methods. Synchronous construction requires an immediate read result; asynchronous construction normalizes both synchronous and asynchronous read completion into `AsyncState<T>` transitions.
- Local asynchronous assignment uses `setFuture`; only a successful result that remains current is persisted.
- Write callbacks may overlap; `ensureWrite()` waits for the current explicit Future assignment and most recent write callback Future, not earlier callbacks or the initial read.
- The model composes with the separately planned `AsyncStateReadableX<T>` helpers without making persistence depend on `AsyncSignalImpl` source lifecycle.
- No new package dependencies, codecs, `SignalImpl` changes, persisted-data migration, or collection-signal variants are introduced.
