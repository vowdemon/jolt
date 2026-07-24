## Context

Jolt owns local reactive state through Signal, Computed, Effect, batching, and disposable framework integrations. AsyncSignal can represent one asynchronous source, but it cannot by itself model shared remote data, background refresh with retained data, observer-specific freshness, request deduplication, cache invalidation, pagination, mutations, or in-process network coordination.

The new `jolt_query` package provides a server-state runtime inspired by
TanStack Query v5 without expanding the responsibility of `jolt` itself. The
semantic compatibility baseline for concepts shared by both libraries is
TanStack Query v5.101.4. The same package also exports provider-free ordinary,
infinite, and mutation Flutter widgets from
`package:jolt_query/jolt_query.dart`; there is no companion Flutter package.
The runtime implementation remains separated from Flutter lifecycle and
widget concerns even though the package itself depends on Flutter and
`jolt_flutter`. The complete runtime is designed in this change; persistence,
hydration, DevTools, cross-process recovery, and multi-client synchronization
are deliberately excluded.

Constraints:

- The package is Flutter-capable and depends on Flutter plus `jolt_flutter`; its server-state runtime modules must remain framework-independent in implementation and use only Jolt's public reactive API.
- Cached values may legitimately be null, so null cannot mean “absent”.
- Dart Futures are not forcibly cancellable; correctness must not depend on transport cancellation.
- Dart generic inference must not force users to add casts, raw types, or explicit type arguments in ordinary usage.
- Structural library-owned collections use `fast_immutable_collections` with package-local equality and hash behavior.
- The first retry integration targets exact `retry_plus: 0.1.1`.
- A `QueryClient` may outlive UI scopes and must have explicit ownership and disposal rules.
- QueryWidget must obtain its QueryClient from the query target itself; this version has no QueryClientProvider or inherited client lookup.

## Goals / Non-Goals

**Goals:**

- Deliver one coherent query, mutation, infinite-query, streamed-query, and
  provider-free Flutter observer contract rather than staged P0/P1/P2 subsets.
- Preserve TanStack Query v5.101.4 state-machine and lifecycle semantics where
  Dart has the same concept, and name every deliberate Dart divergence rather
  than silently locking an opposite behavior into tests.
- Share one cache entry and one active operation lane for each structural query key.
- Preserve strong result typing across class-first recipes, inline factories, selection, nullable values, mutation lifecycle results, and infinite-query direction methods.
- Make illegal query-configuration order unrepresentable through staged public types.
- Expose read-only cache state and deterministic bulk-operation reports without exposing mutable entries.
- Make timing, jitter, environment events, and notifications deterministic in tests.
- Support automatic in-process continuation of network-, focus-, or scope-paused work.
- Provide provider-free Flutter QueryWidget, InfiniteQueryWidget, and
  MutationWidget integrations that own observer lifecycle, preserve compatible
  target transitions, and expose borrowed observers to ordinary Flutter
  builders.

**Non-Goals:**

- Add a Resource primitive or generic Task abstraction to `jolt`.
- Provide HTTP, GraphQL, database, DTO, authentication, or repository layers.
- Couple cache, client, query, mutation, retry, infinite-query, or streamed-query behavior to BuildContext, Widget lifecycle, or implicit host-lifecycle detection. Flutter may expose an explicitly installed, explicitly disposed client focus binding.
- Provide QueryClientProvider, inherited client lookup, hooks, Suspense, or
  ErrorBoundary integration.
- Copy every TypeScript callback-valued observer option. External reactive
  inputs use `watchQuery`; this version adds state-derived polling because it
  has a concrete runtime scheduling requirement, while arbitrary stale
  resolvers remain explicitly event-driven.
- Persist or hydrate cache state, recover mutations after process termination, synchronize clients, or provide DevTools.
- Normalize entity graphs or infer relationships between keys.
- Expose mutation cancellation as a public capability.

## Deliberate Dart Adaptations

- `QueryKey` and `MutationKey` are non-generic structural values. Reusing a key is an intentional caller-owned declaration that the cache shape is the same.
- `QueryValue<T>` distinguishes absent from present-null.
- `QueryFailure` retains both `Object` and `StackTrace`.
- Query configuration uses staged classes; the raw cached type is established once and the selected view type is carried forward.
- Dynamic heterogeneous query observation uses explicit erased result types; statically heterogeneous code composes typed observers with Dart records.
- Infinite pagination uses `PageCursor.end` and `PageCursor.more`, so nullable page parameters remain valid values.
- Every mutation uses `Mutation<TVariables, TData, TOnMutateResult>`. The third generic is the result of `onMutate`, not an optimistic-update marker; mutations without a useful result use `void`.
- Mutation callbacks use `QueryValue<TOnMutateResult>` so an omitted or failed `onMutate` remains distinct from a successful present-null result.
- Retry decisions are typed to the raw operation result, while Jolt owns execution, scheduling, cancellation, online gating, and state commits.

## Decisions

### 1. Keep the cache runtime independent from Jolt reactivity

`QueryClient`, caches, entries, operations, filters, retry adaptation, and timers use ordinary Dart objects and explicit subscriptions. Observers adapt committed runtime state to Jolt `Readable` values and implement `Disposable`.

State commits are synchronous. A package-internal notification manager queues cache/listener and automatic-observer notifications and flushes them in one Jolt batch through the injected notification scheduler. An imperative observer refetch locally refreshes its own complete result in a Jolt batch when the returned Future settles, so that Future contains terminal observer state; the later queued listener refresh is equality-deduplicated. Query functions, selectors, retry predicates, reducers, and callbacks execute untracked.

Alternative considered: store every entry in `AsyncSignal`. Rejected because one cached entry needs orthogonal query/fetch state, multiple observers, retained data during refresh, and observer-local presentation.

### 2. Use class-first recipes and staged query targets

`Query<TData>` is the reusable abstract base and implements the exact raw-cache carrier `QueryDataTarget<TData>`. The inline `query(...)` factory returns a private `Query<TData>` and infers `TData` from `fetch`. No `QueryDefinition`, `QueryFamily`, public options bag, or general Query builder is introduced.

The public stages are:

```dart
sealed class QueryTarget<TView> {
  QueryTarget<TView> withObserver({
    bool? enabled,
    StalePolicy? staleTime,
    RefetchPolicy? refetchOnMount,
    RefetchPolicy? refetchOnFocus,
    RefetchPolicy? refetchOnReconnect,
    bool? retryOnMount,
    Duration? pollingInterval,
    QueryPollingIntervalResolver<TView>? pollingIntervalResolver,
    bool? pollingEnabled,
    bool? pollInBackground,
    bool Function(TView previous, TView next)? equality,
  });

  QueryTarget<TView> withPlaceholderData(TView data);

  QueryTarget<TView> withPlaceholder(
    QueryValue<TView> Function(QueryValue<TView> previous) resolve,
  );
}

sealed class QueryView<TView> extends QueryTarget<TView> {
  QueryView<TNext> select<TNext>(TNext Function(TView value) selector);
}

abstract interface class QueryDataTarget<TData> {
  QueryKey get key;
  DataReconciler<TData> get reconciler;
}

abstract base class Query<TData> extends QueryView<TData>
    implements QueryDataTarget<TData> {
  QueryKey get key;
  FutureOr<TData> fetch(QueryContext context);

  Query<TData> withRetry(
    RetryStrategy<TData> Function(RetryBuilder<TData> retry) create,
  );

  QueryView<TData> withInitialData(
    TData data, {
    DateTime? updatedAt,
  });
}
```

