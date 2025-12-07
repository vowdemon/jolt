import 'package:meta/meta.dart';

/// Lifecycle statuses for a query.
enum QueryStatus { idle, loading, success, error }

/// Fetch activity 状态：
/// - idle: 无进行中的请求
/// - pending: 正在请求
/// - paused: 因离线等原因暂停，未真正发起
enum QueryFetchState { idle, pending, paused }

/// Immutable snapshot of a query.
@immutable
class QueryState<T> {
  const QueryState({
    required this.status,
    this.data,
    this.error,
    this.stackTrace,
    this.fetchState = QueryFetchState.idle,
    this.isStale = true,
    this.isPlaceholderData = false,
    this.fetchCount = 0,
    this.fetchedAfterMount = false,
    this.isEnabled = true,
    this.dataUpdatedAt,
  });

  const QueryState.idle({T? initial})
      : status = QueryStatus.idle,
        data = initial,
        error = null,
        stackTrace = null,
        fetchState = QueryFetchState.idle,
        isStale = true,
        isPlaceholderData = false,
        fetchCount = 0,
        fetchedAfterMount = false,
        isEnabled = true,
        dataUpdatedAt = null;

  final QueryStatus status;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final QueryFetchState fetchState;
  final bool isStale;
  final bool isPlaceholderData;
  final int fetchCount;
  final bool fetchedAfterMount;
  final bool isEnabled;
  final DateTime? dataUpdatedAt;

  bool get hasData => dataUpdatedAt != null && data != null;
  bool get isSuccess => status == QueryStatus.success;
  bool get isError => status == QueryStatus.error;
  bool get isLoading => status == QueryStatus.loading;
  bool get isIdle => status == QueryStatus.idle;

  bool get isFetched => fetchCount > 0 || (hasData && !isPlaceholderData);
  bool get isFetchedAfterMount => fetchedAfterMount;
  bool get isRefetching => fetchState == QueryFetchState.pending && isFetched;
  bool get isInitialLoading =>
      isLoading && !isFetched && !isPlaceholderData && fetchState == QueryFetchState.pending;
  bool get isLoadingError => isError && !isFetched;
  bool get isRefetchError => isError && isFetched;
  bool get isPending => isIdle || (isPlaceholderData && !isFetched);
  bool get isPlaceholder => isPlaceholderData;
  bool get isEnabledFlag => isEnabled;
  bool get isPaused => fetchState == QueryFetchState.paused;
  bool get isFetching => fetchState == QueryFetchState.pending;

  QueryState<T> copyWith({
    QueryStatus? status,
    T? data,
    bool setData = false,
    Object? error,
    bool clearError = false,
    StackTrace? stackTrace,
    bool clearStackTrace = false,
    QueryFetchState? fetchState,
    bool? isStale,
    bool? isPlaceholderData,
    int? fetchCount,
    bool? fetchedAfterMount,
    bool? isEnabled,
    DateTime? dataUpdatedAt,
    bool clearDataUpdatedAt = false,
  }) {
    return QueryState<T>(
      status: status ?? this.status,
      data: setData ? data : this.data,
      error: clearError ? null : (error ?? this.error),
      stackTrace: clearStackTrace ? null : (stackTrace ?? this.stackTrace),
      fetchState: fetchState ?? this.fetchState,
      isStale: isStale ?? this.isStale,
      isPlaceholderData: isPlaceholderData ?? this.isPlaceholderData,
      fetchCount: fetchCount ?? this.fetchCount,
      fetchedAfterMount: fetchedAfterMount ?? this.fetchedAfterMount,
      isEnabled: isEnabled ?? this.isEnabled,
      dataUpdatedAt: clearDataUpdatedAt
          ? null
          : (dataUpdatedAt ?? this.dataUpdatedAt),
    );
  }
}
