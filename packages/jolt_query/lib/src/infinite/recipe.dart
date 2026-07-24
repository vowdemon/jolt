import 'dart:async';

import 'package:meta/meta.dart' show internal, nonVirtual;
import 'package:retry_plus/retry_plus.dart' show RetryStrategy;

import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import '../query/client.dart';
import '../query/observer_result.dart';
import '../query/policies.dart';
import '../query/recipe.dart';
import '../query/reconciliation.dart';
import '../retry/retry_policy.dart';
import 'data.dart';

/// Fetches one page using its typed parameter and ordinary query capabilities.
typedef InfinitePageFunction<Page, PageParam> = FutureOr<Page> Function(
  InfinitePageContext<PageParam> context,
);

/// Resolves whether another page exists from the complete aligned data.
typedef InfinitePageParamResolver<Page, PageParam> = PageCursor<PageParam>
    Function(InfiniteData<Page, PageParam> data);

/// The complete-data operation assembled for an ordinary query lane.
enum InfiniteFetchKind {
  /// Fetches a new chain from the configured initial parameter.
  initial,

  /// Rebuilds the retained window from its first retained parameter.
  refresh,

  /// Appends one page using the current next cursor.
  next,

  /// Prepends one page using the current previous cursor.
  previous,
}

/// Erased package boundary retained by specialized infinite targets.
///
/// Its ordinary query data type is always a complete [InfiniteData], never one
/// page. Directional runtimes use the object methods without leaking page
/// generics after selection.
abstract base class ResolvedInfiniteQueryPlanBase {
  const ResolvedInfiniteQueryPlanBase();

  /// Initial page parameter, including a valid `null` value.
  Object? get initialPageParamObject;

  /// Maximum retained pages, or `null` when unbounded.
  int? get maxPages;

  /// Fetches one typed page through the erased runtime boundary.
  FutureOr<Object?> fetchPageObject({
    required Object? pageParam,
    required InfiniteDirection direction,
    required QueryContext queryContext,
  });

  /// Resolves the next cursor from complete raw data.
  PageCursor<Object?> getNextPageParamObject(Object? data);

  /// Resolves the previous cursor from complete raw data.
  PageCursor<Object?> getPreviousPageParamObject(Object? data);

  /// Creates an ordinary whole-data plan for one infinite operation.
  ResolvedQueryPlanBase createFetchPlan({
    required ResolvedQueryPlanBase sourcePlan,
    required InfiniteFetchKind kind,
    Object? baseline,
    int? pages,
  });

  /// Creates the retained ordinary plan used by bulk lifecycle operations.
  ResolvedQueryPlanBase createLifecyclePlan({
    required ResolvedQueryPlanBase sourcePlan,
    required Object? Function() readBaseline,
  });
}

