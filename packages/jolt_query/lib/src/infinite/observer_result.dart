import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import '../query/observer_result.dart';
import '../query/state.dart';

/// One selected infinite-query presentation plus pagination state.
///
/// Directional failures deliberately reuse [failure]. They are classified by
/// flags only, so selecting a view never exposes its Page or PageParam types.
final class InfiniteQueryObserverResult<TView> {
  /// Creates and validates an infinite observer result.
  factory InfiniteQueryObserverResult({
    required QueryObserverResult<TView> query,
    required bool hasNextPage,
    required bool hasPreviousPage,
    bool isFetchingNextPage = false,
    bool isFetchingPreviousPage = false,
    bool isFetchNextPageError = false,
    bool isFetchPreviousPageError = false,
  }) {
    if (isFetchingNextPage && isFetchingPreviousPage) {
      throw ArgumentError(
        'Only one infinite-query direction can be fetching at a time.',
      );
    }
    if (isFetchNextPageError && isFetchPreviousPageError) {
      throw ArgumentError(
        'One canonical failure cannot belong to both directions.',
      );
    }
    if ((isFetchingNextPage || isFetchingPreviousPage) && !query.isFetching) {
      throw ArgumentError(
        'A directional fetch flag requires ordinary fetching state.',
      );
    }
    if ((isFetchNextPageError || isFetchPreviousPageError) &&
        query.failure == null) {
      throw ArgumentError(
        'A directional error flag requires the canonical query failure.',
      );
    }
    return InfiniteQueryObserverResult<TView>._(
      query: query,
      hasNextPage: hasNextPage,
      hasPreviousPage: hasPreviousPage,
      isFetchingNextPage: isFetchingNextPage,
      isFetchingPreviousPage: isFetchingPreviousPage,
      isFetchNextPageError: isFetchNextPageError,
      isFetchPreviousPageError: isFetchPreviousPageError,
    );
  }

  const InfiniteQueryObserverResult._({
    required this.query,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.isFetchNextPageError,
    required this.isFetchPreviousPageError,
  });

  /// The ordinary selected-query presentation.
  final QueryObserverResult<TView> query;

  /// Whether the raw aligned data currently exposes a next cursor.
  final bool hasNextPage;

  /// Whether the raw aligned data currently exposes a previous cursor.
  final bool hasPreviousPage;

  /// Whether the shared operation lane is fetching the next page.
  final bool isFetchingNextPage;

  /// Whether the shared operation lane is fetching the previous page.
  final bool isFetchingPreviousPage;

  /// Whether [failure] came from the latest next-page operation.
  final bool isFetchNextPageError;

  /// Whether [failure] came from the latest previous-page operation.
  final bool isFetchPreviousPageError;

  QueryKey get key => query.key;
  QueryValue<TView> get data => query.data;
  QueryStatus get status => query.status;
  FetchStatus get fetchStatus => query.fetchStatus;
  PauseReason? get pauseReason => query.pauseReason;
  QueryFailure? get failure => query.failure;
  QueryFailure? get transientFailure => query.transientFailure;
  int get failureCount => query.failureCount;
  DateTime? get dataUpdatedAt => query.dataUpdatedAt;
  DateTime? get failureUpdatedAt => query.failureUpdatedAt;
  bool get isInvalidated => query.isInvalidated;
  bool get isStale => query.isStale;
  bool get isPlaceholderData => query.isPlaceholderData;
  bool get isFetched => query.isFetched;
  bool get isFetchedAfterMount => query.isFetchedAfterMount;
  bool get isEnabled => query.isEnabled;
  bool get isPending => query.isPending;
  bool get isSuccess => query.isSuccess;
  bool get isError => query.isError;
  bool get isFetching => query.isFetching;
  bool get isPaused => query.isPaused;
  bool get isLoading => query.isLoading;
  bool get isInitialLoading => query.isInitialLoading;

  /// Whether retained data is undergoing a non-directional refresh.
  bool get isRefetching =>
      query.isRefetching && !isFetchingNextPage && !isFetchingPreviousPage;

  bool get isLoadingError => query.isLoadingError;
  bool get isRefetchError =>
      query.isRefetchError &&
      !isFetchNextPageError &&
      !isFetchPreviousPageError;
}
