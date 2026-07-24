## 1. Package and Public Contract

- [x] 1.1 Create `packages/jolt_query` with SDK constraints, `fast_immutable_collections: ^11.2.0`, exact `retry_plus: 0.1.1`, Jolt public-API dependencies, strict analysis options, metadata, license, changelog, and README.
- [x] 1.2 Register the package in the workspace, repository analysis, test tooling, and CI.
- [x] 1.3 Update the public `jolt_query.dart` entry point for the unified Mutation V/D/R family and non-disposable caches while retaining only public-signature `IList` from FIC and no retry_plus exports.
- [x] 1.4 Update runtime behavior tests to exercise the revised observers, clients, cache boundaries, and existing Jolt integration through normal executable tests.
- [x] 1.5 Keep strict-inference, strict-casts, and strict-raw-types package settings, with ordinary type witnesses only inside executable behavior tests; do not add tests that read, scan, generate, or separately analyze Dart source.
- [x] 1.6 Document the revised public surface and excluded capabilities without source-inspection, generated-source, negative-compilation, or export-scan tests.

## 2. Deterministic Foundation and Ownership

- [x] 2.1 Implement exhaustive QueryValue with public const root/variant construction, presence getters, `valueOrNull`, and `requireValue`; test application construction, absent, present non-null, and present-null.
- [x] 2.2 Implement `QueryFailure` with exact Object and StackTrace preservation and snapshot-safe formatting/equality behavior.
- [x] 2.3 Implement public borrowed `QueryRuntime`, wall/monotonic `QueryClock`, one-shot/periodic `QueryTimerScheduler`, `[0,1)` `QueryRandomSource`, `QueryNotificationScheduler`, and idempotent `QueryScheduledHandle` capabilities plus deterministic fakes.
- [x] 2.4 Implement package-private timer orchestration with cancellable timeout/interval/retry handles and generation-safe late callbacks; do not expose `TimeoutManager`.
- [x] 2.5 Implement package-private notification orchestration with synchronous commit, queued cache/listener and automatic-observer callbacks, Jolt batch flushing, reentrancy safety, and injected scheduling; locally batch an imperative observer's complete result when its own refetch Future settles; do not expose `NotifyManager`.
- [x] 2.6 Implement `QueryCancellationToken` and controller with reason, completion Future, listeners, consumption tracking, throw helper, and idempotent cancellation.
- [x] 2.7 Implement client-owned stable `FocusManager` and `OnlineManager` with direct state, `setEventSource(Stream<bool>?)`, captured-Zone source error handling, completion cleanup/last-state retention, replacement cleanup, and platform-neutral defaults.
- [x] 2.8 Update ownership tests proving QueryClient disposal transitively disposes all client-owned resources, observers remain independently disposable without terminating the client, public caches cannot terminate owners, and borrowed runtime providers/caller-owned Streams remain undisposed.

## 3. Retry Facade and Manual Adapter

- [x] 3.1 Implement sealed `RetryPolicy<T>` with covariant `RetryPolicy<Never>.none` and `.standard` constant markers and typed `RetryPolicy<T>.custom` strategy factories.
- [x] 3.2 Implement `RetryBuilder<T>` as a narrow type witness with `exceptions`, `exceptionWhere`, `exceptionType<E>`, `result`, `where`, `any`, `never`, `maxRetries`, and `strategy` helpers.
- [x] 3.3 Keep all `retry_plus` types out of `jolt_query.dart` exports; document that custom-policy users declare/import `retry_plus` directly while default marker users do not.
- [x] 3.4 Implement once-per-operation strategy creation and exact manual policy order: context → await shouldHandle → when accepted await onRetry → await delay.compute → owned delay/online gate; when refused after a prior retry await onGiveUp → final outcome.
- [x] 3.5 Construct adapted `RetryAttemptContext<T>` values using one detached upstream `RetryPipelineContext<T>` identity per logical operation, resynchronize elapsed, preserve stateful-delay behavior, await predicates/delay/hooks, and document every unsupported executor member and overwritten elapsed writes.
- [x] 3.6 Revalidate retry integration against unified Mutation<V,D,R>, explicit query cancellation, client-only disposal, generation guards, failure-state commits, and final-observer retry stopping.
- [x] 3.7 Support every 0.1.1 exception/result/attempt/elapsed/budget predicate, finite and unlimited composition, delay, jitter, `onRetry`, and `onGiveUp` form without accepting or invoking `RetryPipeline` or top-level executors; preserve custom/generated delay outcome erasure to Object?.
- [x] 3.8 Add adapter contract tests for exact predicate/hook/delay order, first-attempt no-give-up, exception/result retry, budget exhaustion returning final Data, typed hooks, deterministic jitter, online pauses, cancellation during delay, late completion, and stage failures.
- [x] 3.9 Add exact 0.1.1 regression tests where `onGiveUp` runs after a retry followed by success and where a throwing hook converts that success into operation failure.
- [x] 3.10 Implement documented defaults: observer queries retry three times with non-jittered one-to-thirty-second exponential delay; imperative queries and mutations default to no retry.

