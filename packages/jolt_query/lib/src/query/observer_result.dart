import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import 'state.dart';

/// Resolves the delay before the next polling tick from the current result.
///
/// Returning null stops polling until another observer-result transition or
/// target update asks the resolver again.
typedef QueryPollingIntervalResolver<T> = Duration? Function(
  QueryObserverResult<T> result,
);

/// One complete immutable presentation of a query observer.
final class QueryObserverResult<T> {
  /// Creates and validates an observer result.
  factory QueryObserverResult({
    required QueryKey key,
    required QueryValue<T> data,
    required QueryStatus status,
    required FetchStatus fetchStatus,
    PauseReason? pauseReason,
    QueryFailure? failure,
    QueryFailure? transientFailure,
    int failureCount = 0,
    DateTime? dataUpdatedAt,
    DateTime? failureUpdatedAt,
    bool isInvalidated = false,
    bool isStale = true,
    bool isPlaceholderData = false,
    bool isFetched = false,
    bool isFetchedAfterMount = false,
    bool isEnabled = true,
  }) {
    if ((fetchStatus == FetchStatus.paused) != (pauseReason != null)) {
      throw ArgumentError(
        'pauseReason must be present exactly while fetchStatus is paused.',
      );
    }
    if (failureCount < 0) {
      throw ArgumentError.value(
        failureCount,
        'failureCount',
        'Must not be negative.',
      );
    }
    if (status == QueryStatus.success && data.isAbsent) {
      throw ArgumentError.value(
        data,
        'data',
        'A successful observer result must contain present data.',
      );
    }
    if (status == QueryStatus.error && failure == null) {
      throw ArgumentError.value(
        failure,
        'failure',
        'An error observer result must contain a failure.',
      );
    }
    if (isPlaceholderData && data.isAbsent) {
      throw ArgumentError.value(
        data,
        'data',
        'Placeholder presentation requires present data.',
      );
    }
    return QueryObserverResult<T>._(
      key: key,
      data: data,
      status: status,
      fetchStatus: fetchStatus,
      pauseReason: pauseReason,
      failure: failure,
      transientFailure: transientFailure,
      failureCount: failureCount,
      dataUpdatedAt: dataUpdatedAt,
      failureUpdatedAt: failureUpdatedAt,
      isInvalidated: isInvalidated,
      isStale: isStale,
      isPlaceholderData: isPlaceholderData,
      isFetched: isFetched,
      isFetchedAfterMount: isFetchedAfterMount,
      isEnabled: isEnabled,
    );
  }

  const QueryObserverResult._({
    required this.key,
    required this.data,
    required this.status,
    required this.fetchStatus,
    required this.pauseReason,
    required this.failure,
    required this.transientFailure,
    required this.failureCount,
    required this.dataUpdatedAt,
    required this.failureUpdatedAt,
    required this.isInvalidated,
    required this.isStale,
    required this.isPlaceholderData,
    required this.isFetched,
    required this.isFetchedAfterMount,
    required this.isEnabled,
  });

  /// The structural key being presented.
  final QueryKey key;

  /// Selected observer data with explicit presence.
  final QueryValue<T> data;

  /// Canonical data state.
  final QueryStatus status;

  /// Orthogonal execution state.
  final FetchStatus fetchStatus;

  /// Why work is paused, when applicable.
  final PauseReason? pauseReason;

  /// Latest terminal or observer-local failure.
  final QueryFailure? failure;

  /// Latest retryable failure while work continues.
  final QueryFailure? transientFailure;

  /// Number of failed transport attempts.
  final int failureCount;

  /// Time at which raw cache data was last accepted.
  final DateTime? dataUpdatedAt;

  /// Time at which [failure] was last committed.
  final DateTime? failureUpdatedAt;

  /// Whether the underlying entry is explicitly invalidated.
  final bool isInvalidated;

  /// Observer-specific freshness.
  final bool isStale;

  /// Whether [data] is an observer-local placeholder.
  final bool isPlaceholderData;

  /// Whether this entry has accepted at least one data or failure update.
  final bool isFetched;

  /// Whether data or failure was updated after this observer attached.
  final bool isFetchedAfterMount;

  /// Whether this observer currently participates in automatic query work.
  final bool isEnabled;

  /// Whether no accepted value has completed yet.
  bool get isPending => status == QueryStatus.pending;

  /// Whether the current presentation is successful.
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the current presentation is failed.
  bool get isError => status == QueryStatus.error;

