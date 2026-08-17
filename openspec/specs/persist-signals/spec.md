# persist-signals Specification

## Purpose

Defines storage-backed reactive values whose assignments are persisted through synchronous or asynchronous operations, with asynchronous loading and failure represented explicitly as reactive state.

## Requirements

### Requirement: Persistence integrations support direct callbacks
Persistent signals SHALL expose direct callback construction through the unnamed `PersistSignal` and `AsyncPersistSignal` constructors, SHALL allow writes to complete synchronously or asynchronously, and SHALL NOT require callers to adopt the storage abstraction.

#### Scenario: Caller integrates synchronous storage
- **WHEN** a caller creates `PersistSignal(...)` with a synchronous read callback and a write callback
- **THEN** the signal obtains its initial value from the read callback and sends later assigned values to the write callback

#### Scenario: Caller integrates asynchronous storage
- **WHEN** a caller creates `AsyncPersistSignal(...)` with an asynchronous read callback and a write callback
- **THEN** the signal represents the read through async-state transitions and sends eligible later assignments to the write callback

#### Scenario: Caller performs mapping inside callbacks
- **WHEN** storage requires a key, fallback value, encoding, or decoding
- **THEN** the caller can perform those operations inside the read and write callbacks

#### Scenario: Caller controls write scheduling
- **WHEN** persistence requires throttling, debouncing, serialization, coalescing, retry, or transactions
- **THEN** the caller can implement that policy inside the write callback or a callback wrapper

### Requirement: Typed storage integration owns keyed access
`PersistSignalStorage<K>` SHALL expose generic `read<T>(K key, [initial])` and `write<T>(K key, T value)` operations returning `FutureOr`; the static storage factories and `PersistSignalStorageX<K>` convenience methods SHALL adapt those operations without adding codec or scheduling policy.

#### Scenario: Non-string key
- **WHEN** a caller supplies a storage and key with the same non-string type `K`
- **THEN** storage construction forwards that key without erasing its static type

#### Scenario: Storage returns a stored value
- **WHEN** the storage finds a value for the requested key, including a stored nullable value
- **THEN** it can return that value without invoking the initial-value function

#### Scenario: Storage selects the initial value
- **WHEN** the storage considers the requested key missing
- **THEN** it can invoke and return the caller-provided initial-value function

#### Scenario: Initial value is omitted
- **WHEN** a caller omits the initial-value function
- **THEN** the storage receives no fallback and owns the missing-value behavior

#### Scenario: Synchronous storage read
- **WHEN** `PersistSignal.storage<K, T>` or `storage.sync<T>` receives `T` synchronously from storage
- **THEN** the returned signal exposes that value immediately

#### Scenario: Synchronous construction receives a Future
- **WHEN** synchronous storage construction receives `Future<T>` from storage
- **THEN** construction fails immediately with guidance to use asynchronous storage construction

#### Scenario: Asynchronous storage read succeeds
- **WHEN** `AsyncPersistSignal.storage<K, T>` or `storage.async<T>` receives either `T` or `Future<T>` and the read succeeds
- **THEN** the signal transitions from `AsyncLoading<T>` to `AsyncSuccess<T>` with the stored value

#### Scenario: Asynchronous storage read fails
- **WHEN** asynchronous storage construction encounters either a synchronous throw or a failed Future
- **THEN** construction returns a signal whose state transitions from `AsyncLoading<T>` to `AsyncError<T>` with the error and stack trace

#### Scenario: Storage-backed assignment
- **WHEN** either storage-backed persistent signal accepts a value eligible for persistence
- **THEN** it forwards the configured key and value to storage using immediate-callback and last-write-barrier semantics

#### Scenario: Storage extension construction
- **WHEN** a caller invokes `storage.sync<T>` or `storage.async<T>` with a key, optional initial-value function, and optional debug configuration
- **THEN** it returns behavior equivalent to the corresponding static storage factory and forwards those arguments unchanged

### Requirement: Synchronous persistence exposes an ordinary value signal
`PersistSignal<T>` SHALL expose `T` as its signal value, initialize eagerly from its direct read callback or storage read, and update its in-memory value immediately before invoking write for a later assignment.

#### Scenario: Synchronous initialization
- **WHEN** a synchronous persistent signal is constructed
- **THEN** its read source runs during construction and its value is immediately available

#### Scenario: Optimistic synchronous assignment
- **WHEN** a caller assigns a new value
- **THEN** observers can read the new value immediately while the write callback may complete later

### Requirement: Asynchronous persistence exposes AsyncState
`AsyncPersistSignal<T>` SHALL expose `AsyncState<T>` as its signal value, SHALL represent asynchronous completion through reactive state replacement, and SHALL distinguish initial reads from explicit persistence assignments.

