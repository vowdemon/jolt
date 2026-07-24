## ADDED Requirements

### Requirement: Unified class-first mutation recipes inline factory and key semantics
The system SHALL define one externally subclassable `Mutation<TVariables, TData, TOnMutateResult>` recipe and one inline `mutation(...)` factory over the same runtime. `TOnMutateResult` SHALL describe only the return type of the optional recipe `onMutate` callback and SHALL NOT classify the mutation as optimistic. Mutations without a useful result SHALL use `void`. The class-first recipe SHALL provide concrete no-op lifecycle defaults so a minimal `Mutation<Variables, Data, void>` subclass implements only `mutate`. Because an arbitrary generic result cannot have a sound method default, `onMutate` SHALL be exposed as a nullable typed callback getter whose absence records no result.

The class-first constructor and inline factory SHALL accept nullable retry,
network-mode, and retention policy configuration so omission remains distinct
from explicitly supplying a built-in value. Class-first public policy getters
SHALL be non-virtual views of constructor configuration, and runtime resolution
SHALL read that configuration directly rather than infer explicitness from an
overridden getter result. Resolution SHALL be built-in, global defaults,
matching key defaults from general to specific, then explicit recipe
configuration. Thus an omitted field inherits a matching default while an
explicit `RetryPolicy.none`, `NetworkMode.online`, or
`RetentionPolicy.standard` overrides it. Marker retry arguments SHALL use
inference-neutral `RetryPolicy<Never>?`; typed custom retry SHALL be applied
after `TData` inference and preserve Variables, Data, and OnMutateResult. A
structural `MutationKey` SHALL reuse QueryKey normalization, equality, hashing,
and prefix matching, but SHALL be used only for filters, defaults, and
observation. A repeated key SHALL NOT imply execution identity, deduplication,
cancellation, or serialization. No public `MutationRecipe`,
`OptimisticMutation`, `MutationDefinition`, general options type, or mandatory
registry SHALL be exposed.

#### Scenario: Minimal reusable mutation binds three types once
- **WHEN** an external class subclasses `Mutation<Variables, Data, void>` without an onMutate callback
- **THEN** it implements only mutate and client and observer execution infer all recipe types without casts, raw types, or dynamic

#### Scenario: Inline mutation infers an onMutate result
- **WHEN** `mutation(...)` receives typed mutate and onMutate callbacks
- **THEN** it infers Variables, Data, and OnMutateResult under strict inference

#### Scenario: Inline mutation omits onMutate
- **WHEN** an inline mutation has no downward expected type and omits onMutate
- **THEN** the caller supplies `mutation<Variables, Data, void>(...)` because Dart has no source from which to infer the third generic

#### Scenario: Typed custom retry is added
- **WHEN** `Mutation<Variables, Data, OnMutateResult>.withRetry` is applied after recipe inference
- **THEN** all three generics are preserved and retry predicates receive Data

#### Scenario: Omitted mutation policies inherit defaults
- **WHEN** a class-first or inline mutation omits retry, network mode, or retention and matching defaults supply them
- **THEN** the matching default values fill only those omitted fields

#### Scenario: Explicit built-in mutation policies beat defaults
- **WHEN** a mutation explicitly supplies no retry, online mode, or standard retention while matching defaults supply different values
- **THEN** the explicit built-in values remain authoritative

#### Scenario: Mutation keys repeat
- **WHEN** two mutation submissions have structurally equal keys and no scope
- **THEN** both remain independent and may execute concurrently

#### Scenario: Numeric key forms differ only by integral representation
- **WHEN** otherwise equal MutationKeys contain `1` and `1.0` or `-0.0` and `0`
- **THEN** they normalize and hash identically under the shared key contract

