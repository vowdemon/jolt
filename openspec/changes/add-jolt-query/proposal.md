## Why

Jolt currently provides local reactive primitives and basic asynchronous signals, but applications must repeatedly implement remote-data caching, request deduplication, freshness, invalidation, retries, pagination, mutations, and in-process offline coordination themselves. A standalone `jolt_query` package will provide a complete TanStack Query-inspired server-state runtime while keeping `jolt` focused on local reactivity.

## What Changes

- Add one Flutter-capable `jolt_query` package that depends on Jolt's public reactive API and `jolt_flutter`, exposes the framework-independent server-state runtime through disposable reactive observers, and exports its Flutter integration from `package:jolt_query/jolt_query.dart`.
- Add provider-free `QueryWidget`, `InfiniteQueryWidget`, and `MutationWidget`
  integrations inside `jolt_query`. Each widget owns only its observer,
  preserves same-client observer identity across parent rebuilds, and rebuilds
  only from the observer's complete result rather than implicitly tracking
  arbitrary builder reads.
- Add a Dart-native staged class-first Query<T> API plus an inference-friendly inline query(...) factory over the same runtime model, fast_immutable_collections-backed structural query keys, shared query caching, observers, filters, defaults, freshness, garbage collection, invalidation, refetching, deeply customizable `retry_plus` retry strategies, polling, cancellation, focus, online, and network-mode behavior.
- Align shared query-core semantics with TanStack Query v5.101.4 where the
  concepts match: no-data retry re-enters pending/loading state, manual writes
  advance cancellation rollback state, invalidation exposes TanStack-compatible
  replacement control, paused bulk work does not hold lifecycle Futures open,
  disabled/static/never-fetched eligibility follows the shared Query model,
  mutation settlement is observer-visible before callbacks and Futures settle,
  infinite direction and streamed refetch modes share ordinary query
  transitions, and query-cache lifecycle callbacks run once per terminal
  operation.
- Add a lazily available static default `QueryClient`, configurable through `QueryClient.setDefault(...)`, and allow ordinary and infinite query targets to carry an explicit client binding that survives every staged transformation.
- Add one class-first `Mutation<Variables, Data, OnMutateResult>` API plus an inline factory, explicit-versus-omitted retry/network/retention policies, typed `onMutate` lifecycle results, per-execution state, explicit QueryClient cache coordination, scoped serial execution, retries, zero-variable action conveniences, and automatic in-process network/focus pausing and continuation. Optimistic cache updates remain an optional behavior composed inside lifecycle callbacks rather than a mutation subtype.
- Add class-first InfiniteQuery<Page, PageParam> plus an inline factory for forward and backward pagination, retained-window sequential refresh, progress-preserving page retry, cancellation-guarded page chains, observer retargeting, directional state, and bounded page retention.
- Add streamedQuery helpers for generic reduction and typed list accumulation through ordinary queries with reset, append, and replace refetch modes.
- Add a borrowed clock/timer/random/notification runtime plus stable client-owned focus and online managers with replaceable event sources so asynchronous lifecycle behavior is deterministic and testable.
- Add an explicit provider-free Flutter lifecycle binding that drives a chosen client's focus manager without making lifecycle ownership implicit in every QueryWidget.
- Explicitly exclude cache persistence, cross-process paused-mutation recovery, multi-client synchronization, DevTools, public server/client hydration APIs, QueryClient provider/inherited-widget APIs, and UI-framework-specific Suspense or ErrorBoundary behavior from this version.

## Capabilities

### New Capabilities

- `query-runtime`: Class-first typed query recipes, structural query identity,
  shared caching, reactive observers, client operations, TanStack-compatible
  disabled/static/fetched eligibility, fallback defaults, explicit
  cancellation, non-cancelling typed cache writes with cancellation-safe
  rollback baselines, revisioned conditional data checkpoints, filtering,
  query-cache lifecycle callbacks, resumable `retry_plus` integration,
  state-derived polling, focus/online behavior, structural sharing, and
  deterministic runtime infrastructure.
- `query-mutations`: One typed mutation model, mutation executions, mutation cache and observers, typed lifecycle results, explicit user-composed query-cache updates, scoped serialization, customizable retry, and in-process network pausing.
- `infinite-queries`: Cursor-based bidirectional page fetching, directional state, retained-window sequential refresh, progress-preserving page retries, cache integration, and bounded page retention.
- `streamed-queries`: Ordinary query-function helpers for generic reduction and typed list accumulation with cancellation and reset/append/replace refetch behavior.
- `flutter-query-widgets`: Provider-free Flutter widgets for ordinary queries,
  infinite queries, and mutations. Query targets resolve their configured or
  default client, MutationWidget accepts an optional explicit client, widgets
  preserve compatible observer identity across target updates, rebuild from
  complete observer-result transitions, and coexist with an explicitly owned
  application-lifecycle focus bridge.

### Modified Capabilities

None.

## Impact

- Adds and registers only `packages/jolt_query` in the repository workspace and test tooling.
- Adds new public Dart APIs for class-first and inline queries, observers, caches, mutations, infinite queries, streamed query functions, retry customization, and environment integration.
- Adds `QueryClient.defaultClient`, `QueryClient.setDefault(...)`, client-bound
  query targets, immutable QueryCache callback policy, and Flutter
  `QueryWidget<T>`, `InfiniteQueryWidget<T>`, and
  `MutationWidget<V, D, R>` integrations without a QueryClientProvider.
- Makes `jolt_query` a Flutter package depending on the Flutter SDK and `jolt_flutter`, while keeping its cache, client, observer, mutation, infinite-query, streamed-query, and retry runtime implementation free of Flutter lifecycle or widget dependencies. This does not change the existing `jolt` runtime contract.
- Retains exact `retry_plus: 0.1.1` and `fast_immutable_collections`; the package adapts `retry_plus` strategies but does not re-export its symbols, so applications using custom strategies declare and import `retry_plus` directly.
- Requires comprehensive deterministic tests for state transitions, races, cancellation, timers, retry customization, and in-process offline continuation.
