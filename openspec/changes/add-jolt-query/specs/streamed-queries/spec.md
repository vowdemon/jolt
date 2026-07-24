## ADDED Requirements

### Requirement: Attempt-aware stream-backed query function helper
The system SHALL define public `StreamRefetchMode { reset, append, replace }` and `streamedQuery<Chunk, Data>({required Stream<Chunk> Function(QueryContext) stream, required Data Function() initial, required Data Function(Data, Chunk) reduce, StreamRefetchMode mode = StreamRefetchMode.reset})` returning an ordinary `QueryFunction<Data>`. `streamedListQuery<Chunk>` SHALL expose the common list-accumulation case with the same modes and return `QueryFunction<IList<Chunk>>`. `initial` SHALL be invoked once per retry attempt, the reducer SHALL be synchronous, and each retry attempt SHALL create a new StreamSubscription. The operation SHALL be guarded after `initial` returns and again after the stream factory returns before subscription, so reentrant cancellation, replacement, removal, or disposal cannot start later stale work. Both helpers SHALL work with inline Query recipes and class-first Query fetch methods without a `StreamedQuery` class or cache discriminator.

#### Scenario: Streamed list receives chunks
- **WHEN** streamedListQuery receives two chunks and closes normally
- **THEN** the ordinary query result contains those chunks in arrival order without requiring a user reducer

#### Scenario: First attempt starts
- **WHEN** an enabled streamed query begins
- **THEN** it invokes `initial()` once, creates one stream with QueryContext, and subscribes once

#### Scenario: Retry attempt starts
- **WHEN** a failed attempt qualifies for retry
- **THEN** a new `initial()` invocation and a new StreamSubscription are created

#### Scenario: Initial callback supersedes the operation
- **WHEN** `initial()` synchronously cancels, replaces, removes, or disposes the current operation
- **THEN** the operation guard prevents the stream factory from running

#### Scenario: Stream factory supersedes the operation
- **WHEN** the stream factory synchronously cancels, replaces, removes, or disposes the current operation
- **THEN** the returned stale stream is not subscribed

#### Scenario: Ordinary recipe later uses the key
- **WHEN** a normal Future-based Query later initiates work for the same structural key
- **THEN** the shared entry uses that initiating Query plan without streamed behavior becoming identity

### Requirement: Incremental state and normal completion
Before the first committed chunk of an absent reset or append operation, the query SHALL be pending and fetching. After a chunk is committed it SHALL be successful while remaining fetching. Normal stream close SHALL make fetch status idle and accept the final accumulator. An empty reset or replace attempt SHALL accept its initial Data. An empty append attempt SHALL retain a present logical baseline, or accept its initial Data when the baseline was absent. Replace mode SHALL retain old presentation until its final result is accepted.

#### Scenario: Stream waits for first chunk
- **WHEN** no value has been emitted and no baseline is visible
- **THEN** query status is pending, fetch status is fetching, and data is absent

#### Scenario: First incremental chunk arrives
- **WHEN** reset or append reduces and commits its first chunk
- **THEN** data becomes present and successful while fetch status remains fetching

#### Scenario: Stream closes normally
- **WHEN** no retry result predicate requests another attempt
- **THEN** the final Data remains successful and fetch status becomes idle

#### Scenario: Stream emits no chunks
- **WHEN** reset or replace closes normally without an event, or append closes with no present baseline
- **THEN** the Data produced by that attempt's `initial()` is treated as the final result

#### Scenario: Empty append has cached baseline
- **WHEN** append mode starts with present cached Data and closes without a chunk
- **THEN** the captured baseline is the final result and `initial()` does not replace it

#### Scenario: Replace waits for completion
- **WHEN** replace mode receives chunks
- **THEN** old cached data remains visible and private accumulation is not published before accepted close

### Requirement: Data-typed retry classification
Streamed queries SHALL use `RetryPolicy<Data>`, never `RetryPolicy<Chunk>`. Exception predicates SHALL receive stream and reducer failures. Result predicates SHALL be evaluated exactly once after normal close using the final accumulated Data and SHALL never run for individual chunks. A handled result whose finite retry budget is exhausted SHALL be accepted as success.

#### Scenario: Stream throws
- **WHEN** a Stream emits an error
- **THEN** the exception outcome enters the Data-typed RetryStrategy exception path

#### Scenario: Reducer throws
- **WHEN** synchronous reduction throws
- **THEN** that error enters the same exception retry path and the failed reducer step is not committed

#### Scenario: Chunks arrive before close
- **WHEN** several chunks are successfully reduced
- **THEN** no result predicate is invoked for those intermediate values

#### Scenario: Stream closes with final Data
- **WHEN** the Stream closes normally
- **THEN** the result predicate is invoked once with final Data

#### Scenario: Result retry budget is exhausted
- **WHEN** the final Data is handled by the result predicate but no retry remains
- **THEN** that Data is accepted and committed as success