## 4. Keys Recipes and Staged Query API

- [x] 4.1 Implement one recursive normalizer used by QueryKey and MutationKey for supported scalar/List/Map values, defensive FIC conversion, map-order independence, cached hash, structural equality, and prefix matching.
- [x] 4.2 Implement numeric canonicalization: keep int, convert finite integral double to int, equate `1`/`1.0` and `-0.0`/`0`, retain finite fractional double, and reject NaN/infinity at every depth.
- [x] 4.3 Add key property tests for equality/hash consistency, nested normalization, mutable-input isolation, global FIC configuration independence, unsupported leaves, and prefix matching.
- [x] 4.4 Implement non-generic QueryKey and MutationKey public values; keep MutationKey limited to filtering/defaults/observation with no identity, deduplication, or serialization behavior.
- [x] 4.5 Implement `QueryFunction<TData>`, QueryContext, non-generic `AnyQueryTarget`, terminal `QueryTarget<TView>`, select-capable `QueryView<TView>`, and externally subclassable `Query<TData>`.
- [x] 4.6 Implement the inline `query(...)` factory with marker-only retry input and typed `Query<TData>.withRetry` transformation after inference.
- [x] 4.7 Implement `Query<TData>.withInitialData(TData, {updatedAt}) -> QueryView<TData>`, `QueryView.select -> QueryView`, and terminal `withObserver`, `withPlaceholderData`, and `withPlaceholder` transformations.
- [x] 4.8 Add executable recipe and observer tests for a minimal final Query subclass implementing key/fetch, the legal retry → initial → repeated select → terminal order, and direct Query/QueryView observation.
- [x] 4.9 Implement immutable resolved fetch plans and structural-key-only cache identity so recipe class/type/function/policy/reconciler never creates mismatch behavior.
- [x] 4.10 Implement DataReconciler with identity and FIC fast paths, JSON-compatible branch reuse, custom reconcilers, preserved caller types, and diagnostics for common in-place List/Map reuse.

## 5. Query State Cache and Typed Client Operations

