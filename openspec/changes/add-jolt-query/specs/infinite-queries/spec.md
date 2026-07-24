## ADDED Requirements

### Requirement: Class-first infinite recipe page context and aligned data
The system SHALL define `InfiniteQuery<Page, PageParam>` as an externally subclassable query recipe and provide an inference-friendly `infiniteQuery(...)` factory over the same runtime. A page recipe SHALL expose `FutureOr<Page> fetchPage(InfinitePageContext<PageParam>)`, `PageCursor<PageParam> getNextPageParam(InfiniteData<Page, PageParam>)`, and `PageCursor<PageParam> getPreviousPageParam(InfiniteData<Page, PageParam>)`. The previous method SHALL have a concrete `PageCursor.end` default and the inline factory's previous-resolver argument SHALL be optional. Class-first retry, stale, retention, and network policy getters SHALL be non-virtual views of values supplied through the base constructor, including explicit built-in values. `InfinitePageContext` SHALL contain the current page parameter, direction, QueryContext capabilities, and cancellation token. `InfiniteData<Page, PageParam>` SHALL defensively convert Iterable inputs into aligned `IList` pages and pageParams and reject unequal lengths.

#### Scenario: Reusable infinite class binds types once
- **WHEN** an external class subclasses `InfiniteQuery<Page, PageParam>`
- **THEN** observers and client operations infer Page and PageParam without casts, raw types, or dynamic

#### Scenario: Inline infinite recipe infers types
- **WHEN** `infiniteQuery(...)` receives typed page and cursor functions
- **THEN** it returns the same `InfiniteQuery<Page, PageParam>` runtime model

#### Scenario: Initial page succeeds
- **WHEN** the first page is fetched with the configured initial page parameter
- **THEN** committed InfiniteData contains that Page and exact PageParam at corresponding index zero

#### Scenario: Source collections mutate later
- **WHEN** Lists passed to InfiniteData are changed after construction
- **THEN** stored IList values remain unchanged

#### Scenario: Page and parameter counts differ
- **WHEN** construction or a cache write supplies unequal lengths
- **THEN** validation rejects the value before observer publication

### Requirement: Explicit nullable-safe page cursors
Pagination termination SHALL use exhaustive `PageCursor<P>` variants. The static `PageCursor.end` marker SHALL have type `PageCursor<Never>` and be assignable wherever `PageCursor<P>` is expected. `PageCursor.more(P)` SHALL treat its argument as present even when P is nullable. Null SHALL NOT be an end sentinel.

#### Scenario: Nullable cursor continues with null
- **WHEN** a resolver returns `PageCursor.more(null)` for nullable PageParam
- **THEN** the observer reports the direction available and passes null as the next page parameter

#### Scenario: Resolver returns end marker
- **WHEN** a resolver returns `PageCursor.end`
- **THEN** the corresponding availability flag becomes false

#### Scenario: End marker is returned without type argument
- **WHEN** a resolver with return type `PageCursor<String?>` returns the constant end marker
- **THEN** strict inference accepts its `PageCursor<Never>` covariance without a cast

### Requirement: Specialized staged infinite targets
The public transformation chain SHALL be `InfiniteQuery<Page, PageParam>` to `InfiniteQueryView<TView>` to terminal `InfiniteQueryTarget<TView>`. `withRetry` SHALL preserve `InfiniteQuery<Page, PageParam>`. Raw `withInitialData(InfiniteData<Page, PageParam>, {DateTime? updatedAt})` SHALL return `InfiniteQueryView<InfiniteData<Page, PageParam>>`. `select<TNext>` SHALL preserve `InfiniteQueryView<TNext>`. Observer and placeholder configuration SHALL return `InfiniteQueryTarget<TView>`. Every specialized stage SHALL retain directional capability internally. InfiniteQuery, InfiniteQueryView, and InfiniteQueryTarget SHALL each be directly observable using defaults appropriate to its current stage, and selection SHALL not be available after terminal configuration.

#### Scenario: Infinite query is selected
- **WHEN** InfiniteData is selected into an application view model
- **THEN** the result remains `InfiniteQueryView<ViewModel>` with direction capability and no Page or PageParam generic at the observer call site

#### Scenario: Observer configuration follows selection
- **WHEN** a selected infinite view applies placeholder or observer options
- **THEN** the resulting target preserves the selected ViewModel presentation and directional behavior

#### Scenario: Infinite query is observed directly
- **WHEN** `observeInfiniteQuery` receives the original InfiniteQuery
- **THEN** it returns `InfiniteQueryObserver<InfiniteData<Page, PageParam>>`