### Requirement: Future-only public mutation execution
`QueryClient.execute<V, D, R>(Mutation<V, D, R>, V)` and `MutationObserver<V, D, R>.execute` SHALL return `Future<D>`. The public API SHALL NOT expose `MutationExecution`, `MutationHandle`, `cancelMutation`, or `cancelMutations`. The internal execution SHALL own its completion, typed onMutate-result presence, operation generation, retry wait, and queue membership. Observer reset or disposal SHALL detach presentation without stopping the mutation function or retry loop.

#### Scenario: One recipe executes twice
- **WHEN** the same mutation recipe is executed twice
- **THEN** two independent internal executions and public Futures are created

#### Scenario: Earlier execution finishes later
- **WHEN** an earlier call settles after a later call
- **THEN** both Futures settle from their own execution while the observer still presents the latest call

#### Scenario: Observer resets while pending
- **WHEN** a mutation observer resets during its latest execution
- **THEN** it returns to idle presentation and the execution continues

#### Scenario: Observer is disposed during retry delay
- **WHEN** an observer is disposed while its execution is waiting to retry
- **THEN** observer publication stops but the retry remains owned by the client and continues normally

### Requirement: Complete immutable mutation snapshots and state
The public `MutationSnapshot` SHALL be immutable and erased, containing ID, optional key, `MutationStatus`, `isPaused`, nullable pause reason, variables, `QueryValue<Object?>` data, optional `QueryFailure`, failure count, submitted time, `QueryValue<Object?>` `onMutateResult`, optional scope, and metadata. It SHALL contain no Future or mutable execution reference. `MutationCache.snapshots` SHALL return `IList<MutationSnapshot>` in submission order, and its observation-only events SHALL be broadcast, remain open across cache clear, and close only on QueryClient disposal. `MutationCache` SHALL expose cache-local clear but SHALL NOT implement `Disposable` or terminate its client. Global cache lifecycle callbacks SHALL be immutable policy supplied at QueryClient construction, captured for each submission, unavailable through a mutable setter, and distinct from observation events.

The public callback configuration and zero-configuration client constructor SHALL have this erased shape:

```dart
typedef MutationCacheOnMutate = FutureOr<void> Function(
  Object? variables,
  MutationContext context,
);

typedef MutationCacheOnSuccess = FutureOr<void> Function(
  Object? data,
  Object? variables,
  QueryValue<Object?> onMutateResult,
  MutationContext context,
);

typedef MutationCacheOnError = FutureOr<void> Function(
  QueryFailure failure,
  Object? variables,
  QueryValue<Object?> onMutateResult,
  MutationContext context,
);

typedef MutationCacheOnSettled = FutureOr<void> Function(
  QueryValue<Object?> data,
  QueryFailure? failure,
  Object? variables,
  QueryValue<Object?> onMutateResult,
  MutationContext context,
);

final class MutationCacheCallbacks {
  const MutationCacheCallbacks({
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  final MutationCacheOnMutate? onMutate;
  final MutationCacheOnSuccess? onSuccess;
  final MutationCacheOnError? onError;
  final MutationCacheOnSettled? onSettled;
}

QueryClient({
  QueryRuntime? runtime,
  QueryCacheCallbacks queryCallbacks = const QueryCacheCallbacks(),
  MutationCacheCallbacks mutationCallbacks =
      const MutationCacheCallbacks(),
});
```

Cache `onMutate` SHALL return only `FutureOr<void>` and SHALL NOT produce recipe result `R`. `MutationCache.clear()` SHALL NOT change constructor policy, and already-submitted executions SHALL continue using their submission-time callback snapshot.

`MutationFilter` SHALL support key/exact, status, pause, scope, and a `MutationSnapshot` predicate. `MutationStatus` SHALL contain only idle, pending, success, and error, but submitted cache snapshots SHALL never be idle; idle is observer initial/reset presentation only. `isPaused` SHALL imply pending status and a non-null offline, focus, or scope reason. Retry delay SHALL be pending but not paused. Pending and error data SHALL be absent; success data SHALL be present. `onMutateResult` SHALL be absent before successful recipe onMutate completion, remain absent when the hook is omitted or fails, and remain present afterward including present-null. `failureCount` SHALL count thrown mutation-function attempts only, excluding result retries and callback failures, and SHALL reset to zero on terminal success. Paused executions SHALL count as mutating.

