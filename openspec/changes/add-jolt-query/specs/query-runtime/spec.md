## ADDED Requirements

### Requirement: Flutter-capable package with framework-independent runtime observers
The system SHALL provide one Flutter-capable `jolt_query` package using Jolt's public reactive API for its server-state runtime and `jolt_flutter` for its widget integration. The cache, client, query, observer, mutation, retry, infinite-query, and streamed-query runtime implementations SHALL NOT depend on BuildContext, mounted Widget state, or Flutter lifecycle callbacks. A query observer SHALL implement `Readable<QueryObserverResult<TView>>` and `Disposable`; creating, reading, or disposing one SHALL NOT require a mounted widget or an active Jolt effect scope.

#### Scenario: Observer participates in tracking
- **WHEN** a Jolt computation reads a query observer or one of its tracked field getters
- **THEN** it is notified according to the complete-result or field-level subscription contract

#### Scenario: Observer is disposed twice
- **WHEN** an observer is disposed more than once
- **THEN** disposal is idempotent and no owned listener, effect, or polling timer remains active

#### Scenario: Existing Jolt runtime is used
- **WHEN** an application does not import `jolt_query`
- **THEN** the existing Jolt package API and runtime behavior remain unchanged

### Requirement: Class-first queries inline factory and staged targets
The system SHALL define `abstract base class Query<TData>` as the reusable executable recipe and provide an inference-friendly `query(...)` factory returning the same model. Both forms SHALL accept an optional QueryClient binding. The public stage relationship SHALL be `Query<TData> extends QueryView<TData> extends QueryTarget<TData>`, where `QueryView<TView>` is the only select-capable stage and `QueryTarget<TView>` is observable, exposes a non-null resolved client, and can add terminal observer or placeholder configuration. All transformation methods SHALL have package-provided concrete implementations and SHALL preserve the client binding. A minimal external Query subclass SHALL implement only QueryKey and fetch; policies, metadata, reconciliation, retry, initial-data, selection, observer, and placeholder behavior SHALL have inherited defaults or concrete transforms. `Query<TData>.withRetry` SHALL return `Query<TData>`. `Query<TData>.withInitialData(TData data, {DateTime? updatedAt})` SHALL return `QueryView<TData>`. `QueryView<TView>.select<TNext>` SHALL return `QueryView<TNext>`. `withObserver`, `withPlaceholderData`, and `withPlaceholder` SHALL return terminal `QueryTarget<TView>`. Class-first retry, stale, retention, and network policy getters SHALL be non-virtual views of values supplied through the base constructor; runtime default resolution SHALL use that constructor configuration directly and SHALL NOT infer explicitness by comparing an overridden getter result to a built-in singleton. A `Query` or `QueryView` SHALL be directly observable using defaults. The public API SHALL NOT expose `QueryDefinition`, `QueryFamily`, a general Query builder, or a public options object as the type carrier.

#### Scenario: Reusable class binds data type once
- **WHEN** an external package subclasses `Query<User>` and passes an instance to observer and client operations
- **THEN** the final/base/sealed subclass implements only key and fetch, inherits every transform, and operations infer `User` without a type argument, cast, raw type, dynamic, or retry_plus import

#### Scenario: Inline query infers data
- **WHEN** `query(...)` receives a fetch function returning `Future<User>`
- **THEN** the expression has type `Query<User>` under strict inference

#### Scenario: Legal transformation order is used
- **WHEN** a query applies retry, initial data, multiple selectors, then placeholder or observer configuration
- **THEN** every stage retains its exact current data or view type and the final target is observable

#### Scenario: Query view is observed directly
- **WHEN** a `QueryView<String>` produced by selection is supplied directly to `observeQuery`
- **THEN** the returned observer is `QueryObserver<String>` with default observer configuration

#### Scenario: Query transformations preserve an explicit client
- **WHEN** a query with an explicit QueryClient applies retry, initial data, selection, observer settings, and placeholder transformations
- **THEN** every resulting target exposes that identical QueryClient

#### Scenario: Class-first query explicitly selects a built-in policy
- **WHEN** a reusable query passes an immediate stale policy, online network mode, standard retention, or marker retry policy to `super(...)`
- **THEN** that explicit constructor value wins over matching registered defaults without relying on an overrideable getter

### Requirement: Static default QueryClient
`QueryClient.defaultClient` SHALL lazily return one zero-configuration active client per isolate when no client was installed. `QueryClient.setDefault(QueryClient client)` SHALL install an active default before default resolution. Resolving the default SHALL lock its identity; a later set attempt SHALL fail rather than silently move new query targets to another cache. A disposed client SHALL be rejected. The static holder SHALL NOT automatically dispose a configured or lazy default. Query targets without an explicit client SHALL resolve this default only when their public client binding is read; staged transformations and explicit QueryClient receiver operations SHALL preserve an unresolved fallback without reading or locking it. Explicitly bound targets SHALL not read or replace the default. Explicit instance methods invoked on another QueryClient SHALL continue to use their receiver rather than rejecting a target bound elsewhere.

#### Scenario: Default client is used lazily
- **WHEN** a query target without an explicit client first reads its client and no default was configured
- **THEN** it receives one lazily created active QueryClient reused by later unbound targets

#### Scenario: Default client is configured before use
- **WHEN** `QueryClient.setDefault(client)` receives an active client before default resolution
- **THEN** unbound query targets resolve that identical client

#### Scenario: Default is changed after resolution
- **WHEN** code calls `setDefault` after `defaultClient` was resolved
- **THEN** it receives a deterministic StateError and the original default remains installed

#### Scenario: Disposed default is supplied
- **WHEN** `setDefault` receives a disposed QueryClient
- **THEN** it rejects the value without changing default resolution

#### Scenario: Explicit client operation overrides target binding
- **WHEN** a QueryClient instance method receives a target bound to another client
- **THEN** the operation uses the method receiver and its cache, while the target binding remains unchanged

#### Scenario: Unbound staging and explicit operations remain lazy
- **WHEN** an unbound query is transformed and used through an explicit QueryClient receiver before its public client binding is read
- **THEN** the default remains unresolved and `setDefault` can still install the application client

### Requirement: Structural query keys and caller-owned identity
`QueryKey` SHALL be a non-generic immutable structural value backed by defensively converted `IList` and `IMap` values. It SHALL accept null, bool, String, int, finite double, recursive List, and `Map<String, Object?>`; reject unsupported leaves; compare list order; ignore map insertion order; cache a hash consistent with equality; and support structural prefix matching. Prefix matching SHALL recursively partial-match nested maps and lists while exact key equality remains fully structural. Query class, declared Dart type, ordinary or infinite behavior, instance identity, fetch closure, retry policy, and reconciler SHALL NOT participate in cache identity or cause mismatch errors. Reusing a structural key SHALL be a caller-owned assertion that one cached shape is intended.

#### Scenario: Structurally equal inputs are used
- **WHEN** two separately constructed keys normalize to the same structure
- **THEN** they locate one cache entry and have equal hashes

#### Scenario: Original mutable values change
- **WHEN** source Lists or Maps are mutated after key construction
- **THEN** the key value, equality, and hash remain unchanged