/// Immutable typed directional behavior captured from an infinite recipe.
final class ResolvedInfiniteQueryPlan<Page, PageParam>
    extends ResolvedInfiniteQueryPlanBase {
  /// Creates a typed resolved infinite plan.
  ResolvedInfiniteQueryPlan({
    required this.initialPageParam,
    required this.fetchPage,
    required this.getNextPageParam,
    required this.getPreviousPageParam,
    this.maxPages,
  }) {
    _validateMaxPages(maxPages);
  }

  /// Parameter used by the first fetch.
  final PageParam initialPageParam;

  /// Performs one page attempt.
  final InfinitePageFunction<Page, PageParam> fetchPage;

  /// Resolves forward pagination from the whole aligned value.
  final InfinitePageParamResolver<Page, PageParam> getNextPageParam;

  /// Resolves backward pagination from the whole aligned value.
  final InfinitePageParamResolver<Page, PageParam> getPreviousPageParam;

  @override
  final int? maxPages;

  @override
  Object? get initialPageParamObject => initialPageParam;

  /// Builds the complete initial raw value for one ordinary query attempt.
  ///
  /// A page-level validation failure must be thrown by [fetchPage]. The throw
  /// then belongs to the ordinary whole-[InfiniteData] retry operation.
  Future<InfiniteData<Page, PageParam>> fetchInitial(
    QueryContext queryContext,
  ) async {
    final page = await fetchPage(
      InfinitePageContext<PageParam>(
        pageParam: initialPageParam,
        direction: InfiniteDirection.forward,
        queryContext: queryContext,
      ),
    );
    queryContext.ensureOperationCurrentInternal();
    return InfiniteData<Page, PageParam>(
      pages: <Page>[page],
      pageParams: <PageParam>[initialPageParam],
    );
  }

  @override
  FutureOr<Object?> fetchPageObject({
    required Object? pageParam,
    required InfiniteDirection direction,
    required QueryContext queryContext,
  }) {
    return fetchPage(
      InfinitePageContext<PageParam>(
        pageParam: pageParam as PageParam,
        direction: direction,
        queryContext: queryContext,
      ),
    );
  }

  @override
  PageCursor<Object?> getNextPageParamObject(Object? data) {
    return getNextPageParam(data as InfiniteData<Page, PageParam>);
  }

  @override
  PageCursor<Object?> getPreviousPageParamObject(Object? data) {
    return getPreviousPageParam(data as InfiniteData<Page, PageParam>);
  }

  @override
  ResolvedQueryPlan<InfiniteData<Page, PageParam>> createFetchPlan({
    required ResolvedQueryPlanBase sourcePlan,
    required InfiniteFetchKind kind,
    Object? baseline,
    int? pages,
  }) {
    if (pages != null && pages <= 0) {
      throw ArgumentError.value(pages, 'pages', 'pages must be positive.');
    }
    final typedSource =
        sourcePlan as ResolvedQueryPlan<InfiniteData<Page, PageParam>>;
    final typedBaseline = switch (kind) {
      InfiniteFetchKind.initial => null,
      _ => baseline as InfiniteData<Page, PageParam>,
    };
    final attempt = _InfiniteFetchAttempt<Page, PageParam>(
      owner: this,
      kind: kind,
      baseline: typedBaseline,
      pages: pages,
    );
    return ResolvedQueryPlan<InfiniteData<Page, PageParam>>(
      key: typedSource.key,
      fetch: attempt.execute,
      configuredRetry: typedSource.configuredRetry,
      networkMode: typedSource.networkMode,
      hasExplicitNetworkMode: typedSource.hasExplicitNetworkMode,
      stalePolicy: typedSource.stalePolicy,
      hasExplicitStalePolicy: typedSource.hasExplicitStalePolicy,
      retentionPolicy: typedSource.retentionPolicy,
      hasExplicitRetentionPolicy: typedSource.hasExplicitRetentionPolicy,
      metadata: typedSource.metadata,
      reconciler: typedSource.reconciler,
    );
  }

  @override
  ResolvedQueryPlan<InfiniteData<Page, PageParam>> createLifecyclePlan({
    required ResolvedQueryPlanBase sourcePlan,
    required Object? Function() readBaseline,
  }) {
    final typedSource =
        sourcePlan as ResolvedQueryPlan<InfiniteData<Page, PageParam>>;
    final attempt = _InfiniteLifecycleFetchAttempt<Page, PageParam>(
      owner: this,
      readBaseline: () => readBaseline() as InfiniteData<Page, PageParam>?,
    );
    return ResolvedQueryPlan<InfiniteData<Page, PageParam>>(
      key: typedSource.key,
      fetch: attempt.execute,
      configuredRetry: typedSource.configuredRetry,
      networkMode: typedSource.networkMode,
      hasExplicitNetworkMode: typedSource.hasExplicitNetworkMode,
      stalePolicy: typedSource.stalePolicy,
      hasExplicitStalePolicy: typedSource.hasExplicitStalePolicy,
      retentionPolicy: typedSource.retentionPolicy,
      hasExplicitRetentionPolicy: typedSource.hasExplicitRetentionPolicy,
      metadata: typedSource.metadata,
      reconciler: typedSource.reconciler,
    );
  }

  /// Fetches up to [pages] pages sequentially from [initialPageParam].
  Future<InfiniteData<Page, PageParam>> fetchPages(
    QueryContext queryContext, {
    int pages = 1,
  }) {
    if (pages <= 0) {
      throw ArgumentError.value(pages, 'pages', 'pages must be positive.');
    }
    return _InfiniteFetchAttempt<Page, PageParam>(
      owner: this,
      kind: InfiniteFetchKind.initial,
      pages: pages,
    ).execute(queryContext);
  }

  /// Atomically rebuilds the retained window from its first page parameter.
  ///
  /// An empty retained value falls back to [initialPageParam]. A bounded value
  /// therefore keeps its current cursor window instead of jumping back to the
  /// recipe's original beginning.
  Future<InfiniteData<Page, PageParam>> refresh(
    InfiniteData<Page, PageParam> baseline,
    QueryContext queryContext,
  ) {
    return _InfiniteFetchAttempt<Page, PageParam>(
      owner: this,
      kind: InfiniteFetchKind.refresh,
      baseline: baseline,
    ).execute(queryContext);
  }

  /// Builds one directional addition without mutating [baseline].
  Future<InfiniteData<Page, PageParam>> fetchDirection(
    InfiniteData<Page, PageParam> baseline,
    InfiniteDirection direction,
    QueryContext queryContext,
  ) {
    return _InfiniteFetchAttempt<Page, PageParam>(
      owner: this,
      kind: direction == InfiniteDirection.forward
          ? InfiniteFetchKind.next
          : InfiniteFetchKind.previous,
      baseline: baseline,
    ).execute(queryContext);
  }

  InfiniteData<Page, PageParam> _emptyData() {
    return InfiniteData<Page, PageParam>(
      pages: <Page>[],
      pageParams: <PageParam>[],
    );
  }

  InfiniteData<Page, PageParam> _addPage(
    InfiniteData<Page, PageParam> data, {
    required Page page,
    required PageParam pageParam,
    required InfiniteDirection direction,
  }) {
    final pages = data.pages.toList(growable: true);
    final pageParams = data.pageParams.toList(growable: true);
    switch (direction) {
      case InfiniteDirection.forward:
        pages.add(page);
        pageParams.add(pageParam);
      case InfiniteDirection.backward:
        pages.insert(0, page);
        pageParams.insert(0, pageParam);
    }
    final maximum = maxPages;
    if (maximum != null) {
      while (pages.length > maximum) {
        switch (direction) {
          case InfiniteDirection.forward:
            pages.removeAt(0);
            pageParams.removeAt(0);
          case InfiniteDirection.backward:
            pages.removeLast();
            pageParams.removeLast();
        }
      }
    }
    return InfiniteData<Page, PageParam>(
      pages: pages,
      pageParams: pageParams,
    );
  }
}

