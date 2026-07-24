import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('nullable present data is success and can be erased safely', () {
    final result = QueryObserverResult<String?>(
      key: QueryKey(<Object?>['nullable']),
      data: const QueryValue<String?>.present(null),
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      isFetched: true,
      isEnabled: false,
    );
    final erased = ErasedQueryObserverResult.from(result);

    expect(result.isSuccess, isTrue);
    expect(result.data.isPresent, isTrue);
    expect(erased.data.isPresent, isTrue);
    expect(erased.data.requireValue(), isNull);
    expect(result.isEnabled, isFalse);
    expect(erased.isEnabled, isFalse);
  });

  test('retained-data failure is distinguishable from loading failure', () {
    final failure = QueryFailure(StateError('failed'), StackTrace.current);
    final retained = QueryObserverResult<int>(
      key: QueryKey(<Object?>['value']),
      data: const QueryValue<int>.present(1),
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      failure: failure,
    );
    final loading = QueryObserverResult<int>(
      key: QueryKey(<Object?>['other']),
      data: const QueryValue<int>.absent(),
      status: QueryStatus.error,
      fetchStatus: FetchStatus.idle,
      failure: failure,
    );

    expect(retained.isRefetchError, isTrue);
    expect(retained.isLoadingError, isFalse);
    expect(loading.isLoadingError, isTrue);
    expect(loading.isRefetchError, isFalse);
  });

  test('pending fetching state reports initial loading', () {
    final result = QueryObserverResult<int>(
      key: QueryKey(<Object?>['value']),
      data: const QueryValue<int>.absent(),
      status: QueryStatus.pending,
      fetchStatus: FetchStatus.fetching,
    );

    expect(result.isLoading, isTrue);
    expect(result.isInitialLoading, isTrue);
    expect(result.isRefetching, isFalse);
  });
}