The snippet shows public signatures, not abstract implementation obligations. All transformation methods are concrete package implementations inherited by external subclasses. A minimal external subclass is declared final, base, or sealed as required by Dart's base-class rules and implements only `key` and `fetch`. Type-independent recipe policy is supplied through the `Query` super-constructor so the runtime can distinguish an omitted value from an explicit value equal to the built-in default. Public getters continue to expose the effective recipe-facing value. It does not import `retry_plus` unless it opts into custom retry construction.

The legal transformation order is retry, initial data, zero or more
selections, then observer configuration or placeholder configuration. Calling
`withObserver`, `withPlaceholderData`, or `withPlaceholder` returns terminal
`QueryTarget<TView>`, so `select` cannot accidentally run after final observer
presentation has been configured. Any `Query` or `QueryView` can be observed
directly with defaults. Class-first retry, stale, retention, and network
policy getters are non-virtual views of constructor configuration. External
subclasses pass every policy, including an explicit built-in value, to
`super(...)`; runtime resolution never tries to infer explicitness by comparing
an overridden getter result to a singleton default.

`withInitialData` and `withPlaceholderData` take required raw values. Invoking either method means the value is present; passing null when `T` is nullable means present-null. The placeholder resolver receives `QueryValue<TView>` so it can preserve a prior view, return an explicit present-null, or return absent. Initial data seeds the shared raw cache only when absent and supplies the reset baseline, but it does not increment fetch/data completion counters; `isFetched` remains false until an accepted operation result or streamed partial, manual write, restore, or terminal error updates the entry. A monotonic completion sequence plus a resettable/rollback-aware visible marker keeps `isFetchedAfterMount` correct across reset without allowing queued reset events to rewrite a later attachment baseline. Placeholder data is observer-local, is applied after selection, and never enters the cache.

Transformation stages internally retain the originating raw Query, but exact cache reads and writes intentionally accept `QueryDataTarget<TData>`, not a selected view. Ordinary `Query<TData>` and raw `InfiniteQuery<Page, PageParam>` implement the carrier with their raw cache type and typed reconciler. Callers keep the original raw recipe for exact operations; selected Query or InfiniteQuery views cannot masquerade as raw cache carriers. The carrier exposes no executable ordinary-query plan.

The recipe's retry policy is fixed while `TData` is still visible. Selection never changes retry typing. Each operation captures an immutable resolved fetch plan from the initiating `Query`; later observer changes cannot mutate a running plan.

### 3. Represent value presence and public cache reads explicitly

`QueryValue<T>` is a public exhaustive sealed union with public const `QueryAbsent<T>` and `QueryPresent<T>` variants plus const root factories `QueryValue.absent()` and `QueryValue.present(T)`. It exposes `isPresent`, `isAbsent`, `valueOrNull`, and `requireValue()`. A present value may contain null, and placeholder resolvers can construct either result without package-private helpers.

Canonical read surfaces use `QueryValue`: query and mutation observer-result data, tracked observer data, `QuerySnapshot.data`, exact and bulk cache reads, `MutationSnapshot.data`, and mutation `onMutateResult`. Raw `T` is accepted for writes because calling a write method itself expresses presence.

Exact query data operations are:

```dart
QueryValue<T> getQueryData<T>(QueryDataTarget<T> query);
QuerySnapshot<T>? getQueryState<T>(QueryDataTarget<T> query);
QueryDataSnapshot<T> snapshotQueryData<T>(QueryDataTarget<T> query);

QueryDataSnapshot<T> setQueryData<T>(
  QueryDataTarget<T> query,
  T data, {
  DateTime? updatedAt,
});

QueryDataSnapshot<T> updateQueryData<T>(
  QueryDataTarget<T> query,
  T Function(QueryValue<T> previous) update, {
  DateTime? updatedAt,
});

bool restoreQueryData<T>(
  QueryDataTarget<T> query,
  QueryDataSnapshot<T> snapshot, {
  required int ifRevision,
});
```

`QueryDataSnapshot<T>` is a general revisioned data checkpoint. It publicly records the complete `QueryValue<T>` (including absent and present-null), update time, and revision, and privately carries client, normalized-key, and per-key lineage provenance. It deliberately does not capture or restore the internal existence of a `QueryEntry`. Restoring an absent checkpoint into an existing entry writes `QueryAbsent<T>` while leaving the entry, observers, and active operation intact so ordinary GC can later remove it. When an otherwise valid absent checkpoint targets no existing entry, restoration succeeds as a no-op and does not manufacture an empty entry. `restoreQueryData` returns false without changing state for a snapshot from another client or key, a non-matching revision, a lineage invalidated by removing that key, or any checkpoint issued before a QueryCache clear. Clear rotates all known per-key lineages, including keys known only through an absent checkpoint. Different Query instances with the same structural key share valid provenance.

Except for the successful absent-checkpoint-to-missing-entry no-op, exact
`setQueryData`, `updateQueryData`, and successful `restoreQueryData`, plus bulk
`setQueriesData` and `updateQueriesData`, modify only the cached-data lane: the
complete `QueryValue<T>`, data-derived query status, data timestamp/update
count/revision, clearing `isInvalidated`, and clearing terminal data failure. A
conditional restore that returns false changes no state. Data-lane writes do
not cancel or replace an active query operation and preserve its cancellation
token, operation identity, fetch status, pause state, transient attempt
failure, and retry progress. When a manual write succeeds during active work,
the operation's cancellation rollback baseline advances to that post-write data
state. Reversion restores the advanced data/status/failure/counter state while
normalizing fetch status to idle and clearing its pause reason, because the
reverted operation no longer owns the lane. A later cancellation or
retained-data replacement therefore cannot erase the manual value by restoring
the older operation-start snapshot or leave an idle lane presented as fetching.
The active operation may still complete normally and replace the manual value
or fail against it. A caller that needs to prevent that later normal completion
explicitly awaits `cancelQueries` before writing. There is no bulk restore
operation.

Conditional restoration is a compare-and-set primitive, not a complete concurrent optimistic-rollback algorithm. A matching revision proves only that the expected write is still current. Overlapping optimistic mutations can still require a shared `MutationScope`, application-owned patch/rebase logic, or final invalidation and refetch.

`QuerySnapshot<T>` is the complete read-only typed state. Bulk data operations use an immutable `QueryDataMatch<T>` pairing `QueryKey key` with the current read checkpoint or post-write `QueryDataSnapshot<T> snapshot`:

```dart
IList<QueryDataMatch<T>> getQueriesData<T>(TypedQueryFilter<T> filter);

IList<QueryDataMatch<T>> setQueriesData<T>(
  TypedQueryFilter<T> filter,
  T data, {
  DateTime? updatedAt,
});

IList<QueryDataMatch<T>> updateQueriesData<T>(
  TypedQueryFilter<T> filter,
  T Function(QueryKey key, QueryValue<T> previous) update, {
  DateTime? updatedAt,
});
```

Bulk writes affect only existing matches and return their post-write snapshots in stable cache order. Heterogeneous bulk mutation without the typed filter assertion is unavailable.

`QueryCache` exposes `IList<QueryCacheSnapshot> snapshots`, a broadcast
`Stream<QueryCacheEvent> events`, and query-cache-only `clear()`. Each erased
snapshot contains its QueryKey, `QueryValue<Object?>` data, query/fetch status,
failure state, timestamps/revisions, activity, aggregate freshness, and
metadata, but no executable plan or mutable entry. Events and snapshots are
immutable. `QueryClient` accepts immutable `QueryCacheCallbacks` containing
`onSuccess`, `onError`, and `onSettled`. Each network-backed logical query
operation captures that policy, commits its terminal cache state first, then
invokes the matching callbacks exactly once with immutable post-commit
snapshot state before settling its public Future. Manual writes, initial-data
seeds, streamed partials, and cancellation do not independently trigger those
terminal callbacks. Callback failures are reported to the operation's captured
Zone and do not rewrite already committed query state.

