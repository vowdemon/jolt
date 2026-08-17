## 1. Shared Async-State Readable API

- [x] 1.1 Add the documented `AsyncStateReadableX<T>` extension on `Readable<AsyncState<T>>` with state inspection getters and `map<R>`, preserving the existing `map` inline hints.
- [x] 1.2 Remove the derived helper declarations from `AsyncSignal<T>` and their forwarding overrides from `AsyncSignalImpl<T>` while leaving constructors and `fetch` unchanged.
- [x] 1.3 Confirm the extension is exported through the public async and Jolt libraries and ordinary statically typed `AsyncSignal<T>` call sites continue to compile.

## 2. Shared Helper Tests

- [x] 2.1 Move async-signal convenience expectations to the shared readable contract and cover loading, success, error, nullable results, and `map` callback selection.
- [x] 2.2 Add coverage proving `Computed<AsyncState<T>>` and read-only async-state views expose the same helpers without write or source-control APIs.
- [x] 2.3 Add reactive tracking coverage proving helper reads subscribe through `value`, reflect replacement states, and do not cache an earlier state.
- [x] 2.4 Retain and run source replacement, stale emission, completion, and disposal tests to prove `AsyncSignal.fetch` lifecycle behavior is unchanged.

## 3. Documentation And Migration

- [x] 3.1 Update async API Dartdoc and advanced-techniques documentation to present the helpers as shared `Readable<AsyncState<T>>` operations.
- [x] 3.2 Update the `use-jolt` skill and async reference with async signal, computed, and readonly helper examples.
- [x] 3.3 Document the breaking static-dispatch boundary for `dynamic` receivers and custom helper overrides, including direct `value` access as the migration path.

## 4. Verification

- [x] 4.1 Format and analyze affected Jolt sources and tests.
- [x] 4.2 Run focused async-state and async-signal tests followed by the full `packages/jolt` test suite.
- [x] 4.3 Validate the modified skill package and run strict OpenSpec validation for this change.