#### Scenario: Mutation is submitted behind a gate
- **WHEN** online or scope eligibility is unavailable at submission
- **THEN** its snapshot is pending and paused with variables and submitted time already visible

#### Scenario: Nullable result succeeds with null
- **WHEN** a mutation whose Data permits null succeeds with null
- **THEN** its snapshot is success with `QueryPresent<Object?>(null)`

#### Scenario: Mutation fails
- **WHEN** execution exhausts retry
- **THEN** its snapshot is error with the final Object and StackTrace in QueryFailure

#### Scenario: Mutation cache is inspected
- **WHEN** a consumer reads cache snapshots or applies a predicate filter
- **THEN** it receives stable immutable erased values describing committed execution state, and filters return matching snapshots without changing the executions

#### Scenario: Paused mutation count is observed
- **WHEN** a pending execution waits for connectivity or scope
- **THEN** matching mutating counts include it

#### Scenario: Mutation waits for retry delay
- **WHEN** a thrown mutation-function attempt qualifies for another retry
- **THEN** failureCount increments, status remains pending, and the delay itself is not represented as paused

#### Scenario: Result-based retry occurs
- **WHEN** a successful Data result qualifies for retry
- **THEN** failureCount does not increment

#### Scenario: Mutation without onMutate is inspected
- **WHEN** a Mutation<Variables, Data, void> omits its onMutate callback
- **THEN** its onMutateResult remains absent in pending, success, and error snapshots

#### Scenario: Mutation cache is cleared
- **WHEN** MutationCache.clear removes current cache records while an execution is active
- **THEN** it emits removals in submission order, leaves its event stream open, and permanently detaches the active execution from cache snapshots, later cache updates, and cache-derived mutating counts
- **AND** the execution's Future, observer, scope, retry, mutation work, and captured lifecycle callbacks continue without reinserting it

#### Scenario: QueryClient uses default mutation callbacks
- **WHEN** QueryClient is constructed without mutationCallbacks
- **THEN** it uses the empty const callback policy and requires no MutationCache configuration

### Requirement: Typed onMutate result presence
`Mutation<V, D, R>.onMutate` SHALL be optional and, when supplied, return `FutureOr<R>`. Successful invocation SHALL record `QueryPresent<R>`, including present-null; omission or failure before successful completion SHALL retain `QueryAbsent<R>`. Recipe, cache, observer-result, and observer per-call success, error, and settled surfaces SHALL receive the same typed or erased `QueryValue<R>` presence. The result SHALL describe lifecycle data only and SHALL NOT imply that query cache data was read or changed.

#### Scenario: onMutate returns nullable null
- **WHEN** onMutate successfully returns null for nullable R
- **THEN** later callbacks and observer state receive `QueryPresent<R>(null)` rather than absent

#### Scenario: onMutate completes while transport remains pending
- **WHEN** onMutate produces R and the mutation function has not settled
- **THEN** MutationObserver and MutationCache publish pending state with `QueryPresent<R>`

#### Scenario: onMutate is omitted
- **WHEN** a mutation has no recipe onMutate callback
- **THEN** mutate still runs and every later lifecycle surface receives `QueryAbsent<R>`

#### Scenario: onMutate throws
- **WHEN** recipe onMutate throws before invoking the mutation function
- **THEN** the mutation function is skipped, error and settled callbacks receive `QueryAbsent<R>`, and the execution fails

#### Scenario: Cache onMutate throws
- **WHEN** cache onMutate throws before recipe onMutate
- **THEN** recipe onMutate and the mutation function are skipped, onMutateResult is absent, and the error and settled chains still run

#### Scenario: onMutate returns a non-cache token
- **WHEN** onMutate returns correlation or timing data without calling QueryClient cache operations
- **THEN** callbacks receive that typed result and no query cache entry changes