`QueryCache.clear()` removes query entries in stable cache order, signals
cancellation of their active query operations, immediately guards late
results, rotates every known checkpoint lineage, and emits removal events
while leaving the event stream, owning client, MutationCache, active mutations,
and QueryObservers alive. A live observer reattaches to a fresh entry
incarnation when it receives removal; its ordinary enabled and activation
policies then decide whether to fetch, so observed queries may repopulate the
cache after clear. `QueryCache` is not `Disposable` and cannot terminate its
owner; only `QueryClient.dispose()` stops all owned work and closes cache event
streams. `QueryEntry` and the mutable map remain package-private.

Cache-level freshness follows TanStack's observer-first definition rather than
one retained recipe policy. When observers are attached, the entry is
aggregate-stale only when at least one current observer result is stale;
disabled and immutable observer results are non-stale. When no observer is
attached, absence or invalidation makes the entry stale. An invalidation marker
therefore remains visible without forcing an attached immutable-only query to
match stale filters. `QueryFilter` freshness matching uses the same aggregate
definition. A pure observer-freshness transition, such as a duration deadline,
publishes `QueryCacheEventKind.freshnessChanged` only when the aggregate
actually changes. When `added`, `updated`, `invalidated`, `reset`, or
`activityChanged` already reports the transition and its final aggregate
snapshot, the cache does not emit a duplicate `freshnessChanged` event.

Because `IList` appears in the deliberate public contract, `jolt_query.dart` re-exports only the `IList` symbol from `fast_immutable_collections`. Other FIC implementation types remain unexported unless a later public API deliberately adopts them. This differs from `retry_plus`, whose construction vocabulary is never re-exported.

Query lifecycle operations return `Future<QueryBatchResult>` where asynchronous work is involved. `QueryBatchResult` exposes integer `matched`, `affected`, and `skippedNonExecutable` fields plus `IList<QueryBatchFailure> failures`; each failure pairs its `QueryKey` with `QueryFailure`. `matched` is the stable pre-operation match count. `affected` counts entries for which the requested state change or asynchronous attempt actually began, including attempts that later failed. No-op matches can make `matched` greater than the other counts. `skippedNonExecutable` counts matches that required execution but had no retained plan, and `failures` is the subset of affected entries whose requested work failed. Failure records follow the pre-operation stable match/cache order, never asynchronous completion order.

`invalidateQueries`, `refetchQueries`, `cancelQueries`, and `resetQueries` are asynchronous. `int removeQueries(QueryFilter filter)` synchronously returns the number removed; `clear()` returns void. Bulk refetch never invents an executable plan for a cache-only entry.

### 4. Normalize keys recursively with one numeric contract

`QueryKey` and `MutationKey` use the same recursive normalizer. Supported leaves are null, bool, String, int, and finite double. Lists preserve order; maps require String keys and compare independent of insertion order. Mutable inputs are defensively converted to `IList` and `IMap` using package-local equality and hashing.

Numeric normalization is exact and recursive:

- `int` remains `int`;
- a finite integral `double` canonicalizes to `int`;
- `1` and `1.0` are identical;
- `-0.0` and `0` are identical;
- a finite fractional `double` remains `double`;
- NaN and positive or negative infinity are rejected.

Sets, DateTime, custom leaves, non-String map keys, and other unsupported values are rejected. Key hash and equality operate on the same normalized representation. `MutationKey` supports filtering, defaults, and observation only; it does not create mutation identity, deduplication, or implicit serial execution.

### 5. Adapt `retry_plus` strategies without re-exporting them

The package pins `retry_plus: 0.1.1` and exposes a Jolt-owned policy facade:

```dart
sealed class RetryPolicy<T> {
  static const RetryPolicy<Never> none;
  static const RetryPolicy<Never> standard;

  factory RetryPolicy.custom(
    RetryStrategy<T> Function(RetryBuilder<T> retry) create,
  );
}
```

Inline recipe factories accept only inference-neutral `RetryPolicy<Never>?` marker values. Typed custom retry is added after inference with `Query<T>.withRetry`, `Mutation<V, T, R>.withRetry`, or the equivalent specialized infinite transformation. The mutation transformation preserves `V`, `T`, and `R`. Reusable classes may override a contextually typed `RetryPolicy<T>`.

`RetryBuilder<T>` is a narrow type witness. It exposes `exceptions`, `exceptionWhere`, `exceptionType<E>`, `result`, `where`, `any`, `never`, `maxRetries`, and `strategy`. The builder helpers prevent exception-only expressions from widening to `dynamic`; callers can still use every `RetryStrategy<T>`, `RetryIf<T>`, `DelayPolicy`, `Jitter`, and hook supported by 0.1.1.

No `retry_plus` symbol is re-exported from `package:jolt_query/jolt_query.dart`. `none` and `standard` users import only Jolt Query. Applications that construct custom `retry_plus` values declare their own direct dependency and import both packages:

```dart
import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart';
```

`RetryPolicy.custom` treats the upstream `RetryStrategy<T>` as a policy description, not as an executor. The strategy factory runs once per logical operation. After each attempt, the Jolt-owned adapter builds `RetryAttemptContext<T>` and awaits `retryIf.shouldHandle`. When retry is accepted, it awaits `onRetry`, awaits `DelayPolicy.compute` with the injected random source, treats a null delay as zero, then performs the Jolt-owned cancellable delay/online gate before the next attempt. When retry is refused after at least one earlier retry, it awaits `onGiveUp` before returning or throwing the final attempt outcome; it does not call `onGiveUp` when the first attempt was never retried. Predicate, hook, or delay failures terminate the operation at their stage.

The adapter also owns timer handles, cancellation, failure-state commits, operation/incarnation guards, observer-detach behavior, and disposal. It never invokes or accepts `RetryPipeline`, the top-level retry executor, or any broader resilience pipeline.

One detached upstream `RetryPipelineContext<T>` object is retained for the entire logical operation because `RetryAttemptContext<T>` requires it and stateful policies such as decorrelated jitter use its identity. Its elapsed view is resynchronized from the Jolt clock before each decision. The adapter awaits `retryIf.shouldHandle`, `DelayPolicy.compute`, `onRetry`, and `onGiveUp`.

The authoritative adapted context is `outcome`, `retryIndex`, `attemptNumber`, `elapsed`, and `attemptDuration`. On the detached `pipelineContext`, only stable per-operation identity and the resynchronized elapsed read are supported. `now`, `random`, `sleep`, `cancelToken`, `isCancelled`, `throwIfCancelled`, `timeout`, `telemetry`, `phase`, and `setPhase` are upstream executor facilities: they may expose retry_plus detached-context defaults or throw, and custom policy code must not use them to control Jolt execution. Writes to its elapsed property are overwritten at the next decision. Jolt time, randomness, sleeps, cancellation, telemetry behavior, and operation phase remain authoritative. The upstream signatures of `DelayPolicy.custom` and `DelayPolicy.generated` erase their attempt result to `Object?`; Jolt preserves that limitation while keeping retry predicates and hooks typed to `T`.

