import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    show IList;
import 'package:jolt/jolt.dart' show Readable, Signal, untracked;
import 'package:meta/meta.dart' show internal;
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../foundation/environment_manager.dart';
import '../foundation/notification_orchestrator.dart';
import '../foundation/query_cancellation.dart';
import '../foundation/query_failure.dart';
import '../foundation/query_runtime.dart';
import '../foundation/query_value.dart';
import '../foundation/timer_orchestrator.dart';
import '../keys/query_key.dart';
import '../mutation/models.dart';
import '../retry/retry_policy.dart';
import 'batch_result.dart';
import 'cache.dart';
import 'cache_models.dart';
import 'filters.dart';
import 'policies.dart';
import 'recipe.dart';
import 'reconciliation.dart';
import 'state.dart';

/// Failure raised when active work is requested from a disposed client.
final class QueryClientDisposedException implements Exception {
  /// Creates the disposed-client failure.
  const QueryClientDisposedException();

  @override
  String toString() => 'QueryClientDisposedException: QueryClient is disposed.';
}

/// Owns query and mutation state, operations, observers, and environment gates.
///
/// Runtime providers are borrowed. The client cancels only handles it creates.
final class QueryClient implements Disposable {
  /// Returns the isolate-wide client used by queries without an explicit
  /// client binding.
  ///
  /// The first read locks the default binding for the rest of the isolate.
  /// When no client was configured, the first read lazily creates one.
  static QueryClient get defaultClient {
    _defaultClientWasRead = true;
    return _defaultClient ??= QueryClient();
  }

  /// Configures the isolate-wide client before [defaultClient] is first read.
  ///
  /// The default cannot be replaced after queries have started resolving it,
  /// because mounted observers and later queries would otherwise silently use
  /// different cache owners.
  static void setDefault(QueryClient client) {
    if (_defaultClientWasRead) {
      throw StateError(
        'The default QueryClient has already been resolved and cannot be '
        'replaced.',
      );
    }
    if (client.isDisposed) {
      throw ArgumentError.value(
        client,
        'client',
        'The default QueryClient must be active.',
      );
    }
    _defaultClient = client;
  }

  static QueryClient? _defaultClient;
  static bool _defaultClientWasRead = false;

  /// Creates an active client with stable focus and online managers.
  QueryClient({
    QueryRuntime? runtime,
    QueryCacheCallbacks queryCallbacks = const QueryCacheCallbacks(),
    MutationCacheCallbacks mutationCallbacks = const MutationCacheCallbacks(),
  })  : runtime = runtime ?? QueryRuntime.system(),
        queryCallbacksInternal = queryCallbacks,
        mutationCallbacksInternal = mutationCallbacks {
    timersInternal = TimerOrchestrator(this.runtime.timers);
    notificationsInternal =
        NotificationOrchestrator(this.runtime.notifications);
    focusManager = FocusManager();
    onlineManager = OnlineManager();
    _fetchingCountInternal = Signal<int>(0);
    queryCacheControllerInternal = QueryCacheControllerInternal(
      notifications: notificationsInternal,
      clearOwnerCache: _clearQueryCacheInternal,
      onCommittedEvent: _refreshFetchingCountInternal,
    );
  }

  /// Borrowed deterministic runtime capabilities.
  final QueryRuntime runtime;

  /// Immutable global query callbacks captured by every operation.
  @internal
  final QueryCacheCallbacks queryCallbacksInternal;

  /// Immutable global mutation callbacks captured by every submission.
  @internal
  final MutationCacheCallbacks mutationCallbacksInternal;

  /// Stable focus manager owned by this client.
  late final FocusManager focusManager;

  /// Stable online manager owned by this client.
  late final OnlineManager onlineManager;

  /// Package-internal timer ownership boundary.
  @internal
  late final TimerOrchestrator timersInternal;

  /// Package-internal outward notification boundary.
  @internal
  late final NotificationOrchestrator notificationsInternal;

  /// Package-internal mutable query-cache controller.
  @internal
  late final QueryCacheControllerInternal queryCacheControllerInternal;

  late final Signal<int> _fetchingCountInternal;

  /// Public read-only query cache.
  QueryCache get queryCache => queryCacheControllerInternal.public;

  /// Reactive count of query entries whose transport is currently fetching.
  Readable<int> get fetchingCount => _fetchingCountInternal;

  /// Synchronously counts matching active query operations.
  int countFetching({QueryFilter filter = const QueryFilter()}) {
    checkActiveInternal();
    return _matchingQueryEntries(filter)
        .where((entry) => entry.fetchStatus == FetchStatus.fetching)
        .length;
  }

  final Set<Disposable> _ownedDisposables = <Disposable>{};
  final Set<QueryCancellationController> _ownedCancellations =
      <QueryCancellationController>{};
  final Set<_ClientQueryOperation> _awaitingQueryCancellationCleanup =
      <_ClientQueryOperation>{};
  final Set<void Function()> _ownedCacheClearers = <void Function()>{};
  final List<_QueryDefaultsRegistration> _queryDefaults =
      <_QueryDefaultsRegistration>[];
  int _generation = 0;
  bool _isDisposed = false;

  /// Whether this client has been disposed.
  bool get isDisposed => _isDisposed;

  /// Package-internal generation used to reject stale completions.
  @internal
  int get generationInternal => _generation;

  /// Registers global or structural-prefix query defaults.
  ///
  /// Registrations merge in call order. Register broad defaults before later
  /// specific prefixes. Passing no [key] registers global defaults.
  void registerQueryDefaults(
    QueryDefaults defaults, {
    QueryKey? key,
  }) {
    checkActiveInternal();
    const QueryDefaults().merge(defaults);
    _queryDefaults.add(_QueryDefaultsRegistration(key, defaults));
  }

  /// Removes all query-default registrations without changing cache state.
  void clearQueryDefaults() {
    checkActiveInternal();
    _queryDefaults.clear();
  }

  /// Resolves type-independent defaults for [key] in registration order.
  QueryDefaults getQueryDefaults(QueryKey key) {
    checkActiveInternal();
    return resolveQueryDefaultsInternal(key);
  }

  /// Package-internal default resolution that does not recheck disposal.
  @internal
  QueryDefaults resolveQueryDefaultsInternal(QueryKey key) {
    var resolved = const QueryDefaults();
    for (final registration in _queryDefaults) {
      final prefix = registration.key;
      if (prefix == null || key.startsWith(prefix)) {
        resolved = resolved.merge(registration.defaults);
      }
    }
    return resolved;
  }

  /// Resolves concrete settings for one typed observer target.
  @internal
  ResolvedObserverSettings<T> resolveQueryObserverSettingsInternal<T>(
    ResolvedQueryTarget<T> target,
  ) {
    final defaults = resolveQueryDefaultsInternal(target.plan.key);
    final networkMode = _effectiveNetworkMode(target.plan, defaults);
    final base = ResolvedObserverSettings<T>(
      enabled: defaults.enabled ?? true,
      staleTime: target.plan.hasExplicitStalePolicy
          ? target.plan.stalePolicy
          : defaults.staleTime ?? target.plan.stalePolicy,
      refetchOnMount: defaults.refetchOnMount ?? RefetchPolicy.stale,
      refetchOnFocus: defaults.refetchOnFocus ?? RefetchPolicy.stale,
      refetchOnReconnect: defaults.refetchOnReconnect ??
          (networkMode == NetworkMode.always
              ? RefetchPolicy.never
              : RefetchPolicy.stale),
      retryOnMount: defaults.retryOnMount ?? true,
      pollingInterval: defaults.pollingInterval,
      pollingEnabled: defaults.pollingEnabled,
      pollInBackground: defaults.pollInBackground ?? false,
    );
    return base.merge(target.observer);
  }

  /// Throws when the client is no longer active.
  @internal
  void checkActiveInternal() {
    if (_isDisposed || queryCacheControllerInternal.isDisposed) {
      throw const QueryClientDisposedException();
    }
  }

  /// Registers a client-created disposable and returns it unchanged.
  @internal
  T ownDisposableInternal<T extends Disposable>(T disposable) {
    checkActiveInternal();
    _ownedDisposables.add(disposable);
    return disposable;
  }

  /// Detaches an already disposed client-created value.
  @internal
  void releaseDisposableInternal(Disposable disposable) {
    _ownedDisposables.remove(disposable);
  }