### Requirement: Exact awaited cache and recipe lifecycle order
Each submission SHALL publish pending and then execute cache `onMutate`, the optional recipe `onMutate` when present, and the mutation function with retry. Normal success SHALL next invoke cache `onSuccess`, recipe `onSuccess`, cache `onSettled`, and recipe `onSettled`. Failure SHALL invoke cache `onError`, recipe `onError`, cache `onSettled`, and recipe `onSettled`. Cache and recipe callbacks SHALL be `FutureOr`, awaited, and invoked at most once. The first failure from a mutate stage, mutation function/retry adapter, or not-yet-completed success-chain callback SHALL become the primary failure. Pre-function failure SHALL skip remaining mutate/function stages. Success-chain failure SHALL enter the error chain; previously invoked callbacks SHALL not repeat, and only not-yet-invoked settled callbacks SHALL remain eligible after error callbacks. Error and settled cleanup SHALL continue after later failures, forwarding those secondary failures to the execution's submission Zone while retaining the primary failure. Error-chain data SHALL be absent even when the mutation function had produced a candidate D before a callback failed. The scope lane and public Future SHALL remain pending until all eligible cache/recipe lifecycle work completes.

#### Scenario: Successful lifecycle runs
- **WHEN** `onMutate`, the mutation function, and every success callback complete
- **THEN** each stage runs exactly once in the specified order and the Future resolves only afterward

#### Scenario: Function failure runs error lifecycle
- **WHEN** the mutation function fails after onMutateResult was produced
- **THEN** cache and recipe error/settled callbacks are awaited in order before committing error

#### Scenario: Success callback throws
- **WHEN** the mutation function succeeds but a cache or recipe success callback throws
- **THEN** that callback failure becomes primary, Data remains absent, and the non-repeating error/settled chain runs before the returned Future rejects

#### Scenario: Success-path settled callback throws
- **WHEN** a success-path settled callback throws
- **THEN** it becomes the primary failure, already invoked callbacks are not repeated, error callbacks run, and any not-yet-invoked settled callback runs once with absent Data

#### Scenario: Error callback also throws
- **WHEN** a main failure already exists and a later error or settled callback throws
- **THEN** remaining cleanup continues, the first main failure remains authoritative, and the later error is delivered to the Zone captured at submission

#### Scenario: Scope successor waits for callbacks
- **WHEN** a scoped head has completed transport but is still awaiting cache or recipe callbacks
- **THEN** the next scoped execution remains paused

### Requirement: Typed mutation observers and observer-local per-call callbacks
`MutationObserver<V, D, R>` SHALL implement `Readable<MutationObserverResult<V, D, R>>`. Its result SHALL use `QueryValue<V>` variables, `QueryValue<D>` data, and `QueryValue<R>` `onMutateResult` and SHALL expose status, pause state/reason, failure, failure count, and submission time. The observer SHALL forward `isIdle`, `isPending`, `isSuccess`, and `isError` convenience getters from its current result. Reset SHALL produce idle with variables, data, and onMutateResult absent. `execute` SHALL return only `Future<D>` and accept void per-call success, error, and settled callbacks but no per-call `onMutate`. Every per-call callback SHALL receive the same `QueryValue<R>` lifecycle-result presence; settled SHALL additionally receive `QueryValue<D>`. Per-call callbacks SHALL be eligible only if the observer still targets that same latest execution generation and has not reset or disposed; external Readable listener count SHALL not affect eligibility.

After all cache/recipe work, the runtime SHALL atomically commit terminal state
and release the scope lane, synchronously refresh the eligible latest
MutationObserver presentation, synchronously invoke eligible per-call
callbacks, queue outward cache/reactive publication, and only then complete the
public Future. Per-call callbacks SHALL therefore observe terminal state, and
code resumed after `await execute()` SHALL observe the same state without an
extra notification pump. A queued cache listener refresh SHALL
equality-deduplicate the already visible result. Per-call callbacks SHALL be
invoked at most once, SHALL not be awaited as lifecycle work, and SHALL not
alter terminal state, Future outcome, or scope release. Their failures SHALL be
delivered to the submission Zone.