The adapter preserves the exact 0.1.1 `onGiveUp` contract, including the upstream behavior where `onGiveUp` can run after at least one retry followed by a successful result. If that hook throws, the successful result becomes an operation failure. Result-based retry is evaluated only for a completed attempt; when its budget refuses another retry, the final handled result is committed as success.

The default observer query policy performs three retries after the first attempt with non-jittered exponential delays starting at one second and capped at thirty seconds. Imperative queries and all mutations default to no retry unless a recipe, call, or matching default opts in.

### 6. Give query operations domain-specific conflict semantics

The package exposes no generic concurrency `Task`. Ordinary duplicate initial
fetches join the active operation. Imperative `fetchQuery` and
`fetchInfiniteQuery` also join an existing operation by default and accept an
explicit `cancelRefetch` opt-in for retained-data replacement. Observer
`refetch` and bulk `refetchQueries` retain their user-action default of
replacing an active retained-data refresh. Each operation captures entry
incarnation, operation ID, and prior state. Completion commits only while the
entry/lane guards still match. `invalidationRevision` remains monotonic
diagnostic state, but accepted query success clears the current invalidated
flag as TanStack does; it is not an extra commit-suppression guard.

Cancellation is a reentrant boundary because a consumed token may synchronously invoke application code. Jolt therefore commits lane detachment, rollback or reset state, publication, and GC eligibility before notifying listeners. Replacement temporarily reserves the lane so reentrant same-key work joins or cancels one deterministic winner. Remove and clear detach captured entry identities before notification, reset commits before notification, and disposal closes its acceptance gate before cancellation. A lost operation is always completed as stale or disposed instead of relying on an ownership invariant to avoid a leaked Future.

`QueryCancellationToken` is cooperative. Explicit query cancellation normally restores pre-operation state and never increments failure count. Operation guards reject late results even if the underlying Future ignores cancellation. Removing and recreating a key creates a new incarnation that old completions cannot mutate.

Starting an operation from absent data always enters the canonical
pending/loading state and clears the prior terminal failure presentation after
capturing rollback. Cancelling with reversion may still restore that prior
error. Starting a background operation with retained data preserves its
current data-state presentation.

Observed and active are distinct. Any attached observer keeps an entry
observed for retention purposes, while an entry is active only when at least
one attached observer is enabled. Disabled observers report non-stale
presentation state and are skipped by active filters and automatic/bulk
refetch, while their explicit `refetch` remains available. Bulk execution uses
the same three Query-wide eligibility rules as TanStack:

- an observed entry is disabled when none of its observers is active;
- an unobserved entry is disabled until at least one data or terminal-error
  completion has been accepted;
- an observed entry is static when any attached observer uses immutable
  freshness, regardless of whether that observer is enabled.

Static queries are excluded from bulk refetch even when another active observer
would otherwise consider the data stale. Manual observer refetch remains
available.

`invalidateQueries` marks every match and accepts
`cancelRefetch = true`. Its refetch phase follows ordinary bulk replacement:
by default retained active work is cancelled and restarted immediately, while
an absent initial load is joined. `cancelRefetch = false` joins current work
without scheduling a serial follow-up request. Any accepted success from that
joined or replacement operation clears the invalidated flag; invalidation does
not silently schedule a second request after the joined work.

Bulk lifecycle Futures describe work available now, not future connectivity.
When a started or joined item is immediately paused behind focus/online
eligibility, that item counts as affected and its bulk item completes without
waiting for the environment to recover. The underlying query operation remains
owned by the cache and continues later; any later failure is consumed by that
operation's normal state/callback path rather than becoming an unhandled bulk
Future error.

When the final observer detaches, an initial paused operation or an operation that consumed its token is cancelled. Otherwise the current attempt may complete and populate cache, while future retries are paused rather than irreversibly disabled. Reattachment to the operation resumes retry eligibility. Explicit imperative and inactive/all lifecycle work owns retry independently of observer attachment; joining observer-started work upgrades that operation to the same detach-independent ownership for its explicit caller. Retry continuation waits for focus as well as the applicable online gate; `NetworkMode.always` bypasses online state but not focus.

Every created inactive entry receives effective retention immediately, including entries created by manual cache writes. Fresh imperative cache hits preserve or reschedule their GC deadline rather than cancelling retention indefinitely. GC never removes an observed entry or an entry with active work.

Query state and fetch state remain orthogonal. Cached data can stay successful while a background refetch is fetching or fails. A retained-data terminal failure marks the entry stale/invalidated for future focus, reconnect, or invalidation revalidation instead of allowing an until-invalidated policy to hide the failed refresh. Staleness is observer-specific; entries store update and invalidation state, not one global stale time.

For a duration stale policy, a fresh observer owns a one-shot deadline handle from the injected runtime. Reaching that deadline only recomputes and publishes the observer result, so `isStale` can change from false to true while data stays present, query status stays successful, fetch status stays idle, and the query function is not invoked. Mount, focus, reconnect, polling, invalidation, and explicit fetch/refetch remain the events that may start work under their configured policies. The handle is replaced or cancelled when the target, entry data, policy, or observer lifecycle changes, and a generation guard makes a late callback harmless. An arbitrary `StalePolicy.resolve` has no predictable time boundary, so it is recalculated on query, target, and environment events rather than receiving an inferred deadline timer.

### 7. Make dynamic observation and fine-grained reads explicit

`QueryClient.watchQuery<TView>` evaluates its target factory inside Jolt dependency tracking. Signal reads therefore define the query's reactive inputs. When a dependency changes, the factory is reevaluated; a structural-key change detaches the prior entry, attaches the new entry, and updates the observer key and result as one target transition. An absent enabled entry starts one shared fetch. For a key switch on an already mounted observer, a stale cached entry starts background work and a fresh cached entry does not; `refetchOnMount` applies only to the observer's real mount. The prior final view remains available solely to the new target's observer-local placeholder resolver and is never copied into the new cache entry.

`AnyQueryTarget` is a non-generic erased base implemented by every target. Dynamic APIs never use raw types or `dynamic`:

```dart
QueriesObserver<IList<ErasedQueryObserverResult>> observeQueries(
  Iterable<AnyQueryTarget> targets,
);

QueriesObserver<IList<ErasedQueryObserverResult>> watchQueries(
  Iterable<AnyQueryTarget> Function() targets,
);

QueriesObserver<R> observeCombinedQueries<R>(
  Iterable<AnyQueryTarget> targets,
  R Function(IList<ErasedQueryObserverResult> results) combine,
);

QueriesObserver<R> watchCombinedQueries<R>(
  Iterable<AnyQueryTarget> Function() targets,
  R Function(IList<ErasedQueryObserverResult> results) combine,
);
```

Dynamic lists preserve input order and allow repeated keys to share an entry while retaining separate observer presentation. On reevaluation, child observers are reused by `(client identity, structural key, repeated-key occurrence)` so a new same-key target updates options without a remount. Static heterogeneous composition uses individual typed observers and Dart records.

Tracked observer field getters subscribe only to that field. Reading
`observer.value` subscribes to the complete result. Every result includes the
resolved `isEnabled` value so callers do not need to reconstruct inherited
defaults. Every result transition is committed atomically in one Jolt batch.
Cache/listener-driven transitions use the injected notification flush; an
imperative observer refetch may publish its own complete terminal result first,
and the queued cache listener then observes the same committed snapshot without
a duplicate observer transition.

Fixed polling remains the common API. Advanced state-derived polling uses:

```dart
typedef QueryPollingIntervalResolver<T> = Duration? Function(
  QueryObserverResult<T> result,
);
```