  /// Registers an active operation cancellation controller.
  @internal
  QueryCancellationController ownCancellationInternal() {
    checkActiveInternal();
    final controller = QueryCancellationController();
    _ownedCancellations.add(controller);
    return controller;
  }

  /// Releases an operation cancellation controller after settlement.
  @internal
  void releaseCancellationInternal(QueryCancellationController controller) {
    _ownedCancellations.remove(controller);
  }

  /// Registers an owned cache partition to participate in [clear].
  @internal
  void registerCacheClearerInternal(void Function() clear) {
    checkActiveInternal();
    _ownedCacheClearers.add(clear);
  }

  /// Removes a cache partition's [clear] callback during its disposal.
  @internal
  void releaseCacheClearerInternal(void Function() clear) {
    _ownedCacheClearers.remove(clear);
  }

  /// Attaches an observer to a stable structural-key entry.
  @internal
  QueryEntryInternal attachQueryObserverInternal(
    ResolvedQueryTargetBase target,
    QueryEntryListenerInternal listener,
  ) {
    checkActiveInternal();
    final existing = queryCacheControllerInternal.lookup(target.plan.key);
    final wasObserved = existing?.isObserved ?? false;
    final entry = queryCacheControllerInternal.getOrCreate(
      target.plan.key,
      initialListener: listener,
      initialize: (created) {
        _applyResolvedTargetToEntry(created, target, publish: false);
      },
    );
    if (existing != null) {
      _applyResolvedTargetToEntry(entry, target, publish: false);
    }
    _cancelGc(entry);
    if (!wasObserved && entry.isObserved) {
      final operation = entry.operation;
      if (operation != null && operation.dependsOnObserverActivity) {
        operation.resumeRetries();
      }
    }
    if (existing != null) {
      queryCacheControllerInternal.publish(
        entry,
        QueryCacheEventKind.activityChanged,
      );
    }
    return entry;
  }

  /// Retargets an attached observer without an inactive attachment gap.
  ///
  /// Returns false when cache removal already detached [entry] but its queued
  /// removal notification has not reached the observer yet.
  @internal
  bool updateQueryObserverTargetInternal(
    QueryEntryInternal entry,
    ResolvedQueryTargetBase target,
  ) {
    checkActiveInternal();
    if (entry.key != target.plan.key) {
      throw StateError('The observer entry key no longer matches its target.');
    }
    if (!queryCacheControllerInternal.containsEntry(entry)) {
      return false;
    }
    final changed = _applyResolvedTargetToEntry(entry, target, publish: false);
    if (changed) {
      queryCacheControllerInternal.publish(entry, QueryCacheEventKind.updated);
    }
    return true;
  }

  /// Detaches an observer and applies final-observer retry and GC rules.
  @internal
  void detachQueryObserverInternal(
    QueryEntryInternal entry,
    QueryEntryListenerInternal listener,
  ) {
    if (_isDisposed || !queryCacheControllerInternal.containsEntry(entry)) {
      entry.listeners.remove(listener);
      return;
    }
    if (!entry.listeners.remove(listener)) return;
    if (!entry.isObserved) {
      final operation = entry.operation;
      if (operation != null && operation.dependsOnObserverActivity) {
        if ((entry.data.isAbsent && entry.fetchStatus == FetchStatus.paused) ||
            operation.cancellationWasConsumed) {
          operation.cancel(
            reason: const _FinalQueryObserverDetachedReason(),
            revert: true,
          );
        } else {
          operation.pauseRetries();
        }
      }
      _scheduleGc(entry);
    }
    queryCacheControllerInternal.publish(
      entry,
      QueryCacheEventKind.activityChanged,
    );
  }

  /// Reconciles enabled activity after a same-key observer settings update.
  @internal
  void refreshQueryObserverActivityInternal(
    QueryEntryInternal entry, {
    required bool wasActive,
  }) {
    if (_isDisposed || !queryCacheControllerInternal.containsEntry(entry)) {
      return;
    }
    final isActive = entry.isActive;
    if (wasActive != isActive) {
      queryCacheControllerInternal.publish(
        entry,
        QueryCacheEventKind.activityChanged,
      );
      return;
    }
    queryCacheControllerInternal.refreshObserverFreshnessInternal(entry);
  }

  /// Whether [entry] is stale under one observer's policy.
  @internal
  bool isQueryEntryStaleInternal(
    QueryEntryInternal entry,
    StalePolicy policy,
  ) =>
      _isStale(entry, policy);

  /// Starts or joins one observer-owned operation.
  @internal
  Future<Object?> refetchQueryEntryInternal(
    QueryEntryInternal entry,
    ResolvedQueryPlanBase plan, {
    required bool cancelRefetch,
  }) =>
      executeQueryPlanInternal(
        entry,
        plan,
        cancelRefetch: cancelRefetch,
        defaultPolicy: RetryPolicy.standard,
        observerOwned: true,
      );

  /// Executes any resolved raw plan through the canonical query lane.
  @internal
  Future<Object?> executeQueryPlanInternal(
    QueryEntryInternal entry,
    ResolvedQueryPlanBase plan, {
    required bool cancelRefetch,
    required RetryPolicy<Never> defaultPolicy,
    required bool observerOwned,
  }) {
    checkActiveInternal();
    if (!queryCacheControllerInternal.containsEntry(entry)) {
      throw StateError('Cannot fetch a removed query entry.');
    }
    entry
      ..retainedPlan = plan
      ..receiveRetention(
        _effectiveRetentionPolicy(plan),
      );
    _cancelGc(entry);
    final active = entry.operation;
    if (active != null) {
      if (active.isTransitioning) return active.future;
      if (!cancelRefetch || entry.data.isAbsent) {
        if (!observerOwned) active.retainBeyondObserverActivity();
        return active.future;
      }
      return _replaceQueryOperation(
        entry,
        active,
        plan,
        defaultPolicy:
            resolveQueryDefaultsInternal(plan.key).retry ?? defaultPolicy,
        networkModeOverride: resolveQueryDefaultsInternal(plan.key).networkMode,
        observerOwned: observerOwned,
      );
    }
    return _startQueryOperation(
      entry,
      plan,
      defaultPolicy:
          resolveQueryDefaultsInternal(plan.key).retry ?? defaultPolicy,
      networkModeOverride: resolveQueryDefaultsInternal(plan.key).networkMode,
      observerOwned: observerOwned,
    );
  }

  bool _applyResolvedTargetToEntry(
    QueryEntryInternal entry,
    ResolvedQueryTargetBase target, {
    required bool publish,
  }) {
    entry
      ..retainedPlan = target.plan
      ..receiveRetention(
        _effectiveRetentionPolicy(target.plan),
      );
    var changed = false;
    final initial = target.initialData;
    if (entry.initialData == null && initial != null) {
      entry
        ..initialData = initial
        ..initialValue = QueryValue<Object?>.present(initial.data)
        ..initialUpdatedAt = initial.updatedAt ?? runtime.clock.wallNow();
    }
    if (entry.data.isAbsent && entry.initialData != null) {
      entry
        ..data = entry.initialValue
        ..status = QueryStatus.success
        ..failure = null
        ..transientFailure = null
        ..failureCount = 0
        ..dataUpdatedAt = entry.initialUpdatedAt
        ..revision += 1
        ..isInvalidated = false;
      changed = true;
    }
    if (changed && publish) {
      queryCacheControllerInternal.publish(entry, QueryCacheEventKind.updated);
    }
    return changed;
  }

  /// Reads exact typed cache data using [query] as the raw type carrier.
  QueryValue<T> getQueryData<T>(QueryDataTarget<T> query) {
    checkActiveInternal();
    return _typedQueryValue<T>(
      queryCacheControllerInternal.lookup(query.key)?.data ??
          const QueryValue<Object?>.absent(),
    );
  }

  /// Reads the complete exact typed query state, or null when no entry exists.
  QuerySnapshot<T>? getQueryState<T>(QueryDataTarget<T> query) {
    checkActiveInternal();
    final entry = queryCacheControllerInternal.lookup(query.key);
    return entry == null ? null : _typedSnapshot<T>(entry);
  }