#### Scenario: Observer submits twice
- **WHEN** an observer executes twice and the earlier call settles last
- **THEN** cache and recipe callbacks run for both, while per-call callbacks run only for the latest call

#### Scenario: Observer detaches before settlement
- **WHEN** reset or disposal happens before execution settles
- **THEN** cache and recipe callbacks still run but per-call callbacks do not

#### Scenario: Per-call callback throws
- **WHEN** a per-call callback throws
- **THEN** the error is sent to the submission Zone and cannot change execution status, returned Future, or scope release

#### Scenario: Per-call success observes terminal state
- **WHEN** the latest execution succeeds and its per-call success callback reads the observer
- **THEN** the observer already reports success and accepted data

#### Scenario: Await resumes with terminal presentation
- **WHEN** observer execute succeeds or fails
- **THEN** code immediately resumed from its Future observes the corresponding terminal observer result without pumping queued cache notification

#### Scenario: Per-call callback submits the same scope
- **WHEN** a terminal per-call callback synchronously submits another mutation with the same scope ID
- **THEN** the old lane has already been released and the new execution is eligible according to the current queue

### Requirement: Mutation observer recipe updates
`MutationObserver<V,D,R>.updateMutation` SHALL replace the recipe captured by
future submissions without changing an already submitted execution. Equal
nullable structural MutationKeys SHALL preserve the observer's latest
presentation across a recipe update. A changed key, including null-to-present
or present-to-null, SHALL reset presentation to idle so unrelated mutation
families do not share observer state. Updating a disposed observer SHALL fail
under the ordinary disposed-observer contract.

#### Scenario: Same-key mutation recipe is rebuilt
- **WHEN** an observer receives a new Mutation instance with an equal nullable structural key
- **THEN** its current presentation remains visible and the next execute call captures the new recipe

#### Scenario: Mutation key changes
- **WHEN** updateMutation receives a recipe with a different nullable structural key
- **THEN** observer presentation resets to idle while any prior submitted execution continues under its captured recipe

#### Scenario: Mutation recipe changes while pending
- **WHEN** updateMutation runs during an active execution
- **THEN** that execution and its callbacks use the old captured recipe and a later submission uses the new recipe

### Requirement: Parallel execution and same-client FIFO scopes
Mutations SHALL execute in parallel by default. `MutationScope(String id)` SHALL compare by ID. Executions with equal non-null scope IDs in one client SHALL form a FIFO lane. The head SHALL occupy the lane through online waiting, retry delay, mutation work, and awaited cache/recipe lifecycle callbacks. Later entries SHALL remain pending and paused with a scope reason. Scope identity SHALL not coordinate separate QueryClient instances.

#### Scenario: No scope is supplied
- **WHEN** two independent mutations are submitted without scope
- **THEN** both may invoke their mutation functions concurrently

#### Scenario: Equal scope IDs are submitted
- **WHEN** multiple executions in one client use equal scope IDs
- **THEN** only the head is scope-eligible and later executions remain FIFO

#### Scenario: Scope head retries
- **WHEN** the head waits through a retry delay
- **THEN** no later execution in that scope can pass it

#### Scenario: Offline head blocks always-mode successor
- **WHEN** an online-mode scoped head is offline and a later same-scope mutation uses always mode
- **THEN** the later mutation remains scope-paused until the head settles or the client is disposed

#### Scenario: Different clients use the same scope ID
- **WHEN** executions in separate clients share a scope string
- **THEN** they do not serialize each other