/// One stateful whole-data retry attempt.
///
/// The ordinary retry executor invokes the same fetch closure for each retry.
/// Progress therefore remains after a thrown page attempt, so the next retry
/// resumes at that page. A successfully returned complete value resets this
/// state before result-based retry policy is evaluated; if policy rejects that
/// value, the next invocation deliberately rebuilds the whole chain.
final class _InfiniteFetchAttempt<Page, PageParam> {
  _InfiniteFetchAttempt({
    required this.owner,
    required this.kind,
    this.baseline,
    this.pages,
  });

  final ResolvedInfiniteQueryPlan<Page, PageParam> owner;
  final InfiniteFetchKind kind;
  final InfiniteData<Page, PageParam>? baseline;
  final int? pages;

  bool _initialized = false;
  late InfiniteData<Page, PageParam> _working;
  late PageParam _pageParam;
  late int _targetPageCount;
  int _completedPageCount = 0;
  bool _needsNextCursor = false;
  bool _directionCursorResolved = false;
  bool _directionEnded = false;

  Future<InfiniteData<Page, PageParam>> execute(
    QueryContext queryContext,
  ) async {
    if (!_initialized) _initialize();
    try {
      final result = switch (kind) {
        InfiniteFetchKind.initial ||
        InfiniteFetchKind.refresh =>
          await _executeChain(queryContext),
        InfiniteFetchKind.next => await _executeDirection(
            InfiniteDirection.forward,
            queryContext,
          ),
        InfiniteFetchKind.previous => await _executeDirection(
            InfiniteDirection.backward,
            queryContext,
          ),
      };
      _initialized = false;
      return result;
    } catch (_) {
      // Keep successfully assembled pages and the failed page parameter. The
      // ordinary retry executor will call this same attempt again.
      rethrow;
    }
  }

  void _initialize() {
    _initialized = true;
    _completedPageCount = 0;
    _needsNextCursor = false;
    _directionCursorResolved = false;
    _directionEnded = false;
    switch (kind) {
      case InfiniteFetchKind.initial:
        _working = owner._emptyData();
        _pageParam = owner.initialPageParam;
        _targetPageCount = pages ?? 1;
      case InfiniteFetchKind.refresh:
        final retained = baseline!;
        _working = owner._emptyData();
        _pageParam = retained.isEmpty
            ? owner.initialPageParam
            : retained.pageParams.first;
        _targetPageCount = pages ?? (retained.isEmpty ? 1 : retained.length);
      case InfiniteFetchKind.next:
      case InfiniteFetchKind.previous:
        _working = baseline!;
        _targetPageCount = 1;
    }
  }

