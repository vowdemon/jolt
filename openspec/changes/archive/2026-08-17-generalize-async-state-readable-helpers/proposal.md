## Why

`AsyncSignal<T>` currently repeats `AsyncState<T>` accessors and mapping behavior in both its interface and implementation. Those helpers depend only on a readable's current `AsyncState`, so limiting them to `AsyncSignal` adds delegation code and prevents computed or read-only async-state values from using the same API.

## What Changes

- Add an `AsyncStateReadableX<T>` extension on `Readable<AsyncState<T>>` that exposes `data`, `isLoading`, `isSuccess`, `isError`, `error`, `stackTrace`, and `map` by reading the current state.
- Make the helpers available to `AsyncSignal`, `Computed<AsyncState<T>>`, `Readonly<AsyncState<T>>`, and other readable async-state views with the same tracked-read behavior.
- Keep `AsyncSignal<T>` focused on construction and asynchronous source replacement through `fetch`.
- Preserve `AsyncState` variant behavior, `AsyncSignal` source lifecycle, error handling, and reactive dependency tracking.
- **BREAKING** Remove the helper declarations from the `AsyncSignal<T>` interface and their overrides from `AsyncSignalImpl<T>`; ordinary statically typed calls remain available through the exported extension, while dynamic dispatch and custom overrides of those helpers are no longer supported.

## Capabilities

### New Capabilities

- `async-state-readable-helpers`: Defines state inspection and mapping helpers shared by every `Readable<AsyncState<T>>`.

### Modified Capabilities

None.

## Impact

- Affects `packages/jolt/lib/src/jolt/async.dart`, `packages/jolt/lib/src/jolt/impl/async.dart`, async signal tests, API documentation, tutorials, and Jolt skill references.
- Existing code importing `package:jolt/jolt.dart` and calling helpers on a statically typed `AsyncSignal<T>` remains source-compatible.
- Callers relying on `dynamic` helper dispatch or custom `AsyncSignal` helper overrides must read/map `value` directly or adopt the extension's fixed semantics.
- No package dependencies, `AsyncState` variants, source implementations, or low-level reactive nodes change.
