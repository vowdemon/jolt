import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/cache_models.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:test/test.dart';

void main() {
  test('data and operation states remain orthogonal', () {
    final snapshot = QuerySnapshot<String?>(
      key: QueryKey(<Object?>['profile']),
      data: const QueryValue<String?>.present(null),
      status: QueryStatus.success,
      fetchStatus: FetchStatus.fetching,
    );

    expect(snapshot.status, QueryStatus.success);
    expect(snapshot.fetchStatus, FetchStatus.fetching);
    expect(snapshot.data.isPresent, isTrue);
    expect(snapshot.data.requireValue(), isNull);
  });

  test('paused state and reason form one valid state', () {
    QuerySnapshot<int> create({
      required FetchStatus fetchStatus,
      PauseReason? pauseReason,
    }) =>
        QuerySnapshot<int>(
          key: QueryKey(<Object?>['todos']),
          data: const QueryValue<int>.absent(),
          status: QueryStatus.pending,
          fetchStatus: fetchStatus,
          pauseReason: pauseReason,
        );

    expect(
      () => create(fetchStatus: FetchStatus.paused),
      throwsArgumentError,
    );
    expect(
      () => create(
        fetchStatus: FetchStatus.idle,
        pauseReason: PauseReason.offline,
      ),
      throwsArgumentError,
    );

    final paused = create(
      fetchStatus: FetchStatus.paused,
      pauseReason: PauseReason.scope,
    );
    expect(paused.pauseReason, PauseReason.scope);
  });
}