- [x] 5.1 Implement canonical query state with `QueryValue`, timestamps, update counts, invalidation revision, final and transient retry failures, QueryStatus, FetchStatus, and PauseReason.
- [x] 5.2 Implement private QueryEntry state, observers, retained executable plan, one active lane, operation ID, incarnation ID, rollback state, retention, and revision guards.
- [x] 5.3 Make QueryCache a non-disposable client-owned store with immutable erased snapshots and broadcast events; make cache-local clear remove entries in stable order, cancel/guard old query work, invalidate every issued checkpoint lineage, leave mutations/client/event streams/observers alive, and reattach live observers to fresh incarnations under normal activation policy.
- [x] 5.4 Implement shared single-flight initial fetch, cached refetch replacement, immutable per-operation plan capture, guarded completion, retained-data failures, and global callback ordering.
- [x] 5.5 Implement explicit query cancellation/reversion, token-consumption-aware final-observer detach, future-retry stopping, ignored late completion, and no cancellation failure count.
- [x] 5.6 Implement invalidation revisions, active-operation-safe GC, longest retention, forever retention, reattachment cancellation, and stale-timer generations.
- [x] 5.7 Change `QueryDataSnapshot<T>` into a data-only revisioned checkpoint with complete `QueryValue<T>`/timestamp/revision and opaque client/key/lineage provenance; preserve existing entries on absent restore, make valid absent-to-missing restore a no-op, and invalidate all issued lineages on cache clear including missing-key checkpoints.
- [x] 5.8 Make exact `setQueryData`, `updateQueryData`, and conditional `restoreQueryData` update only the data lane while preserving active operation identity, token, fetch status, and pause state; keep selected views excluded.
- [x] 5.9 Apply the same non-cancelling data-lane semantics to stable-order typed bulk reads and writes using `TypedQueryFilter<T>` and `QueryDataMatch<T>`.
- [x] 5.10 Implement QueryFilter freshness from invalidation, absence, and live attached-observer aggregation rather than retained-plan stale policy; publish `freshnessChanged` only for pure aggregate changes not already represented by another cache event.
- [x] 5.11 Revalidate global and key-prefix query/mutation defaults with unified Mutation<V,D,R>, observer-owned freshness, registration-order merging, and general-before-specific tests.
- [x] 5.12 Implement `QueryBatchResult` and key-associated `QueryBatchFailure` with exact pre-match, affected, non-executable skip, failure-subset, no-op count, and pre-match-stable failure ordering semantics.
- [x] 5.13 Implement fetchQuery, prefetchQuery, and ensureQueryData with type inference, freshness, optional background revalidation, no-retry imperative default, and documented prefetch error behavior.
- [x] 5.14 Revalidate asynchronous invalidate/refetch/cancel/reset reports, synchronous remove, and void clear; ensure QueryClient.clear composes query cancellation/removal with permanently detached mutation-cache records while leaving active mutations and the client usable.
- [x] 5.15 Revalidate reactive fetching and mutating counts against freshness-only events, cache-local clear, unified mutation snapshots, and batched notification.
- [x] 5.16 Add behavior and race tests for non-cancelling exact/bulk writes during active fetch, explicit cancel-before-write protection, complete-QueryValue restore including absent-to-missing no-op and clear-wide lineage invalidation, freshness disagreement/event deduplication, cache clear cancellation plus observer reattachment during active query/mutation work, client-only disposal, remove/recreate, invalidation, and GC/attachment.

## 6. Query Observers Dynamic Observation and Environment Triggers

- [x] 6.1 Implement `QueryObserver<TView>` as Readable/Disposable with fixed observeQuery, reactive watchQuery, entry switching, refetch, snapshot access, and idempotent disposal.
- [x] 6.2 Implement raw shared initial data and nullable present-null semantics before selection, first-writer initialization, and typed updatedAt.
- [x] 6.3 Implement final-view placeholder values and presence-aware previous-view resolvers after selection without cache writes or selector invocation.
- [x] 6.4 Implement selector composition/memoization, custom equality, observer-local failures, and selected structural sharing.
- [x] 6.5 Implement enabled, stale override, retryOnMount, refetch-on-mount/focus/reconnect, immutable behavior, and manual refetch of disabled targets.
- [x] 6.6 Implement observer polling with dynamic intervals, focus policy, no overlap, and entry-level deduplication.
- [x] 6.7 Implement online, always, and offline-first modes; separate paused continuation from reconnect refetch and suppress always-mode reconnect by default.
- [x] 6.8 Implement complete result flags and field-level tracked getters; make `observer.value` track the whole result and publish all transition fields atomically.
- [x] 6.9 Implement `QueriesObserver<IList<ErasedQueryObserverResult>>` for fixed/reactive `AnyQueryTarget` lists and `QueriesObserver<R>` combined variants without raw types or dynamic.
- [x] 6.10 Add dynamic-list tests for input order, target addition/removal/reorder, duplicate-key sharing, erased results, combiner reconciliation, and removed-observer disposal.
- [x] 6.11 Document statically typed heterogeneous composition using individual observers and Dart records rather than a variadic dynamic API.
- [x] 6.12 Add focus/reconnect storm, multiple polling interval, placeholder isolation, selector failure, field tracking, observer detach, and retained-plan lifecycle tests.
- [x] 6.13 Implement reactive single-query structural-key switching with absent-key fetch, fresh-cache reuse, and observer-local previous-view placeholder presentation.
- [x] 6.14 Publish predictable observer duration deadlines without fetching and emit a cache freshness event only when the live observer aggregate changes; keep arbitrary resolver policies event-driven.
- [x] 6.15 Add behavior tests for dynamic key fetch/revisit, duration expiry without a request, observer freshness disagreement, unobserved aggregate freshness, and stale focus refetch.

## 7. Mutation Runtime and Actions

