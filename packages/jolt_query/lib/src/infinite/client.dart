import 'dart:async';

import 'package:jolt/jolt.dart' show Effect, Readable, Signal;
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../foundation/query_cancellation.dart';
import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import '../query/cache.dart';
import '../query/client.dart';
import '../query/observer.dart';
import '../query/observer_result.dart';
import '../query/policies.dart';
import '../query/recipe.dart';
import '../query/reconciliation.dart';
import '../query/state.dart';
import '../retry/retry_policy.dart';
import 'data.dart';
import 'observer_result.dart';
import 'recipe.dart';

/// Infinite-query operations and observation for [QueryClient].
extension QueryClientInfiniteMethods on QueryClient {
  /// Fetches a fresh complete infinite value, using no implicit retry.
  ///
  /// [pages] controls how many reachable pages are assembled. When omitted, a
  /// refresh preserves the retained page count and an initial fetch requests
  /// one page. An active operation is joined unless [cancelRefetch] is true;
  /// active initial loads always retain single-flight behavior.
  Future<InfiniteData<Page, PageParam>> fetchInfiniteQuery<Page, PageParam>(
    InfiniteQuery<Page, PageParam> query, {
    int? pages,
    StalePolicy? staleTime,
    bool cancelRefetch = false,
  }) async {
    if (pages != null && pages <= 0) {
      throw ArgumentError.value(pages, 'pages', 'pages must be positive.');
    }
    checkActiveInternal();
    final sourcePlan = query.resolved.plan;
    final entry = _prepareInfiniteEntry(
      this,
      query.infinitePlan,
      sourcePlan,
    );
    final defaults = resolveQueryDefaultsInternal(sourcePlan.key);
    final policy =
        staleTime ?? effectiveQueryStalePolicyInternal(sourcePlan, defaults);
    if (entry.data.isPresent && !isQueryEntryStaleInternal(entry, policy)) {
      return _typedInfiniteData<Page, PageParam>(entry);
    }
    final baseline = _rawInfiniteData(entry);
    await _executeInfiniteOperation(
      client: this,
      entry: entry,
      infinitePlan: query.infinitePlan,
      sourcePlan: sourcePlan,
      kind: baseline == null
          ? InfiniteFetchKind.initial
          : InfiniteFetchKind.refresh,
      baseline: baseline,
      pages: pages,
      cancelRefetch: cancelRefetch,
      defaultPolicy: RetryPolicy.none,
      observerOwned: false,
    );
    return _typedInfiniteData<Page, PageParam>(entry);
  }

  /// Warms up to [pages] sequential pages and swallows caller-facing errors.
  Future<void> prefetchInfiniteQuery<Page, PageParam>(
    InfiniteQuery<Page, PageParam> query, {
    int pages = 1,
    StalePolicy? staleTime,
    bool cancelRefetch = false,
  }) async {
    if (pages <= 0) {
      throw ArgumentError.value(pages, 'pages', 'pages must be positive.');
    }
    checkActiveInternal();
    final sourcePlan = query.resolved.plan;
    final entry = _prepareInfiniteEntry(
      this,
      query.infinitePlan,
      sourcePlan,
    );
    final defaults = resolveQueryDefaultsInternal(sourcePlan.key);
    final policy =
        staleTime ?? effectiveQueryStalePolicyInternal(sourcePlan, defaults);
    if (entry.data.isPresent && !isQueryEntryStaleInternal(entry, policy)) {
      return;
    }
    final baseline = _rawInfiniteData(entry);
    try {
      await _executeInfiniteOperation(
        client: this,
        entry: entry,
        infinitePlan: query.infinitePlan,
        sourcePlan: sourcePlan,
        kind: baseline == null
            ? InfiniteFetchKind.initial
            : InfiniteFetchKind.refresh,
        baseline: baseline,
        pages: pages,
        cancelRefetch: cancelRefetch,
        defaultPolicy: RetryPolicy.none,
        observerOwned: false,
      );
    } on Object {
      // Failure is already committed to the ordinary cache entry.
    }
  }