### Requirement: Mutation retry and network modes
Mutations SHALL use the Jolt-owned `RetryPolicy<TData>` adapter and default to `RetryPolicy.none`. Custom retry SHALL support typed result and exception predicates, finite or unlimited budgets, every supported delay and jitter, and awaited retry hooks. Online mode SHALL wait while offline, always mode SHALL ignore connectivity, and offline-first SHALL allow the first attempt but gate later attempts. Every retry continuation SHALL wait for application focus; always mode bypasses connectivity, not focus. Enabling retry for writes SHALL be documented as requiring idempotent transport behavior.

#### Scenario: Default mutation fails once
- **WHEN** the default mutation function throws
- **THEN** it enters the error lifecycle without another invocation

#### Scenario: Online mutation starts offline
- **WHEN** an online-mode mutation is submitted while offline
- **THEN** it is pending and paused until online state returns

#### Scenario: Offline-first mutation fails offline
- **WHEN** its first attempt runs offline and qualifies for retry
- **THEN** the next attempt waits for online state

#### Scenario: Result-based mutation retry is exhausted
- **WHEN** a typed result predicate handles Data but its finite budget refuses another attempt
- **THEN** the final Data proceeds through the normal success lifecycle

#### Scenario: Retried write is configured
- **WHEN** an application opts into retry
- **THEN** documentation and API examples identify duplicate non-idempotent write risk

### Requirement: User-composed query cache updates and conditional restoration
Neither `Mutation` nor `MutationCache` SHALL automatically cancel, snapshot, write, restore, invalidate, or refetch Query Cache state. A lifecycle callback MAY explicitly compose ordinary QueryClient operations. An optimistic update SHALL therefore be behavior inside `onMutate` rather than a mutation subtype or guaranteed lifecycle action. Query cache writes SHALL remain non-cancelling; a callback that must prevent an active query from overwriting its manual value SHALL explicitly await `cancelQueries` first. Conditional `QueryDataSnapshot<T>` restoration SHALL reject mismatched revision or provenance but SHALL NOT claim complete rollback correctness for overlapping optimistic mutations. In-place cache mutation SHALL be unsupported and no entity normalization SHALL be inferred.

#### Scenario: Mutation does not touch query cache
- **WHEN** no lifecycle callback invokes a QueryClient cache operation
- **THEN** the mutation can succeed or fail without changing, cancelling, invalidating, or refetching any query

#### Scenario: Optimistic update succeeds
- **WHEN** onMutate snapshots and writes optimistic query data and the mutation succeeds
- **THEN** success or settled callbacks explicitly retain, replace, or invalidate that value

#### Scenario: Optimistic update fails without intervening write
- **WHEN** the mutation fails and the current revision matches the optimistic revision
- **THEN** onError can restore the prior complete QueryValue and timestamp without restoring internal entry existence

#### Scenario: Concurrent update precedes rollback
- **WHEN** a newer optimistic or server write changes the revision
- **THEN** the older rollback is rejected and cannot overwrite newer data

#### Scenario: Overlapping optimistic mutations both fail
- **WHEN** multiple unscoped optimistic writes overlap and their conditional restores cannot reconstruct a correct final value
- **THEN** the runtime performs no automatic rebase or rollback stack and the application uses scope serialization, patch/rebase logic, or invalidation and refetch

#### Scenario: Mutation returns canonical server data
- **WHEN** success returns the complete updated object
- **THEN** onSuccess can write it through typed QueryClient operations without mandatory refetch

### Requirement: Zero-variable action facade
The system SHALL define `enum NoVariables { value }` and `action<D, R>(...)` returning `Mutation<NoVariables, D, R>`. The action factory SHALL omit NoVariables from its recipe mutation and lifecycle callback signatures and adapt them internally with `NoVariables.value`. When onMutate and a downward expected type are both absent, the caller SHALL supply `action<D, void>` under the same Dart inference rule as mutation. It SHALL provide `run()` on `MutationObserver<NoVariables, D, R>` whose per-call callbacks omit the sentinel while retaining `QueryValue<R>`, plus typed `QueryClient.executeAction<D, R>(...)`. Global `MutationCacheCallbacks` SHALL retain their one erased signature for all mutations and receive `NoVariables.value` in the variables position for actions. It SHALL NOT add `optimisticAction`, ActionObserver, ActionExecution, ActionCache, or a separate action state model.