- [x] 7.1 Replace public MutationRecipe and ordinary/optimistic families with one externally subclassable `Mutation<V,D,R>`, one inline factory, optional typed onMutate callback getter, typed retry transformation, MutationScope-by-ID, metadata, policies, and MutationContext.
- [x] 7.2 Refactor package-private `MutationExecution<V,D,R>` to retain `QueryValue<R>` onMutateResult presence plus ID, variables, data, failure state, submitted time, pause reason, completion, queue membership, and generation guards.
- [x] 7.3 Expose only typed `Future<D>` execution through `QueryClient.execute<V,D,R>` and one `observeMutation<V,D,R>` family; keep execution handles, cancellation, and cancelled status private.
- [x] 7.4 Rename erased snapshot/cache lifecycle state from optimistic context to onMutateResult, keep submission ordering and filters, make MutationCache non-disposable, and implement the specified immutable `MutationCacheCallbacks` typedefs/config plus zero-config QueryClient constructor capture.
- [x] 7.5 Enforce idle-only observer presentation, pending/success/error execution snapshots, pause/retry invariants, Data presence, optional onMutateResult absence/present-null, and mutation-function-only failureCount semantics.
- [x] 7.6 Collapse duplicate observer/result/binding implementations into `MutationObserver<V,D,R>` and `MutationObserverResult<V,D,R>` with latest-execution presentation, reset, idempotent disposal, and continuation of detached work.
- [x] 7.7 Implement cache then optional recipe onMutate ordering, `QueryAbsent<R>` for omission/failure, `QueryPresent<R>` for successful values including null, and typed propagation to every later lifecycle surface.
- [x] 7.8 Revalidate the at-most-once awaited lifecycle state machine with unified callbacks: cache before recipe, primary failure selection, non-repeating error chain, absent terminal Data after callback failure, cleanup continuation, and Zone delivery of secondary errors.
- [x] 7.9 Pass `QueryValue<R>` to eligible generation-bound per-call callbacks after terminal commit and scope release; retain per-call error and same-scope reentrant-submission behavior, with final observer/Future visibility order revalidated by 13.6.
- [x] 7.10 Revalidate parallel default execution and same-client FIFO MutationScope lanes through offline waits, retry delays, mutation work, and awaited unified lifecycle callbacks.
- [x] 7.11 Preserve online/always/offline-first behavior, no-retry default, Data-typed retry_plus policies while retaining V/D/R, and non-idempotent-write documentation.
- [x] 7.12 Keep all Query Cache coordination user-composed through lifecycle QueryClient calls; add explicit optimistic examples without automatic cancel/write/rollback/invalidation and document conditional-checkpoint overlap limits.
- [x] 7.13 Implement automatic in-process pause continuation, settled retention/GC, and MutationCache.clear removal events plus permanent active-record detachment without cancellation/reinsertion; keep Future/observer/scope/retry/captured callbacks alive and reserve terminal disposal for QueryClient.
- [x] 7.14 Guard already-started transports/callbacks after client disposal: acknowledge unavoidable external side effects but prevent every later callback and mutation/query-cache commit.
- [x] 7.15 Replace ordinary/optimistic action variants with one `action<D,R>`, the specified typed `MutationObserver<NoVariables,D,R>.run` callbacks, and `QueryClient.executeAction<D,R>`; hide NoVariables from action recipe/per-call public callbacks while uniform global callbacks receive NoVariables.value.
- [x] 7.16 Add executable behavior tests for V/D/R inference, default/global callback signatures and capture, omitted/present/present-null onMutateResult, non-cache tokens, action sentinel adaptation, out-of-order calls, snapshot invariants, callback failures, per-call ownership, scopes, retry, explicit cache composition, overlapping rollback limits, retention, clear detachment/count/event semantics, and client disposal.

## 8. Infinite Queries