  Future<InfiniteData<Page, PageParam>> _executeChain(
    QueryContext queryContext,
  ) async {
    while (_completedPageCount < _targetPageCount) {
      queryContext.ensureOperationCurrentInternal();
      if (_needsNextCursor) {
        final cursor = owner.getNextPageParam(_working);
        queryContext.ensureOperationCurrentInternal();
        switch (cursor) {
          case PageCursorEnd():
            return _working;
          case PageCursorMore<PageParam>(pageParam: final nextPageParam):
            _pageParam = nextPageParam;
            _needsNextCursor = false;
        }
      }

      queryContext.ensureOperationCurrentInternal();
      final page = await owner.fetchPage(
        InfinitePageContext<PageParam>(
          pageParam: _pageParam,
          direction: InfiniteDirection.forward,
          queryContext: queryContext,
        ),
      );
      queryContext.ensureOperationCurrentInternal();
      _working = owner._addPage(
        _working,
        page: page,
        pageParam: _pageParam,
        direction: InfiniteDirection.forward,
      );
      _completedPageCount += 1;
      _needsNextCursor = _completedPageCount < _targetPageCount;
    }
    return _working;
  }

  Future<InfiniteData<Page, PageParam>> _executeDirection(
    InfiniteDirection direction,
    QueryContext queryContext,
  ) async {
    queryContext.ensureOperationCurrentInternal();
    if (!_directionCursorResolved) {
      final cursor = switch (direction) {
        InfiniteDirection.forward => owner.getNextPageParam(_working),
        InfiniteDirection.backward => owner.getPreviousPageParam(_working),
      };
      queryContext.ensureOperationCurrentInternal();
      switch (cursor) {
        case PageCursorEnd():
          _directionEnded = true;
        case PageCursorMore<PageParam>(:final pageParam):
          _pageParam = pageParam;
      }
      _directionCursorResolved = true;
    }
    if (_directionEnded) return _working;

    queryContext.ensureOperationCurrentInternal();
    final page = await owner.fetchPage(
      InfinitePageContext<PageParam>(
        pageParam: _pageParam,
        direction: direction,
        queryContext: queryContext,
      ),
    );
    queryContext.ensureOperationCurrentInternal();
    return owner._addPage(
      _working,
      page: page,
      pageParam: _pageParam,
      direction: direction,
    );
  }
}

/// Recreates state for each logical operation while preserving retry progress.
///
/// Retained lifecycle plans can serve many invalidation/refetch operations. A
/// cancellation token has operation identity and remains stable across that
/// operation's retries, so it safely separates those uses.
final class _InfiniteLifecycleFetchAttempt<Page, PageParam> {
  _InfiniteLifecycleFetchAttempt({
    required this.owner,
    required this.readBaseline,
  });

  final ResolvedInfiniteQueryPlan<Page, PageParam> owner;
  final InfiniteData<Page, PageParam>? Function() readBaseline;

  Object? _operationToken;
  _InfiniteFetchAttempt<Page, PageParam>? _attempt;

  Future<InfiniteData<Page, PageParam>> execute(
    QueryContext queryContext,
  ) {
    if (!identical(_operationToken, queryContext.cancellationToken)) {
      _operationToken = queryContext.cancellationToken;
      final retained = readBaseline();
      _attempt = _InfiniteFetchAttempt<Page, PageParam>(
        owner: owner,
        kind: retained == null
            ? InfiniteFetchKind.initial
            : InfiniteFetchKind.refresh,
        baseline: retained,
      );
    }
    return _attempt!.execute(queryContext);
  }
}

/// Observable terminal stage for an infinite selected view.
sealed class InfiniteQueryTarget<TView> implements AnyQueryTarget {
  const InfiniteQueryTarget({QueryClient? client}) : _configuredClient = client;

  final QueryClient? _configuredClient;

  @override
  QueryClient get client => _configuredClient ?? QueryClient.defaultClient;

  _InfiniteTargetBundle<TView> get _bundle;

  /// Directional raw plan retained independently of selected [TView].
  @internal
  ResolvedInfiniteQueryPlanBase get infinitePlan => _bundle.infinitePlan;