`pollingInterval` and `pollingIntervalResolver` are mutually exclusive. A null
resolver result disables the next poll. Because the interval may change after
every result, polling uses a generation-guarded one-shot schedule rather than a
periodic timer, resolves again after each observer transition and tick, never
overlaps entry work, and still honors enabled, immutable, focus, background,
and explicit polling-disable rules. The resolver runs untracked. External
reactive policy inputs continue to use `watchQuery`; arbitrary stale resolvers
remain event-driven instead of pretending the runtime can infer their next time
boundary.

### 8. Use client-owned managers and a borrowed runtime capability bundle

Each `QueryClient` creates and owns stable `FocusManager` and `OnlineManager` objects. The manager references are not replaceable. Each manager exposes direct state mutation and `setEventSource(Stream<bool>?)`; it owns and cancels the stream subscription, while the caller owns and closes the external stream. Source completion preserves the last state and releases the subscription. Source errors are forwarded to the Zone captured by `setEventSource` and do not replace the manager or mutate its last state.

Deterministic infrastructure is supplied through a public borrowed capability bundle:

```dart
abstract interface class QueryScheduledHandle {
  bool get isCancelled;
  void cancel();
}

abstract interface class QueryClock {
  DateTime wallNow();
  Duration monotonicNow();
}

abstract interface class QueryTimerScheduler {
  QueryScheduledHandle schedule(Duration delay, void Function() callback);
  QueryScheduledHandle schedulePeriodic(
    Duration interval,
    void Function() callback,
  );
}

abstract interface class QueryRandomSource {
  double nextDouble(); // 0.0 inclusive, 1.0 exclusive
}

abstract interface class QueryNotificationScheduler {
  QueryScheduledHandle schedule(void Function() flush);
}

final class QueryRuntime {
  const QueryRuntime({
    required this.clock,
    required this.timers,
    required this.random,
    required this.notifications,
  });

  factory QueryRuntime.system();

  final QueryClock clock;
  final QueryTimerScheduler timers;
  final QueryRandomSource random;
  final QueryNotificationScheduler notifications;
}
```

Handle cancellation is idempotent. Providers may still deliver an already queued callback, so every callback also checks its owner generation and becomes a no-op after cancellation/disposal. QueryClient uses `QueryRuntime.system()` when no bundle is supplied. It does not dispose supplied or system runtime providers, but it owns and cancels every handle it creates. `TimeoutManager` and `NotifyManager` are package-private orchestration types, not public extension seams.

Online mode waits before the first attempt while offline. Always mode ignores connectivity. Offline-first performs its first attempt and gates only later attempts. Retry continuation additionally waits for focus in every network mode. Resume from a gate and refetch-on-reconnect are separate events. Polling is observer-owned and never overlaps an entry operation. `pollingEnabled: false` explicitly disables an inherited interval; a supplied interval explicitly enables polling unless disabled in the same terminal settings.

### 9. Model each mutation call with one typed, non-cancellable public execution

`Mutation<V, D, R>` is the only public mutation recipe. `V` is the variables type, `D` is the successful mutation-function result, and `R` is the recipe `onMutate` result. `R` does not indicate whether a callback performs an optimistic update. A mutation without a useful pre-mutation result uses `void`. `MutationScope(String id)` compares by ID, and a repeated `MutationKey` affects defaults, filters, and observation only.

The class-first contract gives every lifecycle member a concrete no-op default except `mutate`. `onMutate` is represented as a nullable, strongly typed callback getter because a generic class cannot safely manufacture an arbitrary `R`:

```dart
typedef MutationOnMutate<V, R> = FutureOr<R> Function(
  V variables,
  MutationContext context,
);

abstract base class Mutation<V, D, R> {
  const Mutation({
    RetryPolicy<D>? retry,
    NetworkMode? networkMode,
    RetentionPolicy? retention,
  });

  MutationOnMutate<V, R>? get onMutate => null;
  FutureOr<D> mutate(V variables, MutationContext context);

  FutureOr<void> onSuccess(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {}

  FutureOr<void> onError(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {}

  FutureOr<void> onSettled(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {}

  Mutation<V, D, R> withRetry(
    RetryStrategy<D> Function(RetryBuilder<D> retry) create,
  );
}
```

The nullable policy constructor arguments preserve whether retry, network mode,
and retention were omitted. Omission permits matching mutation defaults to
fill the field; passing any value, including `RetryPolicy.none`,
`NetworkMode.online`, or `RetentionPolicy.standard`, is an explicit recipe
override. Inline `mutation(...)` and `action(...)` use the same nullable seam.
As with Query, a class-first recipe passes every policy override to `super`.
Public policy getters are non-virtual views of that constructor state, and the
runtime never attempts to infer omission from an overridden getter value.

A minimal `Mutation<V, D, void>` subclass implements only `mutate`. A class that produces `R` overrides the callback getter with a typed function value or method tear-off. The inline `mutation<V, D, R>(...)` factory exposes the same optional hook and lifecycle signatures. When `onMutate` is supplied, its return type can infer `R`. When it is omitted, callers either provide the complete expected type, write `mutation<V, D, void>(...)`, or supply a no-op void callback; the design does not claim that Dart can infer an unconstrained omitted `R`.

The public execution surface is Future-only:

```dart
Future<D> QueryClient.execute<V, D, R>(
  Mutation<V, D, R> mutation,
  V variables,
);

MutationObserver<V, D, R> observeMutation<V, D, R>(
  Mutation<V, D, R> mutation,
);

Future<D> MutationObserver<V, D, R>.execute(
  V variables, {
  void Function(D, V, QueryValue<R>, MutationContext)? onSuccess,
  void Function(QueryFailure, V, QueryValue<R>, MutationContext)? onError,
  void Function(
    QueryValue<D>,
    QueryFailure?,
    V,
    QueryValue<R>,
    MutationContext,
  )? onSettled,
});
```

There is no public `MutationRecipe`, optimistic mutation subtype, `MutationHandle`, `MutationExecution`, `cancelMutation`, or `cancelMutations`. The internal `MutationExecution<V, D, R>` owns completion, guards, lifecycle-result presence, and queue membership. Observer reset or disposal only detaches presentation; it never stops the mutation or retry loop.

`MutationObserver<V, D, R>` is `Readable<MutationObserverResult<V, D, R>>`. Its result uses `QueryValue<V>` variables, `QueryValue<D>` data, and `QueryValue<R>` `onMutateResult` so idle, hook absence/failure, and present-null remain distinct. Status, pause state/reason, failure, failure count, and submission time are also present. Reset produces idle with absent variables, data, and `onMutateResult`.

Public cache state is an immutable erased `MutationSnapshot` with ID, key, status, pause state/reason, variables, `QueryValue<Object?>` data, failure, failure count, submission time, `QueryValue<Object?>` `onMutateResult`, scope, and metadata. It contains no Future. `MutationCache.snapshots` returns submission-ordered `IList<MutationSnapshot>` values, and `MutationFilter` exposes key/exact, status, pause, scope, and snapshot-predicate fields. Mutation cache events are observation-only, remain open across cache clear, and close only when the owning `QueryClient` is disposed.

`MutationStatus` is idle, pending, success, or error, but idle exists only in observer presentation. Submission immediately creates a pending snapshot. `isPaused` is true only for an offline, focus, or scope gate, implies pending and a non-null pause reason, and counts as mutating. Retry delay is pending but not paused. Pending/error data is absent; success data is present, including present-null. `onMutateResult` is absent until the recipe hook completes, remains absent when the hook is omitted or fails, and is present after a successful hook, including present-null. `failureCount` counts thrown mutation-function attempts only, not result retries or callback failures, and resets to zero on terminal success.