### Requirement: Whole-data retry typing and page validation
Infinite retry SHALL use `RetryPolicy<InfiniteData<Page, PageParam>>`, not `RetryPolicy<Page>`. Result predicates and hooks SHALL receive only complete operation results. Successful page progress SHALL survive exception retries inside one complete-data attempt so only the failed page is retried. A result predicate that rejects an assembled InfiniteData SHALL start a new complete-data attempt. A page-specific response that should retry SHALL throw from `fetchPage`; the runtime SHALL not expose a second page-result retry policy.

#### Scenario: Infinite custom retry is inferred
- **WHEN** `withRetry` is called after Page and PageParam inference
- **THEN** `RetryBuilder` and RetryStrategy are typed to `InfiniteData<Page, PageParam>`

#### Scenario: Page response is invalid
- **WHEN** application page validation fails inside `fetchPage`
- **THEN** the thrown failure enters the ordinary exception retry policy and a retry resumes at that page without replaying earlier successful pages

#### Scenario: Whole result predicate requests retry
- **WHEN** a completed InfiniteData result satisfies a result predicate
- **THEN** retry evaluates that complete value and never an individual Page

### Requirement: Selected directional observer results
`observeInfiniteQuery` and `watchInfiniteQuery` SHALL return `InfiniteQueryObserver<TView>` implementing `Readable<InfiniteQueryObserverResult<TView>>`. `fetchNextPage({bool cancelRefetch = true})` and `fetchPreviousPage({bool cancelRefetch = true})` SHALL return `Future<InfiniteQueryObserverResult<TView>>`. When cache data is absent, either method SHALL start the ordinary initial-page operation with `initialPageParam` without invoking a direction resolver, while preserving the requested direction in fetching/error presentation. Only a present InfiniteData whose corresponding resolver returns `PageCursor.end` SHALL make the direction call a current-result no-op. The result SHALL expose selected `QueryValue<TView>`, availability and directional fetching/error flags, resolved enabled state, and one canonical `QueryFailure?`; it SHALL NOT expose separate directional error objects or leak Page and PageParam after selection. A directional error SHALL be mutually exclusive with whole-window `isRefetchError`.

#### Scenario: Next page starts on selected observer
- **WHEN** a selected observer fetches an available next page
- **THEN** `isFetchingNextPage` and ordinary fetching become true while selected TView data remains visible

#### Scenario: Previous page fails
- **WHEN** previous-page fetch exhausts retry
- **THEN** the previous-direction error flag is true, isRefetchError is false, the one canonical failure identifies the error, and prior selected data remains present

#### Scenario: Present data has no next cursor
- **WHEN** `fetchNextPage` is called with present InfiniteData whose next resolver returns PageCursor.end
- **THEN** it returns the current `InfiniteQueryObserverResult<TView>` without starting an operation or changing cache

#### Scenario: Next page is requested before initial data
- **WHEN** `fetchNextPage` is called while cache data is absent
- **THEN** it fetches initialPageParam once, reports next-direction fetching during that work, and commits the initial InfiniteData

#### Scenario: Previous page is requested before initial data
- **WHEN** `fetchPreviousPage` is called while cache data is absent
- **THEN** it fetches initialPageParam once without invoking the previous resolver and retains previous-direction presentation metadata

#### Scenario: Initial direction request fails
- **WHEN** an absent next-page request fails its initial transport
- **THEN** loading-error and next-direction-error are true while isRefetchError is false

#### Scenario: Direction call completes
- **WHEN** a next-page call succeeds after selection
- **THEN** its Future resolves to the new selected observer result rather than raw Page or InfiniteData

### Requirement: Infinite observer retargeting follows query observer semantics
An `InfiniteQueryObserver` SHALL retain its logical observer across target
updates and SHALL delegate ordinary mount, enabled activation, key switching,
focus, reconnect, stale-deadline, polling, attachment, and disposal behavior to
one composed QueryObserver lifecycle. A package-private whole-window fetch
delegate MAY specialize the operation behavior, but the infinite layer SHALL
not maintain a second independent lifecycle state machine. A same-client,
same-key target update SHALL replace configuration and presentation without
detaching, applying mount policy again, or resetting the current query's mount
baseline. When the ordinary result identity and every directional flag remain
unchanged, the complete infinite result SHALL retain its identity and publish
no observer notification. A different-key update SHALL attach the new entry
through the same observer, preserve observer-local previous-view placeholder
input, and reset fetched-after-mount relative to the new query. For the
already-mounted key switch, an enabled stale or absent entry SHALL fetch and a
fresh entry SHALL not fetch regardless of `refetchOnMount`. Environment events
SHALL recompute resolver-based freshness even when their refetch policies
decline transport.