  @override
  @internal
  ResolvedQueryTarget<TView> get resolved => _bundle.target.resolved;

  @override
  QueryKey get key => resolved.plan.key;

  /// Applies observer-local behavior and returns a terminal infinite target.
  InfiniteQueryTarget<TView> withObserver({
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
    QueryDataEquality<TView>? equality,
  }) {
    final current = _bundle;
    return _TerminalInfiniteQueryTarget<TView>(
      _InfiniteTargetBundle<TView>(
        target: current.target.withObserver(
          enabled: enabled,
          staleTime: staleTime,
          refetchOnMount: refetchOnMount,
          refetchOnFocus: refetchOnFocus,
          refetchOnReconnect: refetchOnReconnect,
          retryOnMount: retryOnMount,
          pollingInterval: pollingInterval,
          pollingIntervalResolver: pollingIntervalResolver,
          pollingEnabled: pollingEnabled,
          pollInBackground: pollInBackground,
          equality: equality,
        ),
        infinitePlan: current.infinitePlan,
      ),
      client: _configuredClient,
    );
  }

  /// Uses an explicit observer-local placeholder value.
  InfiniteQueryTarget<TView> withPlaceholderData(TView data) {
    return withPlaceholder((previous) => QueryValue<TView>.present(data));
  }

  /// Derives observer-local placeholder presence.
  InfiniteQueryTarget<TView> withPlaceholder(
    QueryPlaceholderResolver<TView> resolve,
  ) {
    final current = _bundle;
    return _TerminalInfiniteQueryTarget<TView>(
      _InfiniteTargetBundle<TView>(
        target: current.target.withPlaceholder(resolve),
        infinitePlan: current.infinitePlan,
      ),
      client: _configuredClient,
    );
  }
}

/// Select-capable infinite view that retains directional raw behavior.
sealed class InfiniteQueryView<TView> extends InfiniteQueryTarget<TView> {
  const InfiniteQueryView({super.client});

  @override
  _InfiniteViewBundle<TView> get _bundle;

  /// Selects this view without exposing its Page or PageParam types.
  InfiniteQueryView<TNext> select<TNext>(
    TNext Function(TView value) selector,
  ) {
    final current = _bundle;
    return _SelectedInfiniteQueryView<TNext>(
      _InfiniteViewBundle<TNext>(
        view: current.view.select(selector),
        infinitePlan: current.infinitePlan,
      ),
      client: _configuredClient,
    );
  }
}