#### Scenario: Map insertion order differs
- **WHEN** two nested maps contain equal fields in different insertion orders
- **THEN** the normalized keys are equal

#### Scenario: Nested prefix partially matches a map
- **WHEN** a filter prefix contains a nested map subset and the candidate key contains those fields plus additional nested fields
- **THEN** prefix matching succeeds without weakening exact QueryKey equality

#### Scenario: Unsupported key value is supplied
- **WHEN** a key contains a Set, DateTime, custom leaf, non-String map key, or other unsupported value
- **THEN** construction fails before cache lookup

#### Scenario: Different recipes reuse a key
- **WHEN** Query instances with different classes, declared types, or fetch functions use one structural key
- **THEN** they share the entry, join an active operation, and the Query initiating a later operation supplies its captured plan

#### Scenario: Entry-level operation has no plan
- **WHEN** a cache-only entry matches a refetch but has never retained an executable Query plan
- **THEN** it is reported as skipped-non-executable rather than guessing a fetch function

### Requirement: Shared recursive numeric key normalization
`QueryKey` and `MutationKey` SHALL use one recursive numeric normalization contract: int remains int; finite integral double canonicalizes to int; `1` equals `1.0`; `-0.0` equals `0`; finite fractional double remains double; and NaN or either infinity is rejected. The rule SHALL apply at every nested List or Map depth and SHALL drive both equality and hashing.

#### Scenario: Integral numbers use canonical identity
- **WHEN** otherwise equal keys contain `1`, `1.0`, `-0.0`, or `0` in corresponding positions
- **THEN** the integral equivalents normalize identically and have equal hashes

#### Scenario: Fractional value remains distinct
- **WHEN** corresponding key parts contain `1` and `1.5`
- **THEN** their normalized values and keys remain distinct

#### Scenario: Non-finite value is nested
- **WHEN** NaN or infinity occurs inside a nested collection
- **THEN** construction rejects the complete key

### Requirement: Explicit cached-value presence and failure information
The public `QueryValue<T>` SHALL be an exhaustive sealed union of public const `QueryAbsent<T>` and `QueryPresent<T>` variants, with const root factories for absent and present plus `isPresent`, `isAbsent`, `valueOrNull`, and `requireValue()`. Present-null SHALL be distinct from absent, and application placeholder resolvers SHALL be able to construct either variant. `QueryFailure` SHALL preserve the thrown `Object` and its `StackTrace`. Canonical query and mutation reads SHALL use `QueryValue` rather than nullable `T?` as their presence contract.

#### Scenario: Nullable query succeeds with null
- **WHEN** a `Query<User?>` successfully returns null
- **THEN** observer state and cache reads contain `QueryPresent<User?>(null)`

#### Scenario: Query has no value
- **WHEN** a query has never produced data and has no initial or placeholder value
- **THEN** its canonical data is `QueryAbsent<T>`

#### Scenario: Required absent value is read
- **WHEN** `requireValue()` is called on `QueryAbsent<T>`
- **THEN** it throws the documented absence error rather than returning null

#### Scenario: Query function throws a non-Exception object
- **WHEN** a query function throws any Dart Object
- **THEN** `QueryFailure` retains that exact object and stack trace

### Requirement: Typed cache data operations and revisioned conditional checkpoints
`QueryClient` SHALL expose exact typed `getQueryData`, `getQueryState`, `snapshotQueryData`, `setQueryData`, `updateQueryData`, and conditional `restoreQueryData` operations using `QueryDataTarget<T>` as the raw cache type carrier. `Query<T>` and raw `InfiniteQuery<Page, PageParam>` SHALL implement the carrier for `T` and `InfiniteData<Page, PageParam>` respectively; selected views SHALL NOT implement it. The carrier SHALL expose the structural key and typed reconciler needed by exact writes without exposing an executable ordinary-query bridge. Reads SHALL return `QueryValue<T>` or typed snapshots. Writes SHALL accept raw `T`, and updaters SHALL receive `QueryValue<T>`.

`QueryDataSnapshot<T>` SHALL be a general data checkpoint that publicly records the complete `QueryValue<T>` including absent and present-null, update time, and revision and privately binds the originating client, normalized structural key, and per-key lineage. It SHALL NOT capture or restore internal entry existence. Conditional restoration SHALL require matching expected revision and provenance. Restoring absent data into an existing entry SHALL write `QueryAbsent<T>` while leaving that entry available to attached observers, active work, and ordinary GC. An otherwise valid absent checkpoint targeting no existing entry SHALL succeed as a no-op without creating an empty entry. Different type carriers with one structural key SHALL be compatible, while another key/client, a removed-key lineage, or any checkpoint issued before QueryCache clear SHALL be rejected. Clear SHALL rotate all known per-key lineages, including a key known only through an absent checkpoint.

Except for the successful absent-checkpoint-to-missing-entry no-op, exact `set`, `update`, and successful `restore`, plus bulk `set` and `update`, SHALL synchronously change the complete cached `QueryValue<T>`, data-derived query status, data timestamp/update count/revision, clear `isInvalidated`, and clear terminal data failure without cancelling or replacing an active operation. A conditional restore that returns false SHALL change no state. Data-lane writes SHALL preserve the active operation's identity, cancellation token, fetch status, pause state, transient attempt failure, and retry progress. A successful manual write during active work SHALL advance that operation's cancellation rollback baseline to the post-write data/status/failure/counter state; reversion SHALL normalize fetch status to idle and clear the pause reason rather than restoring an active-looking state without an operation. The active operation MAY later commit normally and replace the manual value or fail against the retained manual data. A caller that needs to prevent that normal replacement SHALL explicitly await `cancelQueries` before writing. Bulk data operations SHALL require `TypedQueryFilter<T>` and return stable-order `IList<QueryDataMatch<T>>`, where each read match pairs QueryKey with its current typed checkpoint and each write match contains its post-write checkpoint; bulk writes SHALL target existing matches. There SHALL be no bulk restore operation.

#### Scenario: Exact read infers its result
- **WHEN** `getQueryData` receives `Query<User?>`
- **THEN** it returns `QueryValue<User?>` without a manually supplied generic argument

#### Scenario: Raw nullable write is made
- **WHEN** `setQueryData` receives null for `Query<User?>`
- **THEN** it writes a present-null value and returns its new revisioned snapshot

#### Scenario: Updater sees absence
- **WHEN** `updateQueryData` targets a query with no cached value
- **THEN** the updater receives `QueryAbsent<T>` and its returned `T` becomes present

#### Scenario: Cache write occurs during an active fetch
- **WHEN** setQueryData, updateQueryData, or a bulk write updates an entry whose fetch is active
- **THEN** cached data changes synchronously while operation identity, cancellation token, fetch status, and pause state remain unchanged
- **AND** the active fetch may later commit normally and replace the manual value

#### Scenario: Active fetch is cancelled after a manual write
- **WHEN** an exact or bulk manual data write succeeds during active work and that work is later cancelled with reversion
- **THEN** cancellation retains the latest manual data state, clears fetching/pause presentation, and does not restore the older operation-start value