Global MutationCache callbacks are immutable lifecycle policy supplied to the `QueryClient` constructor and captured for each submission; there is no mutable cache callback setter. A default client remains zero-configuration:

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

The event stream is the non-transactional observation surface. Cache `onMutate` runs first, returns only `FutureOr<void>`, and does not create or replace recipe `R`. If it succeeds, the optional recipe `onMutate` runs once. Its successful return becomes `QueryPresent<R>`; omission or failure remains `QueryAbsent<R>`. Every later recipe, cache, and eligible per-call callback receives the same erased or typed presence value. Returning null when `R` is nullable records present-null. `MutationCache.clear()` does not change the constructor policy, and each already-submitted execution continues with the callbacks it captured at submission.

Lifecycle ownership and order remain exact. Pending publication is followed by cache `onMutate`, optional recipe `onMutate`, and the mutation function with retry. Success runs cache `onSuccess`, recipe `onSuccess`, cache `onSettled`, and recipe `onSettled`. Failure runs cache `onError`, recipe `onError`, cache `onSettled`, and recipe `onSettled`. Cache and recipe callbacks are `FutureOr`, awaited, and invoked at most once.

The first failure from either `onMutate` stage, the mutation function/retry adapter, or a not-yet-completed success callback is primary. A pre-function failure skips remaining pre-function/function stages. A success-chain failure enters the non-repeating error chain. Error and settled cleanup continue after secondary failures, which are delivered to the submission Zone without replacing the primary failure. When a candidate `D` is followed by callback failure, terminal and error-chain data is absent because success was never committed.

After all cache/recipe lifecycle work, the runtime atomically commits terminal
state and releases the scope lane. An eligible latest
`MutationObserver` synchronously refreshes its complete result before any
per-call callback or public Future settlement. Eligible per-call success/error
and settled callbacks then run synchronously, the cache event and external
reactive notification are queued, and the public Future completes. A queued
listener refresh observes the already committed result and equality-deduplicates
instead of publishing a second observer transition. Per-call callbacks have no
`onMutate`, are eligible only while the observer still targets that latest
execution generation, and are invoked at most once. Their failures go to the
submission Zone and cannot alter terminal state, Future outcome, or scope
release. Because the lane is released before per-call callbacks, a callback may
submit same-scope work without deadlock.

Mutations run in parallel unless they share a non-null scope. Equal scope IDs form a same-client FIFO lane, and the head owns the lane through offline waits, retry delays, mutation work, and awaited cache/recipe callbacks. A later always-mode mutation cannot pass an offline head in the same scope.

Mutation runtime never infers a relationship between `MutationKey` and `QueryKey` and never automatically cancels, snapshots, writes, restores, invalidates, or refetches query data. A lifecycle callback may explicitly compose those `QueryClient` operations. Optimistic updates are therefore one possible body of `onMutate`, not an API mode or guaranteed behavior.

Settled mutation snapshots remain retained while an observer is attached, including when zero-duration retention races settlement. Detaching the final observer makes the settled execution eligible for GC. `MutationCache.clear()` emits one removal per current record in submission order. An active execution removed by clear remains permanently detached from MutationCache: later state changes neither reinsert it nor emit cache update events, and cache-derived `countMutating`/`mutatingCount` no longer include it. Its public Future, observer presentation, scope membership, retry, mutation work, and captured lifecycle callbacks continue normally; later submissions enter the cache normally. The cache itself is not `Disposable`.

Only client disposal is terminal. It immediately completes every unsettled public mutation Future with the disposed-client failure, cancels owned retry waits, abandons queued/paused work, clears cache state, and closes cache streams. Already invoked transport or user callback code may finish external side effects, but generation guards prevent later lifecycle/per-call callbacks or mutation/query-cache commits.

Zero-variable operations are a facade over the same generic runtime:

```dart
enum NoVariables { value }

Mutation<NoVariables, D, R> action<D, R>(...);
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
Future<D> QueryClient.executeAction<D, R>(
  Mutation<NoVariables, D, R> action,
);
```

The action factory's recipe callbacks and the `run()` extension's per-call callbacks omit the sentinel variables parameter, then adapt internally with `NoVariables.value`. Global `MutationCacheCallbacks` keep their one erased signature for every mutation and therefore receive `NoVariables.value` in their variables position for an action. `action<D, R>` follows the same third-generic inference rule as `mutation<V, D, R>`; without an `onMutate` or downward expected type, callers use `action<D, void>`. No optimistic action factory, `ActionObserver`, action cache, or action execution type is introduced.

### 10. Preserve infinite-query direction through specialized stages

`InfiniteData<Page, PageParam>` stores aligned `IList` values. The static marker `PageCursor.end` has type `PageCursor<Never>` and is assignable wherever `PageCursor<P>` is expected, while `PageCursor.more(P)` can contain null when `P` is nullable.

The page recipe is:

```dart
FutureOr<Page> fetchPage(InfinitePageContext<PageParam> context);
PageCursor<PageParam> getNextPageParam(InfiniteData<Page, PageParam> data);
PageCursor<PageParam> getPreviousPageParam(InfiniteData<Page, PageParam> data);
```

The previous-page method has a concrete default returning `PageCursor.end`; the inline factory's previous resolver parameter is optional. Forward-only recipes therefore need no boilerplate, including when `maxPages` is set, while every observer still has a consistent previous-direction no-op API. Supplying or overriding the previous resolver is what makes backward pagination available, so a bidirectional recipe has both resolvers by construction rather than through a separate runtime flag.

Specialized staged types mirror regular queries: `InfiniteQuery<Page, PageParam>` → `InfiniteQueryView<TView>` → terminal `InfiniteQueryTarget<TView>`. `withRetry` remains an `InfiniteQuery`; `withInitialData` returns an `InfiniteQueryView<InfiniteData<Page, PageParam>>`; `select` remains an `InfiniteQueryView<TNext>`; observer and placeholder configuration return an `InfiniteQueryTarget<TView>`. Page and cursor types stay internal after selection.

The retry result type is the complete `InfiniteData<Page, PageParam>`, never one `Page`. Page-level validation errors must be thrown inside `fetchPage` to participate in retry. Successful pages and the current cursor live for the logical operation so an exception retry resumes at the failed page rather than replaying earlier pages. A result-based retry of a completed `InfiniteData` starts a new complete-chain attempt because the rejected outcome applies to the whole result.

Directional methods return `Future<InfiniteQueryObserverResult<TView>>` and
accept `cancelRefetch = true`. When cache data is absent, either direction
request starts the ordinary initial-page operation while retaining its requested
direction metadata for fetching/error presentation. Only a present
`InfiniteData` whose corresponding resolver returns `PageCursor.end` is a
current-result no-op. Results expose one ordinary `QueryFailure` plus
directional fetching/error flags; a next/previous failure is not also reported
as a whole-window `isRefetchError`. They do not duplicate directional error
objects. The returned and observed data is selected `TView`, so `Page` and
`PageParam` never leak from a selected target.

Infinite observation composes the ordinary QueryObserver lifecycle rather than
copying it. One package-private fetch delegate lets mount, enabled activation,
key switching, focus, reconnect, polling, and explicit whole-window refetch all
use the ordinary observer state machine with infinite full-window behavior.
The infinite layer owns only its retained infinite plan, direction operations
and metadata, availability calculation, and derived result flags. This keeps
ordinary and infinite eligibility, retargeting, stale, and polling semantics in
one implementation.