/// Reusable externally subclassable infinite query recipe.
///
/// External subclasses implement [key], [initialPageParam], [fetchPage], and
/// [getNextPageParam]. Forward-only recipes inherit a concrete previous-page
/// resolver that returns [PageCursor.end].
abstract base class InfiniteQuery<Page, PageParam>
    extends InfiniteQueryView<InfiniteData<Page, PageParam>>
    implements QueryDataTarget<InfiniteData<Page, PageParam>> {
  const InfiniteQuery({
    super.client,
    RetryPolicy<InfiniteData<Page, PageParam>>? retry,
    StalePolicy? staleTime,
    RetentionPolicy? retention,
    NetworkMode? networkMode,
    Map<String, Object?> metadata = const <String, Object?>{},
    DataReconciler<InfiniteData<Page, PageParam>>? reconciler,
  })  : _configuredRetry = retry,
        _configuredStaleTime = staleTime,
        _configuredRetention = retention,
        _configuredNetworkMode = networkMode,
        _metadata = metadata,
        _configuredReconciler = reconciler;

  final RetryPolicy<InfiniteData<Page, PageParam>>? _configuredRetry;
  final StalePolicy? _configuredStaleTime;
  final RetentionPolicy? _configuredRetention;
  final NetworkMode? _configuredNetworkMode;
  final Map<String, Object?> _metadata;
  final DataReconciler<InfiniteData<Page, PageParam>>? _configuredReconciler;

  @override
  _InfiniteRawBundle<Page, PageParam> get _bundle => _resolveRaw();

  @override
  @internal
  ResolvedInfiniteQueryPlan<Page, PageParam> get infinitePlan =>
      _bundle.infinitePlan;

  /// Package-internal ordinary query carrier used by cache/client delegation.
  ///
  /// The public barrel does not expose this internal bridge as a separate type.
  @internal
  Query<InfiniteData<Page, PageParam>> get ordinaryQueryInternal =>
      _bundle.query;

  /// Structural cache key shared with ordinary query operations.
  @override
  QueryKey get key;

  /// Parameter passed to the first page fetch, including a valid `null`.
  PageParam get initialPageParam;

  /// Performs one page attempt.
  FutureOr<Page> fetchPage(InfinitePageContext<PageParam> context);

  /// Resolves forward pagination from complete aligned data.
  PageCursor<PageParam> getNextPageParam(
    InfiniteData<Page, PageParam> data,
  );

  /// Resolves backward pagination from complete aligned data.
  PageCursor<PageParam> getPreviousPageParam(
    InfiniteData<Page, PageParam> data,
  ) {
    return PageCursor.end;
  }

  /// Maximum retained pages, or `null` for no bound.
  int? get maxPages => null;

  /// Retry policy for complete [InfiniteData] results, never individual pages.
  @nonVirtual
  RetryPolicy<InfiniteData<Page, PageParam>>? get retryPolicy =>
      _configuredRetry;

  /// Default freshness used when an observer does not override it.
  @nonVirtual
  StalePolicy get stalePolicy => _configuredStaleTime ?? StalePolicy.immediate;

  /// Default cache retention.
  @nonVirtual
  RetentionPolicy get retentionPolicy =>
      _configuredRetention ?? RetentionPolicy.standard;

  /// Default connectivity behavior.
  @nonVirtual
  NetworkMode get networkMode => _configuredNetworkMode ?? NetworkMode.online;

  /// Immutable recipe metadata.
  Map<String, Object?> get metadata => _metadata;

  /// Structural sharing for complete aligned results.
  @override
  DataReconciler<InfiniteData<Page, PageParam>> get reconciler =>
      _configuredReconciler ??
      _defaultInfiniteDataReconciler<Page, PageParam>();

  /// Replaces whole-data retry behavior while Page types remain inferred.
  InfiniteQuery<Page, PageParam> withRetry(
    RetryStrategy<InfiniteData<Page, PageParam>> Function(
      RetryBuilder<InfiniteData<Page, PageParam>> retry,
    ) create,
  ) {
    return _RetryInfiniteQuery<Page, PageParam>(
      this,
      RetryPolicy<InfiniteData<Page, PageParam>>.custom(create),
    );
  }

  /// Seeds raw aligned data before selection is applied.
  InfiniteQueryView<InfiniteData<Page, PageParam>> withInitialData(
    InfiniteData<Page, PageParam> data, {
    DateTime? updatedAt,
  }) {
    final current = _resolveRaw();
    return _InitialInfiniteQueryView<Page, PageParam>(
      _InfiniteViewBundle<InfiniteData<Page, PageParam>>(
        view: current.query.withInitialData(data, updatedAt: updatedAt),
        infinitePlan: current.infinitePlan,
      ),
      client: _configuredClient,
    );
  }

  _InfiniteRawBundle<Page, PageParam> _resolveRaw() {
    final resolvedMaxPages = maxPages;
    _validateMaxPages(resolvedMaxPages);
    final infinitePlan = ResolvedInfiniteQueryPlan<Page, PageParam>(
      initialPageParam: initialPageParam,
      fetchPage: fetchPage,
      getNextPageParam: getNextPageParam,
      getPreviousPageParam: getPreviousPageParam,
      maxPages: resolvedMaxPages,
    );
    final ordinaryQuery = _InfinitePlanQuery<Page, PageParam>(
      client: _configuredClient,
      key: key,
      infinitePlan: infinitePlan,
      retry: _configuredRetry,
      staleTime: _configuredStaleTime,
      retention: _configuredRetention,
      networkMode: _configuredNetworkMode,
      metadata: metadata,
      reconciler: reconciler,
    );
    return _InfiniteRawBundle<Page, PageParam>(
      query: ordinaryQuery,
      infinitePlan: infinitePlan,
    );
  }
}