  /// Captures revisioned exact cache data for optimistic restoration.
  QueryDataSnapshot<T> snapshotQueryData<T>(QueryDataTarget<T> query) {
    checkActiveInternal();
    final entry = queryCacheControllerInternal.lookup(query.key);
    final lineage = queryCacheControllerInternal.lineageFor(query.key);
    return createQueryDataSnapshotInternal<T>(
      data: entry == null
          ? QueryValue<T>.absent()
          : _typedQueryValue<T>(entry.data),
      updatedAt: entry?.dataUpdatedAt,
      revision: entry?.revision ?? 0,
      clientToken: this,
      key: query.key,
      lineageToken: lineage,
    );
  }

  /// Writes exact typed data and returns its new revisioned snapshot.
  QueryDataSnapshot<T> setQueryData<T>(
    QueryDataTarget<T> query,
    T data, {
    DateTime? updatedAt,
  }) {
    checkActiveInternal();
    final entry = queryCacheControllerInternal.getOrCreate(query.key)
      ..receiveRetention(
        resolveQueryDefaultsInternal(query.key).retention ??
            RetentionPolicy.standard,
      );
    return _writeEntryData<T>(
      entry,
      data,
      updatedAt: updatedAt,
      reconcileWith: query.reconciler,
    );
  }

  /// Updates exact typed data with explicit previous-value presence.
  QueryDataSnapshot<T> updateQueryData<T>(
    QueryDataTarget<T> query,
    T Function(QueryValue<T> previous) update, {
    DateTime? updatedAt,
  }) {
    checkActiveInternal();
    final previous = getQueryData(query);
    final next = untracked(() => update(previous));
    return setQueryData(query, next, updatedAt: updatedAt);
  }

  /// Conditionally restores a provenance-bound optimistic data snapshot.
  bool restoreQueryData<T>(
    QueryDataTarget<T> query,
    QueryDataSnapshot<T> snapshot, {
    required int ifRevision,
  }) {
    checkActiveInternal();
    final entry = queryCacheControllerInternal.lookup(query.key);
    final lineage = queryCacheControllerInternal.lineageFor(query.key);
    if (!queryDataSnapshotMatchesProvenanceInternal(
      snapshot,
      clientToken: this,
      key: query.key,
      lineageToken: lineage,
    )) {
      return false;
    }
    if ((entry?.revision ?? 0) != ifRevision) return false;
    if (entry == null) return snapshot.data.isAbsent;

    entry
      ..data = _eraseQueryValue(snapshot.data)
      ..dataUpdatedAt = snapshot.updatedAt
      ..status =
          snapshot.data.isPresent ? QueryStatus.success : QueryStatus.pending
      ..failure = null
      ..dataUpdateCount += 1
      ..recordCompletion()
      ..revision += 1
      ..isInvalidated = false;
    _rebaseActiveQueryRollbackData(entry);
    queryCacheControllerInternal.publish(entry, QueryCacheEventKind.updated);
    _scheduleGc(entry);
    return true;
  }

  /// Reads typed existing matches in stable cache order.
  IList<QueryDataMatch<T>> getQueriesData<T>(TypedQueryFilter<T> filter) {
    checkActiveInternal();
    return IList<QueryDataMatch<T>>(
      queryCacheControllerInternal.entries
          .where(
            (entry) => filter.matches(
              queryCacheControllerInternal.snapshotOf(entry),
            ),
          )
          .map(
            (entry) => QueryDataMatch<T>(
              key: entry.key,
              snapshot: _dataSnapshotForEntry<T>(entry),
            ),
          ),
    );
  }

  /// Writes one typed value to every existing match in stable cache order.
  IList<QueryDataMatch<T>> setQueriesData<T>(
    TypedQueryFilter<T> filter,
    T data, {
    DateTime? updatedAt,
  }) {
    checkActiveInternal();
    final entries = queryCacheControllerInternal.entries
        .where(
          (entry) => filter.matches(
            queryCacheControllerInternal.snapshotOf(entry),
          ),
        )
        .toList(growable: false);
    return IList<QueryDataMatch<T>>(
      entries.map((entry) {
        final snapshot = _writeEntryData<T>(
          entry,
          data,
          updatedAt: updatedAt,
        );
        return QueryDataMatch<T>(key: entry.key, snapshot: snapshot);
      }),
    );
  }

  /// Updates every typed existing match in stable cache order.
  IList<QueryDataMatch<T>> updateQueriesData<T>(
    TypedQueryFilter<T> filter,
    T Function(QueryKey key, QueryValue<T> previous) update, {
    DateTime? updatedAt,
  }) {
    checkActiveInternal();
    final entries = queryCacheControllerInternal.entries
        .where(
          (entry) => filter.matches(
            queryCacheControllerInternal.snapshotOf(entry),
          ),
        )
        .toList(growable: false);
    return IList<QueryDataMatch<T>>(
      entries.map((entry) {
        final previous = _typedQueryValue<T>(entry.data);
        final next = untracked(() => update(entry.key, previous));
        final snapshot = _writeEntryData<T>(
          entry,
          next,
          updatedAt: updatedAt,
        );
        return QueryDataMatch<T>(key: entry.key, snapshot: snapshot);
      }),
    );
  }

  /// Fetches raw query data, using no retry when none was explicitly set.
  Future<T> fetchQuery<T>(
    Query<T> query, {
    StalePolicy? staleTime,
    bool cancelRefetch = false,
  }) async {
    checkActiveInternal();
    final plan = query.resolved.plan;
    final entry = queryCacheControllerInternal.getOrCreate(query.key);
    entry
      ..retainedPlan = plan
      ..receiveRetention(
        _effectiveRetentionPolicy(plan),
      );
    _cancelGc(entry);

    final defaults = resolveQueryDefaultsInternal(plan.key);
    final policy = staleTime ?? _effectiveStalePolicy(plan, defaults);
    if (entry.data.isPresent && !_isStale(entry, policy)) {
      _scheduleGc(entry);
      return _typedQueryValue<T>(entry.data).requireValue();
    }

    final active = entry.operation;
    if (active != null) {
      if (active.isTransitioning) return (await active.future) as T;
      if (!cancelRefetch || entry.data.isAbsent) {
        active.retainBeyondObserverActivity();
        return (await active.future) as T;
      }
      return (await _replaceQueryOperation(
        entry,
        active,
        plan,
        defaultPolicy: _defaultRetryFor(plan, observerOwned: false),
        networkModeOverride: defaults.networkMode,
        observerOwned: false,
      )) as T;
    }
    return (await _startQueryOperation(
      entry,
      plan,
      defaultPolicy: _defaultRetryFor(plan, observerOwned: false),
      networkModeOverride: defaults.networkMode,
      observerOwned: false,
    )) as T;
  }

  /// Warms the cache and intentionally swallows the caller-facing error.
  Future<void> prefetchQuery<T>(
    Query<T> query, {
    StalePolicy? staleTime,
    bool cancelRefetch = false,
  }) async {
    try {
      await fetchQuery(
        query,
        staleTime: staleTime,
        cancelRefetch: cancelRefetch,
      );
    } on Object {
      // Failure is already committed to cache state.
    }
  }

  /// Returns cached data immediately and optionally revalidates it.
  Future<T> ensureQueryData<T>(
    Query<T> query, {
    StalePolicy? staleTime,
    bool revalidateIfStale = false,
  }) {
    checkActiveInternal();
    final entry = queryCacheControllerInternal.lookup(query.key);
    if (entry != null && entry.data.isPresent) {
      final result = _typedQueryValue<T>(entry.data).requireValue();
      final plan = query.resolved.plan;
      entry
        ..retainedPlan = plan
        ..receiveRetention(
          _effectiveRetentionPolicy(plan),
        );
      _scheduleGc(entry);
      final defaults = resolveQueryDefaultsInternal(plan.key);
      if (revalidateIfStale &&
          _isStale(entry, staleTime ?? _effectiveStalePolicy(plan, defaults))) {
        unawaited(prefetchQuery(query, staleTime: staleTime));
      }
      return Future<T>.value(result);
    }
    return fetchQuery(query, staleTime: staleTime);
  }