### Requirement: Per-operation baseline and explicit cancellation ownership
Every streamed logical operation SHALL retain the private state required by its
mode. Append SHALL retain a pre-operation `QueryValue<Data>` baseline and
replace SHALL use a private attempt accumulator. Reset SHALL instead resolve
the query's current fetched state at the beginning of every attempt: when
fetched it SHALL restore the query's configured reset/initial state before
subscription, and when seeded only by initial data it SHALL preserve that
visible value on the first attempt. Operation identity, entry incarnation,
operation generation, explicit cancellation, replacement, and disposal SHALL
guard every later chunk, retry, and final commit. The partial-commit guard SHALL
run both before and after the user-configured structural reconciler, because
that callback MAY synchronously supersede the operation. An ordinary data
revision change SHALL NOT by itself supersede the streamed operation.

`setQueryData`, `updateQueryData`, bulk writes, and conditional restore SHALL NOT supersede or cancel an active streamed operation. A manual value SHALL become visible synchronously, while a later accepted stream chunk or final result MAY replace it. A caller that needs the manual value to remain authoritative SHALL explicitly await `cancelQueries` before writing.

#### Scenario: External write follows partial stream data
- **WHEN** reset or append publishes partial data and setQueryData writes another value without cancellation
- **THEN** the stream operation remains active and a later accepted chunk may replace the manual value

#### Scenario: External write precedes replace completion
- **WHEN** replace mode accumulates privately and an external write occurs without cancellation
- **THEN** the manual value is visible until the active replace operation may commit its accepted final result

#### Scenario: Explicit cancellation protects an external write
- **WHEN** the caller awaits cancelQueries before writing during a streamed operation
- **THEN** the cancelled subscription's late chunks and completion cannot overwrite the manual value

#### Scenario: Retry reuses the logical baseline
- **WHEN** an append attempt fails after partial output and another retry is eligible
- **THEN** the next append attempt seeds its private accumulator from the logical baseline rather than failed partial output and does not publish that seed merely because retry starts

#### Scenario: Entry is removed and recreated
- **WHEN** removal and recreation occur while a subscription is active
- **THEN** incarnation and operation-generation guards reject all old chunks, retries, and completion

#### Scenario: Structural reconciler supersedes a partial commit
- **WHEN** a streamed partial invokes a reconciler that synchronously replaces or removes the operation
- **THEN** a second ownership guard rejects the old partial before any state write or cache event

### Requirement: Reset mode fetched-state and retry semantics
Reset mode SHALL evaluate whether the query has accepted a data or terminal
error completion at the beginning of every attempt. Initial-data seeding alone
SHALL not count as fetched. When the query is fetched, attempt start SHALL
restore the configured reset state while retaining the active operation lane:
configured initial data and its timestamp produce success presentation,
otherwise data becomes absent and status pending; terminal and transient
failure presentation is cleared, fetch status remains fetching, completion
visibility returns to the reset baseline, and the transition is published. When
the first attempt is seeded only by initial data, it SHALL not clear that data;
the first chunk SHALL reduce from it. `initial()` SHALL still be invoked once
per attempt and supplies the reducer seed only when reset-state data is absent.

Accepted partial values MAY remain visible during retry delay. When the next
retry attempt actually begins, it SHALL reevaluate fetched state and restore
reset state before creating the new subscription, so the failed attempt's
partial value no longer remains visible after retry start.

#### Scenario: Initial-data stream starts for the first time
- **WHEN** a reset-mode query seeded only by initial data starts its first streamed attempt
- **THEN** the seed remains visible, isFetched remains false, and the first chunk reduces from that initial data

#### Scenario: Reset refetch starts after a fetched value
- **WHEN** reset mode refetches a query that has accepted a completion
- **THEN** attempt start restores configured initial data when present or clears to pending absence otherwise before new chunks arrive

#### Scenario: Reset attempt fails after chunks
- **WHEN** partial values were committed and retry remains eligible
- **THEN** the partial value may stay visible during delay but the next attempt start restores reset state before accumulating from initial data or a fresh initial value

#### Scenario: Reset exception retries exhaust
- **WHEN** the last reset attempt fails and no retry remains
- **THEN** terminal failure classifies from the QueryValue visible after the latest reset-state or partial transition

### Requirement: Append mode retry semantics without duplication
Append mode SHALL capture present cached Data as a private logical-operation baseline; if data is absent, it SHALL use that attempt's `initial()` result. Each attempt SHALL initialize one accumulator from that baseline or initial value, then reduce every chunk serially into the current accumulator. A retry SHALL start a new private accumulator from the logical baseline, never from partial output of an earlier failed attempt. The current cache value MAY remain visible during retry delay, and retry start SHALL NOT restore or publish the baseline; only an accepted chunk or final result MAY replace that value.

#### Scenario: Append refetch emits chunks
- **WHEN** append mode starts with cached Data
- **THEN** the first chunk reduces into the captured baseline and each later chunk reduces into the preceding accumulated result before incremental publication

#### Scenario: Append attempt retries
- **WHEN** the first attempt appended chunks and then failed
- **THEN** the next attempt rebuilds from the pre-operation baseline so repeated transport chunks are not duplicated

#### Scenario: Append exception retries exhaust
- **WHEN** the final attempt fails after partial commits
- **THEN** terminal failure leaves the current QueryValue unchanged and classifies the failure as retained-data or loading from that current presence