`InfiniteQuery<Page, PageParam>` implements `QueryDataTarget<InfiniteData<Page, PageParam>>`, so the six exact QueryClient cache APIs infer complete aligned data directly from the raw infinite recipe. Selected infinite views intentionally do not implement the carrier. `fetchInfiniteQuery` and `ensureInfiniteQueryData` return `InfiniteData`; fetch and prefetch accept a positive `pages` count defaulting to one when starting an absent chain. Full refresh preserves the current retained window: it begins at the first retained page parameter, recomputes later cursors sequentially, and commits atomically. Each user cursor resolver is followed by another operation guard before transport. The entry retains a reusable lifecycle refresh plan while the active operation separately owns its one-shot direction or page-count plan, so invalidation during pagination follows with a full-window refresh rather than another append. Bounded pagination trims the opposite edge.

### 11. Treat streamed queries as attempt-aware ordinary query functions

The public helper is:

```dart
enum StreamRefetchMode { reset, append, replace }

QueryFunction<Data> streamedQuery<Chunk, Data>({
  required Stream<Chunk> Function(QueryContext context) stream,
  required Data Function() initial,
  required Data Function(Data current, Chunk chunk) reduce,
  StreamRefetchMode mode = StreamRefetchMode.reset,
});

QueryFunction<IList<Chunk>> streamedListQuery<Chunk>({
  required Stream<Chunk> Function(QueryContext context) stream,
  StreamRefetchMode mode = StreamRefetchMode.reset,
});
```

`initial` is a factory invoked once per retry attempt; the reducer is synchronous. Retry is `RetryPolicy<Data>`, not `RetryPolicy<Chunk>`. Exception predicates see stream and reducer failures. A result predicate is evaluated once, only after normal stream close, against final `Data`; it never runs per chunk. Every retry creates a new stream subscription. Guards run after `initial`, after the stream factory but before subscription, and both before and after structural reconciliation of a partial value, closing reentrant user-callback supersession gaps.

Each retry attempt resolves whether the query has accepted any real data or
terminal-error completion at that instant. Initial-data seeding alone is not a
fetch. Reset follows TanStack's `isFetched + resetState` transition, while
append and replace retain Jolt's deliberately deterministic retry accumulators:

- reset restores the query's reset state at the start of every fetched/refetch
  attempt; the reset state may contain configured initial data. A first attempt
  backed only by initial data does not clear it. Chunks publish incrementally
  and reduce from currently visible reset/initial data when present, otherwise
  from that attempt's `initial()`.
- append initializes from one logical operation baseline, so a retry rebuilds
  without duplicating chunks from a failed attempt. This is a documented
  stronger retry guarantee than TanStack's live-cache accumulator.
- replace accumulates privately on every attempt and commits only the accepted
  final value.

Every attempt invokes `initial()` once and creates a fresh subscription. A
reset retry that follows an accepted partial observes the query as fetched and
restores reset state before subscribing again; failed partial output is not
left visible after the next retry actually starts. Append and replace continue
to rebuild from their logical/private seeds without a retry-start cache write.
Operation identity, entry incarnation, operation generation, explicit
cancellation, replacement, and disposal guard all later events and commits;
ordinary data revision changes are not a streamed-operation supersession guard.

An external `setQueryData`, `updateQueryData`, bulk write, or conditional restore does not supersede an active streamed operation. The manual value is visible immediately, but a later accepted stream chunk or final result may replace it. A caller that wants the manual value to remain authoritative explicitly awaits `cancelQueries` before writing. Streamed queries therefore obey the same cache-write/fetch-lane separation as Future-backed queries. If subscription cancellation itself is asynchronous, the old public Future still awaits that cleanup, but the logical cache lane is released and reverted immediately so a reattached observer or imperative fetch can start; the detached cleanup is tracked separately and cannot touch a replacement operation.

When exception retry is exhausted, terminal failure commits against the
`QueryValue<Data>` currently visible at that instant: present data produces
retained-data failure and absent data produces loading failure. Reset reflects
the latest reset-state/accepted-partial presentation, append reflects its
latest incrementally accepted value, and replace-refetch retains its prior
visible value. A later manual value survives exhaustion unless an accepted
stream chunk or final result already replaced it. When a result predicate
requests a retry but its budget is exhausted, the final `Data` is accepted and
committed as success.

### 12. Keep ownership and lifecycle explicit

`QueryClient` owns caches, its stable focus/online managers, observers created through it, active operations, internal timer handles, and manager event-source subscriptions. It disposes all owned resources idempotently and is the only public object that can terminate cache event streams or active client work. `QueryCache` and `MutationCache` expose cache-local `clear()` but are not `Disposable`; `QueryClient.clear()` clears both caches while leaving the client usable. The client borrows the `QueryRuntime` providers and external streams.

Observers are independently idempotent `Disposable` values. Disposing an observer detaches it, cancels its polling and reactive target effect, and may schedule entry GC. It does not dispose the client. `clear()` empties caches but leaves the client usable.

### 13. Bind query targets to a configurable default client

`QueryClient` owns one per-isolate default reference. `QueryClient.defaultClient` lazily creates an ordinary zero-configuration client when no explicit default has been installed. `QueryClient.setDefault(QueryClient client)` installs an active client before the default is first resolved. Default resolution then locks the reference so mounted and subsequently created query widgets cannot silently split across cache universes. Staged transformations copy the nullable configured binding without reading `defaultClient`; only a target-owned integration that reads the public non-null `target.client` resolves the fallback. Explicit QueryClient receiver operations likewise use their receiver without resolving an otherwise unbound target's fallback. The static holder never disposes the default client; a configured client remains caller-owned, while the lazily created client intentionally has isolate lifetime.

Ordinary `Query<TData>` and `query(...)` plus `InfiniteQuery<Page, PageParam>` and `infiniteQuery(...)` accept an optional client binding. Every observable `QueryTarget` and `InfiniteQueryTarget` exposes a non-null resolved `client`: an explicit binding wins, otherwise it resolves `QueryClient.defaultClient`. Retry, initial-data, select, observer, and placeholder transformations preserve the same binding. QueryClient instance methods remain explicitly receiver-owned: `otherClient.fetchQuery(boundQuery)` still operates on `otherClient`; the target binding is the default used by target-owned integrations such as QueryWidget, not a prohibition against explicit client operations.

For a target-owned observer, cache identity is the pair `(QueryClient identity, QueryKey)`. Equal structural keys in different clients are unrelated. A client identity change therefore replaces the observer rather than retargeting it inside the old client.

### 14. Export provider-free Flutter observer widgets from jolt_query

`jolt_query` depends on Flutter and `jolt_flutter`, keeps widget
implementations in Flutter-specific source modules inside the same package, and
exports ordinary-query, infinite-query, and mutation integrations from
`package:jolt_query/jolt_query.dart`:

```dart
typedef QueryWidgetBuilder<T> = Widget Function(
  BuildContext context,
  QueryObserver<T> observer,
);

class QueryWidget<T> extends StatefulWidget {
  const QueryWidget({
    super.key,
    required QueryTarget<T> query,
    required QueryWidgetBuilder<T> builder,
  });
}

class InfiniteQueryWidget<T> extends StatefulWidget {
  const InfiniteQueryWidget({
    super.key,
    required InfiniteQueryTarget<T> query,
    required InfiniteQueryWidgetBuilder<T> builder,
  });
}

class MutationWidget<V, D, R> extends StatefulWidget {
  const MutationWidget({
    super.key,
    QueryClient? client,
    required Mutation<V, D, R> mutation,
    required MutationWidgetBuilder<V, D, R> builder,
  });
}
```