#### Scenario: Caller protects a manual cache write
- **WHEN** the caller awaits cancelQueries before writing cache data
- **THEN** the cancelled operation's late completion cannot overwrite the manual value

#### Scenario: Conditional checkpoint remains current
- **WHEN** `restoreQueryData` receives a snapshot and the supplied revision matches the current entry revision
- **THEN** it restores the checkpoint's complete QueryValue and update time and returns true without restoring internal entry existence

#### Scenario: Conditional restore occurs during an active fetch
- **WHEN** restoreQueryData receives matching provenance and revision while the entry is fetching
- **THEN** it restores only the captured QueryValue and update time without cancelling or replacing the fetch
- **AND** the active fetch may later commit normally

#### Scenario: Active fetch is cancelled after conditional restore
- **WHEN** a conditional restore succeeds during active work and that work is later cancelled with reversion
- **THEN** the restored checkpoint remains the visible idle data state

#### Scenario: Absent checkpoint targets no entry
- **WHEN** an otherwise valid absent checkpoint is restored while its target still has no QueryEntry
- **THEN** restoration returns true as a no-op and does not create an empty entry

#### Scenario: Newer write precedes conditional restore
- **WHEN** another write changed the revision before conditional restore
- **THEN** restoration returns false and cannot overwrite the newer value

#### Scenario: Snapshot is used with another key or client
- **WHEN** `restoreQueryData` receives an otherwise type-compatible snapshot from a different structural key or QueryClient
- **THEN** it returns false without changing cache

#### Scenario: Checkpoint crosses a lineage boundary
- **WHEN** its key was removed and recreated or QueryCache was cleared after any checkpoint was issued, including one for a missing key
- **THEN** restoration returns false and cannot write into the new lineage even when its revision coincidentally matches

### Requirement: Shared cache single-flight and orthogonal state
One structural key SHALL own one raw cache entry and one active operation lane.
Duplicate initial fetches SHALL join. Imperative fetch SHALL join by default,
while observer and bulk manual refetch SHALL replace a retained-data operation
by default. Starting work from absent data SHALL capture rollback first and
then clear terminal failure presentation, enter pending query status, and enter
fetching or paused fetch status; retained-data background work SHALL preserve
its data-state presentation. Query status and fetch status SHALL remain
orthogonal so retained data can stay successful while a background fetch runs
or fails. Every operation SHALL guard commits with entry incarnation and
operation ID. Invalidation revision SHALL remain monotonic diagnostic state,
but every accepted success SHALL clear the current invalidated flag rather than
using the start revision as a second commit guard. QueryContext SHALL expose
the actual QueryClient receiver executing the operation, including when it
differs from the target's configured client.

Cancellation SHALL commit lane detachment, rollback/reset state, cache publication, and GC eligibility before synchronously notifying user cancellation-token listeners. A retained-data replacement SHALL reserve its lane before that notification, so reentrant same-key work joins the eventual replacement or explicitly cancels the reservation without orphaning either Future. Removal and clear SHALL detach the captured entry identity before notification, so reentrant same-key work enters a new incarnation and is not accidentally removed. Reset SHALL commit its reset state and release the old lane before notification; work started by a listener SHALL not be overwritten into an idle-but-active contradiction. Any operation that nevertheless loses ownership SHALL settle as stale or disposed rather than leaving its public Future or cancellation ownership pending.

#### Scenario: Two observers mount a missing key
- **WHEN** two observers become enabled for the same absent entry before its fetch finishes
- **THEN** one query function invocation supplies both observers

#### Scenario: Cached data refreshes
- **WHEN** a successful entry starts a background refetch
- **THEN** data remains present and successful while fetch status becomes fetching

#### Scenario: Background refetch fails
- **WHEN** a retained-data refetch exhausts retries
- **THEN** data remains present, the result reports a refetch failure rather than a loading failure, and the entry remains stale for a later eligible revalidation

#### Scenario: Loading error is retried
- **WHEN** an entry with terminal error and absent data starts another fetch
- **THEN** it immediately presents pending loading with the old terminal failure cleared, while cancellation with reversion can still restore the prior error

#### Scenario: Bound query executes on another client
- **WHEN** a query bound to one client is fetched through a different QueryClient receiver
- **THEN** QueryContext.client is the executing receiver client

#### Scenario: Underlying Future ignores cancellation
- **WHEN** a replaced or cancelled Future later completes
- **THEN** operation identity prevents any stale state commit

#### Scenario: Entry is removed and recreated
- **WHEN** a key is removed and recreated before the old operation completes
- **THEN** the old incarnation cannot mutate the new entry

#### Scenario: Invalidation joins active work
- **WHEN** invalidation refetch joins an eligible active operation instead of replacing it
- **THEN** accepted success clears the invalidated flag and no hidden serial follow-up request is scheduled

#### Scenario: Cancellation listener fetches during replacement
- **WHEN** a cancellation-token listener synchronously fetches the same key while retained-data replacement is transitioning
- **THEN** it joins the reserved winning operation and neither old nor new Future is orphaned

#### Scenario: Cancellation listener cancels a replacement reservation
- **WHEN** a cancellation-token listener synchronously cancels the same key while its replacement lane is reserved
- **THEN** the reservation and outer replacement settle as cancelled, the lane is cleared, and a later fetch can start

#### Scenario: Removal listener recreates the same key
- **WHEN** removal triggers a token listener that synchronously fetches the same structural key
- **THEN** the listener creates a new incarnation which survives the outer removal

#### Scenario: Reset listener starts new work
- **WHEN** reset cancels active work and its token listener synchronously fetches the same key
- **THEN** the listener observes reset state and its active fetching state is not overwritten by the outer reset

### Requirement: Observer-local initial placeholder selection and activation
Initial data SHALL be raw shared-cache input configured only on `Query<TData>` and accepted as required `TData`. Seeding or resetting to initial data SHALL establish successful cached data and its update time but SHALL NOT increment fetch/data completion counters; therefore `isFetched` and `isFetchedAfterMount` remain false until an accepted operation result or streamed partial, manual write, restore, or terminal error updates the entry. Starting a reset-mode streamed attempt and restoring or clearing its visible seed SHALL NOT itself count as accepted data. The entry SHALL use a monotonic completion sequence plus a resettable visible-completion marker: reset clears visible completion without rewinding sequence, rollback restores the captured visible marker, and the next accepted completion receives a later sequence. Observers SHALL compare their attachment marker to current visible completion, not mutate their baseline from queued reset events. Placeholder data SHALL be a final `TView` or a resolver from previous `QueryValue<TView>`, SHALL bypass selection, and SHALL never enter shared cache. Selectors SHALL affect only their observer. Enabled state, stale override, trigger policies, equality, and polling SHALL remain observer-local. Every typed, erased, and infinite observer result SHALL expose the resolved `isEnabled` state.

#### Scenario: Initial data is supplied as null
- **WHEN** `Query<User?>.withInitialData(null)` initializes an absent entry
- **THEN** shared cache contains present-null with the supplied or default update time

#### Scenario: Initial data precedes selection
- **WHEN** raw User initial data is followed by selection to String
- **THEN** User is cached and only the observer publishes selected String