- [x] 8.1 Implement aligned defensive `InfiniteData<Page, PageParam>`, `InfinitePageContext<PageParam>`, and covariant nullable-safe `PageCursor.end/more`.
- [x] 8.2 Implement externally subclassable `InfiniteQuery<Page, PageParam>` and inline factory using `fetchPage`, whole-data next resolver, concrete default-end/optional inline previous resolver, initial PageParam, and optional positive maxPages.
- [x] 8.3 Implement specialized `InfiniteQueryView<TView>` and terminal `InfiniteQueryTarget<TView>` stages preserving direction through retry, raw initial data, repeated select, observer, and placeholder transformations.
- [x] 8.4 Type retry to complete `InfiniteData<Page, PageParam>` and document/test page validation through thrown `fetchPage` failures rather than Page result predicates.
- [x] 8.5 Implement initial page integration and next/previous direction methods returning selected `InfiniteQueryObserverResult<TView>`, with current-result no-op when no cursor exists.
- [x] 8.6 Implement one canonical QueryFailure plus directional fetch/error flags without separate directional error objects or selected Page/PageParam leaks.
- [x] 8.7 Implement one operation lane, default `cancelRefetch: true`, false-mode joining/no-op, cursor validation, cancellation guards, and aligned directional commits.
- [x] 8.8 Implement sequential full refresh with cursor recomputation, old-data visibility, early end, failure rollback, and atomic complete commit.
- [x] 8.9 Implement maxPages trimming from the opposite edge and resolver-defined direction availability.
- [x] 8.10 Implement fetch/ensure returning InfiniteData and prefetch returning void with positive `{pages = 1}` plus all six inherited typed exact cache operations through `QueryDataTarget<InfiniteData<Page, PageParam>>` and ordinary lifecycle operations.
- [x] 8.11 Add executable recipe and client behavior tests for nullable PageParam, optional previous resolvers, selected direction results, no-cursor behavior, overlaps, refresh failure, early end, maxPages, GC, and structural sharing.

## 9. Streamed Queries

- [x] 9.1 Implement `StreamRefetchMode` and `streamedQuery<Chunk, Data>` with per-attempt initial factory, synchronous reducer, and ordinary QueryFunction<Data> output.
- [x] 9.2 Implement pending-before-first-visible-chunk, success-after-partial-commit, fetching-until-close, mode/baseline-specific empty-stream final values, and replace-mode retained presentation.
- [x] 9.3 Integrate `RetryPolicy<Data>` so stream/reducer errors use exception predicates and final normal-close Data invokes result predicates exactly once, never per chunk.
- [x] 9.4 Retain one logical-operation baseline and guard chunks/retries/commits by operation identity, incarnation, explicit cancellation, replacement, and disposal without treating manual cache writes as supersession.
- [x] 9.5 Update reset retries to clear the baseline only at logical-operation start, rebuild private state from fresh initial values without retry-start cache writes, preserve the then-current visible value on exhaustion, and avoid revision-owned supersession.
- [x] 9.6 Update append retries to rebuild private accumulators from the logical baseline without duplication or retry-start cache writes, while allowing only later accepted stream output to replace uncancelled manual values.
- [x] 9.7 Update replace private accumulation and final guarded commit so uncancelled manual writes remain visible only until the active stream may accept its final result.
- [x] 9.8 Implement result-retry budget exhaustion as successful final Data commit for every mode.
- [x] 9.9 Implement per-attempt StreamSubscription cancellation, explicit cancel-before-write protection, and late event rejection through operation/incarnation/generation guards.
- [x] 9.10 Revalidate ordinary cache, observers, filters, invalidation, environment triggers, polling, GC, cache events, and structural sharing after removing data-revision supersession and visible baseline restoration.
- [x] 9.11 Add tests for new subscription/initial per retry, append private-baseline reuse without duplication, reset attempt transitions, replace discard, empty/no-chunk modes, final-only result retry, manual writes replaced only by accepted output and preserved on intervening exhaustion, explicit cancel-before-write protection, remove/recreate, and shared observers.

## 10. Documentation and Release Verification

- [x] 10.1 Update package concepts, state matrices, staged Query ordering, V/D/R mutation typing, explicit presence, client-only ownership, cache-local clear, defaults, and the package boundary from AsyncSignal and generic Task.
- [x] 10.2 Update examples for reusable/inline queries, selection, data-only checkpoints, non-cancelling writes, explicit cancel-before-write, invalidation, prefetch, polling, focus/online modes, and dynamic erased versus record observation.
- [x] 10.3 Add retry examples showing marker policies with only the Jolt Query import and custom policies with a direct `retry_plus` dependency plus dual imports; document adapted context and exact onGiveUp semantics.
- [x] 10.4 Replace ordinary/optimistic examples with one `Mutation<V,D,R>` family showing omitted onMutate, a non-cache result, optional optimistic cache behavior, action, scope, idempotent retry, conditional-restore limits, InfiniteQuery, and streamed modes.
- [x] 10.5 Document all revised ownership: stable client managers, replaceable event sources, caller-owned Streams, borrowed QueryRuntime providers, client-created handles, non-disposable caches, observers, checkpoints, and mutation Futures.
- [x] 10.6 Regenerate API documentation for the revised public surface and document excluded capabilities, dependency ownership, and package boundaries without testing source text or export diagnostics.
- [x] 10.7 Run formatting and analysis with strict modes and resolve every warning/error after the boundary refactor.
- [x] 10.8 Run the complete deterministic package suite and existing workspace tests after updating behavior coverage.
- [x] 10.9 Remap every revised OpenSpec scenario to a named executable behavior test and record no source-inspection substitutes or implicit divergences.
- [x] 10.10 Update the runnable Flutter Web demo for the unified Mutation API, explicit optimistic behavior, non-cancelling cache writes, stale deadlines, query-key switching, and visible refetch triggers.