  /// Invalidates matching entries and optionally refetches an activity subset.
  Future<QueryBatchResult> invalidateQueries({
    QueryFilter filter = const QueryFilter(),
    QueryRefetchTarget refetchType = QueryRefetchTarget.active,
    bool cancelRefetch = true,
  }) async {
    checkActiveInternal();
    final entries = _matchingQueryEntries(filter);
    final work = <_QueryBatchWork>[];
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      entry
        ..isInvalidated = true
        ..invalidationRevision += 1;
      queryCacheControllerInternal.publish(
        entry,
        QueryCacheEventKind.invalidated,
      );
      final plan = entry.retainedPlan;
      if (_matchesRefetchTarget(entry, refetchType) &&
          _canBulkRefetch(entry) &&
          plan != null) {
        work.add(_QueryBatchWork(index, entry, plan));
      }
    }
    final failures = await _runQueryBatchWork(
      work,
      cancelRefetch: cancelRefetch,
      defaultPolicy: RetryPolicy.standard,
      observerOwned: false,
    );
    return QueryBatchResult(
      matched: entries.length,
      affected: entries.length,
      failures: failures,
    );
  }

  /// Imperatively refetches matching executable entries.
  Future<QueryBatchResult> refetchQueries({
    QueryFilter filter = const QueryFilter(),
    QueryRefetchTarget refetchType = QueryRefetchTarget.all,
    bool cancelRefetch = true,
  }) async {
    checkActiveInternal();
    final entries = _matchingQueryEntries(filter);
    final work = <_QueryBatchWork>[];
    var skipped = 0;
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      if (!_matchesRefetchTarget(entry, refetchType)) continue;
      if (!_canBulkRefetch(entry)) continue;
      final plan = entry.retainedPlan;
      if (plan == null) {
        skipped += 1;
      } else {
        work.add(_QueryBatchWork(index, entry, plan));
      }
    }
    final failures = await _runQueryBatchWork(
      work,
      cancelRefetch: cancelRefetch,
      defaultPolicy: RetryPolicy.none,
      observerOwned: false,
    );
    return QueryBatchResult(
      matched: entries.length,
      affected: work.length,
      skippedNonExecutable: skipped,
      failures: failures,
    );
  }

  /// Cancels matching active operations, reverting their pre-operation state.
  Future<QueryBatchResult> cancelQueries({
    QueryFilter filter = const QueryFilter(),
    bool revert = true,
  }) async {
    checkActiveInternal();
    final entries = _matchingQueryEntries(filter);
    final settlements = <Future<void>>[];
    var affected = 0;
    for (final entry in entries) {
      final operation = entry.operation;
      if (operation == null) continue;
      affected += 1;
      settlements.add(_ignoreQueryCancellation(operation.future));
      operation.cancel(
        reason: const _ExplicitQueryCancellationReason(),
        revert: revert,
      );
    }
    await Future.wait(settlements);
    return QueryBatchResult(matched: entries.length, affected: affected);
  }

  /// Resets matching entries and optionally refetches an activity subset.
  Future<QueryBatchResult> resetQueries({
    QueryFilter filter = const QueryFilter(),
    QueryRefetchTarget refetchType = QueryRefetchTarget.active,
  }) async {
    checkActiveInternal();
    final entries = _matchingQueryEntries(filter);
    final work = <_QueryBatchWork>[];
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final operation = entry.operation;
      if (operation != null && identical(entry.operation, operation)) {
        entry.operation = null;
      }
      entry
        ..data = entry.initialValue
        ..status = entry.initialValue.isPresent
            ? QueryStatus.success
            : QueryStatus.pending
        ..fetchStatus = FetchStatus.idle
        ..pauseReason = null
        ..failure = null
        ..transientFailure = null
        ..failureCount = 0
        ..dataUpdatedAt =
            entry.initialValue.isPresent ? entry.initialUpdatedAt : null
        ..failureUpdatedAt = null
        ..dataUpdateCount = 0
        ..failureUpdateCount = 0
        ..visibleCompletionSequence = 0
        ..revision += 1
        ..invalidationRevision += 1
        ..isInvalidated = false
        ..operationCompletionCount = 0;
      queryCacheControllerInternal.publish(entry, QueryCacheEventKind.reset);
      _scheduleGc(entry);
      if (operation is _ClientQueryOperation) {
        _requestClientQueryOperationCancellation(
          operation,
          reason: const _ResetQueryReason(),
          revert: false,
          publish: false,
        );
      } else if (operation != null) {
        operation.cancel(
          reason: const _ResetQueryReason(),
          revert: false,
        );
      }
      if (!queryCacheControllerInternal.containsEntry(entry)) continue;
      final plan = entry.retainedPlan;
      if (_matchesRefetchTarget(entry, refetchType) &&
          _canBulkRefetch(entry) &&
          plan != null) {
        work.add(_QueryBatchWork(index, entry, plan));
      }
    }
    final failures = await _runQueryBatchWork(
      work,
      cancelRefetch: true,
      defaultPolicy: RetryPolicy.standard,
      observerOwned: false,
    );
    return QueryBatchResult(
      matched: entries.length,
      affected: entries.length,
      failures: failures,
    );
  }

  /// Removes matching query entries synchronously.
  int removeQueries([QueryFilter filter = const QueryFilter()]) {
    checkActiveInternal();
    final entries = _matchingQueryEntries(filter);
    for (final entry in entries) {
      if (queryCacheControllerInternal.removeEntry(entry) == null) continue;
      _cancelEntryOperation(
        entry,
        reason: const _RemovedQueryReason(),
        revert: false,
        publish: false,
      );
    }
    return entries.length;
  }

  /// Clears owned cache state while leaving this client usable.
  void clear() {
    checkActiveInternal();
    _clearQueryCacheInternal();
    for (final clearOwnedCache in List<void Function()>.of(
      _ownedCacheClearers,
    )) {
      clearOwnedCache();
    }
  }

  void _clearQueryCacheInternal() {
    checkActiveInternal();
    final entries = queryCacheControllerInternal.clearEntries();
    for (final entry in entries) {
      _cancelEntryOperation(
        entry,
        reason: const _RemovedQueryReason(),
        revert: false,
        publish: false,
      );
    }
  }

  List<QueryEntryInternal> _matchingQueryEntries(QueryFilter filter) {
    return queryCacheControllerInternal.entries
        .where(
          (entry) => untracked(
            () => filter.matches(
              queryCacheControllerInternal.snapshotOf(entry),
            ),
          ),
        )
        .toList(growable: false);
  }

  void _refreshFetchingCountInternal() {
    if (_isDisposed || queryCacheControllerInternal.isDisposed) return;
    _fetchingCountInternal.value = queryCacheControllerInternal.entries
        .where((entry) => entry.fetchStatus == FetchStatus.fetching)
        .length;
  }

  bool _matchesRefetchTarget(
    QueryEntryInternal entry,
    QueryRefetchTarget target,
  ) {
    return switch (target) {
      QueryRefetchTarget.none => false,
      QueryRefetchTarget.active => entry.isActive,
      QueryRefetchTarget.inactive => !entry.isActive,
      QueryRefetchTarget.all => true,
    };
  }

  StalePolicy _effectiveStalePolicy(
    ResolvedQueryPlanBase plan, [
    QueryDefaults? resolvedDefaults,
  ]) {
    if (plan.hasExplicitStalePolicy) return plan.stalePolicy;
    return (resolvedDefaults ?? resolveQueryDefaultsInternal(plan.key))
            .staleTime ??
        plan.stalePolicy;
  }

  /// Resolves recipe/default freshness for specialized query implementations.
  @internal
  StalePolicy effectiveQueryStalePolicyInternal(
    ResolvedQueryPlanBase plan, [
    QueryDefaults? resolvedDefaults,
  ]) =>
      _effectiveStalePolicy(plan, resolvedDefaults);

  RetentionPolicy _effectiveRetentionPolicy(ResolvedQueryPlanBase plan) {
    if (plan.hasExplicitRetentionPolicy) return plan.retentionPolicy;
    return resolveQueryDefaultsInternal(plan.key).retention ??
        plan.retentionPolicy;
  }

  /// Resolves recipe/default retention for specialized query implementations.
  @internal
  RetentionPolicy effectiveQueryRetentionPolicyInternal(
    ResolvedQueryPlanBase plan,
  ) =>
      _effectiveRetentionPolicy(plan);

  NetworkMode _effectiveNetworkMode(
    ResolvedQueryPlanBase plan, [
    QueryDefaults? resolvedDefaults,
  ]) {
    if (plan.hasExplicitNetworkMode) return plan.networkMode;
    return (resolvedDefaults ?? resolveQueryDefaultsInternal(plan.key))
            .networkMode ??
        plan.networkMode;
  }

  bool _canBulkRefetch(QueryEntryInternal entry) =>
      !entry.isDisabled && !entry.isStatic;

  Future<List<QueryBatchFailure>> _runQueryBatchWork(
    List<_QueryBatchWork> work, {
    required bool cancelRefetch,
    required RetryPolicy<Never> defaultPolicy,
    required bool observerOwned,
  }) async {
    final failures = <int, QueryBatchFailure>{};
    await Future.wait<void>(
      work.map((item) async {
        try {
          final pending = executeQueryPlanInternal(
            item.entry,
            item.plan,
            cancelRefetch: cancelRefetch,
            defaultPolicy: defaultPolicy,
            observerOwned: observerOwned,
          );
          if (item.entry.fetchStatus == FetchStatus.paused) {
            pending.ignore();
            return;
          }
          await pending;
        } catch (error, stackTrace) {
          failures[item.index] = QueryBatchFailure(
            key: item.entry.key,
            failure: item.entry.failure ?? QueryFailure(error, stackTrace),
          );
        }
      }),
    );
    return work
        .where((item) => failures.containsKey(item.index))
        .map((item) => failures[item.index]!)
        .toList(growable: false);
  }

  QuerySnapshot<T> _typedSnapshot<T>(QueryEntryInternal entry) {
    return QuerySnapshot<T>(
      key: entry.key,
      data: _typedQueryValue<T>(entry.data),
      status: entry.status,
      fetchStatus: entry.fetchStatus,
      pauseReason: entry.pauseReason,
      failure: entry.failure,
      transientFailure: entry.transientFailure,
      failureCount: entry.failureCount,
      dataUpdatedAt: entry.dataUpdatedAt,
      failureUpdatedAt: entry.failureUpdatedAt,
      dataUpdateCount: entry.dataUpdateCount,
      failureUpdateCount: entry.failureUpdateCount,
      revision: entry.revision,
      invalidationRevision: entry.invalidationRevision,
      isInvalidated: entry.isInvalidated,
      metadata: entry.metadata,
    );
  }

  QueryDataSnapshot<T> _dataSnapshotForEntry<T>(QueryEntryInternal entry) {
    return createQueryDataSnapshotInternal<T>(
      data: _typedQueryValue<T>(entry.data),
      updatedAt: entry.dataUpdatedAt,
      revision: entry.revision,
      clientToken: this,
      key: entry.key,
      lineageToken: entry.lineageToken,
    );
  }

  QueryDataSnapshot<T> _writeEntryData<T>(
    QueryEntryInternal entry,
    T data, {
    DateTime? updatedAt,
    DataReconciler<T>? reconcileWith,
  }) {
    Object? next = data;
    final previous = entry.data;
    if (previous case QueryPresent<Object?>(:final value)) {
      final reconciler = reconcileWith;
      if (reconciler != null) {
        next = untracked(() => reconciler.reconcileObject(value, next));
      } else if (entry.retainedPlan case final plan?) {
        next = untracked(() => plan.reconcileData(value, next));
      }
    }

    entry
      ..data = QueryValue<Object?>.present(next)
      ..status = QueryStatus.success
      ..failure = null
      ..dataUpdatedAt = updatedAt ?? runtime.clock.wallNow()
      ..dataUpdateCount += 1
      ..recordCompletion()
      ..revision += 1
      ..isInvalidated = false;
    _rebaseActiveQueryRollbackData(entry);
    queryCacheControllerInternal.publish(entry, QueryCacheEventKind.updated);
    _scheduleGc(entry);
    return _dataSnapshotForEntry<T>(entry);
  }

  void _rebaseActiveQueryRollbackData(QueryEntryInternal entry) {
    final operation = entry.operation;
    if (operation is _ClientQueryOperation &&
        identical(operation.entry, entry) &&
        !operation.isSettled) {
      operation.rebaseRollbackData();
    }
  }

  bool _isStale(QueryEntryInternal entry, StalePolicy policy) {
    if (entry.data.isAbsent) return true;
    final updatedAt = entry.dataUpdatedAt;
    if (updatedAt == null) return true;
    return untracked(
      () => policy.isStale(
        StaleState(
          now: runtime.clock.wallNow(),
          updatedAt: updatedAt,
          isInvalidated: entry.isInvalidated,
        ),
      ),
    );
  }

  RetryPolicy<Never> _defaultRetryFor(
    ResolvedQueryPlanBase plan, {
    required bool observerOwned,
  }) {
    return resolveQueryDefaultsInternal(plan.key).retry ??
        (observerOwned ? RetryPolicy.standard : RetryPolicy.none);
  }

  Future<Object?> _replaceQueryOperation(
    QueryEntryInternal entry,
    QueryOperationInternal active,
    ResolvedQueryPlanBase plan, {
    required RetryPolicy<Never> defaultPolicy,
    NetworkMode? networkModeOverride,
    required bool observerOwned,
  }) {
    final transition = _QueryOperationTransition(this, entry);
    if (active is! _ClientQueryOperation) {
      transition.cancel(
        reason: const _StaleQueryOperationReason(),
        revert: false,
      );
      return transition.future;
    }
    _requestClientQueryOperationCancellation(
      active,
      reason: const _ReplacedQueryOperationReason(),
      revert: true,
      publish: true,
      laneReplacement: transition,
    );
    if (_isDisposed) {
      transition.cancel(
        reason: const QueryClientDisposedException(),
        revert: false,
      );
      return transition.future;
    }
    if (!queryCacheControllerInternal.containsEntry(entry) ||
        !identical(entry.operation, transition) ||
        transition.isSettled) {
      if (!transition.isSettled) {
        transition.cancel(
          reason: const _StaleQueryOperationReason(),
          revert: false,
        );
      }
      return transition.future;
    }
    try {
      final started = _startQueryOperation(
        entry,
        plan,
        defaultPolicy: defaultPolicy,
        networkModeOverride: networkModeOverride,
        observerOwned: observerOwned,
        replacing: transition,
      );
      transition.bind(started);
    } catch (error, stackTrace) {
      transition.completeError(error, stackTrace);
    }
    return transition.future;
  }

  Future<Object?> _startQueryOperation(
    QueryEntryInternal entry,
    ResolvedQueryPlanBase plan, {
    required RetryPolicy<Never> defaultPolicy,
    NetworkMode? networkModeOverride,
    required bool observerOwned,
    _QueryOperationTransition? replacing,
  }) {
    checkActiveInternal();
    final current = entry.operation;
    if (replacing == null) {
      if (current != null) {
        throw StateError('Cannot start a second query operation.');
      }
    } else if (!identical(current, replacing) || replacing.isSettled) {
      throw StateError('The query replacement lane is no longer current.');
    }
    final rollback = _QueryRollbackState.capture(entry);
    final cancellation = ownCancellationInternal();
    final operation = _ClientQueryOperation(
      owner: this,
      entry: entry,
      plan: plan,
      id: ++entry.operationSequence,
      invalidationRevisionAtStart: entry.invalidationRevision,
      cancellation: cancellation,
      rollback: rollback,
      dependsOnObserverActivity: observerOwned,
      callbacks: queryCallbacksInternal,
      callbackZone: Zone.current,
    );
    entry
      ..operation = operation
      ..retainedPlan = plan
      ..fetchStatus = FetchStatus.fetching
      ..pauseReason = null
      ..transientFailure = null
      ..failureCount = 0;
    if (entry.data.isAbsent) {
      entry
        ..status = QueryStatus.pending
        ..failure = null;
    }
    queryCacheControllerInternal.publish(entry, QueryCacheEventKind.updated);

    try {
      final resolved = plan.createOperation(
        QueryPlanExecution(
          client: this,
          runtime: runtime,
          timers: timersInternal,
          cancellation: cancellation,
          onlineManager: onlineManager,
          focusManager: focusManager,
          defaultPolicy: defaultPolicy,
          networkModeOverride: networkModeOverride,
          guard: () => _guardQueryOperation(operation),
          onAttemptFailure: (failure, failureCount) {
            if (!_isCurrentQueryOperation(operation)) return;
            entry
              ..transientFailure = failure
              ..failureCount = failureCount;
            queryCacheControllerInternal.publish(
              entry,
              QueryCacheEventKind.updated,
            );
          },
          onOnlinePauseChanged: (isPaused) {
            if (!_isCurrentQueryOperation(operation)) return;
            entry
              ..fetchStatus =
                  isPaused ? FetchStatus.paused : FetchStatus.fetching
              ..pauseReason = isPaused ? PauseReason.offline : null;
            queryCacheControllerInternal.publish(
              entry,
              QueryCacheEventKind.updated,
            );
          },
          onFocusPauseChanged: (isPaused) {
            if (!_isCurrentQueryOperation(operation)) return;
            entry
              ..fetchStatus =
                  isPaused ? FetchStatus.paused : FetchStatus.fetching
              ..pauseReason = isPaused ? PauseReason.focus : null;
            queryCacheControllerInternal.publish(
              entry,
              QueryCacheEventKind.updated,
            );
          },
          streamData: operation.streamData,
        ),
      );
      operation.attach(resolved);
      unawaited(_settleQueryOperation(operation, resolved.result));
    } catch (error, stackTrace) {
      unawaited(
        _settleQueryOperation(
          operation,
          Future<Object?>.error(error, stackTrace),
        ),
      );
    }
    return operation.future;
  }

  Future<void> _settleQueryOperation(
    _ClientQueryOperation operation,
    Future<Object?> result,
  ) async {
    try {
      var value = await result;
      final awaitedCancellation = operation.takeAwaitedCancellation();
      if (awaitedCancellation != null) {
        _completeAwaitedQueryCancellation(
          operation,
          awaitedCancellation,
        );
        return;
      }
      if (!_isCurrentQueryOperation(operation)) {
        _finishLostQueryOperation(operation);
        return;
      }
      if (!operation.streamData.ensureOwnership()) {
        _finishLostQueryOperation(operation);
        return;
      }
      final entry = operation.entry;
      final plan = operation.plan;
      final previous = entry.data;
      if (previous is QueryPresent<Object?>) {
        value = untracked(
          () => plan.reconcileData(previous.value, value),
        );
      }
      if (!_isCurrentQueryOperation(operation)) {
        _finishLostQueryOperation(operation);
        return;
      }
      entry
        ..data = QueryValue<Object?>.present(value)
        ..status = QueryStatus.success
        ..fetchStatus = FetchStatus.idle
        ..pauseReason = null
        ..failure = null
        ..transientFailure = null
        ..failureCount = 0
        ..dataUpdatedAt = runtime.clock.wallNow()
        ..dataUpdateCount += 1
        ..recordCompletion()
        ..revision += 1;
      entry.operationCompletionCount += 1;
      entry.isInvalidated = false;
      _releaseQueryOperation(operation);
      queryCacheControllerInternal.publish(
        entry,
        QueryCacheEventKind.updated,
      );
      final snapshot = queryCacheControllerInternal.snapshotOf(entry);
      _invokeQuerySuccessCallbacks(operation, value, snapshot);
      operation.finish(value: value);
      _scheduleGc(entry);
    } catch (error, stackTrace) {
      final awaitedCancellation = operation.takeAwaitedCancellation();
      if (awaitedCancellation != null) {
        _completeAwaitedQueryCancellation(
          operation,
          awaitedCancellation,
          stackTrace: stackTrace,
        );
        return;
      }
      if (!_isCurrentQueryOperation(operation)) {
        _finishLostQueryOperation(operation, stackTrace: stackTrace);
        return;
      }
      if (error is QueryCancelledException) {
        final request = operation.takeAwaitedCancellation();
        _cancelClientQueryOperation(
          operation,
          reason: request?.reason ?? error.reason ?? error,
          revert: request?.revert ?? true,
          publish: request?.publish ?? true,
          stackTrace: stackTrace,
        );
        return;
      }
      final entry = operation.entry;
      final hadRetainedData = entry.data.isPresent;
      final failure = QueryFailure(error, stackTrace);
      entry
        ..status = QueryStatus.error
        ..fetchStatus = FetchStatus.idle
        ..pauseReason = null
        ..failure = failure
        ..transientFailure = null
        ..failureUpdatedAt = runtime.clock.wallNow()
        ..failureUpdateCount += 1
        ..recordCompletion();
      if (hadRetainedData) {
        entry.isInvalidated = true;
      }
      entry.operationCompletionCount += 1;
      _releaseQueryOperation(operation);
      queryCacheControllerInternal.publish(
        entry,
        QueryCacheEventKind.updated,
      );
      final snapshot = queryCacheControllerInternal.snapshotOf(entry);
      _invokeQueryErrorCallbacks(operation, failure, snapshot);
      operation.finish(error: error, stackTrace: stackTrace);
      _scheduleGc(entry);
    }
  }

  void _guardQueryOperation(_ClientQueryOperation operation) {
    if (!_isCurrentQueryOperation(operation)) {
      throw const QueryCancelledException(_StaleQueryOperationReason());
    }
  }

  bool _isCurrentQueryOperation(_ClientQueryOperation operation) {
    return !_isDisposed && _ownsQueryOperationLane(operation);
  }

  bool _ownsQueryOperationLane(_ClientQueryOperation operation) {
    return !operation.isSettled &&
        queryCacheControllerInternal.containsEntry(operation.entry) &&
        operation.entry.incarnation == operation.entryIncarnation &&
        identical(operation.entry.operation, operation);
  }

  void _finishLostQueryOperation(
    _ClientQueryOperation operation, {
    StackTrace? stackTrace,
  }) {
    if (operation.isSettled) return;
    _cancelClientQueryOperation(
      operation,
      reason: _isDisposed
          ? const QueryClientDisposedException()
          : const _StaleQueryOperationReason(),
      revert: false,
      publish: false,
      stackTrace: stackTrace,
    );
  }

  void _releaseQueryOperation(_ClientQueryOperation operation) {
    if (identical(operation.entry.operation, operation)) {
      operation.entry.operation = null;
    }
    _awaitingQueryCancellationCleanup.remove(operation);
    releaseCancellationInternal(operation.cancellation);
  }

  void _invokeQuerySuccessCallbacks(
    _ClientQueryOperation operation,
    Object? data,
    QueryCacheSnapshot snapshot,
  ) {
    final callbacks = operation.callbacks;
    final onSuccess = callbacks.onSuccess;
    if (onSuccess != null) {
      _invokeQueryCallback(
        operation,
        () => onSuccess(data, snapshot),
      );
    }
    final onSettled = callbacks.onSettled;
    if (onSettled != null) {
      _invokeQueryCallback(
        operation,
        () => onSettled(snapshot.data, null, snapshot),
      );
    }
  }

  void _invokeQueryErrorCallbacks(
    _ClientQueryOperation operation,
    QueryFailure failure,
    QueryCacheSnapshot snapshot,
  ) {
    final callbacks = operation.callbacks;
    final onError = callbacks.onError;
    if (onError != null) {
      _invokeQueryCallback(
        operation,
        () => onError(failure, snapshot),
      );
    }
    final onSettled = callbacks.onSettled;
    if (onSettled != null) {
      _invokeQueryCallback(
        operation,
        () => onSettled(snapshot.data, failure, snapshot),
      );
    }
  }

  void _invokeQueryCallback(
    _ClientQueryOperation operation,
    void Function() callback,
  ) {
    try {
      operation.callbackZone.runGuarded(() => untracked(callback));
    } on Object {
      // The captured Zone has already received the callback failure.
    }
  }

  void _cancelEntryOperation(
    QueryEntryInternal? entry, {
    required Object reason,
    required bool revert,
    required bool publish,
  }) {
    final operation = entry?.operation;
    if (operation is _ClientQueryOperation) {
      _cancelClientQueryOperation(
        operation,
        reason: reason,
        revert: revert,
        publish: publish,
      );
    } else if (operation != null) {
      operation.cancel(reason: reason, revert: revert);
    }
  }

  void _cancelClientQueryOperation(
    _ClientQueryOperation operation, {
    required Object reason,
    required bool revert,
    required bool publish,
    QueryOperationInternal? laneReplacement,
    StackTrace? stackTrace,
    bool completeAsSuccess = false,
    Object? successValue,
  }) {
    if (operation.isSettled) return;
    final ownsEntry = _ownsQueryOperationLane(operation);
    operation.resolved?.stopRetries();
    final entry = operation.entry;
    if (ownsEntry) {
      if (revert) {
        operation.rollback.restore(entry);
      } else {
        entry
          ..fetchStatus = FetchStatus.idle
          ..pauseReason = null
          ..transientFailure = null;
      }
      entry.operation = laneReplacement;
      if (publish) {
        queryCacheControllerInternal.publish(
          entry,
          QueryCacheEventKind.updated,
        );
      }
      _scheduleGc(entry);
    }
    operation.cancellation.cancel(reason);
    _awaitingQueryCancellationCleanup.remove(operation);
    releaseCancellationInternal(operation.cancellation);
    if (completeAsSuccess) {
      operation.finish(value: successValue);
    } else {
      final publicError = reason is QueryClientDisposedException
          ? reason
          : QueryCancelledException(reason);
      operation.finish(
        error: publicError,
        stackTrace: stackTrace ?? StackTrace.current,
      );
    }
  }

  void _completeAwaitedQueryCancellation(
    _ClientQueryOperation operation,
    _AwaitedQueryCancellation request, {
    StackTrace? stackTrace,
  }) {
    _cancelClientQueryOperation(
      operation,
      reason: request.reason,
      revert: request.revert,
      publish: request.publish,
      stackTrace: stackTrace,
    );
  }

  void _requestClientQueryOperationCancellation(
    _ClientQueryOperation operation, {
    required Object reason,
    required bool revert,
    required bool publish,
    QueryOperationInternal? laneReplacement,
  }) {
    if (operation.isSettled) return;
    if (operation.streamData.wasUsed &&
        operation.cancellationWasConsumed &&
        operation.resolved != null) {
      operation.resolved?.stopRetries();
      operation.awaitCancellation(
        reason: reason,
        revert: revert,
        publish: publish,
      );
      final ownsEntry = _ownsQueryOperationLane(operation);
      final entry = operation.entry;
      if (ownsEntry) {
        if (revert) {
          operation.rollback.restore(entry);
        } else {
          entry
            ..fetchStatus = FetchStatus.idle
            ..pauseReason = null
            ..transientFailure = null;
        }
        entry.operation = laneReplacement;
        if (publish) {
          queryCacheControllerInternal.publish(
            entry,
            QueryCacheEventKind.updated,
          );
        }
        _scheduleGc(entry);
      }
      _awaitingQueryCancellationCleanup.add(operation);
      operation.cancellation.cancel(reason);
      return;
    }
    _cancelClientQueryOperation(
      operation,
      reason: reason,
      revert: revert,
      publish: publish,
      laneReplacement: laneReplacement,
    );
  }

  void _cancelGc(QueryEntryInternal entry) {
    entry.gcGeneration += 1;
    entry.gcHandle?.cancel();
    entry.gcHandle = null;
  }

  /// Reapplies the current longest retention after a specialized cache hit.
  @internal
  void refreshQueryGcInternal(QueryEntryInternal entry) {
    _scheduleGc(entry);
  }

  void _scheduleGc(QueryEntryInternal entry) {
    _cancelGc(entry);
    if (_isDisposed ||
        entry.isObserved ||
        entry.operation != null ||
        entry.retainForever ||
        !queryCacheControllerInternal.containsEntry(entry)) {
      return;
    }
    final generation = entry.gcGeneration;
    entry.gcHandle = timersInternal.schedule(entry.longestRetention, () {
      if (_isDisposed ||
          generation != entry.gcGeneration ||
          entry.isObserved ||
          entry.operation != null ||
          entry.retainForever ||
          !queryCacheControllerInternal.containsEntry(entry)) {
        return;
      }
      queryCacheControllerInternal.remove(entry.key);
    });
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation += 1;
    for (final entry in List<QueryEntryInternal>.of(
      queryCacheControllerInternal.entries,
    )) {
      final operation = entry.operation;
      if (operation is _ClientQueryOperation) {
        _cancelClientQueryOperation(
          operation,
          reason: const QueryClientDisposedException(),
          revert: false,
          publish: false,
        );
      } else if (operation != null) {
        operation.cancel(
          reason: const QueryClientDisposedException(),
          revert: false,
        );
      }
    }
    for (final operation in List<_ClientQueryOperation>.of(
      _awaitingQueryCancellationCleanup,
    )) {
      _cancelClientQueryOperation(
        operation,
        reason: const QueryClientDisposedException(),
        revert: false,
        publish: false,
      );
    }
    _ownedCacheClearers.clear();

    final cancellations =
        List<QueryCancellationController>.of(_ownedCancellations);
    _ownedCancellations.clear();
    for (final controller in cancellations) {
      controller.cancel(const QueryClientDisposedException());
    }

    final disposables = List<Disposable>.of(_ownedDisposables);
    _ownedDisposables.clear();
    for (final disposable in disposables) {
      final result = disposable.dispose();
      if (result is Future<void>) unawaited(result);
    }

    focusManager.dispose();
    onlineManager.dispose();
    queryCacheControllerInternal.dispose();
    timersInternal.dispose();
    notificationsInternal.dispose();
    _fetchingCountInternal.dispose();
  }
}