/// Creates an inference-friendly inline [InfiniteQuery].
InfiniteQuery<Page, PageParam> infiniteQuery<Page, PageParam>(
  QueryKey key,
  InfinitePageFunction<Page, PageParam> fetchPage, {
  QueryClient? client,
  required PageParam initialPageParam,
  required InfinitePageParamResolver<Page, PageParam> getNextPageParam,
  InfinitePageParamResolver<Page, PageParam>? getPreviousPageParam,
  int? maxPages,
  RetryPolicy<Never>? retry,
  StalePolicy? staleTime,
  RetentionPolicy? retention,
  NetworkMode? networkMode,
  Map<String, Object?> metadata = const <String, Object?>{},
  DataReconciler<InfiniteData<Page, PageParam>>? reconciler,
}) {
  _validateMaxPages(maxPages);
  return _InlineInfiniteQuery<Page, PageParam>(
    client: client,
    key: key,
    initialPageParam: initialPageParam,
    fetchPage: fetchPage,
    getNextPageParam: getNextPageParam,
    getPreviousPageParam: getPreviousPageParam,
    maxPages: maxPages,
    retry: _infiniteMarkerRetry<Page, PageParam>(retry),
    staleTime: staleTime,
    retention: retention,
    networkMode: networkMode,
    metadata: metadata,
    reconciler: reconciler,
  );
}

RetryPolicy<InfiniteData<Page, PageParam>>?
    _infiniteMarkerRetry<Page, PageParam>(RetryPolicy<Never>? marker) {
  if (marker == null) return null;
  if (!identical(marker, RetryPolicy.none) &&
      !identical(marker, RetryPolicy.standard)) {
    throw ArgumentError.value(
      marker,
      'retry',
      'Marker retry slots accept only RetryPolicy.none or '
          'RetryPolicy.standard. Apply typed custom retry with withRetry().',
    );
  }
  return marker;
}

final class _InlineInfiniteQuery<Page, PageParam>
    extends InfiniteQuery<Page, PageParam> {
  _InlineInfiniteQuery({
    required super.client,
    required this.key,
    required this.initialPageParam,
    required InfinitePageFunction<Page, PageParam> fetchPage,
    required InfinitePageParamResolver<Page, PageParam> getNextPageParam,
    required InfinitePageParamResolver<Page, PageParam>? getPreviousPageParam,
    required this.maxPages,
    required super.retry,
    required super.staleTime,
    required super.retention,
    required super.networkMode,
    required super.metadata,
    required super.reconciler,
  })  : _fetchPage = fetchPage,
        _getNextPageParam = getNextPageParam,
        _getPreviousPageParam = getPreviousPageParam;

  @override
  final QueryKey key;

  @override
  final PageParam initialPageParam;

  final InfinitePageFunction<Page, PageParam> _fetchPage;

  final InfinitePageParamResolver<Page, PageParam> _getNextPageParam;

  final InfinitePageParamResolver<Page, PageParam>? _getPreviousPageParam;

  @override
  final int? maxPages;

  @override
  FutureOr<Page> fetchPage(InfinitePageContext<PageParam> context) {
    return _fetchPage(context);
  }

  @override
  PageCursor<PageParam> getNextPageParam(
    InfiniteData<Page, PageParam> data,
  ) {
    return _getNextPageParam(data);
  }

  @override
  PageCursor<PageParam> getPreviousPageParam(
    InfiniteData<Page, PageParam> data,
  ) {
    return _getPreviousPageParam?.call(data) ?? PageCursor.end;
  }
}

final class _RetryInfiniteQuery<Page, PageParam>
    extends InfiniteQuery<Page, PageParam> {
  _RetryInfiniteQuery(
    this.source,
    RetryPolicy<InfiniteData<Page, PageParam>> retryPolicy,
  ) : super(
          client: source._configuredClient,
          retry: retryPolicy,
          staleTime: source._configuredStaleTime,
          retention: source._configuredRetention,
          networkMode: source._configuredNetworkMode,
          metadata: source.metadata,
          reconciler: source.reconciler,
        );

  final InfiniteQuery<Page, PageParam> source;

  @override
  QueryKey get key => source.key;

  @override
  PageParam get initialPageParam => source.initialPageParam;

  @override
  FutureOr<Page> fetchPage(InfinitePageContext<PageParam> context) {
    return source.fetchPage(context);
  }

  @override
  PageCursor<PageParam> getNextPageParam(
    InfiniteData<Page, PageParam> data,
  ) {
    return source.getNextPageParam(data);
  }

  @override
  PageCursor<PageParam> getPreviousPageParam(
    InfiniteData<Page, PageParam> data,
  ) {
    return source.getPreviousPageParam(data);
  }

  @override
  int? get maxPages => source.maxPages;
}

