import 'dart:async';

import 'package:jolt/jolt.dart' show Effect;
import 'package:jolt_query/jolt_query.dart';
import 'package:jolt_query/src/query/cache.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('QueryClient exact cache and operation lane', () {
    test('structurally equal keys join one missing-data fetch', () async {
      final first = Completer<int>();
      var firstCalls = 0;
      var secondCalls = 0;
      final firstQuery = query<int>(
        key: QueryKey(<Object?>[
          'todos',
          <Object?>[1.0]
        ]),
        fetch: (_) {
          firstCalls += 1;
          return first.future;
        },
      );
      final equivalent = query<int>(
        key: QueryKey(<Object?>[
          'todos',
          <Object?>[1]
        ]),
        fetch: (_) {
          secondCalls += 1;
          return 99;
        },
      );
      final client = QueryClient();

      final one = client.fetchQuery(firstQuery);
      final two = client.fetchQuery(equivalent);
      await Future<void>.delayed(Duration.zero);
      expect(firstCalls, 1);
      expect(secondCalls, 0);

      first.complete(7);
      expect(await one, 7);
      expect(await two, 7);
      expect(client.getQueryData(firstQuery).requireValue(), 7);

      expect(await client.fetchQuery(equivalent), 99);
      expect(secondCalls, 1);
      expect(client.getQueryData(firstQuery).requireValue(), 99);
      client.dispose();
    });

    test(
        'explicit cached refetch replacement ignores a cancelled late completion',
        () async {
      final slow = Completer<int>();
      var phase = 0;
      final source = query<int>(
          key: QueryKey(<Object?>['replace']),
          fetch: (_) {
            phase += 1;
            return switch (phase) {
              1 => 1,
              2 => slow.future,
              _ => 3,
            };
          });
      final client = QueryClient();
      expect(await client.fetchQuery(source), 1);

      final replaced = client.fetchQuery(source);
      await Future<void>.delayed(Duration.zero);
      final winner = client.fetchQuery(source, cancelRefetch: true);
      await expectLater(replaced, throwsA(isA<QueryCancelledException>()));
      expect(await winner, 3);
      slow.complete(2);
      await Future<void>.delayed(Duration.zero);

      expect(client.getQueryData(source).requireValue(), 3);
      client.dispose();
    });

    test('revision restore rejects newer writes, other clients, and recreation',
        () {
      final queryA =
          query<int>(key: QueryKey(<Object?>['snapshot']), fetch: (_) => 1);
      final sameKey =
          query<int>(key: QueryKey(<Object?>['snapshot']), fetch: (_) => 2);
      final otherKey =
          query<int>(key: QueryKey(<Object?>['other']), fetch: (_) => 3);
      final client = QueryClient();
      final otherClient = QueryClient();
      final before = client.snapshotQueryData(queryA);
      final optimistic = client.setQueryData(queryA, 10);

      expect(
        client.restoreQueryData(
          sameKey,
          before,
          ifRevision: optimistic.revision,
        ),
        isTrue,
      );
      expect(client.getQueryData(queryA).isAbsent, isTrue);

      final timedQuery = query<int>(
        key: QueryKey(<Object?>['snapshot', 'timed']),
        fetch: (_) => 4,
      );
      final priorTime = DateTime.utc(2024, 1, 2, 3, 4, 5);
      client.setQueryData(timedQuery, 4, updatedAt: priorTime);
      final prior = client.snapshotQueryData(timedQuery);
      final timedOptimistic = client.setQueryData(
        timedQuery,
        5,
        updatedAt: DateTime.utc(2024, 2, 3),
      );
      expect(
        client.restoreQueryData(
          timedQuery,
          prior,
          ifRevision: timedOptimistic.revision,
        ),
        isTrue,
      );
      final restored = client.getQueryState(timedQuery)!;
      expect(restored.data.requireValue(), 4);
      expect(restored.dataUpdatedAt, priorTime);

      final existed = client.setQueryData(queryA, 20);
      final token = client.snapshotQueryData(queryA);
      client.setQueryData(queryA, 21);
      expect(
        client.restoreQueryData(
          queryA,
          token,
          ifRevision: existed.revision,
        ),
        isFalse,
      );
      expect(
        client.restoreQueryData(
          otherKey,
          token,
          ifRevision: token.revision,
        ),
        isFalse,
      );
      expect(
        otherClient.restoreQueryData(
          queryA,
          token,
          ifRevision: 0,
        ),
        isFalse,
      );

      client.removeQueries(
        QueryFilter(key: queryA.key, exact: true),
      );
      final recreated = client.setQueryData(queryA, 20);
      expect(
        client.restoreQueryData(
          queryA,
          token,
          ifRevision: recreated.revision,
        ),
        isFalse,
      );
      client.dispose();
      otherClient.dispose();
    });
  });

  group('QueryClient bulk lifecycle', () {
    test('refetch reports stable cache-order failures and skipped plans',
        () async {
      final failures = <String, Completer<int>>{};
      var shouldFail = false;
      Query<int> make(String name) => query<int>(
            key: QueryKey(<Object?>[name]),
            fetch: (_) {
              if (!shouldFail) return 1;
              final completer = Completer<int>();
              failures[name] = completer;
              return completer.future;
            },
          );
      final alpha = make('alpha');
      final beta = make('beta');
      final cacheOnly = make('cache-only');
      final client = QueryClient();
      await client.fetchQuery(alpha);
      await client.fetchQuery(beta);
      client.setQueryData(cacheOnly, 5);
      shouldFail = true;

      final pending = client.refetchQueries();
      await Future<void>.delayed(Duration.zero);
      failures['beta']!.completeError(StateError('beta'));
      failures['alpha']!.completeError(StateError('alpha'));
      final result = await pending;

      expect(result.matched, 3);
      expect(result.affected, 2);
      expect(result.skippedNonExecutable, 1);
      expect(result.noOp, 0);
      expect(
        result.failures.map((item) => item.key),
        <QueryKey>[alpha.key, beta.key],
      );
      expect(
        result.failures.map((item) => item.failure.error.toString()),
        containsAllInOrder(<String>['Bad state: alpha', 'Bad state: beta']),
      );
      client.dispose();
    });

    test('invalidation joins an active initial load without a follow-up',
        () async {
      final first = Completer<int>();
      var calls = 0;
      final source = query<int>(
          key: QueryKey(<Object?>['invalidate']),
          fetch: (_) {
            calls += 1;
            return calls == 1 ? first.future : 2;
          });
      final client = QueryClient();
      final fetching = client.fetchQuery(source);
      final invalidating = client.invalidateQueries(
        refetchType: QueryRefetchTarget.all,
      );
      first.complete(1);

      expect(await fetching, 1);
      final result = await invalidating;
      expect(result.failures, isEmpty);
      expect(calls, 1);
      expect(client.getQueryData(source).requireValue(), 1);
      expect(client.getQueryState(source)!.isInvalidated, isFalse);
      client.dispose();
    });

    test('reset restores first raw initial data and clear leaves client usable',
        () async {
      final source =
          query<int>(key: QueryKey(<Object?>['initial']), fetch: (_) => 2)
              .initialData(1);
      final raw =
          query<int>(key: QueryKey(<Object?>['initial']), fetch: (_) => 2);
      final client = QueryClient();
      final listener = _EntryListener();
      final entry = client.attachQueryObserverInternal(
        source.resolved,
        listener,
      );
      expect(client.getQueryData(raw).requireValue(), 1);
      client.setQueryData(raw, 8);

      final reset = await client.resetQueries(
        filter: QueryFilter(key: raw.key, exact: true),
        refetchType: QueryRefetchTarget.none,
      );
      expect(reset.affected, 1);
      expect(client.getQueryData(raw).requireValue(), 1);

      client.detachQueryObserverInternal(entry, listener);
      client.clear();
      expect(client.queryCache.snapshots, isEmpty);
      client.setQueryData(raw, 9);
      expect(client.getQueryData(raw).requireValue(), 9);
      client.dispose();
    });
  });

  test('query defaults merge broad before specific and affect freshness',
      () async {
    final clock = FakeQueryClock();
    final runtime = QueryRuntime(
      clock: clock,
      timers: FakeQueryTimerScheduler(),
      random: FakeQueryRandomSource(),
      notifications: FakeQueryNotificationScheduler(),
    );
    var calls = 0;
    final source = query<int>(
      key: QueryKey(<Object?>[
        'users',
        <String, Object?>{
          'filters': <String, Object?>{'active': true, 'team': 7},
          'page': 2,
        },
      ]),
      fetch: (_) => ++calls,
    );
    final client = QueryClient(runtime: runtime)
      ..registerQueryDefaults(
        QueryDefaults(
          staleTime: StalePolicy.duration(const Duration(minutes: 1)),
          retention: RetentionPolicy.duration(const Duration(minutes: 2)),
        ),
      )
      ..registerQueryDefaults(
        QueryDefaults(staleTime: StalePolicy.untilInvalidated),
        key: QueryKey(<Object?>[
          'users',
          <String, Object?>{
            'filters': <String, Object?>{'active': true},
          },
        ]),
      );

    expect(await client.fetchQuery(source), 1);
    clock.advance(const Duration(days: 1));
    expect(await client.fetchQuery(source), 1);
    expect(calls, 1);
    expect(
      client.getQueryDefaults(source.key).retention!.duration,
      const Duration(minutes: 2),
    );
    client.dispose();
  });

  test('query defaults reject a custom Never retry marker', () {
    final customMarker = RetryPolicy<Never>.custom(
      (retry) => retry.strategy(retryIf: retry.never),
    );
    final client = QueryClient();

    expect(
      () => client.registerQueryDefaults(
        QueryDefaults(retry: customMarker),
      ),
      throwsArgumentError,
    );
    client.dispose();
  });

  test('prefetch commits failure without exposing a caller error', () async {
    final source = query<int>(
      key: QueryKey(<Object?>['prefetch', 'failure']),
      fetch: (_) => throw StateError('offline'),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();

    await expectLater(client.prefetchQuery(source), completes);

    final snapshot = client.getQueryState(source)!;
    expect(snapshot.status, QueryStatus.error);
    expect(snapshot.data.isAbsent, isTrue);
    expect(snapshot.failure?.error, isA<StateError>());
    client.dispose();
  });

  test('ensure returns stale cached data before background revalidation',
      () async {
    var calls = 0;
    final source = query<int>(
      key: QueryKey(<Object?>['ensure', 'stale']),
      fetch: (_) => ++calls,
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    expect(await client.fetchQuery(source), 1);

    expect(
      await client.ensureQueryData(source, revalidateIfStale: true),
      1,
    );
    for (var index = 0; index < 3; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(calls, 2);
    expect(client.getQueryData(source).requireValue(), 2);
    client.dispose();
  });

  test('typed bulk reads and writes preserve stable key order and presence',
      () {
    final first = query<int>(
      key: QueryKey(<Object?>['bulk', 1]),
      fetch: (_) => 0,
    );
    final second = query<int>(
      key: QueryKey(<Object?>['bulk', 2]),
      fetch: (_) => 0,
    );
    final outside = query<int>(
      key: QueryKey(<Object?>['outside']),
      fetch: (_) => 0,
    );
    final filter = TypedQueryFilter<int>(
      key: QueryKey(<Object?>['bulk']),
    );
    final client = QueryClient()
      ..setQueryData(first, 1)
      ..setQueryData(second, 2)
      ..setQueryData(outside, 9);

    expect(
      client.getQueriesData(filter).map((match) => match.key),
      <QueryKey>[first.key, second.key],
    );
    final updated = client.updateQueriesData(
      filter,
      (key, previous) => previous.requireValue() + 10,
    );
    expect(
      updated.map((match) => match.snapshot.data.requireValue()),
      <int>[11, 12],
    );
    final replaced = client.setQueriesData(filter, 7);
    expect(
      replaced.map((match) => match.snapshot.data.requireValue()),
      <int>[7, 7],
    );
    expect(client.getQueryData(outside).requireValue(), 9);
    client.dispose();
  });

  test('fetchingCount follows fully committed cache notifications', () async {
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: FakeQueryClock(),
      timers: FakeQueryTimerScheduler(),
      random: FakeQueryRandomSource(),
      notifications: notifications,
    );
    final completion = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['fetching-count']),
      fetch: (_) => completion.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient(runtime: runtime);
    final pending = client.fetchQuery(source);
    await Future<void>.delayed(Duration.zero);

    expect(client.fetchingCount.peek, 0);
    expect(client.countFetching(), 1);
    notifications.flushAll();
    expect(client.fetchingCount.peek, 1);

    completion.complete(1);
    expect(await pending, 1);
    await Future<void>.delayed(Duration.zero);
    notifications.flushAll();
    expect(client.fetchingCount.peek, 0);
    client.dispose();
  });

  test('one completion publishes one fully committed cache and observer state',
      () async {
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: FakeQueryClock(),
      timers: FakeQueryTimerScheduler(),
      random: FakeQueryRandomSource(),
      notifications: notifications,
    );
    final completion = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['atomic-completion']),
      fetch: (_) => completion.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient(runtime: runtime);
    final observer = client.observeQuery(source.observer(enabled: false));
    final cacheEvents = <QueryCacheEvent>[];
    final observerPublications = <QueryObserverResult<int>>[];
    final subscription = client.queryCache.events.listen(cacheEvents.add);
    final effect = Effect(() {
      observerPublications.add(observer.value);
    });

    final pending = observer.refetch();
    for (var index = 0; index < 4; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
    cacheEvents.clear();
    observerPublications.clear();

    completion.complete(7);
    expect(await pending, isA<QueryObserverResult<int>>());
    await Future<void>.delayed(Duration.zero);
    expect(cacheEvents, isEmpty);
    expect(observerPublications, hasLength(1));
    expect(observerPublications.single.data.requireValue(), 7);
    expect(observerPublications.single.status, QueryStatus.success);
    expect(observerPublications.single.fetchStatus, FetchStatus.idle);

    notifications.flushAll();
    await Future<void>.delayed(Duration.zero);

    expect(cacheEvents, hasLength(1));
    expect(cacheEvents.single.kind, QueryCacheEventKind.updated);
    final committed = cacheEvents.single.snapshot;
    expect(committed.data.requireValue(), 7);
    expect(committed.status, QueryStatus.success);
    expect(committed.fetchStatus, FetchStatus.idle);
    expect(committed.dataUpdateCount, 1);
    expect(committed.failureCount, 0);
    expect(committed.revision, greaterThan(0));

    expect(observerPublications, hasLength(1));
    final published = observerPublications.single;
    expect(published.data.requireValue(), committed.data.requireValue());
    expect(published.status, committed.status);
    expect(published.fetchStatus, committed.fetchStatus);
    expect(published.failureCount, committed.failureCount);

    effect.dispose();
    observer.dispose();
    await subscription.cancel();
    client.dispose();
  });

  test('cache events survive clear and close only on disposal', () async {
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: FakeQueryClock(),
      timers: FakeQueryTimerScheduler(),
      random: FakeQueryRandomSource(),
      notifications: notifications,
    );
    final client = QueryClient(runtime: runtime);
    final source =
        query<int>(key: QueryKey(<Object?>['events']), fetch: (_) => 1);
    final kinds = <QueryCacheEventKind>[];
    var isDone = false;
    final subscription = client.queryCache.events.listen(
      (event) => kinds.add(event.kind),
      onDone: () => isDone = true,
    );

    client.setQueryData(source, 1);
    notifications.flushAll();
    client.clear();
    notifications.flushAll();
    expect(isDone, isFalse);
    client.setQueryData(source, 2);
    notifications.flushAll();
    expect(
      kinds,
      <QueryCacheEventKind>[
        QueryCacheEventKind.added,
        QueryCacheEventKind.updated,
        QueryCacheEventKind.removed,
        QueryCacheEventKind.added,
        QueryCacheEventKind.updated,
      ],
    );

    client.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(isDone, isTrue);
    await subscription.cancel();
  });

  test('query cache clear cancels old work and live observers reattach',
      () async {
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: FakeQueryClock(),
      timers: FakeQueryTimerScheduler(),
      random: FakeQueryRandomSource(),
      notifications: notifications,
    );
    final transports = <Completer<int>>[];
    var attempts = 0;
    final source = query<int>(
      key: QueryKey(<Object?>['cache-clear-reattach']),
      fetch: (_) {
        attempts += 1;
        final transport = Completer<int>();
        transports.add(transport);
        return transport.future;
      },
      retry: RetryPolicy.none,
    );
    final client = QueryClient(runtime: runtime);
    final events = <QueryCacheEvent>[];
    var eventsClosed = false;
    final subscription = client.queryCache.events.listen(
      events.add,
      onDone: () => eventsClosed = true,
    );
    final observer = client.observeQuery(source);
    await Future<void>.delayed(Duration.zero);
    notifications.flushAll();
    expect(attempts, 1);
    events.clear();

    client.queryCache.clear();

    expect(client.isDisposed, isFalse);
    expect(client.queryCache.isDisposed, isFalse);
    expect(client.queryCache.snapshots, isEmpty);
    expect(eventsClosed, isFalse);

    notifications.flushAll();
    await Future<void>.delayed(Duration.zero);
    notifications.flushAll();

    expect(attempts, 2);
    expect(observer.fetchStatus, FetchStatus.fetching);
    expect(client.queryCache.snapshots.single.observerCount, 1);
    expect(events.map((event) => event.kind),
        contains(QueryCacheEventKind.removed));
    expect(
        events.map((event) => event.kind), contains(QueryCacheEventKind.added));

    transports.first.complete(1);
    await Future<void>.delayed(Duration.zero);
    notifications.flushAll();
    expect(observer.data.isAbsent, isTrue);
    expect(observer.fetchStatus, FetchStatus.fetching);

    transports.last.complete(2);
    await Future<void>.delayed(Duration.zero);
    notifications.flushAll();
    expect(observer.data.requireValue(), 2);

    client.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(eventsClosed, isTrue);
    await subscription.cancel();
  });
}

final class _EntryListener implements QueryEntryListenerInternal {
  @override
  bool get isQueryEntryActiveInternal => true;

  @override
  bool get blocksQueryRefetchInternal => false;

  @override
  bool isQueryEntryStaleInternal(QueryEntryInternal entry) => false;

  @override
  void onQueryEntryChangedInternal(
    QueryEntryInternal entry,
    QueryCacheEventKind kind,
  ) {}

  @override
  void onQueryEntryRemovedInternal(QueryEntryInternal entry) {}
}