final class _ClientQueryOperation implements QueryOperationInternal {
  _ClientQueryOperation({
    required this.owner,
    required this.entry,
    required this.plan,
    required this.id,
    required this.invalidationRevisionAtStart,
    required this.cancellation,
    required this.rollback,
    required this.dependsOnObserverActivity,
    required this.callbacks,
    required this.callbackZone,
  }) : entryIncarnation = entry.incarnation {
    streamData = _ClientQueryStreamDataController(owner, this);
  }

  final QueryClient owner;
  final QueryEntryInternal entry;
  final ResolvedQueryPlanBase plan;

  @override
  final int id;

  @override
  final int entryIncarnation;

  @override
  final int invalidationRevisionAtStart;

  @override
  bool dependsOnObserverActivity;

  @override
  bool get isTransitioning => false;

  final QueryCancellationController cancellation;
  _QueryRollbackState rollback;
  final QueryCacheCallbacks callbacks;
  final Zone callbackZone;
  late final _ClientQueryStreamDataController streamData;
  final Completer<Object?> _completer = Completer<Object?>();
  ResolvedQueryOperation? resolved;
  _AwaitedQueryCancellation? _awaitedCancellation;
  bool _isSettled = false;

  @override
  bool get isSettled => _isSettled;

  @override
  bool get cancellationWasConsumed => cancellation.wasConsumed;

