import 'package:jolt_query/src/foundation/query_failure.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/cache_models.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:test/test.dart';

void main() {
  test('typed snapshot preserves state and defensively freezes metadata', () {
    final metadata = <String, Object?>{'source': 'network'};
    final error = StateError('latest');
    final transientError = StateError('retrying');
    final failure = QueryFailure(error, StackTrace.current);
    final transientFailure = QueryFailure(transientError, StackTrace.current);
    final updatedAt = DateTime.utc(2026, 7, 20);
    final failedAt = DateTime.utc(2026, 7, 20, 0, 0, 1);

    final snapshot = QuerySnapshot<String?>(
      key: QueryKey(<Object?>['profile', 7]),
      data: const QueryValue<String?>.present(null),
      status: QueryStatus.error,
      fetchStatus: FetchStatus.fetching,
      failure: failure,
      transientFailure: transientFailure,
      failureCount: 2,
      dataUpdatedAt: updatedAt,
      failureUpdatedAt: failedAt,
      dataUpdateCount: 3,
      failureUpdateCount: 1,
      revision: 4,
      invalidationRevision: 5,
      isInvalidated: true,
      metadata: metadata,
    );
    metadata['source'] = 'mutated';

    expect(snapshot.data.isPresent, isTrue);
    expect(snapshot.data.requireValue(), isNull);
    expect(snapshot.failure, same(failure));
    expect(snapshot.transientFailure, same(transientFailure));
    expect(snapshot.failureCount, 2);
    expect(snapshot.dataUpdatedAt, updatedAt);
    expect(snapshot.failureUpdatedAt, failedAt);
    expect(snapshot.dataUpdateCount, 3);
    expect(snapshot.failureUpdateCount, 1);
    expect(snapshot.revision, 4);
    expect(snapshot.invalidationRevision, 5);
    expect(snapshot.isInvalidated, isTrue);
    expect(snapshot.metadata, <String, Object?>{'source': 'network'});
    expect(
      () => snapshot.metadata['source'] = 'write',
      throwsUnsupportedError,
    );
  });

  test('data snapshots expose state but keep provenance opaque', () {
    final clientToken = Object();
    final lineageToken = Object();
    final key = QueryKey(<Object?>['todos', 1]);
    final updatedAt = DateTime.utc(2026, 7, 20);
    final snapshot = createQueryDataSnapshotInternal<int>(
      data: const QueryValue<int>.present(3),
      updatedAt: updatedAt,
      revision: 8,
      clientToken: clientToken,
      key: key,
      lineageToken: lineageToken,
    );

    expect(snapshot.data.requireValue(), 3);
    expect(snapshot.updatedAt, updatedAt);
    expect(snapshot.revision, 8);
    expect(
      queryDataSnapshotMatchesProvenanceInternal(
        snapshot,
        clientToken: clientToken,
        key: QueryKey(<Object?>['todos', 1.0]),
        lineageToken: lineageToken,
      ),
      isTrue,
    );
    expect(
      queryDataSnapshotMatchesProvenanceInternal(
        snapshot,
        clientToken: Object(),
        key: key,
        lineageToken: lineageToken,
      ),
      isFalse,
    );
    expect(
      queryDataSnapshotMatchesProvenanceInternal(
        snapshot,
        clientToken: clientToken,
        key: QueryKey(<Object?>['todos', 2]),
        lineageToken: lineageToken,
      ),
      isFalse,
    );
    expect(
      queryDataSnapshotMatchesProvenanceInternal(
        snapshot,
        clientToken: clientToken,
        key: key,
        lineageToken: Object(),
      ),
      isFalse,
    );

    final match = QueryDataMatch<int>(key: key, snapshot: snapshot);
    expect(match.key, key);
    expect(match.snapshot, same(snapshot));
  });

  test('data checkpoints preserve absence and reject negative revisions', () {
    final key = QueryKey(<Object?>['missing']);
    final absent = createQueryDataSnapshotInternal<int>(
      data: const QueryValue<int>.absent(),
      updatedAt: null,
      revision: 0,
      clientToken: Object(),
      key: key,
      lineageToken: Object(),
    );

    expect(absent.data.isAbsent, isTrue);
    expect(absent.updatedAt, isNull);
    expect(absent.revision, 0);
    expect(
      () => createQueryDataSnapshotInternal<int>(
        data: const QueryValue<int>.absent(),
        updatedAt: null,
        revision: -1,
        clientToken: Object(),
        key: key,
        lineageToken: Object(),
      ),
      throwsArgumentError,
    );
  });

  test('erased cache snapshots and events retain a complete immutable view',
      () {
    final metadata = <String, Object?>{'tag': 'profile'};
    final snapshot = QueryCacheSnapshot(
      key: QueryKey(<Object?>['profile']),
      data: const QueryValue<Object?>.present(null),
      status: QueryStatus.success,
      fetchStatus: FetchStatus.idle,
      observerCount: 2,
      isStale: false,
      metadata: metadata,
    );
    metadata['tag'] = 'changed';
    final event = QueryCacheEvent(
      kind: QueryCacheEventKind.activityChanged,
      snapshot: snapshot,
    );

    expect(snapshot.data.isPresent, isTrue);
    expect(snapshot.data.requireValue(), isNull);
    expect(snapshot.observerCount, 2);
    expect(snapshot.isActive, isTrue);
    expect(snapshot.isStale, isFalse);
    expect(snapshot.metadata, <String, Object?>{'tag': 'profile'});
    expect(() => snapshot.metadata.clear(), throwsUnsupportedError);
    expect(event.kind, QueryCacheEventKind.activityChanged);
    expect(event.snapshot, same(snapshot));
  });

  test('snapshot counters cannot be negative', () {
    expect(
      () => QueryCacheSnapshot(
        key: QueryKey(<Object?>['todos']),
        data: const QueryValue<Object?>.absent(),
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        observerCount: -1,
        isStale: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => QuerySnapshot<int>(
        key: QueryKey(<Object?>['todos']),
        data: const QueryValue<int>.absent(),
        status: QueryStatus.pending,
        fetchStatus: FetchStatus.idle,
        failureCount: -1,
      ),
      throwsArgumentError,
    );
  });
}
