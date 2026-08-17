# async-state-readable-helpers Specification

## Purpose

Defines uniform async-state inspection and mapping on every readable async-state value while preserving normal reactive read semantics.

## Requirements

### Requirement: Async-state helpers are available on readable values
Every `Readable<AsyncState<T>>` SHALL expose `data`, `isLoading`, `isSuccess`, `isError`, `error`, `stackTrace`, and `map` through the public Jolt API, regardless of whether the readable is an async signal, computed value, read-only view, or another compatible implementation.

#### Scenario: Async signal uses the shared helpers
- **WHEN** a caller holds a statically typed `AsyncSignal<T>`
- **THEN** the caller can inspect and map its current async state through the shared helper API

#### Scenario: Computed async state uses the shared helpers
- **WHEN** a computed value exposes `AsyncState<T>`
- **THEN** the caller can use the same inspection and mapping helpers without converting it to an async signal

#### Scenario: Read-only async state uses the shared helpers
- **WHEN** a read-only view exposes `AsyncState<T>`
- **THEN** the caller can use the same inspection and mapping helpers without gaining write or source-control operations

### Requirement: Inspection helpers mirror the current AsyncState
The shared inspection helpers SHALL return the values defined by the readable's current `AsyncState<T>` without caching, copying, or independently interpreting that state.

#### Scenario: Loading state
- **WHEN** the readable's current value is `AsyncLoading<T>`
- **THEN** `isLoading` is true, the success and error flags are false, and `data`, `error`, and `stackTrace` are null

#### Scenario: Success state
- **WHEN** the readable's current value is `AsyncSuccess<T>`
- **THEN** `isSuccess` is true, `data` contains the successful value, and the loading and error views match that state

#### Scenario: Error state
- **WHEN** the readable's current value is `AsyncError<T>`
- **THEN** `isError` is true, `error` and `stackTrace` expose the failure details, and the loading and success views match that state

### Requirement: Mapping delegates to the current AsyncState
The shared `map<R>` helper SHALL select the callback for the readable's current state using the same arguments and nullable-result behavior as `AsyncState<T>.map<R>`.

#### Scenario: Matching callback is provided
- **WHEN** the current state's callback is supplied to `map`
- **THEN** that callback runs once with the current state's values and its result is returned

#### Scenario: Matching callback is omitted
- **WHEN** the callback for the current state is omitted
- **THEN** `map` returns null

### Requirement: Helper reads preserve reactive tracking
Each shared helper SHALL obtain the current state through the readable's normal `value` read so dependency tracking and non-reactive readable behavior remain unchanged.

#### Scenario: Helper is read in a reactive computation
- **WHEN** an effect or computed value reads an inspection helper or invokes `map`
- **THEN** it subscribes to the readable exactly as a direct `value` read would and re-evaluates after relevant state replacement

#### Scenario: Helper reads the latest state
- **WHEN** the readable's value is replaced before a helper is invoked
- **THEN** the helper reflects the replacement state rather than an earlier cached state

### Requirement: AsyncSignal retains source lifecycle behavior
Moving derived state helpers to the shared readable API SHALL NOT change async-signal construction, source replacement, stale-source rejection, source disposal, or `fetch` completion behavior.

#### Scenario: Source is replaced
- **WHEN** an async signal fetches a new source while an earlier source remains active
- **THEN** the earlier source is disposed and its late emissions remain ignored

#### Scenario: Async signal is disposed
- **WHEN** an async signal is disposed with an active source
- **THEN** that source is disposed and later emissions do not replace the signal state