#### Scenario: Initial data has not been fetched
- **WHEN** an observer mounts an entry seeded only from initial data
- **THEN** it presents successful data while isFetched and isFetchedAfterMount remain false

#### Scenario: Reset restores the initial completion baseline
- **WHEN** a fetched or manually updated entry is reset to its configured initial data without refetch
- **THEN** completion counters return to zero and observers no longer report it as fetched

#### Scenario: Completion occurs after reset
- **WHEN** an observer mounted after multiple prior completions, reset returns counters to zero, and one later accepted update occurs
- **THEN** isFetchedAfterMount is true for that first post-reset completion without waiting to exceed the pre-reset count

#### Scenario: Reset stream waits for accepted output
- **WHEN** a reset-mode streamed query clears an initial-data seed but has not accepted a chunk or normal-close result
- **THEN** isFetched and isFetchedAfterMount remain false

#### Scenario: Queued reset event reaches a later attachment
- **WHEN** an observer leaves and reattaches to an entry after reset and a new completion but before the old reset notification is delivered
- **THEN** the queued event cannot rewrite its new attachment baseline or falsely report fetched-after-mount

#### Scenario: Placeholder is supplied as null
- **WHEN** a nullable final view calls `withPlaceholderData(null)` while raw cache is absent
- **THEN** that observer reports present-null placeholder success and QueryCache remains absent

#### Scenario: Placeholder resolver keeps previous view
- **WHEN** a target changes while its resolver returns the previous `QueryValue<TView>`
- **THEN** the previous presentation remains observer-local until current data is available

#### Scenario: Placeholder resolver returns absent
- **WHEN** the resolver returns `QueryAbsent<TView>`
- **THEN** no placeholder value is presented

#### Scenario: Selector throws
- **WHEN** one observer selector throws
- **THEN** only that observer reports selector failure and raw cache remains successful

#### Scenario: Disabled observer is manually refetched
- **WHEN** explicit `refetch` is invoked on a disabled observer
- **THEN** the query executes despite automatic activation being disabled

#### Scenario: Observer inherits enabled state
- **WHEN** enabled is supplied by matching defaults rather than the terminal target
- **THEN** the observer result and tracked getter expose the resolved value through `isEnabled`

### Requirement: Reactive single-query observation and structural-key retargeting
`QueryClient.watchQuery<TView>` SHALL evaluate its target factory under Jolt dependency tracking and reevaluate it when a read dependency changes. When reevaluation produces a different structural key, the observer SHALL detach from the prior entry, attach to the new entry, and publish the new key and presentation as one target transition. When it produces a new target with the same structural key, the observer SHALL update the retained plan, selector, placeholder, equality, freshness, enabled, polling, and trigger settings in place without detaching, resetting `isFetchedAfterMount`, or applying `refetchOnMount` again. A false-to-true enabled transition SHALL perform ordinary activation when necessary. If the formerly attached same-key entry was synchronously removed before its queued removal callback, retargeting SHALL attach a fresh current entry rather than updating the removed entry or throwing. An enabled absent entry SHALL start one shared fetch. On an already-mounted observer's key switch, an enabled stale cached entry SHALL refetch and a fresh cached entry SHALL not refetch regardless of `refetchOnMount`; that policy applies only to a real observer mount. A previous-view placeholder SHALL remain observer-local and SHALL NOT write the previous value into the new cache entry.

#### Scenario: Watched key changes to a missing entry
- **WHEN** a Signal read by `watchQuery` changes the target from a successful page key to an absent page key
- **THEN** the observer immediately targets the new key, may present the prior view as placeholder, reports fetching, and invokes the new key's query function once

#### Scenario: Watched key revisits a fresh cached entry
- **WHEN** the Signal changes back to a key whose cached data is still fresh
- **THEN** the observer immediately presents that entry's real data with idle fetch status and does not invoke its query function again

#### Scenario: Watched key switches to stale cache with mount refetch disabled
- **WHEN** an already-mounted observer changes to a cached stale key whose `refetchOnMount` is never
- **THEN** the stale value is presented immediately and one background fetch starts because the transition is a key switch rather than a mount

#### Scenario: Watched key switches to fresh cache with mount refetch forced
- **WHEN** an already-mounted observer changes to a cached fresh key whose `refetchOnMount` is always
- **THEN** the fresh value is presented and no fetch starts because the transition is a key switch rather than a mount

#### Scenario: Watched target changes instance but keeps its key
- **WHEN** reactive reevaluation returns a new target instance with the same structural key and stale mount policy
- **THEN** its plan and presentation options update without another mount refetch or resetting `isFetchedAfterMount`

#### Scenario: Same-key target becomes enabled
- **WHEN** an attached same-key target changes from disabled to enabled while data is absent or eligible for activation
- **THEN** activation starts the required shared fetch without treating the target as newly mounted

#### Scenario: Same-key retarget races cache removal notification
- **WHEN** the current entry is synchronously removed and the target updates before its queued removal callback
- **THEN** the observer attaches the fresh cache incarnation without throwing and the stale removal notification cannot detach it

### Requirement: State-derived observer polling
`QueryTarget<T>.withObserver` SHALL accept either a fixed
`pollingInterval` or a typed
`QueryPollingIntervalResolver<T>` receiving the current complete
`QueryObserverResult<T>`; supplying both SHALL fail before observation. A null
resolver result SHALL disable the next poll. The resolver SHALL run untracked
after relevant result transitions and at each eligible tick. Resolver-driven
polling SHALL use one generation-guarded one-shot schedule so interval changes
take effect without overlapping operations, and SHALL continue to honor
resolved enabled state, immutable freshness, explicit polling disable,
focus/background policy, target changes, and observer disposal. External
Signal-driven policy changes SHALL continue to use `watchQuery`; this
requirement SHALL NOT turn arbitrary stale resolvers into inferred timers.

#### Scenario: Polling stops from query state
- **WHEN** a polling resolver returns an interval before data arrives and null after accepted data satisfies its stop condition
- **THEN** the observer performs eligible polls only until that result transition and leaves no later polling handle

#### Scenario: Polling interval changes
- **WHEN** a result transition makes the resolver return a different positive duration
- **THEN** the prior one-shot handle is replaced and the next poll uses the new duration

#### Scenario: Fixed and resolved intervals conflict
- **WHEN** one target supplies both pollingInterval and pollingIntervalResolver
- **THEN** terminal observer configuration rejects the ambiguity

### Requirement: Observer freshness cache aggregation invalidation retention and default merging
The system SHALL support immediate, duration, until-invalidated, immutable, and resolver-based staleness; duration or forever retention; observer-specific refetch policies; structural filters; and global plus key-prefix defaults merged in registration order. Configuration precedence SHALL be built-in, then global defaults, then matching key defaults, then explicit recipe configuration, then terminal observer or call override. Each enabled observer SHALL evaluate freshness using its own resolved stale policy. A disabled observer SHALL report non-stale, SHALL remain attached for observation/retention, and SHALL NOT make an entry active. `QueryCacheSnapshot.isStale` and freshness filters SHALL use TanStack's observer-first aggregate: while any observer is attached, the entry is stale only when at least one current observer result is stale; with no attached observer, absence or invalidation makes it stale. Thus an invalidation marker remains observable without forcing an attached disabled-only or immutable-only query to match stale filters. The cache SHALL NOT use one retained recipe policy as the entry's freshness authority.