## 11. Client-bound Queries and Flutter QueryWidget

- [x] 11.1 Implement `QueryClient.defaultClient` and `QueryClient.setDefault(...)` with lazy zero-configuration creation, pre-resolution configuration, disposed-client rejection, locked identity after resolution, caller-owned disposal, and receiver-authoritative explicit QueryClient operations.
- [x] 11.2 Add optional client binding to class-first and inline ordinary/infinite queries, expose the lazily resolved client on every observable target, and preserve the nullable configured binding without premature default resolution through retry, initial-data, select, observer, and placeholder transformations.
- [x] 11.3 Correct same-key QueryObserver retargeting so it updates plan/presentation options without detach, mount-policy refetch, or `isFetchedAfterMount` reset; implement enabled activation and safe reattachment when cache removal races its queued notification.
- [x] 11.4 Add executable core behavior and race tests for default/explicit client binding, lazy unbound staging, transformation preservation, explicit receiver override, same-key target updates, activation, and removal races; do not inspect or match source files.
- [x] 11.5 Make `packages/jolt_query` Flutter-capable with Flutter and `jolt_flutter` dependencies, remove/unregister `packages/jolt_query_flutter`, and leave only the single `jolt_query` workspace package and dependency surface.
- [x] 11.6 Move the provider-free `QueryWidget<T>` implementation into `packages/jolt_query`, export it from `package:jolt_query/jolt_query.dart`, and retain only query and builder inputs, query-owned client resolution, observer reuse/replacement/disposal, complete-result JoltWatcher subscription, and no JoltBuilder wrapping.
- [x] 11.7 Add executable Flutter behavior tests inside `packages/jolt_query` for mount/unmount ownership, same-key parent rebuild without mount refetch, key and client switching, placeholder preservation, cache and observer-state rebuilds, unrelated-cache isolation, and lack of implicit builder-signal tracking; do not inspect source text.
- [x] 11.8 Document the single-package default-client, client-bound query, and QueryWidget APIs with concise examples, then run formatting, strict analysis, runtime tests, Flutter widget tests, and relevant workspace verification.
- [x] 11.9 Migrate the runnable Flutter Web demo's primary key/freshness story to `QueryWidget`, bind that query to the demo client, remove its controller-owned observer, preserve key switching, stale triggers, and previous-data presentation, and verify the example through executable Flutter tooling.

## 12. TanStack Semantic Parity Consolidation

- [x] 12.1 Preserve explicit-versus-omitted class-first and inline ordinary-query, infinite-query, mutation, and action policy configuration; resolve built-in, registered defaults, recipe values, and terminal overrides in that order, including explicit built-in values and polling disable.
- [x] 12.2 Separate observed attachment from enabled active state; update snapshots, filters, aggregate freshness, invalidation/refetch eligibility, and disabled observer result semantics.
- [x] 12.3 Give every inactive entry effective retention and GC scheduling, including manual writes and fresh imperative cache hits.
- [x] 12.4 Make imperative ordinary and infinite fetch/prefetch join active work by default with explicit retained-data replacement, while keeping observer and bulk refetch replacement defaults.
- [x] 12.5 Add actual executing QueryClient to QueryContext and forward it through InfinitePageContext.
- [x] 12.6 Replace irreversible observer-detach retry stopping with pause/resume eligibility, make inactive lifecycle retry independent of observer activity, and gate retry continuation on focus plus applicable online state.
- [x] 12.7 Mark retained-data terminal refetch failures stale for later revalidation; make fetchingCount/countFetching count only FetchStatus.fetching and exclude paused eligibility waits.
- [x] 12.8 Apply already-mounted ordinary and infinite key-switch fetch rules independently from refetchOnMount, preserve previous-view presentation and unchanged result identity, and align completion/mount-relative fetched flags with data/error updates while excluding initial-data seeds.
- [x] 12.9 Reuse dynamic multiple-query child observers by client, structural key, and duplicate occurrence when new target instances retain identity.
- [x] 12.10 Preserve retained infinite windows during refresh, retain successful-page progress across exception retry, guard every later page start against cancellation/replacement/disposal, support imperative pages, and retarget infinite observers without remount.
- [x] 12.11 Preserve typed List/Map roots during structural sharing and recursively partial-match nested query-key filter/default prefixes.
- [x] 12.12 Add streamedListQuery as a typed convenience over the existing attempt-aware streamed-query engine.
- [x] 12.13 Add an explicitly installed and disposed provider-free Flutter application lifecycle focus binding.
- [x] 12.14 Add executable public-behavior tests for every consolidation scenario; never read, scan, or match implementation source text.
- [x] 12.15 Update README, API examples, and Flutter Web demo where semantics or signatures changed.
- [x] 12.16 Run formatter, package/workspace analysis, the complete jolt_query behavior/widget suite, and strict OpenSpec validation; resolve every failure before marking this section complete.