#### Scenario: Append fails before every first chunk with baseline
- **WHEN** every attempt fails before committing a chunk, the logical baseline was present, and no external write occurs
- **THEN** the baseline remains visible with retained-data failure state

### Requirement: Replace mode private retry semantics
Replace mode SHALL keep the pre-operation cached value visible, use a private accumulator initialized independently for every attempt, discard failed partial accumulators, and atomically commit only an accepted final Data while the guarded operation identity remains current.

#### Scenario: Replace attempt fails after chunks
- **WHEN** retry remains eligible
- **THEN** its private partial accumulator is discarded and the next attempt starts from a new initial value

#### Scenario: Replace succeeds after retry
- **WHEN** a later attempt closes with accepted Data
- **THEN** the then-current visible value is replaced once with the complete final Data

#### Scenario: Replace retries exhaust on exception
- **WHEN** every attempt ends in exception
- **THEN** terminal failure leaves the then-current cached value unchanged and reports failure from its current presence

### Requirement: Exhausted exception state without a committed chunk
When exception retry exhausts, terminal failure SHALL NOT write `initial()`, an
append logical baseline, or a failed private accumulator. It SHALL preserve the
`QueryValue<Data>` currently visible at that instant. Present data SHALL
produce retained-data/refetch failure, while absent data SHALL produce loading
failure. Without an external write or accepted output, reset reflects its
latest configured reset state, append and replace retain a present visible
baseline or remain absent when none existed, and an `initial()` result SHALL
not become visible merely because an attempt failed before a chunk or normal
close.

#### Scenario: Reset with no configured initial data fails before first chunk
- **WHEN** fetched reset mode restores an absent reset state and exhausts exception retry before another chunk
- **THEN** data is absent and the query reports loading failure

#### Scenario: Reset with configured initial data fails before first chunk
- **WHEN** reset mode preserves or restores configured initial data and exhausts exception retry before another chunk
- **THEN** that initial data remains present and the query reports retained-data failure

#### Scenario: Append has no baseline and fails before first chunk
- **WHEN** append mode began absent, receives no external write, and exhausts exception retry before a committed chunk
- **THEN** data remains absent and the query reports loading failure

#### Scenario: Replace has a present baseline and fails before first chunk
- **WHEN** replace mode began with data, receives no external write, and exhausts exception retry before a committed chunk
- **THEN** the baseline remains present and the query reports retained-data failure

#### Scenario: Replace has no baseline and fails before first chunk
- **WHEN** replace mode began absent, receives no external write, and exhausts exception retry before a committed chunk
- **THEN** data remains absent and the query reports loading failure

#### Scenario: Manual write is followed by exhausted retry
- **WHEN** setQueryData or updateQueryData writes a present manual value after the latest accepted stream output and exception retry exhausts before another output is accepted
- **THEN** terminal failure preserves the manual value and reports retained-data failure

### Requirement: Stream cancellation and ordinary cache integration
Cancellation SHALL cancel the active StreamSubscription and trigger the Query cancellation token. When subscription cancellation must be awaited, cancellation SHALL immediately release and revert the logical QueryEntry operation lane while the cancelled operation's own Future continues waiting for cleanup. A newly attached observer or imperative caller SHALL therefore be able to start a new operation before old subscription cleanup completes. Operation identity, incarnation, and generation guards SHALL prevent the detached cleanup from changing the new operation or cache state. Streamed helpers SHALL otherwise use ordinary QueryEntry state, filters, invalidation, observers, focus, online mode, polling, retention, structural sharing, and cache events. No separate streamed entry type SHALL be public or part of identity.

#### Scenario: Active stream is cancelled
- **WHEN** `cancelQueries` matches a streamed operation
- **THEN** its token fires, subscription cancellation is awaited as required, and ordinary query revert semantics apply

#### Scenario: Transport emits after cancellation
- **WHEN** a source produces a late chunk or close event
- **THEN** guards prevent state or cache changes

#### Scenario: Observer reattaches while cancellation cleanup is pending
- **WHEN** final detachment cancels an absent streamed operation whose subscription cancellation Future has not completed and a new enabled observer attaches
- **THEN** the new observer starts a new subscription immediately, and completion of the old cleanup cannot alter its result

#### Scenario: Reset while subscription cleanup is pending
- **WHEN** reset cancels a streamed operation whose subscription cancellation Future is gated
- **THEN** reset state and the logical lane are available immediately, the old operation Future remains pending until cleanup completes, and its later settlement cannot alter replacement data

#### Scenario: Two observers share a stream
- **WHEN** two targets use streamed queries with one structural key
- **THEN** they share one active subscription and one cached Data value

#### Scenario: Streamed query is invalidated
- **WHEN** active observer policy permits invalidation refetch
- **THEN** a new logical stream operation starts using its configured refetch mode

#### Scenario: Observer reattaches before GC
- **WHEN** a streamed entry remains cached and becomes observed again
- **THEN** the observer receives its last committed Data immediately and ordinary freshness rules decide refetch