Bulk execution SHALL use Query-wide disabled and static eligibility. An
observed entry is disabled when no attached observer is enabled. An unobserved
entry is disabled until it has accepted at least one data or terminal-error
completion; initial-data seeding alone is not fetched. An observed entry is
static when any attached observer uses immutable freshness, regardless of
enabled state. Disabled or static entries SHALL be excluded from bulk refetch.
Consequently one immutable observer blocks bulk refetch for the shared query
even when another enabled observer considers it stale; explicit observer
refetch remains available.

For a predictable duration policy, a fresh observer SHALL schedule a one-shot publication at the fresh-to-stale deadline. Reaching that deadline SHALL recompute and publish observer `isStale` but SHALL NOT itself invoke the query function or change fetch status. A pure observer-freshness transition SHALL publish `QueryCacheEventKind.freshnessChanged` only when aggregate freshness changes. When `added`, `updated`, `invalidated`, `reset`, or `activityChanged` already represents the same transition and carries its final aggregate snapshot, QueryCache SHALL NOT emit an additional `freshnessChanged` event. The observer SHALL replace or cancel its deadline handle when its target, entry data, policy, or lifecycle changes, and generation guards SHALL reject late callbacks. Resolver-based policies SHALL be recalculated on query, target, and environment events without an inferred deadline because an arbitrary resolver has no predictable time boundary. Entries SHALL retain the longest received GC duration. Every newly created inactive entry, including one created by an exact cache write, SHALL immediately receive effective retention and schedule GC. A fresh imperative cache hit SHALL preserve or restore the inactive GC schedule. Applications SHALL register general defaults before later specific defaults. A terminal `pollingEnabled: false` SHALL disable an inherited polling interval.

#### Scenario: Duration-based data is fresh
- **WHEN** data age is below an observer's duration stale policy
- **THEN** stale-based mount, focus, and reconnect triggers do not refetch

#### Scenario: Duration reaches its stale deadline
- **WHEN** a successful observer's duration deadline passes without another trigger
- **THEN** `isStale` publishes false then true while data remains present, fetch status remains idle, and the query function is not invoked

#### Scenario: Observers disagree about freshness
- **WHEN** one attached observer considers an entry fresh and another attached observer considers it stale
- **THEN** QueryCacheSnapshot.isStale is true and stale filters match the entry

#### Scenario: Static and stale observers share an entry
- **WHEN** one attached observer is immutable and another enabled observer considers the same entry stale
- **THEN** aggregate freshness is stale but bulk refetch skips the shared query because any attached immutable observer makes it static

#### Scenario: Cached entry has no observers
- **WHEN** valid present non-invalidated data has no attached observers
- **THEN** cache aggregate freshness is fresh while a future observer still evaluates freshness using its own policy

#### Scenario: Observer deadline changes aggregate freshness
- **WHEN** a duration deadline makes the first attached observer stale
- **THEN** QueryCache publishes the changed aggregate freshness without starting a fetch

#### Scenario: Attachment changes activity and freshness together
- **WHEN** attaching or detaching an observer changes both activity and aggregate freshness
- **THEN** one activityChanged event carries the final aggregate snapshot and no duplicate freshnessChanged event is emitted

#### Scenario: Focus returns after the stale deadline
- **WHEN** duration data becomes stale while unfocused and focus returns with stale-based focus refetch enabled
- **THEN** exactly one background refetch runs, its retained data remains available, and successful replacement data becomes fresh

#### Scenario: Immutable entry is invalidated
- **WHEN** an immutable query is invalidated
- **THEN** invalidation is visible, its attached immutable-only observer and aggregate remain non-stale, and automatic and bulk refetch do not execute it

#### Scenario: Active queries are invalidated by default
- **WHEN** invalidation matches active and inactive entries without an explicit refetch target
- **THEN** all matches are invalidated and only eligible active matches refetch

#### Scenario: Retention policies differ
- **WHEN** observers for one key supply different retention durations
- **THEN** GC uses the longest duration

#### Scenario: Specific default follows general default
- **WHEN** a later registered specific prefix and an earlier general prefix both match
- **THEN** explicitly supplied specific values override general values

#### Scenario: Explicit recipe follows matching defaults
- **WHEN** a matching default and a query recipe both configure stale time, retention, or network mode
- **THEN** the explicit recipe value wins while omitted recipe values inherit the matching default

#### Scenario: Disabled observer remains observed but inactive
- **WHEN** an entry has only an attached observer with enabled false
- **THEN** retention remains attached, active filters do not match, observer and aggregate staleness are false, and automatic or bulk refetch skips it even when data is absent or invalidated

#### Scenario: Never-fetched inactive query is matched
- **WHEN** a disabled observer detaches from a query that has accepted neither data nor terminal error and an inactive/all bulk refetch matches it
- **THEN** the entry is disabled and no query function starts even when an executable plan was retained

#### Scenario: Previously failed inactive query is matched
- **WHEN** an unobserved query has accepted a terminal error and an inactive/all bulk refetch matches it
- **THEN** it is fetched rather than treated as never attempted

#### Scenario: Polling is explicitly disabled
- **WHEN** broad defaults supply an interval and the terminal observer sets `pollingEnabled: false`
- **THEN** no polling timer is scheduled

#### Scenario: Manual cache entry reaches retention
- **WHEN** `setQueryData` creates an inactive entry and its effective finite retention elapses
- **THEN** the entry is removed unless it became observed or acquired active work

### Requirement: Complete client lifecycle operations and deterministic reports
`QueryClient` SHALL provide regular and infinite fetch, prefetch, and ensure operations; exact and filtered cache operations; invalidation, refetch, cancellation, reset, removal, and clear; cache access; and reactive fetching/mutating counts. Imperative fetch and prefetch SHALL join an existing operation by default and MAY explicitly replace a retained-data operation through `cancelRefetch`; observer and bulk refetch SHALL retain their replace-by-default behavior. `invalidateQueries` SHALL expose `cancelRefetch = true`: its refetch phase replaces retained active work by default, joins an absent initial load, and with false joins current work without a serial follow-up request. Query fetching counts SHALL include only `FetchStatus.fetching`, not paused operations. `invalidateQueries`, `refetchQueries`, `cancelQueries`, and `resetQueries` SHALL be asynchronous and return `QueryBatchResult` with integer matched, affected, and skippedNonExecutable plus `IList<QueryBatchFailure>`. Each failure SHALL pair QueryKey with QueryFailure. Matched SHALL be the stable pre-operation match count. Affected SHALL count entries whose requested state transition or asynchronous attempt began, including attempts that failed. A bulk item that is immediately paused behind focus/online eligibility SHALL count as affected but SHALL complete its batch item immediately; its cache-owned operation continues later and its future failure SHALL not become an unhandled asynchronous error or retroactively alter the returned batch. SkippedNonExecutable SHALL count eligible matches that required execution but lacked a retained plan; failures SHALL be the affected non-paused subset whose requested work failed and SHALL follow pre-operation stable match/cache order rather than completion order. `removeQueries` SHALL synchronously return its removed count and `clear()` SHALL return void while leaving the client usable.