#### Scenario: Initial asynchronous read is pending
- **WHEN** an asynchronous persistent signal is constructed and its read has not completed
- **THEN** its current value is `AsyncLoading<T>`

#### Scenario: Initial asynchronous read succeeds
- **WHEN** the current initial read completes successfully
- **THEN** the signal transitions to `AsyncSuccess<T>` and does not write that value back automatically

#### Scenario: Initial asynchronous read fails
- **WHEN** the current initial read throws or completes with an error
- **THEN** the signal transitions to `AsyncError<T>` with the error and stack trace and performs no write

#### Scenario: Assign an available value
- **WHEN** a caller invokes `set(T)`
- **THEN** the signal immediately becomes `AsyncSuccess<T>` and invokes write with that value

#### Scenario: Assign a Future value
- **WHEN** a caller invokes `setFuture(Future<T>)`
- **THEN** the signal immediately becomes `AsyncLoading<T>` and observes that Future as an explicit persistence assignment

#### Scenario: Assigned Future succeeds
- **WHEN** the current explicitly assigned Future completes successfully
- **THEN** the signal becomes `AsyncSuccess<T>` and invokes write with its result

#### Scenario: Assigned Future fails
- **WHEN** the current explicitly assigned Future completes with an error
- **THEN** the signal becomes `AsyncError<T>` with the error and stack trace and performs no write

#### Scenario: Assign AsyncSuccess directly
- **WHEN** a caller assigns `AsyncSuccess<T>` through the signal value setter
- **THEN** the signal exposes that state immediately and invokes write with its successful value

#### Scenario: Assign non-success state directly
- **WHEN** a caller assigns `AsyncLoading<T>` or `AsyncError<T>` through the signal value setter
- **THEN** the signal exposes that state, supersedes pending read or assignment completion, and performs no write

### Requirement: The current asynchronous operation wins races
An asynchronous persistent signal SHALL apply a read or assigned Future result only while that operation remains current and SHALL prevent stale completion from replacing state or invoking write.

#### Scenario: Local assignment supersedes initial read
- **WHEN** any explicit state or value assignment occurs while the initial read is pending
- **THEN** later completion of that read neither replaces the assigned state nor writes its result

#### Scenario: Later Future supersedes earlier Future
- **WHEN** `setFuture` is invoked again before an earlier assigned Future completes
- **THEN** completion of the earlier Future neither replaces the current state nor writes its result

#### Scenario: Direct state assignment supersedes Future
- **WHEN** a direct `AsyncState<T>` assignment occurs while an explicitly assigned Future is pending
- **THEN** that Future is superseded and its later completion has no state or persistence effect

#### Scenario: Signal is disposed while operation is pending
- **WHEN** the signal is disposed before a read or assigned Future completes
- **THEN** later completion does not replace state or invoke write

### Requirement: Persistence callbacks use a last-write barrier
Eligible persistence assignments SHALL invoke write as soon as their value is available, SHALL NOT serialize, throttle, or coalesce callback invocations, SHALL preserve optimistic state, and SHALL expose `ensureWrite()` as a barrier for the current explicit Future assignment and most recent callback-returned Future.

#### Scenario: Available assignments are forwarded immediately
- **WHEN** synchronous values or direct `AsyncSuccess<T>` states are assigned while earlier write callback Futures remain pending
- **THEN** write is invoked immediately for each value without waiting for earlier callbacks

#### Scenario: Future assignment resolves
- **WHEN** the current explicit Future assignment resolves successfully
- **THEN** write is invoked immediately with its result before `ensureWrite()` completes

#### Scenario: Callback wrapper owns scheduling
- **WHEN** the write callback delays or combines persistence work and returns a Future representing that work
- **THEN** the signal does not alter that policy and treats the returned Future as completion of that invocation

#### Scenario: Ensure write ignores initial read
- **WHEN** `ensureWrite()` is invoked while only the initial read remains pending
- **THEN** it does not wait for the read because no explicit persistence assignment exists

#### Scenario: Ensure write waits for current explicit Future
- **WHEN** `ensureWrite()` is invoked after `setFuture`
- **THEN** it waits until that assignment settles or is superseded and then waits for the most recent resulting write callback Future

#### Scenario: Ensure write ignores older callbacks
- **WHEN** write callback Futures overlap
- **THEN** `ensureWrite()` waits only for the most recent callback Future and does not drain earlier callbacks

#### Scenario: Write callback fails
- **WHEN** write throws or completes with an error
- **THEN** the optimistic signal state remains unchanged, no `AsyncError<T>` transition is introduced, `ensureWrite()` remains non-reporting, and later writes remain eligible