```dart
Future<D> MutationObserver<NoVariables, D, R>.run({
  void Function(D, QueryValue<R>, MutationContext)? onSuccess,
  void Function(QueryFailure, QueryValue<R>, MutationContext)? onError,
  void Function(
    QueryValue<D>,
    QueryFailure?,
    QueryValue<R>,
    MutationContext,
  )? onSettled,
});
```

#### Scenario: Action is executed through client
- **WHEN** `executeAction` receives an action recipe
- **THEN** it runs the same mutation pipeline and returns Future<Data> without a variables argument

#### Scenario: Action is executed through observer
- **WHEN** `run()` is called on `MutationObserver<NoVariables, Data, OnMutateResult>`
- **THEN** it delegates to execute with `NoVariables.value` and preserves per-call callback behavior

#### Scenario: Action preserves typed onMutateResult
- **WHEN** an action onMutate callback produces OnMutateResult
- **THEN** its observer run and lifecycle callbacks omit NoVariables while preserving the exact result presence

#### Scenario: Global callbacks observe an action
- **WHEN** an action reaches a configured MutationCache callback
- **THEN** the global erased callback receives NoVariables.value while its signature remains identical to other mutations

### Requirement: Mutation retention automatic continuation and client disposal
Settled mutation snapshots SHALL remain until their retention deadline while unobserved and unneeded by a scope lane. Network-, focus-, and scope-paused work SHALL continue automatically when eligibility returns while the client lives. `MutationCache.clear()` SHALL emit one removal event for every current record in submission order. Any removed active execution SHALL remain permanently detached from cache snapshots, future cache-update events, and cache-derived mutating counts while its Future, observer, scope, retry, mutation work, and captured lifecycle callbacks continue; it SHALL NOT be reinserted by later state changes. Later submissions SHALL enter the cache normally. MutationCache SHALL NOT expose disposal, and there SHALL be no public cross-process resume or mutation cancellation API. QueryClient disposal SHALL immediately complete every unsettled public mutation Future with a disposed-client failure, cancel owned retry waits, abandon internal queued/paused work, clear mutation cache state, and close its event stream. Transport or user callback code already invoked before disposal MAY continue and produce external side effects; it cannot be forcibly cancelled. Generation guards SHALL prevent starting later callbacks or committing mutation/query-cache state after the already-running code returns.

#### Scenario: Connectivity returns
- **WHEN** paused mutations become online
- **THEN** independent scopes may resume concurrently and each shared scope remains FIFO

#### Scenario: Settled mutation is unobserved
- **WHEN** its observer detaches before retention expires
- **THEN** the immutable snapshot remains filterable until safe GC

#### Scenario: Attached observer races zero-retention GC
- **WHEN** an execution settles while its observer remains attached and the zero-retention timer fires
- **THEN** observation prevents removal until the observer detaches, after which the execution is eligible for GC

#### Scenario: Client is disposed with queued mutation
- **WHEN** an execution has not started transport
- **THEN** it is removed from internal gates and its Future fails deterministically as disposed

#### Scenario: Client is disposed with active transport
- **WHEN** a mutation function ignores disposal and later completes
- **THEN** its wrapper Future has already failed as disposed and completion cannot commit state, update query cache, start lifecycle callbacks, or publish observer callbacks

#### Scenario: Client is disposed during an awaited callback
- **WHEN** a cache or recipe callback was already invoked before disposal
- **THEN** that user callback may finish its external work, but the wrapper Future fails as disposed and no following callback or internal commit starts

#### Scenario: Client disposal closes mutation cache observation
- **WHEN** the owning QueryClient is disposed while a mutation transport is active
- **THEN** the wrapper Future fails as disposed, the mutation event stream closes, and late transport completion cannot publish callbacks or state
