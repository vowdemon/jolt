import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  QueryObserverResult<int> ordinary({
    QueryValue<int> data = const QueryValue<int>.present(1),
    QueryStatus status = QueryStatus.success,
    FetchStatus fetchStatus = FetchStatus.idle,
    QueryFailure? failure,
    bool isEnabled = true,
  }) {
    return QueryObserverResult<int>(
      key: QueryKey(<Object?>['pages']),
      data: data,
      status: status,
      fetchStatus: fetchStatus,
      failure: failure,
      isEnabled: isEnabled,
    );
  }

  test('delegates selected data and classifies a next-page fetch', () {
    final result = InfiniteQueryObserverResult<int>(
      query: ordinary(
        fetchStatus: FetchStatus.fetching,
        isEnabled: false,
      ),
      hasNextPage: true,
      hasPreviousPage: false,
      isFetchingNextPage: true,
    );

    expect(result.data.requireValue(), 1);
    expect(result.isFetching, isTrue);
    expect(result.isFetchingNextPage, isTrue);
    expect(result.isFetchingPreviousPage, isFalse);
    expect(result.isRefetching, isFalse);
    expect(result.isEnabled, isFalse);
  });

  test('direction failure uses only the canonical query failure', () {
    final failure = QueryFailure(StateError('previous'), StackTrace.current);
    final result = InfiniteQueryObserverResult<int>(
      query: ordinary(status: QueryStatus.error, failure: failure),
      hasNextPage: true,
      hasPreviousPage: true,
      isFetchPreviousPageError: true,
    );

    expect(result.failure, same(failure));
    expect(result.isFetchPreviousPageError, isTrue);
    expect(result.isFetchNextPageError, isFalse);
    expect(result.isRefetchError, isFalse);
  });

  test('directional loading failure keeps loading classification', () {
    final failure = QueryFailure(StateError('next'), StackTrace.current);
    final result = InfiniteQueryObserverResult<int>(
      query: ordinary(
        data: const QueryValue<int>.absent(),
        status: QueryStatus.error,
        failure: failure,
      ),
      hasNextPage: true,
      hasPreviousPage: false,
      isFetchNextPageError: true,
    );

    expect(result.isLoadingError, isTrue);
    expect(result.isFetchNextPageError, isTrue);
    expect(result.isRefetchError, isFalse);
  });

  test('rejects impossible simultaneous direction states', () {
    expect(
      () => InfiniteQueryObserverResult<int>(
        query: ordinary(fetchStatus: FetchStatus.fetching),
        hasNextPage: true,
        hasPreviousPage: true,
        isFetchingNextPage: true,
        isFetchingPreviousPage: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => InfiniteQueryObserverResult<int>(
        query: ordinary(),
        hasNextPage: true,
        hasPreviousPage: true,
        isFetchNextPageError: true,
      ),
      throwsArgumentError,
    );
  });
}