final class _InfinitePlanQuery<Page, PageParam>
    extends Query<InfiniteData<Page, PageParam>> {
  _InfinitePlanQuery({
    required super.client,
    required this.key,
    required this.infinitePlan,
    required super.retry,
    required super.staleTime,
    required super.retention,
    required super.networkMode,
    required super.metadata,
    required super.reconciler,
  });

  @override
  final QueryKey key;

  final ResolvedInfiniteQueryPlan<Page, PageParam> infinitePlan;

  @override
  Future<InfiniteData<Page, PageParam>> fetch(QueryContext context) {
    return infinitePlan.fetchInitial(context);
  }
}

class _InfiniteTargetBundle<TView> {
  const _InfiniteTargetBundle({
    required this.target,
    required this.infinitePlan,
  });

  final QueryTarget<TView> target;
  final ResolvedInfiniteQueryPlanBase infinitePlan;
}

final class _InfiniteViewBundle<TView> extends _InfiniteTargetBundle<TView> {
  const _InfiniteViewBundle({
    required this.view,
    required super.infinitePlan,
  }) : super(target: view);

  final QueryView<TView> view;
}

final class _InfiniteRawBundle<Page, PageParam>
    extends _InfiniteViewBundle<InfiniteData<Page, PageParam>> {
  const _InfiniteRawBundle({
    required this.query,
    required ResolvedInfiniteQueryPlan<Page, PageParam> infinitePlan,
  }) : super(view: query, infinitePlan: infinitePlan);

  final Query<InfiniteData<Page, PageParam>> query;

  @override
  ResolvedInfiniteQueryPlan<Page, PageParam> get infinitePlan =>
      super.infinitePlan as ResolvedInfiniteQueryPlan<Page, PageParam>;
}

final class _InitialInfiniteQueryView<Page, PageParam>
    extends InfiniteQueryView<InfiniteData<Page, PageParam>> {
  const _InitialInfiniteQueryView(this._bundle, {required super.client});

  @override
  final _InfiniteViewBundle<InfiniteData<Page, PageParam>> _bundle;
}

final class _SelectedInfiniteQueryView<TView> extends InfiniteQueryView<TView> {
  const _SelectedInfiniteQueryView(this._bundle, {required super.client});

  @override
  final _InfiniteViewBundle<TView> _bundle;
}

final class _TerminalInfiniteQueryTarget<TView>
    extends InfiniteQueryTarget<TView> {
  const _TerminalInfiniteQueryTarget(this._bundle, {required super.client});

  @override
  final _InfiniteTargetBundle<TView> _bundle;
}

void _validateMaxPages(int? maxPages) {
  if (maxPages != null && maxPages <= 0) {
    throw ArgumentError.value(
      maxPages,
      'maxPages',
      'maxPages must be positive when provided.',
    );
  }
}

DataReconciler<InfiniteData<Page, PageParam>>
    _defaultInfiniteDataReconciler<Page, PageParam>() {
  return _InfiniteDataReconciler<Page, PageParam>();
}

final class _InfiniteDataReconciler<Page, PageParam>
    extends DataReconciler<InfiniteData<Page, PageParam>> {
  _InfiniteDataReconciler()
      : _pages = DataReconciler<Page>.standard(),
        _pageParams = DataReconciler<PageParam>.standard();

  final DataReconciler<Page> _pages;
  final DataReconciler<PageParam> _pageParams;

  @override
  InfiniteData<Page, PageParam> reconcile(
    InfiniteData<Page, PageParam> previous,
    InfiniteData<Page, PageParam> next,
  ) {
    if (identical(previous, next) || previous == next) return previous;
    var allPrevious = previous.length == next.length;
    final pages = <Page>[];
    final pageParams = <PageParam>[];
    for (var index = 0; index < next.length; index += 1) {
      var page = next.pages[index];
      var pageParam = next.pageParams[index];
      if (index < previous.length) {
        page = _pages.reconcile(previous.pages[index], page);
        pageParam = _pageParams.reconcile(
          previous.pageParams[index],
          pageParam,
        );
        allPrevious = allPrevious &&
            identical(page, previous.pages[index]) &&
            identical(pageParam, previous.pageParams[index]);
      } else {
        allPrevious = false;
      }
      pages.add(page);
      pageParams.add(pageParam);
    }
    if (allPrevious) return previous;
    return InfiniteData<Page, PageParam>(
      pages: pages,
      pageParams: pageParams,
    );
  }
}