  /// Returns cached infinite data and optionally starts an atomic refresh.
  Future<InfiniteData<Page, PageParam>>
      ensureInfiniteQueryData<Page, PageParam>(
    InfiniteQuery<Page, PageParam> query, {
    StalePolicy? staleTime,
    bool revalidateIfStale = false,
  }) {
    checkActiveInternal();
    final sourcePlan = query.resolved.plan;
    final entry = queryCacheControllerInternal.lookup(sourcePlan.key);
    if (entry == null || entry.data.isAbsent) {
      return fetchInfiniteQuery(query, staleTime: staleTime);
    }
    _retainInfinitePlan(this, entry, query.infinitePlan, sourcePlan);
    final result = _typedInfiniteData<Page, PageParam>(entry);
    final defaults = resolveQueryDefaultsInternal(sourcePlan.key);
    final policy =
        staleTime ?? effectiveQueryStalePolicyInternal(sourcePlan, defaults);
    if (revalidateIfStale && isQueryEntryStaleInternal(entry, policy)) {
      unawaited(
        _executeInfiniteOperation(
          client: this,
          entry: entry,
          infinitePlan: query.infinitePlan,
          sourcePlan: sourcePlan,
          kind: InfiniteFetchKind.refresh,
          baseline: _rawInfiniteData(entry),
          cancelRefetch: false,
          defaultPolicy: RetryPolicy.none,
          observerOwned: false,
        ).then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
    }
    return Future<InfiniteData<Page, PageParam>>.value(result);
  }

  /// Observes one fixed specialized infinite target.
  InfiniteQueryObserver<TView> observeInfiniteQuery<TView>(
    InfiniteQueryTarget<TView> target,
  ) {
    checkActiveInternal();
    final observer = InfiniteQueryObserver<TView>._fixed(this, target);
    return ownDisposableInternal(observer);
  }

  /// Reactively switches to the specialized infinite target returned by [target].
  InfiniteQueryObserver<TView> watchInfiniteQuery<TView>(
    InfiniteQueryTarget<TView> Function() target,
  ) {
    checkActiveInternal();
    final observer = InfiniteQueryObserver<TView>._watched(this, target);
    return ownDisposableInternal(observer);
  }
}

/// A selected reactive view over one shared infinite-query entry.
final class InfiniteQueryObserver<TView>
    implements Readable<InfiniteQueryObserverResult<TView>>, Disposable {
  InfiniteQueryObserver._(this._client)
      : _result = Signal<InfiniteQueryObserverResult<TView>>(
          InfiniteQueryObserverResult<TView>(
            query: QueryObserverResult<TView>(
              key: QueryKey(const <Object?>[]),
              data: QueryValue<TView>.absent(),
              status: QueryStatus.pending,
              fetchStatus: FetchStatus.idle,
            ),
            hasNextPage: false,
            hasPreviousPage: false,
          ),
        );

  factory InfiniteQueryObserver._fixed(
    QueryClient client,
    InfiniteQueryTarget<TView> target,
  ) {
    final observer = InfiniteQueryObserver<TView>._(client);
    observer._switchTarget(target);
    return observer;
  }

  factory InfiniteQueryObserver._watched(
    QueryClient client,
    InfiniteQueryTarget<TView> Function() target,
  ) {
    final observer = InfiniteQueryObserver<TView>._(client);
    observer._targetEffect = Effect(
      () => observer._switchTarget(target()),
      detach: true,
    );
    return observer;
  }

  final QueryClient _client;
  final Signal<InfiniteQueryObserverResult<TView>> _result;

  InfiniteQueryTarget<TView>? _target;
  QueryObserver<TView>? _ordinary;
  Effect? _targetEffect;
  Effect? _presentationEffect;
  int? _entryIncarnation;
  bool _isDisposed = false;

  /// Whether all observer-owned resources have been released.
  bool get isDisposed => _isDisposed;

  /// The current untracked complete result.
  InfiniteQueryObserverResult<TView> get snapshot => _result.peek;

  @override
  InfiniteQueryObserverResult<TView> get peek => _result.peek;

  @override
  InfiniteQueryObserverResult<TView> get value => _result.value;

  /// The currently observed structural key.
  QueryKey get key => value.key;

  /// Selected data with explicit presence.
  QueryValue<TView> get data => value.data;

  /// The canonical query status.
  QueryStatus get status => value.status;

  /// The orthogonal operation status.
  FetchStatus get fetchStatus => value.fetchStatus;

  /// Why work is paused, when applicable.
  PauseReason? get pauseReason => value.pauseReason;

  /// The one canonical query or direction failure.
  QueryFailure? get failure => value.failure;

  /// The latest retryable failure while work continues.
  QueryFailure? get transientFailure => value.transientFailure;

  /// The current operation's number of failed attempts.
  int get failureCount => value.failureCount;

  /// The raw data's latest accepted update time.
  DateTime? get dataUpdatedAt => value.dataUpdatedAt;

  /// The latest terminal or selector failure time.
  DateTime? get failureUpdatedAt => value.failureUpdatedAt;

  /// Whether the underlying entry is explicitly invalidated.
  bool get isInvalidated => value.isInvalidated;

  /// Whether data is stale under this observer's policy.
  bool get isStale => value.isStale;

  /// Whether this observer currently participates in automatic query work.
  bool get isEnabled => value.isEnabled;

  /// Whether selected data is an observer-local placeholder.
  bool get isPlaceholderData => value.isPlaceholderData;

  /// Whether this entry has completed an accepted operation.
  bool get isFetched => value.isFetched;

  /// Whether an operation completed after this observer attached.
  bool get isFetchedAfterMount => value.isFetchedAfterMount;

  /// Whether no accepted data exists yet.
  bool get isPending => value.isPending;

  /// Whether the selected presentation is successful.
  bool get isSuccess => value.isSuccess;

  /// Whether the selected presentation has a terminal failure.
  bool get isError => value.isError;

  /// Whether transport or retry-delay work is active.
  bool get isFetching => value.isFetching;

  /// Whether work is waiting behind an eligibility gate.
  bool get isPaused => value.isPaused;

  /// Whether the absent initial value is loading.
  bool get isLoading => value.isLoading;

  /// Alias for [isLoading].
  bool get isInitialLoading => value.isInitialLoading;

  /// Whether retained data is undergoing a non-directional refresh.
  bool get isRefetching => value.isRefetching;

  /// Whether an initial load failed without retained data.
  bool get isLoadingError => value.isLoadingError;

  /// Whether a refresh failed while retained data remains visible.
  bool get isRefetchError => value.isRefetchError;

  /// Whether a next page is currently available.
  bool get hasNextPage => value.hasNextPage;

  /// Whether a previous page is currently available.
  bool get hasPreviousPage => value.hasPreviousPage;

  /// Whether the shared lane is fetching a next page.
  bool get isFetchingNextPage => value.isFetchingNextPage;

  /// Whether the shared lane is fetching a previous page.
  bool get isFetchingPreviousPage => value.isFetchingPreviousPage;

  /// Whether the latest canonical failure came from a next-page operation.
  bool get isFetchNextPageError => value.isFetchNextPageError;

  /// Whether the latest canonical failure came from a previous-page operation.
  bool get isFetchPreviousPageError => value.isFetchPreviousPageError;

  /// Fetches one available next page through the shared guarded lane.
  Future<InfiniteQueryObserverResult<TView>> fetchNextPage({
    bool cancelRefetch = true,
  }) {
    return _fetchDirection(
      InfiniteDirection.forward,
      cancelRefetch: cancelRefetch,
    );
  }

  /// Fetches one available previous page through the shared guarded lane.
  Future<InfiniteQueryObserverResult<TView>> fetchPreviousPage({
    bool cancelRefetch = true,
  }) {
    return _fetchDirection(
      InfiniteDirection.backward,
      cancelRefetch: cancelRefetch,
    );
  }

  /// Atomically refreshes the retained reachable page set.
  Future<InfiniteQueryObserverResult<TView>> refetch({
    bool cancelRefetch = true,
  }) async {
    _checkActive();
    final ordinary = _ordinary!;
    await ordinary.refetch(cancelRefetch: cancelRefetch);
    if (!_isDisposed && identical(_ordinary, ordinary)) {
      _commit(_derive(ordinary.peek));
    }
    return _result.peek;
  }

  Future<InfiniteQueryObserverResult<TView>> _fetchDirection(
    InfiniteDirection direction, {
    required bool cancelRefetch,
  }) async {
    _checkActive();
    final ordinary = _ordinary!;
    final entry = ordinary.entryInternal;
    final target = _target!;
    final fallback = _result.peek;
    final baseline = _rawInfiniteData(entry);
    if (baseline != null) {
      final cursor = switch (direction) {
        InfiniteDirection.forward =>
          target.infinitePlan.getNextPageParamObject(baseline),
        InfiniteDirection.backward =>
          target.infinitePlan.getPreviousPageParamObject(baseline),
      };
      if (_isDisposed) return fallback;
      if (!_isCurrentDirectionTarget(ordinary, target, entry)) {
        return _result.peek;
      }
      if (cursor.isEnd) return _result.peek;
    }
    if (!_isCurrentDirectionTarget(ordinary, target, entry)) {
      return _result.peek;
    }
    await _runObserverOperation(
      ordinary,
      entry,
      target: target,
      kind: baseline == null
          ? InfiniteFetchKind.initial
          : direction == InfiniteDirection.forward
              ? InfiniteFetchKind.next
              : InfiniteFetchKind.previous,
      baseline: baseline,
      cancelRefetch: cancelRefetch,
      requestedDirection: direction,
    );
    return _result.peek;
  }

  Future<void> _runObserverOperation(
    QueryObserver<TView> ordinary,
    QueryEntryInternal entry, {
    required InfiniteQueryTarget<TView> target,
    required InfiniteFetchKind kind,
    required Object? baseline,
    required bool cancelRefetch,
    InfiniteDirection? requestedDirection,
  }) async {
    if (!_isCurrentDirectionTarget(ordinary, target, entry)) return;
    final pending = _executeInfiniteOperation(
      client: _client,
      entry: entry,
      infinitePlan: target.infinitePlan,
      sourcePlan: target.resolved.plan,
      kind: kind,
      baseline: baseline,
      cancelRefetch: cancelRefetch,
      defaultPolicy: RetryPolicy.standard,
      observerOwned: true,
      requestedDirection: requestedDirection,
    );
    if (!_isDisposed && identical(_ordinary, ordinary)) {
      ordinary.refreshInternal();
      _commit(_derive(ordinary.peek));
    }
    try {
      await pending;
    } on Object {
      // The ordinary entry owns and presents operation failures.
    }
    if (_isDisposed || !identical(_ordinary, ordinary)) return;
    ordinary.refreshInternal();
    _commit(_derive(ordinary.peek));
  }

  bool _isCurrentDirectionTarget(
    QueryObserver<TView> ordinary,
    InfiniteQueryTarget<TView> target,
    QueryEntryInternal entry,
  ) {
    return !_isDisposed &&
        identical(_ordinary, ordinary) &&
        identical(_target, target) &&
        identical(ordinary.entryInternal, entry);
  }

  void _switchTarget(InfiniteQueryTarget<TView> target) {
    if (_isDisposed) return;
    _client.checkActiveInternal();
    final previousOrdinary = _ordinary;
    final resolved = target.resolved;
    _target = target;
    if (previousOrdinary != null) {
      previousOrdinary.updateResolvedTargetInternal(resolved);
      final entry = previousOrdinary.entryInternal;
      _entryIncarnation = entry.incarnation;
      _retainInfinitePlan(
        _client,
        entry,
        target.infinitePlan,
        resolved.plan,
      );
      previousOrdinary.refreshInternal();
      _commit(_derive(previousOrdinary.peek));
      return;
    }

    final ordinary = _client.observeResolvedQueryInternal(
      resolved,
      fetchDelegate: _fetchWholeWindow,
    );
    _ordinary = ordinary;
    final entry = ordinary.entryInternal;
    _entryIncarnation = entry.incarnation;
    _retainInfinitePlan(
      _client,
      entry,
      target.infinitePlan,
      resolved.plan,
    );
    _presentationEffect = Effect(
      () {
        final ordinaryResult = ordinary.value;
        if (_isDisposed || !identical(_ordinary, ordinary)) return;
        final entry = ordinary.entryInternal;
        final incarnation = entry.incarnation;
        if (_entryIncarnation != incarnation) {
          _entryIncarnation = incarnation;
          final currentTarget = _target!;
          _retainInfinitePlan(
            _client,
            entry,
            currentTarget.infinitePlan,
            currentTarget.resolved.plan,
          );
        }
        _commit(_derive(ordinaryResult));
      },
      detach: true,
    );
  }

  Future<Object?> _fetchWholeWindow(
    QueryEntryInternal entry,
    ResolvedQueryTarget<TView> resolved, {
    required bool cancelRefetch,
  }) {
    final target = _target!;
    final baseline = _rawInfiniteData(entry);
    return _executeInfiniteOperation(
      client: _client,
      entry: entry,
      infinitePlan: target.infinitePlan,
      sourcePlan: resolved.plan,
      kind: baseline == null
          ? InfiniteFetchKind.initial
          : InfiniteFetchKind.refresh,
      baseline: baseline,
      cancelRefetch: cancelRefetch,
      defaultPolicy: RetryPolicy.standard,
      observerOwned: true,
    );
  }

  InfiniteQueryObserverResult<TView> _derive(
    QueryObserverResult<TView> ordinary,
  ) {
    final target = _target;
    final observer = _ordinary;
    if (target == null || observer == null) {
      return InfiniteQueryObserverResult<TView>(
        query: ordinary,
        hasNextPage: false,
        hasPreviousPage: false,
      );
    }
    final entry = observer.entryInternal;
    final raw = _rawInfiniteData(entry);
    final state = _infiniteOperationStates[entry];
    final activeDirection = entry.operation != null &&
            identical(entry.operation, state?.directionOperation)
        ? state?.activeDirection
        : null;
    final failedDirection = _directionOfFailure(
      entry,
      ordinary,
      state,
    );
    return InfiniteQueryObserverResult<TView>(
      query: ordinary,
      hasNextPage:
          raw != null && target.infinitePlan.getNextPageParamObject(raw).isMore,
      hasPreviousPage: raw != null &&
          target.infinitePlan.getPreviousPageParamObject(raw).isMore,
      isFetchingNextPage:
          ordinary.isFetching && activeDirection == InfiniteDirection.forward,
      isFetchingPreviousPage:
          ordinary.isFetching && activeDirection == InfiniteDirection.backward,
      isFetchNextPageError: ordinary.failure != null &&
          failedDirection == InfiniteDirection.forward,
      isFetchPreviousPageError: ordinary.failure != null &&
          failedDirection == InfiniteDirection.backward,
    );
  }

  void _commit(InfiniteQueryObserverResult<TView> next) {
    final previous = _result.peek;
    if (identical(previous.query, next.query) &&
        previous.hasNextPage == next.hasNextPage &&
        previous.hasPreviousPage == next.hasPreviousPage &&
        previous.isFetchingNextPage == next.isFetchingNextPage &&
        previous.isFetchingPreviousPage == next.isFetchingPreviousPage &&
        previous.isFetchNextPageError == next.isFetchNextPageError &&
        previous.isFetchPreviousPageError == next.isFetchPreviousPageError) {
      return;
    }
    _result.value = next;
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('InfiniteQueryObserver is disposed.');
    _client.checkActiveInternal();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _targetEffect?.dispose();
    _targetEffect = null;
    _presentationEffect?.dispose();
    _presentationEffect = null;
    _ordinary?.dispose();
    _ordinary = null;
    _client.releaseDisposableInternal(this);
    _result.dispose();
  }
}

final Expando<_InfiniteOperationState> _infiniteOperationStates =
    Expando<_InfiniteOperationState>('jolt_query.infinite.operation');

final class _InfiniteOperationState {
  int generation = 0;