#### Scenario: Fresh data is fetched imperatively
- **WHEN** `fetchQuery` finds non-invalidated data fresh under the supplied policy
- **THEN** it returns cached data without executing fetch

#### Scenario: Imperative fetch meets an active background refresh
- **WHEN** `fetchQuery` targets an entry with retained data and an active operation without `cancelRefetch`
- **THEN** it joins the active operation rather than cancelling and restarting transport

#### Scenario: Paused query is counted
- **WHEN** an operation changes from fetching to paused and back
- **THEN** fetching count excludes it while paused and includes it again while transport is fetching

#### Scenario: Prefetch fails
- **WHEN** `prefetchQuery` exhausts retries
- **THEN** failure is committed but the Future does not surface an unhandled caller error

#### Scenario: Imperative fetch omits retry
- **WHEN** fetch, prefetch, or ensure has no explicit recipe or applicable retry override
- **THEN** it performs no retry

#### Scenario: Ensure finds stale data
- **WHEN** ensure enables revalidation and finds stale cached data
- **THEN** it returns cached data immediately and starts a guarded background refetch

#### Scenario: Bulk refetch includes cache-only entry
- **WHEN** one match has no retained executable plan
- **THEN** `QueryBatchResult` counts it as matched and skipped-non-executable without treating it as a failure

#### Scenario: Bulk refetch starts paused work
- **WHEN** an eligible matched operation immediately pauses behind focus or online state
- **THEN** the batch Future completes without waiting for environment recovery while the query operation remains pending and resumes later

#### Scenario: Invalidation replaces retained work by default
- **WHEN** invalidateQueries matches an active retained-data refetch without overriding cancelRefetch
- **THEN** the old refetch is cancelled and one replacement starts immediately

#### Scenario: Invalidation joins an initial load
- **WHEN** invalidateQueries matches an active absent initial load
- **THEN** it joins that load even with the default cancelRefetch and does not schedule a second request after success

#### Scenario: Invalidation replacement is disabled
- **WHEN** invalidateQueries is called with cancelRefetch false while matching work is active
- **THEN** it joins that work and does not schedule a guarded follow-up request

#### Scenario: One bulk operation fails
- **WHEN** one matched asynchronous lifecycle operation fails while others complete
- **THEN** the result reports deterministic affected counts and the per-entry failure

#### Scenario: Client cache is cleared
- **WHEN** `QueryClient.clear()` is called with active queries and mutations
- **THEN** query and mutation cache records are removed, query operations are cancelled and guarded from late commits, and the client remains usable
- **AND** active mutations continue detached from MutationCache under their captured lifecycle policy

### Requirement: Immutable QueryCache terminal lifecycle callbacks
`QueryClient` SHALL accept immutable `QueryCacheCallbacks` containing optional
`onSuccess`, `onError`, and `onSettled` callback policy in addition to mutation
callbacks. Each logical query operation SHALL capture that policy. After a
terminal success or failure is committed and its immutable
`QueryCacheSnapshot` is available, the runtime SHALL invoke success then
settled, or error then settled, exactly once before the operation Future
settles. Settled SHALL receive `QueryValue<Object?>` so absence and
present-null remain distinct. Retryable attempt failures SHALL NOT invoke
terminal callbacks. Manual cache writes, initial-data seeds, streamed partial
commits, cancellation, and superseded losers SHALL NOT independently invoke
them. Callback failures SHALL be delivered to the operation's captured Zone
and SHALL NOT rewrite committed query state, change the operation's transport
result, or repeat another callback.

```dart
typedef QueryCacheOnSuccess = void Function(
  Object? data,
  QueryCacheSnapshot snapshot,
);

typedef QueryCacheOnError = void Function(
  QueryFailure failure,
  QueryCacheSnapshot snapshot,
);

typedef QueryCacheOnSettled = void Function(
  QueryValue<Object?> data,
  QueryFailure? failure,
  QueryCacheSnapshot snapshot,
);

final class QueryCacheCallbacks {
  const QueryCacheCallbacks({
    this.onSuccess,
    this.onError,
    this.onSettled,
  });
}
```

These are synchronous observation hooks. Any returned value is ignored; an
asynchronous callback remains application-owned and does not delay the query
operation Future.

#### Scenario: Query succeeds with present-null
- **WHEN** a nullable query accepts null
- **THEN** onSuccess receives null, onSettled receives present-null, and both receive the post-commit immutable cache snapshot before the fetch Future completes

#### Scenario: Retained-data refetch fails
- **WHEN** a background operation exhausts retry while prior data remains
- **THEN** onError receives the terminal QueryFailure and onSettled receives that failure plus the retained present data exactly once

#### Scenario: Attempt will retry
- **WHEN** a query attempt fails but retry remains eligible
- **THEN** no QueryCache terminal callback runs for that transient attempt

#### Scenario: Query operation is cancelled
- **WHEN** an operation is cancelled, replaced, or loses ownership
- **THEN** no terminal QueryCache callback is attributed to that loser

#### Scenario: Query callback throws
- **WHEN** a QueryCache lifecycle callback throws
- **THEN** the captured Zone receives the callback error while committed cache state and the query Future's transport outcome remain unchanged

### Requirement: retry_plus policy adaptation without export leakage
The system SHALL depend on exact `retry_plus: 0.1.1` behind sealed `RetryPolicy<T>` with covariant `RetryPolicy<Never>` constant markers `none` and `standard` and `RetryPolicy.custom(RetryStrategy<T> Function(RetryBuilder<T>) create)`. `RetryBuilder<T>` SHALL expose typed `exceptions`, `exceptionWhere`, `exceptionType<E>`, `result`, `where`, `any`, `never`, `maxRetries`, and `strategy` helpers. Custom policies SHALL support all 0.1.1 retry predicates, finite or unlimited budget composition, delays, jitter, and awaited hooks. The strategy factory SHALL run once per logical operation and bind to raw query or mutation result type, never selected view type. `jolt_query.dart` SHALL NOT re-export any `retry_plus` symbol; custom-policy users SHALL declare/import `retry_plus` directly, while marker-policy users SHALL not need that import.

#### Scenario: Marker policy preserves inference
- **WHEN** an inline query receives `RetryPolicy.standard` or `RetryPolicy.none`
- **THEN** its fetch result type remains concrete without a generic constructor argument

#### Scenario: Exception-only policy is inferred
- **WHEN** `Query<User>.withRetry` composes builder exception helpers and `maxRetries`
- **THEN** predicates and strategy are typed `User`, not dynamic

#### Scenario: Custom retry symbols are used
- **WHEN** an application constructs `DelayPolicy`, `Jitter`, or another retry_plus value
- **THEN** it declares `retry_plus` directly and imports both packages

#### Scenario: Selected query retries
- **WHEN** `Query<TData>` is selected into `TView`
- **THEN** retry predicates and hooks still receive raw `TData` outcomes