#### Scenario: Same-key infinite target is rebuilt
- **WHEN** a parent supplies a new infinite target instance with the same client and structural key
- **THEN** configuration updates in place without mount refetch, mount-baseline reset, or a result notification when no observable field changed

#### Scenario: Disabled immutable infinite target becomes enabled while absent
- **WHEN** a same-key target changes from disabled to enabled while its cache is absent and its stale policy is immutable
- **THEN** it starts the required initial fetch because immutable suppresses refetch of present data, not initial loading

#### Scenario: Infinite key switches to stale cache
- **WHEN** an already-mounted observer switches to enabled stale data while refetchOnMount is never
- **THEN** it presents the retained value and starts one background refresh

#### Scenario: Infinite key switches to fresh cache
- **WHEN** an already-mounted observer switches to fresh data while refetchOnMount is always
- **THEN** it presents the fresh value without starting transport

#### Scenario: Infinite key switch uses previous presentation
- **WHEN** a switched-to key has no selected data and the placeholder resolver accepts the previous presentation
- **THEN** that value remains observer-local until the new key produces data

#### Scenario: Infinite resolver freshness changes on an environment event
- **WHEN** a resolver-backed stale policy changes and focus or online state emits while refetch policy is never
- **THEN** the observer and aggregate cache freshness update without transport

#### Scenario: Infinite polling uses ordinary lifecycle
- **WHEN** an infinite observer receives fixed or state-derived polling configuration
- **THEN** ordinary observer eligibility, focus policy, no-overlap, retargeting, and disposal rules schedule its whole-window refresh

### Requirement: One guarded operation lane per infinite entry
Initial fetch, full refresh, next-page fetch, and previous-page fetch SHALL share one QueryEntry operation lane. Direction calls SHALL default `cancelRefetch` to true. A replacement SHALL use normal cancellation and operation/incarnation guards. Every sequential page boundary SHALL recheck operation identity, entry incarnation, replacement, cancellation, and client disposal after each user cursor resolver returns, immediately before starting the next page transport, and before accepting its result. With `cancelRefetch: false`, a compatible duplicate SHALL join or return the active result without appending duplicate data. The entry SHALL retain its reusable full-window lifecycle plan while an operation-specific initial, refresh, next, or previous plan is executing; bulk invalidation, refetch, and reset SHALL never capture a transient direction plan.

#### Scenario: Repeated next-page call replaces
- **WHEN** next-page fetch is requested again with default settings while direction work is active
- **THEN** a new invocation supersedes the old one and only the new operation may commit

#### Scenario: Repeated next-page call does not replace
- **WHEN** the repeated call sets `cancelRefetch: false`
- **THEN** it joins or awaits the active invocation and no duplicate page is appended

#### Scenario: Full refresh overlaps direction work
- **WHEN** refresh begins during a page fetch
- **THEN** the caller's cancellation setting determines replacement or joining and only one guarded result commits

#### Scenario: Final observer detaches
- **WHEN** the final infinite observer is disposed during work
- **THEN** ordinary shared-query detachment rules apply and late completion cannot corrupt a recreated entry

#### Scenario: Infinite chain is cancelled between pages
- **WHEN** cancellation, replacement, or client disposal occurs after one page completes but before the next page starts
- **THEN** no later page transport starts and no late chain result can commit

#### Scenario: Cursor resolver cancels the operation
- **WHEN** a next- or previous-page cursor resolver synchronously cancels, replaces, removes, or disposes the current operation
- **THEN** the guard observes that change after the resolver returns and no resolved page transport starts

#### Scenario: Invalidation replaces a direction operation
- **WHEN** active invalidation with default cancelRefetch overlaps an in-flight next- or previous-page operation
- **THEN** it cancels that transient direction plan and starts one full refresh from the retained lifecycle plan

#### Scenario: Invalidation joins a direction operation
- **WHEN** active invalidation with cancelRefetch false overlaps an in-flight next- or previous-page operation
- **THEN** it joins that operation without repeating the direction or scheduling a hidden full-refresh follow-up

### Requirement: Sequential atomic full refresh
A refresh of retained infinite data SHALL begin at the first retained page parameter, falling back to the configured initial parameter only when no retained page exists. It SHALL recompute each subsequent cursor from newly fetched data, fetch sequentially, keep prior committed data visible, and atomically commit only after the complete reachable retained page set succeeds.