QueryWidget and InfiniteQueryWidget read `query.client`, create one compatible
observer, expose that observer as borrowed to the builder, and dispose it at
unmount. They never dispose a QueryClient. Under one client, a new target is
applied to the existing observer. A different key switches entries while
preserving that observer's previous-presentation placeholder semantics. A new
target with the same structural key updates plan, selection, placeholder,
equality, freshness, enabled, polling, and trigger settings without detaching,
resetting the original mount-completion baseline, or re-running
`refetchOnMount`. Transitioning from disabled to enabled performs activation
rather than pretending the observer remounted. A removed entry that is no
longer owned by the cache is reattached safely instead of taking the same-entry
update path.

MutationWidget resolves its optional `client` to
`QueryClient.defaultClient`, owns one `MutationObserver<V,D,R>`, and never
executes automatically. `MutationObserver.updateMutation` changes the recipe
used by future submissions while an already submitted execution retains its
captured recipe. Equal nullable structural MutationKeys preserve the observer's
latest presentation; changing the key resets presentation to idle. A client
identity change disposes the old observer and creates an idle observer in the
new client. MutationWidget never binds a client into the mutation recipe and
never disposes the client.

Each widget observes its complete observer value through the existing
`JoltWatcher` mechanism. Its user builder is not wrapped in `JoltBuilder`, so
arbitrary Jolt reads inside the builder do not become implicit dependencies.
Observer-driven rebuilds therefore come only from the currently bound complete
result or compatible target transition. Ordinary Flutter parent and
inherited-dependency rebuilds remain normal Flutter behavior and are not
suppressed by caching a built child.

There is no QueryClientProvider and no `client` parameter on QueryWidget or
InfiniteQueryWidget. Applications bind a special client on those query targets
or rely on `QueryClient.defaultClient`. Mutation recipes intentionally do not
own clients, so MutationWidget alone accepts the optional explicit client.

An application may explicitly call `client.bindFlutterLifecycle()` once near its root. The returned disposable owns one Flutter application-lifecycle observer, maps resumed/non-resumed states to `focusManager`, initializes from the current lifecycle state, and never owns or disposes the client. QueryWidget itself does not install this binding, so multiple widgets cannot create duplicate lifecycle subscriptions.

### 15. Merge defaults as fallbacks and expose the executing client

Configuration resolves in the order `built-in < global defaults < matching key defaults < explicit recipe < terminal observer/call override`. The class-first and inline ordinary/infinite query APIs retain whether stale time, retention, network mode, retry, and polling enablement were omitted. The class-first and inline mutation/action APIs retain whether retry, retention, and network mode were omitted. Non-virtual public recipe policy getters expose the resolved constructor value; registered defaults never silently replace an explicit recipe value, including an explicitly supplied built-in. Matching registrations merge from broad to specific in registration order. `pollingEnabled: false` is the explicit-off state needed to override a broad query interval.

`QueryContext.client` is the actual receiver client executing the operation. It is not necessarily `query.client`, because `otherClient.fetchQuery(boundQuery)` is legal and receiver-authoritative. Infinite page contexts forward the same executing client through their contained query context.

`fetchingCount` and `countFetching` count only entries whose `FetchStatus` is `fetching`; paused work is observable through entry/observer state but is not reported as active transport. A background error with retained data keeps the data successful for presentation, records the refetch error, and makes the entry stale for later revalidation.

Structural key prefix matching recursively partial-matches nested list/map values while exact key equality remains fully structural. Default structural sharing preserves the caller-declared mutable collection type and reuses unchanged JSON-compatible branches; it never replaces `List<T>` or `Map<K,V>` with erased collection implementations.

## Risks / Trade-offs

- [Large initial surface] → Keep query, cache, observer, mutation, infinite, streamed, retry-adapter, and runtime modules cohesive and require named contract tests for every scenario.
- [Dart cannot infer an omitted mutation result type] → Bind all three types in class-first `Mutation<V, D, R>` recipes; infer `R` from a supplied inline `onMutate`, or require a complete expected type / explicit `void` when the hook is omitted.
- [Manual cache writes can be replaced by active work] → Keep writes and fetch cancellation orthogonal, document the visible race, and require callers to await `cancelQueries` before a write that must remain authoritative.
- [A revision checkpoint can be mistaken for complete rollback safety] → Specify only provenance/revision compare-and-set protection and direct overlapping optimistic work toward scope serialization, patch/rebase, or invalidation/refetch.
- [Public APIs reference `retry_plus` types without re-exporting them] → Pin 0.1.1, document the required direct dependency and dual import for custom policies, and keep default policies usable without that import.
- [`retry_plus` context contains executor facilities Jolt does not honor] → Document the five authoritative adapted fields and test that Jolt-owned time, random, wait, cancellation, and guards remain authoritative.
- [`retry_plus` custom/generated delay callbacks erase their outcome to Object?] → Preserve the dependency's honest signature while keeping retry predicates and hooks result-typed.
- [`retry_plus` 0.1.1 `onGiveUp` can run after eventual success] → Preserve and test that exact behavior, including hook failure converting success to failure, rather than silently presenting a different strategy contract.
- [Dart cannot forcibly cancel Futures] → Combine cooperative tokens with operation/incarnation/generation guards and avoid exposing mutation cancellation promises the runtime cannot reliably make.
- [Mutable caller data can bypass structural sharing] → Preserve declared types, reject in-place cache updates by contract, provide JSON-compatible reconciliation and debug diagnostics, and permit custom reconcilers.
- [Repeated keys may represent incompatible shapes] → Treat key reuse as the caller's explicit contract and do not add runtime type or definition mismatch machinery.
- [A mutable global client could split one application across caches] → Resolve and lock the static default before observation, reject disposed defaults, never replace or auto-dispose it after first use, and keep explicit per-query bindings available for tests and isolated caches.
- [Flutter parent rebuilds recreate same-key query objects] → Treat same-key retargeting as an options/presentation update rather than a mount, preserve observer identity and mount baseline, and cover ordinary parent rebuild plus cache-removal races with executable behavior tests.
- [Offline mutation retry can duplicate writes] → Disable mutation retry by default and document idempotency requirements.
- [Partial streamed values complicate retry rebuilding] → Track one logical-operation baseline and use operation/incarnation/cancellation guards so every retry rebuilds without duplicating failed partial output.
- [Upstream TanStack or dependency behavior may change] → Treat this OpenSpec and the pinned dependency tests as authoritative; adopt changes only through later proposals.

## Migration Plan

1. Add and register only `packages/jolt_query`, including its Flutter dependency and QueryWidget export, without changing existing Jolt APIs.
2. Implement the complete contract in module order: foundation, query cache/client, observers, retry adapter, mutations, infinite queries, and streamed queries.
3. Publish only after deterministic behavior/race tests, Flutter widget behavior tests, and all mapped capability scenarios pass.
4. Applications migrate repository-managed remote state query by query; existing local Jolt and AsyncSignal code remains supported.
5. Rollback removes the independent package. No stored application data or existing package behavior is changed.

## Open Questions

None.

## Validation Plan

Validation uses executable public behavior tests for the unified mutation and cache-boundary decisions, deterministic race and retry tests, Flutter widget tests, static analysis, example compilation, and strict OpenSpec validation. Source inspection, export scanning, and generated-text assertions are not acceptable substitutes for behavior tests.