  @override
  Future<Object?> get future => _completer.future;

  @override
  void retainBeyondObserverActivity() {
    dependsOnObserverActivity = false;
    resumeRetries();
  }

  void rebaseRollbackData() {
    rollback = rollback.rebaseData(entry);
  }

  void attach(ResolvedQueryOperation value) {
    if (_isSettled) {
      value.stopRetries();
    } else {
      resolved = value;
    }
  }

  @override
  void stopRetries() => resolved?.stopRetries();

  @override
  void pauseRetries() => resolved?.pauseRetries();

  @override
  void resumeRetries() => resolved?.resumeRetries();

  @override
  void cancel({required Object reason, required bool revert}) {
    owner._requestClientQueryOperationCancellation(
      this,
      reason: reason,
      revert: revert,
      publish: true,
    );
  }

  void awaitCancellation({
    required Object reason,
    required bool revert,
    required bool publish,
  }) {
    _awaitedCancellation ??= _AwaitedQueryCancellation(
      reason: reason,
      revert: revert,
      publish: publish,
    );
  }

  _AwaitedQueryCancellation? takeAwaitedCancellation() {
    final request = _awaitedCancellation;
    _awaitedCancellation = null;
    return request;
  }

  void finish({
    Object? value,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_isSettled) return;
    _isSettled = true;
    if (error == null) {
      _completer.complete(value);
    } else {
      _completer.completeError(error, stackTrace ?? StackTrace.current);
    }
  }
}

