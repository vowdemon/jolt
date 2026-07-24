import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/cache_models.dart';
import 'package:jolt_query/src/query/filters.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:test/test.dart';

void main() {
  test('key filters use structural prefix matching unless exact', () {
    final snapshot = _snapshot(<Object?>['todos', 1]);

    expect(
      QueryFilter(key: QueryKey(<Object?>['todos'])).matches(snapshot),
      isTrue,
    );
    expect(
      QueryFilter(
        key: QueryKey(<Object?>['todos']),
        exact: true,
      ).matches(snapshot),
      isFalse,
    );
    expect(
      QueryFilter(
        key: QueryKey(<Object?>['todos', 1.0]),
        exact: true,
      ).matches(snapshot),
      isTrue,
    );
  });

  test('key filters accept recursive partial key objects', () {
    final snapshot = _snapshot(<Object?>[
      'todos',
      <String, Object?>{
        'filters': <String, Object?>{'page': 1, 'status': 'open'},
      },
    ]);

    expect(
      QueryFilter(
        key: QueryKey(<Object?>[
          'todos',
          <String, Object?>{
            'filters': <String, Object?>{'page': 1},
          },
        ]),
      ).matches(snapshot),
      isTrue,
    );
    expect(
      QueryFilter(
        key: QueryKey(<Object?>[
          'todos',
          <String, Object?>{
            'filters': <String, Object?>{'page': 1},
          },
        ]),
        exact: true,
      ).matches(snapshot),
      isFalse,
    );
  });

  test('activity and freshness partitions are explicit and composable', () {
    final activeFresh = _snapshot(
      <Object?>['todos', 'active'],
      observerCount: 1,
      isStale: false,
    );
    final inactiveStale = _snapshot(
      <Object?>['todos', 'inactive'],
      isStale: true,
    );

    const active = QueryFilter(activity: QueryActivity.active);
    const inactive = QueryFilter(activity: QueryActivity.inactive);
    const fresh = QueryFilter(freshness: QueryFreshness.fresh);
    const stale = QueryFilter(freshness: QueryFreshness.stale);

    expect(active.matches(activeFresh), isTrue);
    expect(active.matches(inactiveStale), isFalse);
    expect(inactive.matches(activeFresh), isFalse);
    expect(inactive.matches(inactiveStale), isTrue);
    expect(fresh.matches(activeFresh), isTrue);
    expect(fresh.matches(inactiveStale), isFalse);
    expect(stale.matches(activeFresh), isFalse);
    expect(stale.matches(inactiveStale), isTrue);
  });

  test('state constraints short-circuit before the final predicate', () {
    var predicateCalls = 0;
    final filter = QueryFilter(
      status: QueryStatus.success,
      fetchStatus: FetchStatus.fetching,
      predicate: (snapshot) {
        predicateCalls += 1;
        return snapshot.metadata['include'] == true;
      },
    );

    expect(
      filter.matches(
        _snapshot(
          <Object?>['match'],
          status: QueryStatus.success,
          fetchStatus: FetchStatus.fetching,
          metadata: const <String, Object?>{'include': true},
        ),
      ),
      isTrue,
    );
    expect(
      filter.matches(
        _snapshot(
          <Object?>['wrong-status'],
          status: QueryStatus.error,
          fetchStatus: FetchStatus.fetching,
          metadata: const <String, Object?>{'include': true},
        ),
      ),
      isFalse,
    );
    expect(predicateCalls, 1);
  });

  test('typed filters retain the erased rules as a type witness', () {
    final untyped = QueryFilter(key: QueryKey(<Object?>['todos']));
    final TypedQueryFilter<String> typed = untyped.typed<String>();

    expect(typed.untyped, same(untyped));
    expect(typed.key, untyped.key);
    expect(typed.matches(_snapshot(<Object?>['todos', 1])), isTrue);
    expect(typed.matches(_snapshot(<Object?>['profile'])), isFalse);
  });
}

QueryCacheSnapshot _snapshot(
  List<Object?> keyParts, {
  int observerCount = 0,
  bool isStale = false,
  QueryStatus status = QueryStatus.pending,
  FetchStatus fetchStatus = FetchStatus.idle,
  Map<String, Object?> metadata = const <String, Object?>{},
}) =>
    QueryCacheSnapshot(
      key: QueryKey(keyParts),
      data: const QueryValue<Object?>.absent(),
      status: status,
      fetchStatus: fetchStatus,
      observerCount: observerCount,
      isStale: isStale,
      metadata: metadata,
    );