#### Scenario: Unlimited exception retry is configured
- **WHEN** an exception predicate is supplied without a finite budget predicate
- **THEN** retry continues until success, a non-handled outcome, cancellation, detachment policy, or disposal

### Requirement: Jolt-owned manual retry execution boundary
The system SHALL treat `RetryStrategy<T>` as a policy description and SHALL preserve its observable 0.1.1 policy order. After an attempt the adapter SHALL construct `RetryAttemptContext<T>`, await `retryIf.shouldHandle`, and, when accepted, await `onRetry`, await `DelayPolicy.compute` with injected randomness, map null delay to zero, then perform its owned cancellable delay and environment gates before the next attempt. When retry is refused after at least one earlier retry, it SHALL await `onGiveUp` before returning or throwing the final outcome; it SHALL omit onGiveUp when the first attempt was never retried. Predicate, hook, or delay failure SHALL terminate at that stage. The adapter SHALL update failure state and guard operation/incarnation/disposal, and SHALL neither invoke nor accept `RetryPipeline` or an upstream top-level executor. Retry eligibility SHALL be pausable and resumable independently from transport cancellation. Final observer detachment SHALL pause later retries for an otherwise retained active operation, reattachment SHALL resume them, and explicitly requested imperative or inactive/all lifecycle work—including work that joins an observer-started operation—SHALL retain that joined operation independently of observer activity. Every retry continuation SHALL wait for client focus and, except in always mode, online state. It SHALL retain one detached upstream `RetryPipelineContext<T>` identity per logical operation and resynchronize its elapsed view so stateful DelayPolicy implementations preserve per-operation behavior. The authoritative adapted context fields SHALL be outcome, retryIndex, attemptNumber, elapsed, and attemptDuration. Only stable identity and the resynchronized elapsed read SHALL be supported on pipelineContext. Its now, random, sleep, cancelToken, isCancelled, throwIfCancelled, timeout, telemetry, phase, and setPhase executor facilities MAY expose upstream detached defaults or throw and SHALL NOT control Jolt execution; elapsed writes SHALL be overwritten before the next decision. The adapter SHALL preserve the upstream `Object?` outcome erasure of custom/generated delay callbacks while keeping predicates and hooks typed to T.

#### Scenario: Retryable exception occurs
- **WHEN** `shouldHandle` accepts a thrown outcome and budget permits another retry
- **THEN** Jolt updates transient failure state, awaits `onRetry`, awaits delay computation, waits through its owned scheduler and online gate, then starts one new attempt

#### Scenario: First attempt is not retryable
- **WHEN** `shouldHandle` refuses the first attempt outcome
- **THEN** Jolt returns or throws that outcome without invoking onRetry, delay computation, or onGiveUp

#### Scenario: Retry delay is cancelled
- **WHEN** query cancellation or disposal occurs during a non-zero retry delay
- **THEN** the owned timer handle is cancelled immediately and no later attempt starts

#### Scenario: Observer reattaches during retained work
- **WHEN** the final observer detaches without cancelling the active transport and another observer reattaches before the current attempt fails
- **THEN** retry eligibility resumes and the configured later attempt can run

#### Scenario: Inactive lifecycle operation retries
- **WHEN** an explicit inactive or all lifecycle operation fails with a retryable outcome, including after a temporary observer attaches and detaches
- **THEN** its retry continuation and consumed cancellation token remain independent of observer attachment

#### Scenario: Explicit work joins observer-started work
- **WHEN** an imperative fetch or explicit lifecycle operation joins an observer-started operation and the final observer then detaches
- **THEN** the joined operation remains eligible to complete and retry for its explicit caller

#### Scenario: Application loses focus during retry
- **WHEN** a retry becomes ready while the client is unfocused
- **THEN** the next attempt remains paused until focus returns even in always network mode

#### Scenario: Eligibility changes between retry gates
- **WHEN** online state is available while unfocused and becomes offline again before focus returns
- **THEN** an online or offline-first retry remains paused until focus and online state are simultaneously eligible

#### Scenario: Result retry remains eligible
- **WHEN** a result predicate handles final `T` and budget permits another attempt
- **THEN** that intermediate result is not committed and failure count remains reserved for thrown attempts

#### Scenario: Result retry budget is exhausted
- **WHEN** a result predicate handles final `T` but the finite budget refuses another retry
- **THEN** that `T` is accepted and committed as success

#### Scenario: Give-up hook follows eventual success
- **WHEN** 0.1.1 semantics invoke `onGiveUp` after at least one retry followed by a successful result
- **THEN** Jolt awaits the hook before committing that success

#### Scenario: Give-up hook throws after success
- **WHEN** that eventual-success `onGiveUp` hook throws
- **THEN** the operation fails with the hook error and does not commit the successful value

#### Scenario: Executor-only pipeline context is customized
- **WHEN** a custom strategy refers to pipeline-context executor facilities
- **THEN** Jolt's clock, random source, timer scheduler, telemetry behavior, and operation phase remain authoritative and the unsupported facilities are not advertised as execution controls

#### Scenario: Stateful delay spans attempts
- **WHEN** decorrelated jitter or another DelayPolicy keys mutable state by pipeline-context identity
- **THEN** all attempts in one logical operation share one detached upstream context while a separate operation receives a separate context

#### Scenario: Custom delay inspects its outcome
- **WHEN** `DelayPolicy.custom` or `DelayPolicy.generated` receives an attempt
- **THEN** its result is typed `Object?` exactly as in retry_plus 0.1.1 while retry predicates and hooks retain T

### Requirement: Stable environment managers and borrowed deterministic runtime
Each `QueryClient` SHALL create and own stable `FocusManager` and `OnlineManager` instances. Manager objects SHALL not be replaceable. They SHALL support direct state updates and `setEventSource(Stream<bool>?)`, own/cancel the active source subscription, and leave source stream closure to the caller. Event-source completion SHALL preserve the last state and release the subscription; source errors SHALL go to the Zone captured by `setEventSource` without changing state. A public borrowed `QueryRuntime` SHALL have a complete constructor, a system-default factory, a QueryClock with wall and monotonic reads, a QueryTimerScheduler with one-shot and periodic scheduling, a QueryRandomSource producing values in `[0, 1)`, and a QueryNotificationScheduler. QueryClient SHALL use the system factory when no bundle is supplied. Timer and notification scheduling SHALL return `QueryScheduledHandle` with observable cancellation and idempotent `cancel()`. The client SHALL not dispose providers but SHALL own/cancel every handle it creates. A provider MAY deliver an already queued callback after cancellation, so owner-generation checks SHALL make it a no-op. `TimeoutManager` and `NotifyManager` SHALL remain package-private.

#### Scenario: Focus event source changes
- **WHEN** `setEventSource` replaces a manager source
- **THEN** the prior subscription is cancelled, the manager identity is unchanged, and the new source controls state

#### Scenario: External event stream outlives client
- **WHEN** a client is disposed
- **THEN** its manager subscription is cancelled but the caller-owned Stream is not closed

#### Scenario: Environment event source fails or closes
- **WHEN** a manager source emits an error and later closes
- **THEN** the captured Zone receives the error, the last manager state remains, and completion releases only the owned subscription