final class _QueryOperationTransition implements QueryOperationInternal {
  _QueryOperationTransition(this.owner, this.entry)
      : entryIncarnation = entry.incarnation,
        invalidationRevisionAtStart = entry.invalidationRevision;

  final QueryClient owner;
  final QueryEntryInternal entry;
  final Completer<Object?> _completer = Completer<Object?>();
  bool _isSettled = false;

  @override
  int get id => -1;

  @override
  final int entryIncarnation;

  @override
  final int invalidationRevisionAtStart;

  @override
  bool get isSettled => _isSettled;

  @override
  bool get cancellationWasConsumed => false;

  @override
  bool get dependsOnObserverActivity => false;

  @override
  bool get isTransitioning => true;

  @override
  Future<Object?> get future => _completer.future;

  void bind(Future<Object?> source) {
    if (_isSettled) return;
    unawaited(
      source.then<void>(
        complete,
        onError: completeError,
      ),
    );
  }

  void complete(Object? value) {
    if (_isSettled) return;
    _isSettled = true;
    _completer.complete(value);
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (_isSettled) return;
    _isSettled = true;
    _completer.completeError(error, stackTrace ?? StackTrace.current);
  }

  @override
  void retainBeyondObserverActivity() {}

  @override
  void stopRetries() {}