  /// Whether transport or retry delay work is active.
  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// Whether work is waiting behind an eligibility gate.
  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// Whether an initial value is currently loading.
  bool get isLoading => isPending && isFetching;

  /// Alias for [isLoading].
  bool get isInitialLoading => isLoading;

  /// Whether retained data is being refreshed.
  bool get isRefetching => isFetching && !isPending;

  /// Whether an initial load failed without retained data.
  bool get isLoadingError => isError && data.isAbsent;

  /// Whether a refresh failed while retained data remains visible.
  bool get isRefetchError => isError && data.isPresent;
}

/// A non-generic immutable query result for dynamic target lists.
final class ErasedQueryObserverResult {
  /// Erases only the selected data generic from [result].
  static ErasedQueryObserverResult from<T>(QueryObserverResult<T> result) {
    final erasedData = switch (result.data) {
      QueryAbsent<T>() => const QueryValue<Object?>.absent(),
      QueryPresent<T>(:final value) => QueryValue<Object?>.present(value),
    };
    return ErasedQueryObserverResult._(
      key: result.key,
      data: erasedData,
      status: result.status,
      fetchStatus: result.fetchStatus,
      pauseReason: result.pauseReason,
      failure: result.failure,
      transientFailure: result.transientFailure,
      failureCount: result.failureCount,
      dataUpdatedAt: result.dataUpdatedAt,
      failureUpdatedAt: result.failureUpdatedAt,
      isInvalidated: result.isInvalidated,
      isStale: result.isStale,
      isPlaceholderData: result.isPlaceholderData,
      isFetched: result.isFetched,
      isFetchedAfterMount: result.isFetchedAfterMount,
      isEnabled: result.isEnabled,
    );
  }

  const ErasedQueryObserverResult._({
    required this.key,
    required this.data,
    required this.status,
    required this.fetchStatus,
    required this.pauseReason,
    required this.failure,
    required this.transientFailure,
    required this.failureCount,
    required this.dataUpdatedAt,
    required this.failureUpdatedAt,
    required this.isInvalidated,
    required this.isStale,
    required this.isPlaceholderData,
    required this.isFetched,
    required this.isFetchedAfterMount,
    required this.isEnabled,
  });

  /// The structural key being presented.
  final QueryKey key;

  /// Selected data with only its generic erased.
  final QueryValue<Object?> data;

  /// Canonical data state.
  final QueryStatus status;

  /// Orthogonal execution state.
  final FetchStatus fetchStatus;

  /// Why work is paused, when applicable.
  final PauseReason? pauseReason;

  /// Latest terminal or observer-local failure.
  final QueryFailure? failure;

  /// Latest retryable failure while work continues.
  final QueryFailure? transientFailure;

  /// Number of failed transport attempts.
  final int failureCount;

  /// Time at which raw cache data was last accepted.
  final DateTime? dataUpdatedAt;

  /// Time at which [failure] was last committed.
  final DateTime? failureUpdatedAt;

  /// Whether the underlying entry is explicitly invalidated.
  final bool isInvalidated;

  /// Observer-specific freshness.
  final bool isStale;

  /// Whether data is observer-local placeholder data.
  final bool isPlaceholderData;

  /// Whether the entry accepted at least one data or failure update.
  final bool isFetched;

  /// Whether data or failure was updated after observer attachment.
  final bool isFetchedAfterMount;

  /// Whether the source observer participates in automatic query work.
  final bool isEnabled;

  /// Whether no accepted value has completed yet.
  bool get isPending => status == QueryStatus.pending;

  /// Whether the current presentation is successful.
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the current presentation is failed.
  bool get isError => status == QueryStatus.error;

  /// Whether transport or retry-delay work is active.
  bool get isFetching => fetchStatus == FetchStatus.fetching;

  /// Whether work is waiting behind an eligibility gate.
  bool get isPaused => fetchStatus == FetchStatus.paused;

  /// Whether an initial value is currently loading.
  bool get isLoading => isPending && isFetching;

  /// Alias for [isLoading].
  bool get isInitialLoading => isLoading;

  /// Whether retained data is being refreshed.
  bool get isRefetching => isFetching && !isPending;

  /// Whether an initial load failed without retained data.
  bool get isLoadingError => isError && data.isAbsent;

  /// Whether a refresh failed while retained data remains visible.
  bool get isRefetchError => isError && data.isPresent;
}
