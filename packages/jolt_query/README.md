# Jolt Query

Jolt Query is a Flutter server-state cache built for Jolt. It provides
structural cache keys, shared single-flight fetching, reactive observers,
stale and retention policies, background refetching, mutations, infinite
queries, stream-backed queries, deterministic runtime capabilities, and a
provider-free `QueryWidget`, `InfiniteQueryWidget`, and `MutationWidget` in
one package.

Use it for remote or otherwise shared asynchronous data whose lifetime is not
owned by one widget, signal, or operation.

## Installation

```sh
flutter pub add jolt_query
```

Import the public barrel:

```dart
import 'package:jolt_query/jolt_query.dart';
```

Custom retry policies also require a direct `retry_plus` dependency. See
[Custom retry](#custom-retry); Jolt Query deliberately does not re-export that
package.

## Guide

- [Quick start](#quick-start)
- [Define, transform, and observe queries](#define-a-query)
- [Client binding and the default client](#client-binding-and-the-default-client)
- [Reactive key changes](#reactive-key-changes)
- [Freshness, triggers, and retention](#freshness-refetch-triggers-and-retention)
- [Imperative query and cache operations](#imperative-query-operations)
- [Multiple queries and defaults](#observe-multiple-queries)
- [Retry](#retry)
- [Mutations and optimistic updates](#mutations)
- [Infinite queries](#infinite-queries)
- [Stream-backed queries](#stream-backed-queries)
- [Runtime and ownership](#deterministic-runtime)
- [Flutter observer widgets](#flutter-observer-widgets)
- [Public API quick reference](#public-api-quick-reference)

## Quick start

```dart
import 'package:jolt_query/jolt_query.dart';

Future<void> main() async {
  final client = QueryClient();

  final todosQuery = query<List<String>>(
    key: QueryKey(<Object?>['todos']),
    fetch: (_) async => <String>['write the README'],
    staleTime: StalePolicy.duration(const Duration(minutes: 1)),
  );

  final observer = client.observeQuery(todosQuery);
  final result = await observer.refetch();

  if (result.data.isPresent) {
    print(result.data.requireValue());
  } else {
    print(result.failure?.error);
  }

  observer.dispose();
  client.dispose();
}
```

The observer starts a fetch when it attaches to an empty entry. Calling
`refetch()` during that initial load joins the same operation. Another observer
using the same structural key shares the cache and in-flight request.

`observer.value` and its field getters are Jolt reactive reads. `snapshot` and
`peek` are synchronous, untracked reads.

## Mental model

| Concept | Responsibility |
| --- | --- |
| `Query<T>` | Reusable description of how raw server data `T` is fetched. |
| `QueryKey` | Structural identity of one shared query-cache entry. |
| `QueryView<T>` | A query stage that can still be transformed with `select`. |
| `QueryTarget<T>` | An observable, client-bound view, optionally configured with observer and placeholder behavior. |
| `QueryObserver<T>` | Reactive state for one currently attached target. |
| `QueryClient` | Owns caches, operations, defaults, environment state, observers, and lifecycle. |
| `Mutation<V, D, R>` | Reusable write operation: variables `V`, success data `D`, optional `onMutate` result `R`. |
| `QueryValue<T>` | Distinguishes absent data from present data, including present `null`. |

Jolt Query is for server state. Continue to use ordinary Jolt signals or task
abstractions for application-owned state and arbitrary one-off work.

## Structural keys

Queries with equal `QueryKey` values address the same cache entry, regardless
of recipe class, instance identity, fetch closure, or selected view:

```dart
final first = QueryKey(<Object?>[
  'todos',
  <String, Object?>{'status': 'open', 'page': 1},
]);

final second = QueryKey(<Object?>[
  'todos',
  <String, Object?>{'page': 1.0, 'status': 'open'},
]);

assert(first == second);
assert(first.startsWith(QueryKey(<Object?>['todos'])));
assert(
  first.startsWith(
    QueryKey(<Object?>[
      'todos',
      <String, Object?>{'status': 'open'},
    ]),
  ),
);
```

Keys accept recursive values made from:

- `null`, `bool`, `String`, `int`, and finite `double`;
- `List` or `IList`;
- `Map` or `IMap` with `String` keys.

Map insertion order does not affect equality. Integral doubles are normalized
with integers, and `-0.0` is normalized with `0`. Unsupported custom objects,
`DateTime`, `Set`, non-string map keys, `NaN`, and infinity are rejected.

Prefix matching is recursive: a key-pattern list may be a prefix of the value
list, and a key-pattern map may contain a subset of the value map's fields.
This makes nested object-style prefixes useful for defaults and filters without
weakening exact `QueryKey` equality.

Only `IList` is re-exported by `jolt_query.dart`. If application code names or
constructs `IMap` directly, import `fast_immutable_collections` itself.

`MutationKey` follows the same structural rules, but mutation keys are only for
defaults, filtering, and observation. Equal mutation keys do not deduplicate or
serialize writes.

Reusing a key is the application's assertion that every user of that key agrees
on the raw cached data shape. Jolt Query does not maintain a runtime type
registry for duplicate keys.

## Define a query

### Inline query

Use `query(...)` for local definitions. The fetch callback establishes the raw
data type, so explicit type arguments are usually unnecessary:

```dart
final userQuery = query(
  key: QueryKey(<Object?>['users', userId]),
  fetch: (context) => api.getUser(userId),
  client: client,
  staleTime: StalePolicy.duration(const Duration(minutes: 1)),
  retention: RetentionPolicy.duration(const Duration(minutes: 10)),
  networkMode: NetworkMode.online,
  metadata: <String, Object?>{'endpoint': '/users/:id'},
);
```

The inline options are:

| Option | Meaning | Default |
| --- | --- | --- |
| `client` | Client used by target-owned integrations such as `QueryWidget`. | Lazy `QueryClient.defaultClient` |
| `retry` | Inference-neutral `RetryPolicy.none` or `RetryPolicy.standard`. | Omitted; registered defaults or the operation fallback decide. |
| `staleTime` | Recipe freshness policy. | Omitted; built-in fallback is `StalePolicy.immediate`. |
| `retention` | Retention after the final observer detaches. | Omitted; built-in fallback is `RetentionPolicy.standard`. |
| `networkMode` | How attempts interact with online state. | Omitted; built-in fallback is `NetworkMode.online`. |
| `metadata` | Immutable application metadata copied into operations and snapshots. | Empty map |
| `reconciler` | Structural-sharing policy for accepted raw data. | `DataReconciler.standard()` |

### Class-first query

Subclass `Query<T>` for reusable domain queries. A minimal subclass only needs
`key` and `fetch`:

```dart
final class UserQuery extends Query<User> {
  UserQuery(
    this.id, {
    QueryClient? client,
  }) : super(
          client: client,
          staleTime: StalePolicy.duration(const Duration(minutes: 1)),
          retention: RetentionPolicy.forever,
          metadata: const <String, Object?>{'resource': 'user'},
        );

  final int id;

  @override
  QueryKey get key => QueryKey(<Object?>['users', id]);

  @override
  Future<User> fetch(QueryContext context) => api.getUser(id);
}

final user = await client.fetchQuery(UserQuery(42));
```

Pass retry, stale, retention, and network policies to `super`. Their
non-virtual getters preserve the distinction between an omitted value, which
may inherit a registered default, and an explicit value, including a built-in
such as `StalePolicy.immediate`. A specialized subclass may still override
`metadata` and `reconciler`.

### Client binding and the default client

Every ordinary and infinite query target exposes a non-null `client`. Bind a
client explicitly when a query belongs to an isolated cache:

```dart
final client = QueryClient();

final profileQuery = query(
  key: QueryKey(<Object?>['profile', userId]),
  fetch: (_) => api.getProfile(userId),
  client: client,
).select((profile) => profile.displayName);

assert(identical(profileQuery.client, client));
```

Retry, initial-data, selection, observer, and placeholder transformations keep
the configured binding. An unbound target resolves `QueryClient.defaultClient`
only when its `client` is read. Staging an unbound target or passing it to an
explicit client operation does not resolve the fallback.

Applications that want one shared implicit client can install it once, before
the default is first read:

```dart
Future<void> main() async {
  final appClient = QueryClient();
  QueryClient.setDefault(appClient);

  try {
    await runApplication();
  } finally {
    appClient.dispose();
  }
}
```

If no client is installed, the first `QueryClient.defaultClient` read lazily
creates a zero-configuration client. The first read locks the default identity;
later `setDefault` calls throw `StateError`, and a disposed client is rejected.
The static reference never disposes its client.

Client binding guides target-owned integrations. An explicit operation remains
receiver-authoritative:

```dart
final boundToA = query(
  key: QueryKey(<Object?>['profile']),
  fetch: (_) => api.getProfile(),
  client: clientA,
);

await clientB.fetchQuery(boundToA); // Reads and writes clientB's cache.
assert(identical(boundToA.client, clientA));
```

### Query context and cooperative cancellation

Every attempt receives a `QueryContext` containing the actual executing
`client`, its structural `key`, immutable `metadata`, and a cooperative
`cancellationToken`:

```dart
final reportQuery = query(
  key: QueryKey(<Object?>['reports', reportId]),
  fetch: (context) async {
    context.cancellationToken.throwIfCancelled();
    final report = await api.getReport(
      reportId,
      traceName: context.metadata['traceName'] as String,
    );
    context.cancellationToken.throwIfCancelled();
    return report;
  },
  metadata: <String, Object?>{'traceName': 'report-detail'},
);
```

If the transport has its own cancellation primitive, bridge it with a listener:

```dart
final downloadQuery = query(
  key: QueryKey(<Object?>['download', fileId]),
  fetch: (context) async {
    final request = api.startDownload(fileId);
    final removeListener = context.cancellationToken.addListener(
      (_) => request.cancel(),
    );
    try {
      return await request.result;
    } finally {
      removeListener();
    }
  },
);
```

The token also exposes `isCancelled`, `reason`, `whenCancelled`, and
`throwIfCancelled()`. These cancellation reads mark the token as consumed so
the client knows the operation cooperates with cancellation. The thrown value
is `QueryCancelledException`; `wasConsumed` reports whether user code consumed
one of these capabilities.

When the final observer detaches, an active operation that consumed its token
is cancelled and rolled back. If it did not consume cancellation, an
already-running attempt may finish and populate the cache, but later retries
pause while the entry is unobserved. Attaching a new observer resumes that
retry progression. An absent operation already paused behind an eligibility
gate is cancelled when the final observer detaches even if its token was not
consumed.

`QueryCancellationController` is the public owner/token pair when application
code needs the same primitive independently:

```dart
final cancellation = QueryCancellationController();
final waiting = cancellation.token.whenCancelled;
cancellation.cancel('navigation changed');
await waiting;
```

## Transform and configure a query

The type-safe stage order is:

```text
Query<TData>
  -> retry(...)
  -> initialData(...)
  -> select(...) zero or more times
  -> observer(...) / placeholder(...) / placeholderData(...)
```

Raw-data transforms must happen before the first terminal presentation
configuration.

### Typed retry

`retry` keeps the raw `TData` visible to custom result predicates:

```dart
final retried = userQuery.retry(
  (retry) => retry.strategy(
    retryIf: retry.exceptions & retry.maxRetries(2),
  ),
);
```

### Initial data

Initial data seeds the raw shared cache before selection:

```dart
final seeded = userQuery.initialData(
  User.loading(userId),
  updatedAt: DateTime.now(),
);
```

The first target supplying initial data registers the entry's reset baseline.
If entry data is absent, that seed populates it; it never overwrites present
cache data. Later initial values do not replace the first registered seed.
The observer reports successful data, but the seed is not a completed fetch:
`isFetched` and `isFetchedAfterMount` stay false until an accepted operation
result or streamed partial, manual write, restore, or terminal error updates
the entry. Merely starting a reset-mode stream does not count as completion.
Resetting to the seed restores that zero-completion baseline.

### Selection

`select` derives an observer-local view while leaving raw cache data unchanged:

```dart
final displayName = userQuery.select((user) => user.displayName);
final nameLength = displayName.select((name) => name.length);

final observer = client.observeQuery(nameLength);
```

Selector exceptions become observer-local failures. They do not replace or
invalidate the raw cached value. A selected `QueryView<T>` is not a
`QueryDataTarget<T>` and therefore cannot be passed to exact raw cache APIs.

### Observer options

```dart
final target = userQuery.select((user) => user.displayName).observer(
  enabled: true,
  staleTime: StalePolicy.duration(const Duration(minutes: 5)),
  refetchOnMount: RefetchPolicy.stale,
  refetchOnFocus: RefetchPolicy.stale,
  refetchOnReconnect: RefetchPolicy.stale,
  retryOnMount: true,
  pollingInterval: const Duration(minutes: 1),
  // pollingIntervalResolver: (result) =>
  //     result.failureCount == 0 ? const Duration(minutes: 1) : null,
  pollingEnabled: true,
  pollInBackground: false,
  equality: (previous, next) => previous == next,
);
```

Observer options affect only that presentation. `equality` compares selected
values for observer publication; it is separate from raw cache reconciliation.
`pollingEnabled: false` explicitly disables an interval inherited from a
broader default without needing a nullable “clear this field” convention.
Supplying a new `pollingInterval` implicitly enables polling unless the same
more-specific configuration also sets `pollingEnabled: false`.
`pollingIntervalResolver` receives the complete current observer result and
returns the delay before the next poll, or `null` to stop. It is mutually
exclusive with `pollingInterval`. Resolver polling uses a generation-safe
one-shot timer after each result transition, so it cannot overlap an active
operation and can adapt its next delay to data or failure state.

### Placeholder data

Placeholder data belongs only to the final observer view and is never written
to the shared cache:

```dart
final keepPrevious = userQuery
    .select((user) => user.displayName)
    .placeholder((previous) => previous);

final fixedPlaceholder = userQuery.placeholderData(User.loading(userId));
```

The resolver receives the previous selected presentation during a target
switch. It may return `QueryValue.absent()`. Placeholder data is already the
final view type, is not passed through selectors, and sets
`isPlaceholderData`. Placeholder exceptions are observer-local failures.

## Observe a query

```dart
final observer = client.observeQuery(
  userQuery.observer(refetchOnMount: RefetchPolicy.stale),
);

final untracked = observer.snapshot; // same role as observer.peek
final trackedWholeResult = observer.value;
final trackedStatus = observer.status;

final afterRefetch = await observer.refetch(cancelRefetch: true);
observer.dispose();
```

`value` tracks the complete immutable `QueryObserverResult<T>`. Individual
getters track only the minimum fields needed to compute that getter.
`snapshot` and `peek` do not create a reactive dependency.

`refetch()` forces the current target even when `enabled` is false. It returns a
result state and does not rethrow an ordinary query failure to its caller. An
active retained-data refetch is replaced when `cancelRefetch` is true; an
active initial load is joined to preserve single-flight behavior.

### Observer result fields

| Group | Fields |
| --- | --- |
| Identity/data | `key`, `data` |
| State | `status`, `fetchStatus`, `pauseReason` |
| Failure | `failure`, `transientFailure`, `failureCount` |
| Time | `dataUpdatedAt`, `failureUpdatedAt` |
| Freshness/activity | `isInvalidated`, `isStale`, `isEnabled` |
| Presentation | `isPlaceholderData` |
| Completion | `isFetched`, `isFetchedAfterMount` |
| Derived flags | `isPending`, `isSuccess`, `isError`, `isFetching`, `isPaused`, `isLoading`, `isInitialLoading`, `isRefetching`, `isLoadingError`, `isRefetchError` |

`QueryFailure` preserves the exact thrown object and stack trace as `error` and
`stackTrace`. `transientFailure` is a retryable attempt failure while work is
still active; `failure` is terminal or observer-local.

### Data presence

`QueryValue<T>` distinguishes absence from a present nullable value:

```dart
const absent = QueryValue<String?>.absent();
const presentNull = QueryValue<String?>.present(null);

assert(absent.isAbsent);
assert(presentNull.isPresent);
assert(presentNull.requireValue() == null);
```

Use `isPresent`, `isAbsent`, pattern matching, or `requireValue()` when `null`
is a valid cached value. `valueOrNull` cannot distinguish absent from
present-null by itself.

### Query and fetch state

Query data state and transport state are independent:

| State | Meaning |
| --- | --- |
| `QueryStatus.pending` | No accepted query result has completed. An observer may still show placeholder data. |
| `QueryStatus.success` | Accepted data is present, including present `null`. |
| `QueryStatus.error` | The operation or observer-local projection failed. Retained data may still be present. |
| `FetchStatus.idle` | No query operation is active. |
| `FetchStatus.fetching` | Transport work or retry delay is active. |
| `FetchStatus.paused` | Work is waiting for an eligibility gate; inspect `pauseReason`. |

Common combinations are:

| Presentation | Meaning |
| --- | --- |
| absent + `pending` + `fetching` | Initial loading (`isLoading`). |
| present + `success` + `idle` | Settled data. |
| present + `success` + `fetching` | Background refresh (`isRefetching`). |
| present + `error` + `idle` | Refresh failed but retained data remains (`isRefetchError`). |
| absent + `error` + `idle` | Initial load failed (`isLoadingError`). |
| `paused` + `PauseReason.offline` | Query is waiting for online eligibility. |

### Disable automatic activation

```dart
final observer = client.observeQuery(
  userQuery.observer(enabled: false),
);

assert(observer.fetchStatus == FetchStatus.idle);
await observer.refetch(); // explicit refetch still runs
```

`retryOnMount: false` prevents a failed empty entry from automatically retrying
when a new observer mounts. It does not disable an explicit refetch.

Jolt Query distinguishes **observed** from **active**:

- an entry is observed while any observer is attached, including a disabled
  observer; observed entries are not garbage-collected;
- an entry is active while at least one attached observer has
  `enabled: true`; only active observers participate in automatic triggers;
- a disabled observer reports `isStale == false`, does not make the entry an
  active bulk-refetch target, and can still run `observer.refetch()`
  explicitly.

`QueryCacheSnapshot.observerCount`, `activeObserverCount`, `isObserved`, and
`isActive` expose the distinction. `QueryActivity.active` and `.inactive`
partition by active observers, not merely by attachment.

## Reactive key changes

`watchQuery` tracks Jolt signal reads made while the target factory runs. When a
dependency changes, the observer retargets to the new key, publishes the new
key's state, and automatically fetches when the target is enabled and the new
entry is absent or stale:

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt_query/jolt_query.dart';

final page = Signal<int>(1);

final projects = client.watchQuery(() {
  final currentPage = page.value;
  return query(
    key: QueryKey(<Object?>['projects', currentPage]),
    fetch: (_) => api.getProjects(currentPage),
    staleTime: StalePolicy.duration(const Duration(minutes: 1)),
  ).placeholder((previous) => previous);
});

page.value = 2;
// projects.key changes immediately, the old selected value can be shown as a
// placeholder, and page 2 starts fetching if its cache is empty or stale.

page.value = 1;
// Fresh page-1 cache is reused without another request.
```

Capture signal values inside the target factory, as above, so each fetch
closure is bound to the key it describes. A placeholder from the previous key
is not inserted into the new key's cache.

Changing to another recipe instance with the same client and key updates the
observer configuration in place. It does not simulate a remount and therefore
does not re-run `refetchOnMount`. A different key is a dependency change, so
its enabled + stale state decides whether it fetches; `refetchOnMount` is not
used to suppress key-driven fetching.

## Freshness, refetch triggers, and retention

Staleness answers “may this data be revalidated for a stale-sensitive trigger?”
It is not itself a request trigger. When an attached duration-based observer
reaches its stale deadline, it publishes `isStale`, but no request starts until
mount, focus, reconnect, polling, invalidation, or an explicit operation asks
for one.

### Stale policies

| Policy | Behavior |
| --- | --- |
| `StalePolicy.immediate` | Data is stale immediately after commit. |
| `StalePolicy.duration(duration)` | Data becomes stale after the duration or when invalidated. |
| `StalePolicy.untilInvalidated` | Data stays fresh until explicitly invalidated. |
| `StalePolicy.immutable` | Disables automatic and bulk refetch execution, even after invalidation. `observer.refetch()` still runs; `fetchQuery` can be forced with a different `staleTime` override. |
| `StalePolicy.resolve(callback)` | Application decides from `StaleState`. |

```dart
final businessFreshness = StalePolicy.resolve(
  (state) => state.isInvalidated ||
      state.age >= const Duration(minutes: 15),
);
```

`StaleState` provides `now`, `updatedAt`, `isInvalidated`, and non-negative
`age`. A resolver has no predictable timer boundary, so it is re-evaluated when
query, target, or environment state changes.

If a background refetch fails while retaining usable data, the entry is marked
invalidated. The result is an error with retained data, and stale-sensitive
triggers can retry it instead of treating the old value as fresh forever.

### Refetch triggers

```dart
final target = userQuery.observer(
  refetchOnMount: RefetchPolicy.stale,
  refetchOnFocus: RefetchPolicy.stale,
  refetchOnReconnect: RefetchPolicy.stale,
  pollingIntervalResolver: (result) => result.failureCount == 0
      ? const Duration(seconds: 30)
      : const Duration(minutes: 2),
  pollInBackground: false,
);
```

`RefetchPolicy.never`, `.stale`, and `.always` control mount, focus, and
reconnect triggers. Fixed or state-derived polling pauses while unfocused
unless `pollInBackground` is true. `StalePolicy.immutable` disables polling.
Use `pollingEnabled: false` to turn off inherited polling explicitly.

### Retention

| Policy | Behavior while the entry has no attached observers |
| --- | --- |
| `RetentionPolicy.standard` | Retain for five minutes. |
| `RetentionPolicy.duration(duration)` | Retain for a non-negative custom duration. |
| `RetentionPolicy.forever` | Retain until explicit removal, clear, or client disposal. |

Retention is cache lifetime, not freshness. A retained entry can be stale, and
a fresh inactive entry can still be garbage-collected.

The same retention clock applies to entries created by `fetchQuery`,
`prefetchQuery`, `ensureQueryData`, and manual cache writes even if they were
never observed. Attaching any observer, including a disabled one, cancels that
entry's pending collection; the clock restarts after the final detach.

An entry remembers the longest finite retention it has received. Once its
current lineage receives `RetentionPolicy.forever`, later targets cannot
shorten it. Switching to a shorter policy therefore does not bring an existing
entry's GC deadline forward; removal or clear starts a new lineage.

### Focus, online state, and network mode

Each client owns stable focus and online managers:

```dart
client.focusManager.isFocused = false;
client.onlineManager.isOnline = false;

client.focusManager.setEventSource(appFocusChanges);
client.onlineManager.setEventSource(connectivityChanges);
```

The managers own and replace their subscriptions. The caller still owns the
Streams.

| Network mode | First attempt | Retries |
| --- | --- | --- |
| `NetworkMode.online` | Wait while offline. | Wait while offline. |
| `NetworkMode.always` | Ignore online state. | Ignore online state. |
| `NetworkMode.offlineFirst` | Run even while offline. | Wait while offline. |

Changing focus from false to true can trigger `refetchOnFocus`; changing online
from false to true can resume paused work and trigger `refetchOnReconnect`.

Focus is also a retry-continuation gate. Losing focus does not abort a transport
attempt already in flight, but after a failed attempt a later retry waits until
focus returns. Online gating still follows `NetworkMode`; retry focus gating is
independent of that mode.

Flutter applications can mirror app lifecycle into focus explicitly:

```dart
final lifecycle = client.bindFlutterLifecycle();
// Optional early unbind; client.dispose() also disposes the binding.
lifecycle.dispose();
```

Only `AppLifecycleState.resumed` is treated as focused. The binding does not
infer connectivity, does not dispose the Flutter binding, and does not require
a provider.

## Structural sharing

Accepted query data is reconciled before publication to preserve unchanged
references where safe:

```dart
final userQuery = query(
  key: QueryKey(<Object?>['users', userId]),
  fetch: (_) => api.getUser(userId),
  reconciler: DataReconciler<User>.custom(
    (previous, next) => previous == next ? previous : next,
  ),
);
```

Available policies are:

| Reconciler | Behavior |
| --- | --- |
| `DataReconciler.standard()` | Reuses identical values, equal FIC collections, and unchanged branches of JSON-compatible `List`/`Map` values. |
| `DataReconciler.identity()` | Reuses only an identical previous value. |
| `DataReconciler.custom(callback)` | Delegates the complete decision to application code. |
| A `DataReconciler<T>` subclass | Encapsulates a reusable domain policy. |

Ordinary custom classes are treated as new by the standard reconciler, even if
their `==` operator says they are equal. Use a custom reconciler when domain
equality should preserve the previous instance.

Do not mutate a cached mutable `List` or `Map` in place and return the same
instance. The standard reconciler cannot reconstruct the previous value. An
optional diagnostic sink can surface that mistake:

```dart
final reconciler = DataReconciler<List<Todo>>.standard(
  diagnostics: (diagnostic) => logWarning(diagnostic.message),
);
```

Successful fetches and exact `setQueryData`/`updateQueryData` writes use the
query carrier's reconciler. `restoreQueryData` restores the checkpoint value
exactly and does not reconcile it. Bulk writes use the matched entry's retained
plan when one is available.

## Imperative query operations

### Fetch, prefetch, and ensure

```dart
final user = await client.fetchQuery(userQuery);

await client.prefetchQuery(userQuery);

final cachedFirst = await client.ensureQueryData(
  userQuery,
  revalidateIfStale: true,
);
```

| API | Fresh cache hit | Fetch failure | Result |
| --- | --- | --- | --- |
| `fetchQuery` | Returns immediately. | Throws after committing failure state. | `Future<T>` |
| `prefetchQuery` | Completes immediately. | Swallows the caller-facing error after committing failure state. | `Future<void>` |
| `ensureQueryData` | Returns cached data immediately; optionally starts background revalidation. | Throws only when it had to fetch because data was absent. | `Future<T>` |

All three accept a `staleTime` override. `revalidateIfStale: true` does not wait
for the background refresh when cached data is already present.

Direct fetch, prefetch, and ensure operations use no retry unless the recipe or
a matching default configures one.

When a fetch is required, `fetchQuery` and `prefetchQuery` join any compatible
active operation by default, whether the entry is initially loading or already
has retained data. Pass `cancelRefetch: true` to replace an active
retained-data refetch. An active initial load is always joined so one key keeps
single-flight behavior.

### Exact cache reads and writes

All exact data operations accept `QueryDataTarget<T>`. Raw `Query<T>` and raw
`InfiniteQuery<Page, PageParam>` implement it; selected views do not.

```dart
final data = client.getQueryData(userQuery);       // QueryValue<User>
final state = client.getQueryState(userQuery);     // QuerySnapshot<User>?

final written = client.setQueryData(
  userQuery,
  updatedUser,
  updatedAt: DateTime.now(),
);

final updated = client.updateQueryData(
  userQuery,
  (previous) => previous.isPresent
      ? previous.requireValue().copyWith(active: true)
      : User.loading(userId),
);
```

`getQueryState` returns `null` when the entry does not exist. A
`QuerySnapshot<T>` includes data and status, fetch/pause state, failures and
failure count, update times and counts, revision, invalidation state, and
metadata. Cache updater callbacks run untracked.

`setQueryData` and `updateQueryData` return a revisioned
`QueryDataSnapshot<T>` containing the post-write data, update time, and
revision.

### Manual writes do not cancel active work

```dart
final inFlight = observer.refetch();
client.setQueryData(userQuery, editedUser); // visible immediately
await inFlight; // accepted fetch data may replace editedUser
```

This applies to exact set/update/restore, typed bulk writes, and stream-backed
queries. A manual write preserves the active operation identity, cancellation
token, fetch/pause state, transient failure, and retry progress.

When a manual value must remain authoritative, cancel and await first:

```dart
await client.cancelQueries(
  filter: QueryFilter(key: userQuery.key, exact: true),
);
client.setQueryData(userQuery, editedUser);
```

### Revisioned checkpoints

```dart
final before = client.snapshotQueryData(userQuery);
final optimistic = client.setQueryData(userQuery, editedUser);

final restored = client.restoreQueryData(
  userQuery,
  before,
  ifRevision: optimistic.revision,
);
```

A checkpoint is data-only and provenance-bound to one client, structural key,
and entry lineage. Restoration returns `false` after a newer write, for another
client or key, or after remove-and-recreate or clear. It does not restore entry
existence, fetch/retry state, invalidation, observers, or active work.

Restoring an absent checkpoint into an existing entry writes absent data but
does not remove the entry. Restoring it to an already-missing entry is a valid
no-op when provenance and revision still match.

### Filters

```dart
final staleActiveTodos = QueryFilter(
  key: QueryKey(<Object?>['todos']),
  exact: false,
  activity: QueryActivity.active,
  freshness: QueryFreshness.stale,
  status: QueryStatus.success,
  fetchStatus: FetchStatus.idle,
  predicate: (snapshot) => !snapshot.isInvalidated,
);
```

Every non-null constraint must match. A non-exact key is a recursive structural
prefix. Freshness is observer-aware. While observers are attached, the cache is
aggregate-stale only when at least one current observer result is stale;
disabled observers report non-stale. With no observers, absent or invalidated
data is stale, while present non-invalidated data is aggregate-fresh even if a
duration would have expired. A later observer still evaluates that entry using
its own stale policy when attaching.

### Typed bulk data

Bulk data APIs require a caller-owned `TypedQueryFilter<T>` type assertion and
only touch entries that already exist:

```dart
final todoLists = QueryFilter(
  key: QueryKey(<Object?>['todos']),
).typed<List<Todo>>();

final matches = client.getQueriesData(todoLists);

client.setQueriesData(todoLists, const <Todo>[]);

client.updateQueriesData(
  todoLists,
  (key, previous) => previous.isPresent
      ? previous.requireValue().where((todo) => !todo.done).toList()
      : const <Todo>[],
);
```

`TypedQueryFilter<T>` is a type witness, not a runtime registry. Use
`TypedQueryFilter<Object?>` only when heterogeneous matches are intentional.
Results are `IList<QueryDataMatch<T>>` in stable cache insertion order. Each
match contains its key and captured or post-write `QueryDataSnapshot<T>`.

### Query lifecycle operations

```dart
final prefix = QueryFilter(key: QueryKey(<Object?>['todos']));

await client.invalidateQueries(
  filter: prefix,
  refetchType: QueryRefetchTarget.active,
  cancelRefetch: true,
);

await client.refetchQueries(
  filter: prefix,
  refetchType: QueryRefetchTarget.all,
  cancelRefetch: true,
);

await client.cancelQueries(filter: prefix, revert: true);
await client.resetQueries(filter: prefix);
final removed = client.removeQueries(prefix);
```

| API | Default behavior |
| --- | --- |
| `invalidateQueries` | Marks matches invalid and, by default, replaces retained-data work before refetching active executable entries. |
| `refetchQueries` | Refetches all executable matches and replaces retained-data refetches. |
| `cancelQueries` | Cancels active matches and reverts their pre-operation state. |
| `resetQueries` | Restores initial state and refetches active executable entries. |
| `removeQueries` | Synchronously cancels and removes all matches; returns the count. |
| `client.clear()` | Clears query and mutation cache records while keeping the client usable. |

`QueryRefetchTarget.none`, `.active`, `.inactive`, and `.all` select the
execution subset. Async lifecycle methods return `QueryBatchResult` with
`matched`, `affected`, `skippedNonExecutable`, `noOp`, ordered `failures`, and
`hasFailures`.

Here “active” means at least one enabled observer. A disabled attached entry is
observed but inactive, so automatic invalidation/reset refetch skips it.
An entry is query-wide static when any attached observer uses
`StalePolicy.immutable`, including a disabled observer; static entries block
automatic and bulk execution, while explicit exact `observer.refetch()` remains
available. An unobserved entry is disabled until it has completed at least one
operation, so never-fetched inactive entries are also skipped.

`invalidateQueries(cancelRefetch: true)` is the default: retained-data work is
cancelled and replaced, while a shared initial load is joined. With
`cancelRefetch: false`, active work is joined and no hidden follow-up refetch is
scheduled. A batch item that immediately pauses for an eligibility gate does
not hold the batch Future open; the cache-owned operation resumes later.

## Query cache and counts

```dart
final client = QueryClient(
  queryCallbacks: QueryCacheCallbacks(
    onSuccess: (data, snapshot) {
      metrics.record('query.ok', key: snapshot.key);
    },
    onError: (failure, snapshot) {
      errors.report(failure.error, failure.stackTrace);
    },
    onSettled: (data, failure, snapshot) {
      metrics.record('query.done', key: snapshot.key);
    },
  ),
);

final eventSubscription = client.queryCache.events.listen((event) {
  print('${event.kind}: ${event.snapshot.key}');
});

final snapshots = client.queryCache.snapshots;
final activeNow = client.countFetching(filter: staleActiveTodos);
final reactiveCount = client.fetchingCount.value;

await eventSubscription.cancel();
```

`QueryCacheSnapshot` is an immutable erased view containing the entry key,
data presence, state, failures, timestamps, revisions, invalidation, metadata,
total/active observer counts, observed/active flags, and aggregate freshness.
`QueryCacheEventKind` is one of
`added`, `updated`, `invalidated`, `reset`, `removed`, `activityChanged`, or
`freshnessChanged`.

Query-cache callbacks are synchronous post-commit observation hooks. They run
exactly once for an accepted terminal query operation—never for retry attempts,
stream partials, manual writes, cancellation, or superseded work—and receive
an immutable snapshot. Success/error then settled run before the operation
Future completes. `onSuccess` receives the accepted value directly, including
`null`; `onSettled` receives `QueryValue<Object?>`, so absent and present-null
remain distinct and retained-data failures can carry data plus failure.
Callback exceptions are delivered to the operation's Zone without rewriting
committed state or the fetch Future outcome. Start application-owned
asynchronous work inside a callback when needed; it is not awaited by Jolt
Query.

`countFetching(...)` reads internal state synchronously. The reactive
`fetchingCount` is committed through the configured notification scheduler, so
an immediate read during a transition can briefly differ. Both count only
entries whose fetch state is `fetching`; paused eligibility waits are excluded.

`queryCache.clear()` clears only query entries and leaves the client and event
stream active. `queryCache.isDisposed` becomes true only after owner disposal.

## Observe multiple queries

For a fixed heterogeneous group, keep static types with separate observers and
a Dart record:

```dart
final group = (
  user: client.observeQuery(userQuery),
  todoCount: client.observeQuery(todosQuery.select((items) => items.length)),
);
```

For runtime-sized heterogeneous lists, use erased results:

```dart
final queries = client.observeQueries(<AnyQueryTarget>[
  userQuery,
  todosQuery.select((items) => items.length),
]);

final current = queries.snapshot; // IList<ErasedQueryObserverResult>
queries.dispose();
```

Use `watchQueries` when the target list itself depends on Jolt signals:

```dart
final queries = client.watchQueries(
  () => selectedTargets.value,
);
```

Added targets attach, removed targets dispose, and ordering follows the latest
list. Repeated keys share the raw cache and active operation while retaining
independent observer presentations.

Child observers are reused by `(client, key, occurrence)` rather than recipe
object identity. Rebuilding equal target instances therefore updates
configuration in place. Duplicate keys remain independent presentations: the
first occurrence reuses the first old child, the second reuses the second, and
so on. Unchanged result objects keep their identity.

Derive one reactive value with `observeCombinedQueries` or
`watchCombinedQueries`:

```dart
final summary = client.observeCombinedQueries(
  <AnyQueryTarget>[userQuery, todosQuery],
  (results) => (
    isFetching: results.any((result) => result.isFetching),
    errorCount: results.where((result) => result.isError).length,
  ),
);

print(summary.snapshot);
summary.dispose();
```

`QueriesObserver<R>` exposes `value`, `peek`, `snapshot`, `isDisposed`, and
`dispose()`.

## Defaults

Register broad defaults before specific structural prefixes. Matching
registrations merge in call order; later non-null fields win:

```dart
client.registerQueryDefaults(
  const QueryDefaults(
    retention: RetentionPolicy.forever,
    retry: RetryPolicy.standard,
  ),
);

client.registerQueryDefaults(
  QueryDefaults(
    staleTime: StalePolicy.duration(const Duration(minutes: 2)),
    networkMode: NetworkMode.offlineFirst,
  ),
  key: QueryKey(<Object?>['todos']),
);

final resolved = client.getQueryDefaults(
  QueryKey(<Object?>['todos', 'open']),
);
client.clearQueryDefaults();
```

`QueryDefaults` can set `retry`, `staleTime`, `retention`, `networkMode`,
`enabled`, `refetchOnMount`, `refetchOnFocus`, `refetchOnReconnect`,
`retryOnMount`, `pollingInterval`, `pollingEnabled`, and `pollInBackground`.
`pollingEnabled: false` is the explicit way for a more-specific registration
to disable a broader inherited interval.

Mutation defaults work the same way:

```dart
client.registerMutationDefaults(
  const MutationDefaults(
    retry: RetryPolicy.standard,
    retention: RetentionPolicy.forever,
    networkMode: NetworkMode.online,
  ),
  key: MutationKey(<Object?>['todos']),
);

final defaults = client.getMutationDefaults(
  MutationKey(<Object?>['todos', 'save']),
);
client.clearMutationDefaults();
```

The two `get...Defaults` methods return the merged registered values. Fields
that no registration supplied remain `null`; built-in fallback behavior is
applied later when a query or mutation observer/operation is resolved.

### Default behavior

| Feature | Default |
| --- | --- |
| Query freshness | Immediately stale |
| Unobserved query retention | Five minutes |
| Mount/focus policy | Refetch stale data |
| Reconnect policy | Refetch stale data, except effective `NetworkMode.always` defaults to `never`. |
| Observer enabled / retry on mount | `true` / `true` |
| Polling | Off |
| Direct fetch/prefetch/ensure retry | None |
| Observer, invalidation, and reset retry | Three retries with standard backoff |
| `refetchQueries` retry | None |
| Mutation retry | None |
| Mutation execution | Parallel unless a scope is supplied |
| Settled mutation retention | Five minutes |

Query configuration resolves in this order:

```text
built-in fallback
  < merged registered defaults
  < explicit inline/class-first recipe configuration
  < explicit observer or imperative-call override
```

“Explicit” includes a built-in value. For example, a recipe that passes
`staleTime: StalePolicy.immediate` intentionally beats a registered two-minute
default; omitting `staleTime` inherits that default. This is why class-first
recipes should pass policy values to `super` instead of relying on getters that
look identical to their built-in fallback. Typed or marker recipe retry also
wins over a matching retry default; a default fills an omitted recipe retry.

Mutation configuration follows the same fallback order. An omitted retry,
network mode, or retention inherits matching defaults. Any explicitly supplied
value wins, including the built-ins `RetryPolicy.none`, `NetworkMode.online`,
and `RetentionPolicy.standard`.

Clearing defaults does not change existing cache state.

## Retry

### Marker policies

The inference-neutral policies require only Jolt Query:

```dart
final noRetry = query(
  key: QueryKey(<Object?>['health']),
  fetch: (_) => api.health(),
  retry: RetryPolicy.none,
);

final standardRetry = query(
  key: QueryKey(<Object?>['profile']),
  fetch: (_) => api.profile(),
  retry: RetryPolicy.standard,
);
```

`RetryPolicy.standard` retries exceptions three times with non-jittered
exponential delays beginning at one second and capped at thirty seconds.

Inline `retry:` fields and defaults accept only `none` and `standard`. Apply a
typed custom policy after raw-data inference with `retry()`.

### Custom retry

Jolt Query supports `retry_plus: 0.1.1` as policy vocabulary but does not
re-export it. Applications using custom policies declare and import it
directly:

```yaml
dependencies:
  jolt_query: any
  retry_plus: 0.1.1
```

```dart
import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart';

final customized = userQuery.retry(
  (retry) => retry.strategy(
    retryIf: retry.exceptions & retry.maxRetries(5),
    delay: DelayPolicy.exponential(
      initial: const Duration(milliseconds: 250),
      max: const Duration(seconds: 5),
      jitter: Jitter.full(),
    ),
    onRetry: (attempt) => logRetry(attempt.attemptNumber),
    onGiveUp: (attempt) => logGiveUp(attempt.attemptNumber),
  ),
);
```

Successful results can participate in a typed retry decision:

```dart
final retriedResponse = responseQuery.retry(
  (retry) => retry.strategy(
    retryIf: retry.result((response) => response.statusCode == 503) &
        retry.maxRetries(3),
  ),
);
```

`RetryBuilder<T>` provides `exceptions`, `exceptionWhere`, `exceptionType`,
`result`, `where`, `any`, `never`, `maxRetries`, and `strategy`. These return
the corresponding typed `retry_plus` predicates and strategies, so the full
upstream composition vocabulary remains available.

The strategy factory runs once per logical operation. Jolt evaluates the
decision and hooks, then uses its own cancellable timers and eligibility gates.
It does not call the upstream executor or accept `RetryPipeline` as an
execution surface.

Retry attempts also honor application focus. An attempt already executing is
not aborted when focus is lost, but the next retry waits and reports
`FetchStatus.paused` with `PauseReason.focus` until focus returns. For
observer-owned query work, detaching the final observer pauses later retries;
reattaching an observer resumes the same logical operation when it was safe to
retain.

Custom retry is typed to raw query data before `select`, complete
`InfiniteData` for infinite queries, and mutation success data for mutations.
With the supported `retry_plus` version, `onGiveUp` can run after an earlier
retry even if a later attempt succeeds; if that hook throws, the operation
fails. A handled successful result whose retry budget is exhausted is accepted
as success.

## Mutations

### Execute a mutation

```dart
final saveTodo = mutation<TodoDraft, Todo, void>(
  key: MutationKey(<Object?>['todos', 'save']),
  mutate: (draft, context) => api.saveTodo(draft),
  onSuccess: (todo, draft, onMutateResult, context) async {
    context.client.setQueryData(todoQuery(todo.id), todo);
    await context.client.invalidateQueries(
      filter: QueryFilter(key: QueryKey(<Object?>['todos'])),
    );
  },
);

final saved = await client.execute(saveTodo, draft);
```

`Mutation<V, D, R>` has three type parameters:

| Type | Meaning |
| --- | --- |
| `V` | Variables supplied to each execution. |
| `D` | Successful transport result. |
| `R` | Optional result returned by `onMutate` and passed to later callbacks. |

`R` is lifecycle data; it does not mean the mutation is optimistic. If
`onMutate` has no useful result, use `void` explicitly. Each `execute` call is
an independent execution.

Inline mutation options include `key`, `scope`, `metadata`, `networkMode`,
`retention`, `retry`, `onMutate`, `onSuccess`, `onError`, and `onSettled`.
`MutationContext` exposes the submitting `client`, optional `key`, optional
`scope`, and immutable `metadata`.

### Class-first mutation

```dart
final class SaveTodo extends Mutation<TodoDraft, Todo, void> {
  const SaveTodo()
      : super(
          retry: RetryPolicy.none,
          networkMode: NetworkMode.online,
          retention: RetentionPolicy.standard,
        );

  @override
  MutationKey get key => MutationKey(<Object?>['todos', 'save']);

  @override
  Future<Todo> mutate(TodoDraft draft, MutationContext context) {
    return api.saveTodo(draft);
  }
}
```

A class-first mutation can override `key`, `scope`, `metadata`, `onMutate`, and
lifecycle methods. Retry, network mode, and retention are constructor policies:
pass them to `super`. Their public getters are non-virtual views of the
constructor values, which lets the runtime distinguish an omitted policy from
an explicit built-in value when it merges client defaults.

### Mutation observer

```dart
final observer = client.observeMutation(saveTodo);

await observer.execute(
  draft,
  onSuccess: (todo, variables, onMutateResult, context) {
    showSavedToast(todo);
  },
  onError: (failure, variables, onMutateResult, context) {
    showError(failure.error);
  },
  onSettled: (data, failure, variables, onMutateResult, context) {
    closeEditor();
  },
);

observer.reset();
observer.dispose();
```

The observer presents only its latest `execute` call. Earlier Futures continue
independently. A later execute, `reset`, or `dispose` detaches the old
presentation and suppresses its not-yet-fired per-call callbacks; it does not
stop the execution or recipe/cache lifecycle.

`observer.updateMutation(next)` changes the recipe used by future submissions.
An equal nullable structural `MutationKey` preserves the latest presentation;
a changed key resets it to idle. An already submitted execution retains the
recipe and lifecycle callbacks captured when it was submitted.

Per-call callbacks are synchronous `void` presentation callbacks and are not
awaited as mutation lifecycle. Recipe and global cache callbacks may return
`FutureOr<void>` and are awaited.

`MutationObserverResult<V, D, R>` and field getters expose `status`,
`variables`, `data`, `onMutateResult`, `failure`, `failureCount`, `isPaused`,
`pauseReason`, `submittedAt`, and `isIdle`/`isPending`/`isSuccess`/`isError`.
`variables`, `data`, and `onMutateResult` use explicit `QueryValue` presence.

| Status | `variables` | `data` | `onMutateResult` |
| --- | --- | --- | --- |
| `idle` | absent | absent | absent |
| `pending` | present | absent | absent or present |
| `success` | present | present | absent or present |
| `error` | present | absent | absent or present |

A paused mutation is still pending. A retry delay is pending but not paused;
`PauseReason.offline`, `PauseReason.focus`, and `PauseReason.scope` identify
actual gates.
`failureCount` counts thrown mutation-function attempts and resets to zero on
success.

### Lifecycle order

The successful path is awaited in this order:

```text
global cache onMutate
recipe onMutate
mutate
global cache onSuccess
recipe onSuccess
global cache onSettled
recipe onSettled
commit terminal state and release the scope lane
publish the latest eligible MutationObserver result synchronously
eligible observer per-call onSuccess and onSettled
queue cache/reactive notifications
complete the public Future
```

The synchronous observer publication means a per-call callback and code
resuming after `await observer.execute(...)` both see the terminal observer
state. A later queued cache notification is equality-deduplicated rather than
publishing the same observer transition twice.

After a failure, global then recipe `onError` run, followed by only the settled
hooks that have not already been attempted. Every settled hook runs at most
once. `onMutate` may return a present nullable value; later hooks receive it as
`QueryValue<R>`. If a cleanup hook throws while another primary failure already
exists, the primary failure is preserved and the cleanup error is reported to
the submission Zone.

Global mutation callbacks are immutable client configuration captured by every
submission:

```dart
final client = QueryClient(
  mutationCallbacks: MutationCacheCallbacks(
    onSettled: (data, failure, variables, result, context) {
      metrics.record(failure == null ? 'mutation.ok' : 'mutation.error');
    },
  ),
);
```

Only recipe `onMutate` produces the typed `R`; global cache `onMutate` returns
`void`. The value can carry any lifecycle state and need not touch Query Cache:

```dart
final tracedSave = mutation<TodoDraft, Todo, String>(
  onMutate: (draft, context) => createCorrelationId(),
  mutate: (draft, context) => api.saveTodo(draft),
  onSettled: (data, failure, draft, token, context) {
    if (token.isPresent) tracing.finish(token.requireValue());
  },
);
```

### Parallel writes, keys, and scopes

Mutations run in parallel unless they share a same-client `MutationScope`:

```dart
final serialSave = mutation<TodoDraft, Todo, void>(
  key: MutationKey(<Object?>['todos', 'save']),
  scope: const MutationScope('todo-writes'),
  mutate: (draft, context) => api.saveTodo(draft),
);
```

The scope creates a FIFO lane covering offline waits, retry delays, transport,
and awaited lifecycle callbacks. Scope equality is based on its string ID and
only coordinates executions belonging to the same `QueryClient`.

A `MutationKey` does not deduplicate, cancel, or serialize anything.

### Mutation cache, filters, defaults, and counts

```dart
final pendingSaves = client.mutationCache.findAll(
  filter: MutationFilter(
    key: MutationKey(<Object?>['todos', 'save']),
    exact: true,
    status: MutationStatus.pending,
    isPaused: false,
  ),
);

final subscription = client.mutationCache.events.listen((event) {
  print('${event.kind}: mutation ${event.snapshot.id}');
});

final pendingNow = client.countMutating(
  filter: const MutationFilter(status: MutationStatus.pending),
);
final reactivePending = client.mutatingCount.value;

await subscription.cancel();
```

`MutationFilter` can match key prefix/exactness, status, pause state, scope,
and a final predicate. `MutationSnapshot` contains ID, key, status/pause state,
variables, data, failure/count, submission time, `onMutateResult`, scope, and
metadata. Mutation cache event kinds are `added`, `updated`, and `removed`.

`mutationCache.snapshots` returns submission-ordered immutable snapshots.
`mutationCache.clear()` removes and permanently detaches records but does not
cancel active Futures, retries, callbacks, observers, or scope membership.
Detached work does not reinsert itself.

`countMutating(...)` is a synchronous filtered read. `mutatingCount` is the
notification-scheduled reactive committed count. Both include every pending
execution, including work paused for online or scope eligibility.

Use `registerMutationDefaults`, `getMutationDefaults`, and
`clearMutationDefaults` for retry-marker, retention, and network defaults.

### Optional optimistic update

`onMutate` does not imply an optimistic update. Optimistic behavior is ordinary
application code that snapshots and writes Query Cache inside that hook:

```dart
typedef RenameRollback = ({
  QueryDataSnapshot<Todo> before,
  int optimisticRevision,
});

final renameTodo = mutation<String, Todo, RenameRollback>(
  onMutate: (name, context) {
    final before = context.client.snapshotQueryData(todoQuery);
    if (before.data.isAbsent) {
      throw StateError('The todo must be loaded before it can be renamed.');
    }

    final optimistic = context.client.setQueryData(
      todoQuery,
      before.data.requireValue().copyWith(name: name),
    );
    return (
      before: before,
      optimisticRevision: optimistic.revision,
    );
  },
  mutate: (name, context) => api.renameTodo(name),
  onSuccess: (saved, name, rollback, context) {
    context.client.setQueryData(todoQuery, saved);
  },
  onError: (failure, name, rollback, context) {
    if (rollback.isAbsent) return;
    final value = rollback.requireValue();
    context.client.restoreQueryData(
      todoQuery,
      value.before,
      ifRevision: value.optimisticRevision,
    );
  },
);
```

Load the query before executing this example, for example with
`ensureQueryData(todoQuery)`. If active query work must not replace the
optimistic value, make `onMutate` asynchronous and await exact
`cancelQueries` before taking the snapshot and writing.

The revision guard prevents an old rollback from overwriting a newer write. It
is not a rollback stack. Concurrent optimistic failures may require scope
serialization, patch/rebase logic, or invalidation and refetch.

### Retry writes safely

Retrying a non-idempotent write can duplicate it if the server applied an
attempt but the response was lost. Make the transport idempotent or reuse one
application idempotency key across every attempt of one logical execution:

```dart
Mutation<ProfileDraft, Profile, void> saveProfileMutation() {
  final requestId = createIdempotencyKey();
  return mutation<ProfileDraft, Profile, void>(
    metadata: <String, Object?>{'idempotencyKey': requestId},
    retry: RetryPolicy.standard,
    mutate: (draft, context) => api.saveProfile(
      draft,
      idempotencyKey: context.metadata['idempotencyKey'] as String,
    ),
  );
}

final saved = await client.execute(saveProfileMutation(), draft);
```

Create a new recipe and application idempotency key for each logical write.
Recipe metadata remains stable across that execution's attempts.

### Zero-variable actions

`action<D, R>` uses the same mutation runtime without exposing the
`NoVariables.value` sentinel:

```dart
final refreshToken = action<Token, void>(
  mutate: (context) => api.refreshToken(),
);

final token = await client.executeAction(refreshToken);

final observer = client.observeMutation(refreshToken);
await observer.run(onSuccess: (token, result, context) {
  saveToken(token);
});
```

There is no special optimistic action subtype. Put optional cache work in its
`onMutate` exactly as for any other mutation.

Mutation execution exposes `Future<D>`, not a cancellation handle or cancelled
status. Client disposal prevents later commits/callbacks and fails unsettled
wrapper Futures, but cannot undo an external side effect that already started.

## Infinite queries

### Inline infinite query

The page type should represent one complete server page, not one item:

```dart
final feed = infiniteQuery<FeedPage, String?>(
  QueryKey(<Object?>['feed']),
  (context) => api.getFeedPage(context.pageParam),
  client: client,
  initialPageParam: null,
  getNextPageParam: (data) {
    final cursor = data.pages.last.nextCursor;
    return cursor == null ? PageCursor.end : PageCursor.more(cursor);
  },
  getPreviousPageParam: (data) {
    final cursor = data.pages.first.previousCursor;
    return cursor == null ? PageCursor.end : PageCursor.more(cursor);
  },
  maxPages: 5,
  staleTime: StalePolicy.duration(const Duration(minutes: 1)),
);
```

`InfinitePageContext<PageParam>` exposes `pageParam`, `direction`, and the
underlying query `client`, `key`, `metadata`, and `cancellationToken`.

`InfiniteData<Page, PageParam>` contains aligned immutable `IList` values in
`pages` and `pageParams`. Only `PageCursor.end` ends pagination. If the page
parameter is nullable, `PageCursor.more(null)` is a valid continuation.

Omit `getPreviousPageParam` for a forward-only query. `maxPages` bounds retained
pages and trims the opposite edge of the direction being added. Calling
`fetchPreviousPage()` on a forward-only query returns the current result
without starting a request.

### Class-first infinite query

```dart
final class FeedQuery extends InfiniteQuery<FeedPage, String?> {
  const FeedQuery({QueryClient? client})
      : super(
          client: client,
          staleTime: StalePolicy.untilInvalidated,
          retention: RetentionPolicy.forever,
        );

  @override
  QueryKey get key => QueryKey(<Object?>['feed']);

  @override
  String? get initialPageParam => null;

  @override
  Future<FeedPage> fetchPage(InfinitePageContext<String?> context) {
    return api.getFeedPage(context.pageParam);
  }

  @override
  PageCursor<String?> getNextPageParam(
    InfiniteData<FeedPage, String?> data,
  ) {
    final cursor = data.pages.last.nextCursor;
    return cursor == null ? PageCursor.end : PageCursor.more(cursor);
  }
}
```

A class-first infinite query uses the same constructor-first policy
configuration as `Query<T>`. It may also override previous-page resolution and
`maxPages`; specialized subclasses may override metadata and whole-data
reconciliation, while whole-data retry, freshness, retention, and network mode
are passed to `super`.

### Observe and select infinite data

Selection preserves pagination capability:

```dart
final posts = feed.select(
  (data) => data.pages.expand((page) => page.posts).toList(),
);

final observer = client.observeInfiniteQuery(posts);

if (observer.hasNextPage) {
  await observer.fetchNextPage(cancelRefetch: true);
}
if (observer.hasPreviousPage) {
  await observer.fetchPreviousPage();
}
await observer.refetch();
```

`InfiniteQueryObserverResult<TView>` includes every ordinary query result field
plus `hasNextPage`, `hasPreviousPage`, `isFetchingNextPage`,
`isFetchingPreviousPage`, `isFetchNextPageError`, and
`isFetchPreviousPageError`. There is one canonical `failure`; directional flags
classify it.

Like `watchQuery`, `watchInfiniteQuery` reacts to target-factory signal reads:

```dart
final observer = client.watchInfiniteQuery(
  () => feedQueryForCategory(category.value),
);
```

Next and previous requests share one guarded operation lane. `refetch()`
sequentially rebuilds the retained reachable page count and commits the final
aligned value atomically rather than exposing half-refreshed pages. If a page
attempt fails and exception retry is accepted, retry resumes from that failed
page without repeating already accepted pages from the same refresh. If a
completed whole result is rejected by a result predicate, the retry rebuilds
the requested window from its initial page.

### Imperative infinite operations and raw cache

```dart
final refreshed = await client.fetchInfiniteQuery(feed);
final firstThree = await client.fetchInfiniteQuery(feed, pages: 3);
await client.prefetchInfiniteQuery(feed, pages: 3);
final data = await client.ensureInfiniteQueryData(feed);

final cached = await client.ensureInfiniteQueryData(
  feed,
  revalidateIfStale: true,
);

final raw = client.getQueryData(feed);
final checkpoint = client.snapshotQueryData(feed);
client.updateQueryData(
  feed,
  (previous) => previous.requireValue(),
);
```

Imperative infinite fetches use no retry unless configured. The raw recipe is a
`QueryDataTarget<InfiniteData<FeedPage, String?>>`, so all six exact cache APIs
remain typed. Selected infinite views are observable but are not raw cache
carriers and cannot be passed to imperative infinite fetch methods.

`prefetchInfiniteQuery(pages: n)` starts from the initial page and fetches at
most `n` sequential pages only when the cache is missing or stale. It does not
append `n` pages to a fresh cache or guarantee a total of `n` pages.

When `fetchInfiniteQuery` omits `pages`, an initial fetch requests one page and
a refresh preserves the retained reachable page count. Imperative infinite
fetches join an active operation by default; `cancelRefetch: true` replaces an
active retained-data refresh, while an active initial load remains
single-flight.

Whole-data retry applies to `InfiniteData`, not individual pages. Page
validation should throw from `fetchPage`; the enclosing whole-data operation
then decides whether to retry.

`retry`, `initialData`, `select`, `observer`,
`placeholder`, and `placeholderData` follow the same stage rules as an
ordinary query.

## Stream-backed queries

`streamedQuery` creates an ordinary `QueryFunction<Data>`, so it uses the same
cache, observer, stale, invalidation, polling, retry, cancellation, and
retention rules:

```dart
final messagesQuery = query<List<Message>>(
  key: QueryKey(<Object?>['messages']),
  fetch: streamedQuery<Message, List<Message>>(
    stream: (context) => api.messageStream(),
    initial: () => <Message>[],
    reduce: (current, message) => <Message>[...current, message],
    mode: StreamRefetchMode.append,
  ),
);
```

For the common “collect chunks into a list” case, use the typed convenience
helper:

```dart
final messagesQuery = query<IList<Message>>(
  key: QueryKey(<Object?>['messages']),
  fetch: streamedListQuery<Message>(
    stream: (context) => api.messageStream(),
    mode: StreamRefetchMode.append,
  ),
);
```

`streamedListQuery<Chunk>` returns `QueryFunction<IList<Chunk>>` and appends
each chunk to a persistent immutable list. Use the generic `streamedQuery` when
the accumulator is not a list or needs domain-specific reduction.

`append` expects the source to emit events newer than the captured cache
baseline. If every subscription replays a complete snapshot or full history,
use `reset` or `replace` to avoid application-level duplicates.

For a fetched cached baseline `[0]` and incoming chunks `1`, `2`:

| Mode | Visible behavior |
| --- | --- |
| `reset` | Clears the logical baseline, then publishes `[1]` and `[1, 2]`. |
| `append` | Reduces from the captured baseline, publishing `[0, 1]` and `[0, 1, 2]`. |
| `replace` | Keeps `[0]` visible and atomically publishes `[1, 2]` only after normal close. |

Choose `reset` for a fresh progressive result, `append` for event/history
continuation, and `replace` when partial data must remain private.

`initial()` and the stream factory run once per retry attempt. Stream and
reducer exceptions use exception retry predicates. A normal-close final
`Data` is evaluated once by result predicates. Reset and append can publish
partial values; replace never does.

Reset mode checks query-wide `isFetched` at the beginning of every attempt.
Initial-data seeding alone is not fetched: on the first attempt the seed stays
visible and the first chunk reduces from it. Once an operation, partial, manual
write, restore, or terminal error has completed, a reset attempt restores the
configured initial-data state—or pending absence when there is no seed—before
subscribing. A partial may remain visible during retry delay, but the next
attempt restores that reset state when it actually starts.

`append` rebuilds privately from the baseline captured at the start of the
logical operation, not from the failed partial, and does not republish that
baseline merely because retry starts. `replace` discards each failed private
accumulator and keeps the then-current visible value until an accepted attempt
closes normally.

Reset retry start may restore configured query initial data, or pending absence
when no such seed exists. It never publishes the streamed helper's `initial()`
merely because an attempt starts. Append and replace retry starts do not restore
their logical/private baselines into cache. If exception retry is exhausted,
the value visible at that moment stays visible: present data produces a
retained-data refetch error, while absent data produces a loading error.

Each attempt owns and cancels its Stream subscription. Removal/recreation,
operation replacement, explicit cancellation, and client disposal reject late
events. Manual cache writes do not cancel a stream and can still be replaced by
a later accepted chunk or final result; await exact `cancelQueries` first when
the manual value must win.

For large streams, choose a data structure or batching strategy that avoids
copying a growing mutable `List` for every chunk.

## Deterministic runtime

`QueryClient()` uses `QueryRuntime.system()`. Tests and specialized hosts can
inject all time-dependent capabilities:

```dart
final client = QueryClient(
  runtime: QueryRuntime(
    clock: fakeClock,
    timers: fakeTimers,
    random: seededRandom,
    notifications: immediateNotifications,
  ),
);
```

Implement these public contracts as needed:

| Contract | Responsibility |
| --- | --- |
| `QueryClock` | Wall-clock and monotonic time. |
| `QueryTimerScheduler` | One-shot and periodic scheduling. |
| `QueryRandomSource` | Retry jitter values in `[0, 1)`. |
| `QueryNotificationScheduler` | Outward notification flush scheduling. |
| `QueryScheduledHandle` | Idempotent cancellation state for scheduled work. |

Runtime providers are borrowed. The client cancels handles it created but does
not dispose the providers.

## Clear, dispose, and ownership

| Operation | Query records | Mutation records | Active work | Reusable client / event streams |
| --- | --- | --- | --- | --- |
| `queryCache.clear()` | Removed | Kept | Current query operations are cancelled; attached observers reattach normally. | Yes / open |
| `mutationCache.clear()` | Kept | Removed and detached | Mutations continue without reinserting records. | Yes / open |
| `client.clear()` | Removed | Removed and detached | Query work follows query clear; mutation work continues. | Yes / open |
| `client.dispose()` | Removed | Removed | Owned wrappers, retries, timers, subscriptions, and observers terminate or reject late commits. External side effects cannot be undone. | No / closed |

Additional ownership rules:

- Query and mutation observers are independently disposable. The client also
  disposes observers still registered with it.
- `QueryCache` and `MutationCache` are non-disposable views owned by the client.
- Cache snapshots and checkpoints are immutable values, not live handles.
- Focus/online managers own their current event-source subscriptions, but the
  caller owns the supplied Streams.
- Mutation Futures are completion values, not cancellation handles.
- `client.dispose()` is terminal and idempotent; later active operations throw
  `QueryClientDisposedException` or reject late work.

## Runnable Flutter Web example

The [`example`](example/lib/main.dart) is an interactive feature tour. Its
ordinary, infinite, and mutation stories are rendered through their three
observer widgets. It shows query-key switching, fresh-cache reuse, stale
deadlines and triggers, retained-data refetch, placeholders, fixed and
state-derived polling, Flutter lifecycle focus, cancellation, manual-write
versus cancel-before-write behavior, typed retry, mutation scopes and
lifecycle, optional optimistic updates, pagination, and all three stream
refetch modes.

```sh
cd packages/jolt_query/example
flutter run -d chrome
```

## Flutter observer widgets

`jolt_query` directly provides provider-free widgets for ordinary queries,
infinite queries, and mutations.

### QueryWidget

```dart
import 'package:flutter/material.dart';
import 'package:jolt_query/jolt_query.dart';

final todosQuery = query<List<Todo>>(
  key: QueryKey(<Object?>['todos']),
  fetch: (_) => api.listTodos(),
  staleTime: StalePolicy.duration(const Duration(minutes: 1)),
);

class TodoList extends StatelessWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryWidget<List<Todo>>(
      query: todosQuery,
      builder: (context, observer) {
        if (observer.isLoading) {
          return const CircularProgressIndicator();
        }
        if (observer.data.isAbsent) {
          return Text('Failed: ${observer.failure?.error}');
        }
        return ListView(
          children: [
            for (final todo in observer.data.requireValue())
              ListTile(title: Text(todo.title)),
          ],
        );
      },
    );
  }
}
```

`QueryWidget` has only `query` and `builder`; it reads `query.client`, owns one
observer, and disposes that observer on unmount without disposing the client.
The builder receives a borrowed observer and must not dispose it. A same-client
target update reuses the observer. A same-key update changes configuration
without another mount refetch, a key update switches cache entries with normal
previous-view placeholder behavior and automatically fetches when enabled plus
absent/stale, and a client update replaces the observer. `refetchOnMount` does
not suppress a different-key dependency fetch.

The widget listens to the complete observer result. Cache/result and
observer-local state changes rebuild it, while writes to unrelated query keys
do not. The builder is not an implicit `JoltBuilder`; arbitrary Jolt signal
reads inside it are not tracked. Normal Flutter parent and inherited-widget
rebuilds still apply.

### InfiniteQueryWidget

```dart
InfiniteQueryWidget<InfiniteData<Post, String?>>(
  query: feedQuery.observer(staleTime: StalePolicy.untilInvalidated),
  builder: (context, observer) {
    final pages = observer.data.valueOrNull?.pages;
    return Column(
      children: [
        if (pages != null)
          for (final page in pages) Text(page.title),
        FilledButton(
          onPressed: observer.hasNextPage && !observer.isFetchingNextPage
              ? observer.fetchNextPage
              : null,
          child: const Text('More'),
        ),
      ],
    );
  },
);
```

The target supplies its client. Same-client rebuilds retain one
`InfiniteQueryObserver`, including same-key configuration updates; a target
bound to another client replaces the observer. The builder receives that
widget-owned observer as a borrowed value and must not dispose it.

### MutationWidget

```dart
MutationWidget<TodoDraft, Todo, void>(
  client: client,
  mutation: saveTodo,
  builder: (context, observer) {
    return FilledButton(
      onPressed: observer.isPending
          ? null
          : () => observer.execute(currentDraft),
      child: Text(observer.isPending ? 'Saving…' : 'Save'),
    );
  },
);
```

Mounting a `MutationWidget` never executes the mutation. Its optional `client`
defaults to `QueryClient.defaultClient`. A same-client recipe update calls
`updateMutation`: equal nullable keys retain the latest presentation, while a
different key resets it to idle. A client change creates a new idle observer.
Already submitted work continues with the recipe and client captured at
submission. The builder receives the widget-owned observer as a borrowed value
and must not dispose it.

There is no `QueryClientProvider`, inherited client lookup, hook layer,
automatic Material/Cupertino state UI, Suspense, or ErrorBoundary.

## Public API quick reference

### Query recipes and presentation

| API | Main use |
| --- | --- |
| `query`, `Query<T>` | Inline or class-first raw query. |
| `QueryContext` | Executing client, key, metadata, and cancellation for an attempt. |
| `QueryDataTarget<T>` | Typed carrier accepted by exact raw-cache operations. |
| `QueryView<T>` | Select-capable stage. |
| `QueryTarget<T>` / `AnyQueryTarget` | Observable typed or erased target with a resolved `client`. |
| `select` | Raw/view projection. |
| `retry` | Typed custom raw-data retry. |
| `initialData` | New-entry raw seed. |
| `observer` | Activation, stale, trigger, polling, and equality options. |
| `placeholder` / `placeholderData` | Observer-local final-view fallback. |
| `observeQuery` / `watchQuery` | Fixed or signal-derived target observation. |
| `QueryObserver<T>` / `QueryObserverResult<T>` | Reactive single-query presentation. |
| `QueryWidget<T>` | Provider-free Flutter ownership and rendering of one query observer. |
| `observeQueries` / `watchQueries` | Fixed or signal-derived erased target list. |
| `observeCombinedQueries` / `watchCombinedQueries` | Derive one value from multiple results. |
| `QueriesObserver<R>` / `ErasedQueryObserverResult` | Multi-query presentation. |

### Query client and cache

| API | Main use |
| --- | --- |
| `QueryClient.defaultClient`, `QueryClient.setDefault` | Lazy or application-configured target fallback client. |
| `bindFlutterLifecycle`, `FlutterLifecycleBinding` | Explicitly mirror Flutter app lifecycle into client focus. |
| `fetchQuery`, `prefetchQuery`, `ensureQueryData` | Imperative read/fetch operations. |
| `getQueryData`, `getQueryState` | Exact typed cache reads. |
| `snapshotQueryData`, `restoreQueryData` | Revision-guarded data checkpoint and restore. |
| `setQueryData`, `updateQueryData` | Exact typed writes. |
| `getQueriesData`, `setQueriesData`, `updateQueriesData` | Typed filtered bulk data operations. |
| `invalidateQueries`, `refetchQueries`, `cancelQueries`, `resetQueries` | Async filtered lifecycle operations. |
| `removeQueries`, `clear`, `dispose` | Synchronous removal, reusable clear, terminal disposal. |
| `queryCache.snapshots`, `queryCache.events`, `queryCache.clear` | Read-only query cache view. |
| `QueryCacheCallbacks` | Immutable client-wide post-commit query observation hooks. |
| `fetchingCount`, `countFetching` | Reactive global or synchronous filtered activity count. |
| `registerQueryDefaults`, `getQueryDefaults`, `clearQueryDefaults` | Prefix-merged query defaults. |

Related values are `QuerySnapshot<T>`, `QueryDataSnapshot<T>`,
`QueryDataMatch<T>`, `QueryCacheSnapshot`, `QueryCacheEvent`,
`QueryBatchResult`, and `QueryBatchFailure`.

### Policies and filters

| API | Main use |
| --- | --- |
| `QueryKey`, `MutationKey` | Structural identity/filter keys. |
| `StalePolicy`, `StaleState` | Freshness calculation. |
| `RetentionPolicy` | Inactive/settled cache lifetime. |
| `NetworkMode` | Online attempt gating. |
| `RefetchPolicy`, `QueryRefetchTarget` | Automatic and bulk execution targets. |
| `QueryPollingIntervalResolver<T>` | Resolve the next poll delay from current observer state. |
| `QueryFilter`, `TypedQueryFilter<T>` | Erased lifecycle or typed data matching. |
| `QueryActivity`, `QueryFreshness` | Filter partitions. |
| `DataReconciler<T>` | Raw structural sharing. |
| `RetryPolicy<T>`, `RetryBuilder<T>` | Marker or custom retry. |

### Mutations

| API | Main use |
| --- | --- |
| `mutation`, `Mutation<V, D, R>` | Inline or class-first write recipe. |
| `MutationContext`, `MutationScope` | Submission capabilities and FIFO lane. |
| `execute`, `observeMutation` | Fire a mutation or observe the latest execution. |
| `MutationObserver`, `MutationObserverResult` | Reactive mutation presentation. |
| `MutationWidget<V, D, R>` | Provider-free Flutter ownership of a mutation observer. |
| `action`, `executeAction`, `MutationActionObserverMethods.run` | Zero-variable facade. |
| `MutationCacheCallbacks` | Global awaited lifecycle policy. |
| `mutationCache.snapshots`, `findAll`, `events`, `clear` | Read-only mutation-cache operations. |
| `MutationFilter`, `MutationSnapshot`, `MutationCacheEvent` | Filtering and observation values. |
| `mutatingCount`, `countMutating` | Reactive global or synchronous filtered pending count. |
| `registerMutationDefaults`, `getMutationDefaults`, `clearMutationDefaults` | Prefix-merged mutation defaults. |

### Infinite and stream queries

| API | Main use |
| --- | --- |
| `infiniteQuery`, `InfiniteQuery<Page, PageParam>` | Inline or class-first pagination. |
| `InfiniteData`, `InfinitePageContext`, `InfiniteDirection` | Aligned pages and page attempt context. |
| `PageCursor.more`, `PageCursor.end` | Explicit continuation/end decision. |
| `observeInfiniteQuery`, `watchInfiniteQuery` | Fixed or signal-derived infinite observation. |
| `InfiniteQueryObserver`, `InfiniteQueryObserverResult` | Selected pagination presentation and operations. |
| `InfiniteQueryWidget<T>` | Provider-free Flutter ownership of an infinite observer. |
| `fetchInfiniteQuery`, `prefetchInfiniteQuery`, `ensureInfiniteQueryData` | Imperative raw pagination operations. |
| `streamedQuery`, `streamedListQuery`, `StreamRefetchMode` | Reduce a Stream through an ordinary query lane. |

### Foundation

The barrel also exports `QueryValue<T>`, `QueryAbsent<T>`, `QueryPresent<T>`,
`QueryFailure`, `QueryCancelledException`, `QueryCancellationToken`,
`QueryCancellationController`, `FocusManager`, `OnlineManager`, `QueryRuntime`
and its provider interfaces, and `IList` because immutable lists occur in
public result signatures.

## Intentional boundaries

This release does not include persistence, hydration, DevTools, cross-process
recovery, Suspense, ErrorBoundary, a framework provider layer, or entity
normalization. It does not replace Jolt `AsyncSignal` or define a generic Task.
Caller Streams and custom runtime providers remain caller-owned.

## License

MIT