  @override
  void pauseRetries() {}

  @override
  void resumeRetries() {}

  @override
  void cancel({required Object reason, required bool revert}) {
    if (identical(entry.operation, this)) {
      entry.operation = null;
      if (!owner.isDisposed &&
          owner.queryCacheControllerInternal.containsEntry(entry)) {
        owner.queryCacheControllerInternal.publish(
          entry,
          QueryCacheEventKind.updated,
        );
        owner._scheduleGc(entry);
      }
    }
    completeError(
      reason is QueryClientDisposedException
          ? reason
          : QueryCancelledException(reason),
    );
  }
}

final class _AwaitedQueryCancellation {
  const _AwaitedQueryCancellation({
    required this.reason,
    required this.revert,
    required this.publish,
  });

  final Object reason;
  final bool revert;
  final bool publish;
}

Future<void> _ignoreQueryCancellation(Future<Object?> future) async {
  try {
    await future;
  } on QueryCancelledException {
    // Cancellation is the requested successful outcome of cancelQueries.
  }
}

final class _ClientQueryStreamDataController
    implements QueryStreamDataControllerInternal {
  _ClientQueryStreamDataController(this.owner, this.operation);

  final QueryClient owner;
  final _ClientQueryOperation operation;
  bool wasUsed = false;

  QueryValue<Object?> get baseline => operation.rollback.data;

  @override
  QueryValue<Object?> beginAttempt(QueryStreamAttemptModeInternal mode) {
    wasUsed = true;
    _guardOwnership();
    final entry = operation.entry;
    if (mode == QueryStreamAttemptModeInternal.reset) {
      if (entry.isFetched) {
        _restoreResetState();
      }
      return entry.data;
    }
    return baseline;
  }

  @override
  void commitPartial(Object? data) {
    _guardOwnership();
    final entry = operation.entry;
    var next = data;
    if (entry.data case QueryPresent<Object?>(:final value)) {
      next = untracked(() => operation.plan.reconcileData(value, next));
    }
    _guardOwnership();
    entry
      ..data = QueryValue<Object?>.present(next)
      ..status = QueryStatus.success
      ..fetchStatus = FetchStatus.fetching
      ..pauseReason = null
      ..failure = null
      ..transientFailure = null
      ..dataUpdatedAt = owner.runtime.clock.wallNow()
      ..dataUpdateCount += 1
      ..recordCompletion()
      ..revision += 1;
    owner.queryCacheControllerInternal.publish(
      entry,
      QueryCacheEventKind.updated,
    );
  }

  bool ensureOwnership() {
    if (!wasUsed) return true;
    return owner._isCurrentQueryOperation(operation);
  }

  void _guardOwnership() {
    if (!ensureOwnership()) {
      throw const QueryCancelledException(_StaleQueryOperationReason());
    }
  }

  void _restoreResetState() {
    final entry = operation.entry;
    final value = entry.initialValue;
    entry
      ..data = value
      ..status = value.isPresent ? QueryStatus.success : QueryStatus.pending
      ..fetchStatus = FetchStatus.fetching
      ..pauseReason = null
      ..failure = null
      ..transientFailure = null
      ..failureCount = 0
      ..dataUpdatedAt = value.isPresent ? entry.initialUpdatedAt : null
      ..failureUpdatedAt = null
      ..dataUpdateCount = 0
      ..failureUpdateCount = 0
      ..visibleCompletionSequence = 0
      ..operationCompletionCount = 0
      ..isInvalidated = false
      ..revision += 1;
    owner.queryCacheControllerInternal.publish(
      entry,
      QueryCacheEventKind.updated,
    );
  }
}

final class _QueryRollbackState {
  const _QueryRollbackState({
    required this.data,
    required this.status,
    required this.fetchStatus,
    required this.pauseReason,
    required this.failure,
    required this.transientFailure,
    required this.failureCount,
    required this.dataUpdatedAt,
    required this.failureUpdatedAt,
    required this.dataUpdateCount,
    required this.failureUpdateCount,
    required this.visibleCompletionSequence,
    required this.revision,
  });

  factory _QueryRollbackState.capture(QueryEntryInternal entry) {
    return _QueryRollbackState(
      data: entry.data,
      status: entry.status,
      fetchStatus: entry.fetchStatus,
      pauseReason: entry.pauseReason,
      failure: entry.failure,
      transientFailure: entry.transientFailure,
      failureCount: entry.failureCount,
      dataUpdatedAt: entry.dataUpdatedAt,
      failureUpdatedAt: entry.failureUpdatedAt,
      dataUpdateCount: entry.dataUpdateCount,
      failureUpdateCount: entry.failureUpdateCount,
      visibleCompletionSequence: entry.visibleCompletionSequence,
      revision: entry.revision,
    );
  }

  _QueryRollbackState rebaseData(QueryEntryInternal entry) {
    return _QueryRollbackState(
      data: entry.data,
      status: entry.status,
      fetchStatus: fetchStatus,
      pauseReason: pauseReason,
      failure: entry.failure,
      transientFailure: transientFailure,
      failureCount: failureCount,
      dataUpdatedAt: entry.dataUpdatedAt,
      failureUpdatedAt: entry.failureUpdatedAt,
      dataUpdateCount: entry.dataUpdateCount,
      failureUpdateCount: entry.failureUpdateCount,
      visibleCompletionSequence: entry.visibleCompletionSequence,
      revision: entry.revision,
    );
  }

  final QueryValue<Object?> data;
  final QueryStatus status;
  final FetchStatus fetchStatus;
  final PauseReason? pauseReason;
  final QueryFailure? failure;
  final QueryFailure? transientFailure;
  final int failureCount;
  final DateTime? dataUpdatedAt;
  final DateTime? failureUpdatedAt;
  final int dataUpdateCount;
  final int failureUpdateCount;
  final int visibleCompletionSequence;
  final int revision;

  void restore(QueryEntryInternal entry) {
    final restoredRevision =
        entry.revision == revision ? revision : entry.revision + 1;
    entry
      ..data = data
      ..status = status
      ..fetchStatus = FetchStatus.idle
      ..pauseReason = null
      ..failure = failure
      ..transientFailure = transientFailure
      ..failureCount = failureCount
      ..dataUpdatedAt = dataUpdatedAt
      ..failureUpdatedAt = failureUpdatedAt
      ..dataUpdateCount = dataUpdateCount
      ..failureUpdateCount = failureUpdateCount
      ..visibleCompletionSequence = visibleCompletionSequence
      ..revision = restoredRevision;
  }
}

QueryValue<T> _typedQueryValue<T>(QueryValue<Object?> value) {
  return switch (value) {
    QueryAbsent<Object?>() => QueryValue<T>.absent(),
    QueryPresent<Object?>(:final value) => QueryValue<T>.present(value as T),
  };
}

QueryValue<Object?> _eraseQueryValue<T>(QueryValue<T> value) {
  return switch (value) {
    QueryAbsent<T>() => const QueryValue<Object?>.absent(),
    QueryPresent<T>(:final value) => QueryValue<Object?>.present(value),
  };
}

final class _ReplacedQueryOperationReason {
  const _ReplacedQueryOperationReason();
}

final class _StaleQueryOperationReason {
  const _StaleQueryOperationReason();
}

final class _FinalQueryObserverDetachedReason {
  const _FinalQueryObserverDetachedReason();
}

final class _ExplicitQueryCancellationReason {
  const _ExplicitQueryCancellationReason();
}

final class _ResetQueryReason {
  const _ResetQueryReason();
}

final class _RemovedQueryReason {
  const _RemovedQueryReason();
}

final class _QueryBatchWork {
  const _QueryBatchWork(this.index, this.entry, this.plan);

  final int index;
  final QueryEntryInternal entry;
  final ResolvedQueryPlanBase plan;
}

final class _QueryDefaultsRegistration {
  const _QueryDefaultsRegistration(this.key, this.defaults);

  final QueryKey? key;
  final QueryDefaults defaults;
}