  // Active direction is valid only while the entry still owns this exact lane.
  // Bulk lifecycle work bypasses _executeInfiniteOperation and replaces it.
  InfiniteDirection? activeDirection;
  QueryOperationInternal? directionOperation;

  // Terminal provenance survives later fetch starts so cancellation rollback
  // can reveal the restored canonical failure without another side publish.
  InfiniteDirection? failedDirection;
  QueryFailure? directionFailure;

  // The result wrapper fills these before the ordinary query publishes its
  // terminal failure; the canonical QueryFailure is available only afterward.
  InfiniteDirection? terminalDirection;
  Object? terminalError;
}

InfiniteDirection? _directionOfFailure<TView>(
  QueryEntryInternal entry,
  QueryObserverResult<TView> ordinary,
  _InfiniteOperationState? state,
) {
  final failure = ordinary.failure;
  if (failure == null || state == null || !identical(failure, entry.failure)) {
    return null;
  }
  if (entry.operation != null) {
    return identical(entry.operation, state.directionOperation)
        ? state.activeDirection
        : null;
  }
  if (state.terminalDirection != null &&
      identical(failure.error, state.terminalError)) {
    return state.terminalDirection;
  }
  if (identical(failure, state.directionFailure)) {
    return state.failedDirection;
  }
  return null;
}

QueryEntryInternal _prepareInfiniteEntry(
  QueryClient client,
  ResolvedInfiniteQueryPlanBase infinitePlan,
  ResolvedQueryPlanBase sourcePlan,
) {
  final entry = client.queryCacheControllerInternal.getOrCreate(sourcePlan.key);
  _retainInfinitePlan(client, entry, infinitePlan, sourcePlan);
  return entry;
}

void _retainInfinitePlan(
  QueryClient client,
  QueryEntryInternal entry,
  ResolvedInfiniteQueryPlanBase infinitePlan,
  ResolvedQueryPlanBase sourcePlan,
) {
  final retainedPlan = infinitePlan.createLifecyclePlan(
    sourcePlan: sourcePlan,
    readBaseline: () => _rawInfiniteData(entry),
  );
  entry
    ..retainedPlan = retainedPlan
    ..receiveRetention(
      client.effectiveQueryRetentionPolicyInternal(sourcePlan),
    );
  client.refreshQueryGcInternal(entry);
}

Object? _rawInfiniteData(QueryEntryInternal entry) {
  return switch (entry.data) {
    QueryAbsent<Object?>() => null,
    QueryPresent<Object?>(:final value) => value,
  };
}

InfiniteData<Page, PageParam> _typedInfiniteData<Page, PageParam>(
  QueryEntryInternal entry,
) {
  return entry.data.requireValue() as InfiniteData<Page, PageParam>;
}

Future<Object?> _executeInfiniteOperation({
  required QueryClient client,
  required QueryEntryInternal entry,
  required ResolvedInfiniteQueryPlanBase infinitePlan,
  required ResolvedQueryPlanBase sourcePlan,
  required InfiniteFetchKind kind,
  required Object? baseline,
  int? pages,
  required bool cancelRefetch,
  required RetryPolicy<Never> defaultPolicy,
  required bool observerOwned,
  InfiniteDirection? requestedDirection,
}) async {
  client.checkActiveInternal();
  if (entry.key != sourcePlan.key) {
    throw StateError(
      'An infinite operation cannot execute a plan for a different key.',
    );
  }
  final active = entry.operation;
  if (active != null) {
    if (active.isTransitioning) return active.future;
    if (!cancelRefetch || entry.data.isAbsent) {
      if (!observerOwned) active.retainBeyondObserverActivity();
      return active.future;
    }
  }

  final state = _infiniteOperationStates[entry] ??= _InfiniteOperationState();
  final canonicalFailureAtStart = entry.failure;
  final generation = ++state.generation;
  final direction = requestedDirection ??
      switch (kind) {
        InfiniteFetchKind.next => InfiniteDirection.forward,
        InfiniteFetchKind.previous => InfiniteDirection.backward,
        _ => null,
      };
  state
    ..activeDirection = direction
    ..directionOperation = null
    ..terminalDirection = null
    ..terminalError = null;
  ResolvedQueryPlanBase? operationPlan;
  ResolvedQueryPlanBase? executedPlan;
  try {
    operationPlan = infinitePlan.createFetchPlan(
      sourcePlan: sourcePlan,
      kind: kind,
      baseline: baseline,
      pages: pages,
    );
    executedPlan = direction == null
        ? operationPlan
        : _InfiniteDirectionalQueryPlan(
            source: operationPlan,
            onTerminalFailure: (error) {
              if (state.generation != generation ||
                  error is QueryCancelledException) {
                return;
              }
              state
                ..terminalDirection = direction
                ..terminalError = error;
            },
          );
    final pending = client.executeQueryPlanInternal(
      entry,
      executedPlan,
      cancelRefetch: cancelRefetch,
      defaultPolicy: defaultPolicy,
      observerOwned: observerOwned,
    );
    if (state.generation == generation && direction != null) {
      state.directionOperation = entry.operation;
    }
    if (identical(entry.retainedPlan, executedPlan) &&
        client.queryCacheControllerInternal.containsEntry(entry)) {
      _retainInfinitePlan(client, entry, infinitePlan, sourcePlan);
    }
    final result = await pending;
    if (state.generation == generation) {
      state
        ..failedDirection = null
        ..directionFailure = null;
    }
    return result;
  } catch (error) {
    if (state.generation == generation &&
        error is! QueryCancelledException &&
        entry.failure != null &&
        !identical(entry.failure, canonicalFailureAtStart) &&
        direction != null) {
      state
        ..failedDirection = direction
        ..directionFailure = entry.failure;
    } else if (state.generation == generation &&
        error is! QueryCancelledException &&
        !identical(entry.failure, canonicalFailureAtStart)) {
      state
        ..failedDirection = null
        ..directionFailure = null;
    }
    rethrow;
  } finally {
    if (state.generation == generation) {
      state
        ..activeDirection = null
        ..directionOperation = null
        ..terminalDirection = null
        ..terminalError = null;
    }
    if (executedPlan != null &&
        identical(entry.retainedPlan, executedPlan) &&
        client.queryCacheControllerInternal.containsEntry(entry)) {
      _retainInfinitePlan(client, entry, infinitePlan, sourcePlan);
    }
  }
}

final class _InfiniteDirectionalQueryPlan extends ResolvedQueryPlanBase {
  const _InfiniteDirectionalQueryPlan({
    required this.source,
    required this.onTerminalFailure,
  });

