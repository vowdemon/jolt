## 0.1.0-dev.1

- Initial development release.
- Added the Jolt Query package surface for class-first and inline
  queries, selected views, observers, typed exact/bulk cache operations,
  infinite queries, and stream-backed query functions.
- Added structural query keys, single-flight fetching, stale and retention
  policies, polling, focus/online triggers, deterministic runtime providers,
  typed retry adaptation, explicit cancellation, and immutable cache events.
- Unified writes under `Mutation<V, D, R>` and `action<D, R>`; optimistic cache
  updates are optional user-composed `onMutate` behavior, not a mutation type.
- Added immutable constructor-time `MutationCacheCallbacks`, typed
  `onMutateResult` presence, FIFO mutation scopes, and client-owned mutation
  retention.
- Made QueryCache and MutationCache non-disposable cache-local views with
  independent `clear()` operations; only QueryClient disposal is terminal.
- Made query checkpoints data-only and cache writes non-cancelling. Callers can
  explicitly await query cancellation before a write that must remain
  authoritative.
- Defined retry behavior per stream mode: reset restores configured reset state
  for each fetched attempt, append rebuilds from one logical baseline without
  publishing it at retry start, and replace keeps failed accumulators private.
  Manual writes remain non-cancelling but can be replaced by a later reset or
  accepted stream output.
- Custom retry policies require an application-owned direct
  `retry_plus: 0.1.1` dependency/import; Jolt Query does not re-export
  retry_plus.
- Added a runnable Flutter Web lab for query-key switching, stale deadlines,
  visible refetch triggers, non-cancelling writes, explicit cancel-before-write,
  unified mutations, infinite queries, and streamed modes.
- Added lazy `QueryClient.defaultClient` configuration, optional ordinary and
  infinite query client bindings, and binding preservation across staged
  transformations without premature default resolution.
- Added provider-free `QueryWidget<T>` directly to `jolt_query`; it owns
  observer lifecycle and preserves same-key updates without a second package.
- Added provider-free `InfiniteQueryWidget<T>` and
  `MutationWidget<V, D, R>`, state-derived polling, resolved `isEnabled`
  results, and same-key mutation recipe retargeting.
- Aligned query-wide fetched/disabled/static aggregation, invalidation
  replacement, cancellation rollback baselines, infinite observer lifecycle,
  mutation terminal visibility, and streamed reset attempts with TanStack
  Query v5 semantics.
- Mutation observers now expose terminal state before per-call callbacks and
  returned Futures settle; streamed reset retries restore configured reset
  state at each fetched attempt.
- Added immutable post-commit `QueryCacheCallbacks` without turning callback
  failures into query failures; callbacks run before the operation Future
  settles and ignore retry attempts, partials, manual writes, and cancellation.
- Persistence, hydration, DevTools, and cross-process recovery are not included
  in this release.