## 13. TanStack Query v5.101.4 Final Semantic Convergence

- [x] 13.1 Make ordinary, infinite, mutation, and action class-first policy
  getters non-virtual constructor views; remove value-comparison inference of
  explicitness; expose resolved `isEnabled` across typed, erased, and infinite
  results plus the missing MutationObserver status convenience getters.
- [x] 13.2 Align ordinary fetch-start and cancellation rollback transitions:
  an absent error refetch re-enters pending/loading, and successful exact,
  conditional, or bulk manual writes advance an active operation's revert data
  baseline while cancellation normalizes the released lane to idle.
- [x] 13.3 Centralize TanStack-compatible Query-wide `isFetched`,
  `isDisabled`, `isStatic`, and observer-first `isStale` aggregation; make bulk
  work skip disabled, never-fetched, and any-observer-static entries while
  retaining explicit observer refetch.
- [x] 13.4 Add `invalidateQueries(cancelRefetch: true)`, remove serial guarded
  follow-up behavior, align join/replacement and invalidation clearing, and
  allow immediately paused invalidate/refetch/reset items to complete their
  batch Future while cache-owned work continues safely.
- [x] 13.5 Add immutable QueryCache `onSuccess`, `onError`, and `onSettled`
  callbacks with post-commit immutable snapshots, exact once-per-terminal
  operation behavior, present-null/retained-data support, Zone-contained
  callback failures, and no invocation for transient attempts, partials,
  manual writes, cancellation, or superseded work.
- [x] 13.6 Make MutationObserver terminal presentation synchronously visible
  before per-call callbacks and Future settlement without duplicate queued
  publication; add `updateMutation` with same-key preservation, changed-key
  reset, and captured in-flight recipe behavior.
- [x] 13.7 Move infinite mount, activation, key-switch, focus, reconnect,
  stale-deadline, polling, and disposal decisions onto the ordinary
  QueryObserver lifecycle; make absent direction calls start the initial page
  with direction metadata and make directional errors mutually exclusive with
  whole-window refetch errors.
- [x] 13.8 Align streamed reset with TanStack fetched/reset-state semantics:
  preserve initial data on the never-fetched first attempt, restore configured
  reset state at every fetched retry attempt, and classify terminal failure
  from the resulting visible value while retaining the documented append and
  replace retry guarantees.
- [x] 13.9 Add typed state-derived polling through
  `QueryPollingIntervalResolver<T>`, mutually exclusive with a fixed interval,
  using generation-safe one-shot scheduling and ordinary enabled/static/focus/
  background/no-overlap rules.
- [x] 13.10 Add provider-free `InfiniteQueryWidget` and `MutationWidget` to the
  single `jolt_query` package, preserving compatible observer identity,
  explicit mutation client ownership, same-key recipe retargeting, complete
  result rebuilding, and no implicit JoltBuilder tracking or automatic work.
- [x] 13.11 Update README, API examples, and the runnable Flutter Web feature
  tour for changed lifecycle ordering, invalidation/static/reset semantics,
  QueryCache callbacks, state-derived polling, and all three Flutter observer
  widgets.
- [x] 13.12 Add only executable public-behavior regression tests for every new
  scenario; never read, scan, or match source text. Run formatter, strict
  package/workspace analysis, the complete jolt_query runtime/widget suite,
  example verification, and strict OpenSpec validation before completing this
  section.