  final ResolvedQueryPlanBase source;
  final void Function(Object error) onTerminalFailure;

  @override
  QueryKey get key => source.key;

  @override
  RetryPolicyBase? get configuredRetry => source.configuredRetry;

  @override
  NetworkMode get networkMode => source.networkMode;

  @override
  bool get hasExplicitNetworkMode => source.hasExplicitNetworkMode;

  @override
  StalePolicy get stalePolicy => source.stalePolicy;

  @override
  bool get hasExplicitStalePolicy => source.hasExplicitStalePolicy;

  @override
  RetentionPolicy get retentionPolicy => source.retentionPolicy;

  @override
  bool get hasExplicitRetentionPolicy => source.hasExplicitRetentionPolicy;

  @override
  Map<String, Object?> get metadata => source.metadata;

  @override
  DataReconcilerBase get reconciler => source.reconciler;

  @override
  FutureOr<Object?> fetch(QueryContext context) => source.fetch(context);

  @override
  ResolvedQueryOperation createOperation(QueryPlanExecution execution) {
    final operation = source.createOperation(execution);
    return _InfiniteDirectionalQueryOperation(
      source: operation,
      result: _captureTerminalFailure(
        operation.result,
        onTerminalFailure,
      ),
    );
  }

  @override
  Object? reconcileData(Object? previous, Object? next) {
    return source.reconcileData(previous, next);
  }
}

final class _InfiniteDirectionalQueryOperation
    implements ResolvedQueryOperation {
  const _InfiniteDirectionalQueryOperation({
    required this.source,
    required this.result,
  });

  final ResolvedQueryOperation source;

  @override
  final Future<Object?> result;

  @override
  void stopRetries() => source.stopRetries();

  @override
  void pauseRetries() => source.pauseRetries();

  @override
  void resumeRetries() => source.resumeRetries();
}

Future<Object?> _captureTerminalFailure(
  Future<Object?> result,
  void Function(Object error) onTerminalFailure,
) async {
  try {
    return await result;
  } catch (error) {
    onTerminalFailure(error);
    rethrow;
  }
}