#### Scenario: Multi-page refresh succeeds
- **WHEN** all recomputed retained pages succeed
- **THEN** observers keep old data during work and then receive one complete aligned replacement

#### Scenario: Later refreshed page fails
- **WHEN** an earlier page succeeds but a later page exhausts retry
- **THEN** no partial refresh is committed and old InfiniteData remains with a refetch failure

#### Scenario: New cursor ends earlier
- **WHEN** recomputed pagination reaches PageCursor.end before the old retained count
- **THEN** refresh stops and atomically commits only the newly reachable pages

#### Scenario: Bounded window refreshes from its retained head
- **WHEN** maxPages has trimmed the original initial page and refresh begins
- **THEN** the first retained page parameter is fetched first and the current window is rebuilt instead of resetting to the original window

### Requirement: Bounded bidirectional page retention
Infinite queries SHALL support optional positive `maxPages`. A successful next-page addition exceeding the bound SHALL trim the leading page and parameter; a previous-page addition SHALL trim the trailing pair. Direction availability SHALL be resolver-defined: omitting the optional previous resolver declares a forward-only query even when bounded, while providing it makes both cursor resolvers available by construction. Trimming SHALL never misalign pages from parameters.

#### Scenario: Next addition exceeds maximum
- **WHEN** a successful next page would exceed maxPages
- **THEN** the oldest leading Page and PageParam are removed together

#### Scenario: Previous addition exceeds maximum
- **WHEN** a successful previous page would exceed maxPages
- **THEN** the newest trailing Page and PageParam are removed together

#### Scenario: Maximum is not positive
- **WHEN** maxPages is zero or negative
- **THEN** recipe validation fails before fetching

#### Scenario: Bounded forward-only query omits reverse resolver
- **WHEN** a bounded query omits the optional previous-page resolver
- **THEN** the recipe remains valid and forward-only, reports no previous page, and a previous-page request is a cache no-op

### Requirement: Typed infinite client operations
`QueryClient.fetchInfiniteQuery` and `ensureInfiniteQueryData` SHALL accept `InfiniteQuery<Page, PageParam>` and return `Future<InfiniteData<Page, PageParam>>`. Fetch SHALL accept positive `{int? pages}` and `{bool cancelRefetch = false}`: omitted pages requests one page for absent data and preserves the retained page count during refresh. `prefetchInfiniteQuery` SHALL return `Future<void>`, accept positive `{int pages = 1}` plus the same replacement option, reject non-positive counts, and use no retry unless explicitly configured. Imperative fetch and prefetch SHALL join active work unless replacement is explicitly requested. Raw `InfiniteQuery<Page, PageParam>` SHALL implement `QueryDataTarget<InfiniteData<Page, PageParam>>`, so all inherited exact cache reads, writes, snapshots, updates, and restores remain typed without exposing an ordinary fetch bridge. Filters, invalidation, cancellation, reset, removal, GC, and structural sharing SHALL use the ordinary entry model. Every fresh imperative cache hit SHALL still merge effective retention into the entry and reschedule GC so the longest received retention remains authoritative.

#### Scenario: Infinite imperative fetch meets active refresh
- **WHEN** `fetchInfiniteQuery` targets retained data with an active refresh and cancelRefetch is false
- **THEN** it joins the current whole-data operation rather than replacing it

#### Scenario: Raw infinite query uses exact cache APIs
- **WHEN** a raw InfiniteQuery is passed to each inherited exact cache operation
- **THEN** each operation reads or writes the complete aligned InfiniteData value for that recipe

#### Scenario: Infinite prefetch omits page count
- **WHEN** prefetch is called without `pages`
- **THEN** it requests only the initial page and resolves void

#### Scenario: Infinite prefetch requests several pages
- **WHEN** a positive pages count is supplied and cursors remain available
- **THEN** it fetches up to that count sequentially and stores one aligned InfiniteData value

#### Scenario: Infinite ensure finds stale data
- **WHEN** ensure permits revalidation and stale pages exist
- **THEN** it returns cached InfiniteData immediately and starts guarded sequential refresh

#### Scenario: Fresh infinite hit receives longer retention
- **WHEN** a fresh inactive entry is reused through a recipe or call with longer retention
- **THEN** its GC deadline is rescheduled using the longer received retention

#### Scenario: Invalid page count is supplied
- **WHEN** prefetch pages is zero or negative
- **THEN** validation fails without starting a page fetch