#### Scenario: Borrowed runtime is shared
- **WHEN** multiple clients use one `QueryRuntime`
- **THEN** disposing one client cancels only its handles and does not dispose or disable the providers

#### Scenario: Online-mode operation begins offline
- **WHEN** online-mode query work becomes eligible while OnlineManager is offline
- **THEN** it remains paused until online unless cancelled

#### Scenario: Offline-first attempt fails offline
- **WHEN** offline-first work performs its first attempt offline and requires a retry
- **THEN** the next attempt waits for online state

#### Scenario: Always-mode observer reconnects
- **WHEN** an always-mode observer did not explicitly enable reconnect refetch
- **THEN** reconnect does not create a separate refetch

#### Scenario: Deterministic runtime test is installed
- **WHEN** fake clock, timer, random, and notification providers are supplied
- **THEN** retry, jitter, staleness, GC, polling, cancellation, and notification order are testable without real waiting

### Requirement: Structural sharing and fine-grained observer notification
The system SHALL reconcile successful data before publication, preserve caller-declared data types, use fast_immutable_collections equality as a fast path, structurally share unchanged JSON-compatible branches, and permit custom reconcilers. A changed typed List or Map SHALL retain a value assignable to the declared raw data type while reusing unchanged nested branches. Field getters SHALL track only their field; `observer.value` SHALL track the complete result. One transition SHALL commit and publish atomically.

#### Scenario: Equal data is refetched
- **WHEN** reconciliation finds identical data or unchanged supported branches
- **THEN** references are preserved and data-only readers are not notified

#### Scenario: Arbitrary domain values compare equal
- **WHEN** two non-JSON domain objects compare equal using overloaded `==`
- **THEN** the default reconciler treats the new object as new unless a custom reconciler says otherwise

#### Scenario: Mutable collection is returned
- **WHEN** a query's declared result type is List or Map
- **THEN** Jolt Query preserves that type and does not silently convert it to an immutable collection

#### Scenario: One branch of a typed collection changes
- **WHEN** a refetch returns a typed List or Map with one changed JSON-compatible branch
- **THEN** the resulting root remains assignable to the declared type and unchanged branch identities are reused

#### Scenario: Only fetch status changes
- **WHEN** a transition changes fetch status without changing data
- **THEN** the fetch-status getter and complete value notify, while the data getter does not

#### Scenario: Multiple fields change
- **WHEN** one reducer transition changes data, status, counters, and fetch status
- **THEN** an imperative observer refetch publishes one locally batched complete result when its Future settles, queued cache listeners later receive the same complete snapshot, and the queued listener refresh produces no duplicate observer publication

### Requirement: Explicit erased multiple-query observation and client-owned cache lifetime
Every query target SHALL implement non-generic `AnyQueryTarget`. Dynamic observation SHALL return `QueriesObserver<IList<ErasedQueryObserverResult>>`, and combined observation SHALL return `QueriesObserver<R>` from a combiner receiving the erased ordered results. No dynamic API SHALL use a raw generic or `dynamic`. Static heterogeneous composition SHALL use individual typed observers and Dart records. `QueryCache` SHALL expose immutable erased `IList<QueryCacheSnapshot>` state, a broadcast `Stream<QueryCacheEvent>`, and query-cache-only `clear()`. Query-cache clear SHALL remove entries in stable cache order, signal cancellation of their active query operations, immediately guard late results, rotate every known checkpoint lineage, and emit removal events while leaving MutationCache, active mutations, QueryObservers, the owning client, and both cache event streams alive. On removal notification, a live QueryObserver SHALL reattach its target to a fresh entry incarnation; ordinary enabled and activation policies SHALL decide whether it fetches, so observed queries MAY repopulate cache after clear. `QueryCache` SHALL NOT implement `Disposable` or terminate its owning QueryClient. Only QueryClient disposal SHALL stop all owned work and close the cache event stream. Because IList appears in public signatures, `jolt_query.dart` SHALL re-export only IList from fast_immutable_collections while keeping other FIC implementation types private unless another public contract adopts them.

#### Scenario: Dynamic targets change
- **WHEN** a watched target iterable adds, removes, or reorders targets
- **THEN** observer attachments update, result order follows input order, and removed observers are disposed

#### Scenario: Dynamic targets replace instances with equal keys
- **WHEN** reevaluation supplies new target objects with the same client, keys, and repeated-key order
- **THEN** existing child observers update in place without applying mount policy or resetting mount-relative result state

#### Scenario: Dynamic list repeats a key
- **WHEN** multiple positions use the same structural key
- **THEN** they share one entry while retaining independent observer presentation

#### Scenario: Combined observation runs
- **WHEN** any erased child result changes
- **THEN** the combiner receives an ordered immutable erased list and publishes exactly typed `R`

#### Scenario: Cache state changes
- **WHEN** an entry is added, updated, invalidated, reset, removed, changes activity, or changes aggregate freshness
- **THEN** a read-only event is emitted after complete state commit without exposing `QueryEntry`

#### Scenario: Cache is cleared then reused
- **WHEN** clear removes entries and a later query executes
- **THEN** existing event listeners receive both lifecycles because clear did not close the broadcast stream

#### Scenario: Query cache is cleared during active work
- **WHEN** QueryCache.clear is called with active queries and mutations
- **THEN** query entries are removed, query operations are cancelled, and their late results cannot commit
- **AND** active mutations, MutationCache, QueryClient, and both cache event streams remain alive

#### Scenario: Query cache is cleared with an attached observer
- **WHEN** clear removes the entry targeted by a live QueryObserver
- **THEN** the observer remains alive, reattaches to a fresh incarnation, and may recreate or refetch the entry under its ordinary policies

#### Scenario: Client disposal closes cache observation
- **WHEN** the owning QueryClient is disposed
- **THEN** owned work stops and the QueryCache broadcast event stream closes

### Requirement: Explicit QueryClient lifecycle and stale-callback safety
`QueryClient` SHALL implement idempotent `Disposable` and own its caches, environment managers, observers, operations, source subscriptions, and created timer handles. Disposal SHALL close the new-work acceptance gate before it triggers any user cancellation-token listener, then release owned work. Work reentrantly requested by such a listener SHALL fail deterministically as disposed rather than escaping the disposal snapshot. The client SHALL reject later active operations and use generations so stale callbacks are harmless. Borrowed runtime providers and caller-owned event streams SHALL not be disposed.

#### Scenario: Client is disposed during work
- **WHEN** disposal occurs with active fetches, retry waits, polling, and GC timers
- **THEN** owned handles are cancelled and later transport or timer callbacks cannot mutate client state

#### Scenario: Disposed client is used
- **WHEN** a caller invokes an operation requiring an active client after disposal
- **THEN** it receives the documented disposed-client failure

#### Scenario: Disposal listener requests new work
- **WHEN** disposal cancels an operation whose token listener synchronously calls fetch
- **THEN** that reentrant fetch receives QueryClientDisposedException and cannot create work outside the disposal snapshot

#### Scenario: Stale timer fires
- **WHEN** a cancelled GC, polling, retry, or notification callback is delivered late
- **THEN** its generation guard makes it a no-op
