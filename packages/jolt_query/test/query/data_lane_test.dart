import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('absent error refetch enters loading and cancellation restores error',
      () async {
    final retry = Completer<int>();
    var attempts = 0;
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'loading-retry']),
      fetch: (_) {
        attempts += 1;
        if (attempts == 1) throw StateError('first');
        return retry.future;
      },
      retry: RetryPolicy.none,
    );
    final client = QueryClient();

    await expectLater(client.fetchQuery(source), throwsA(isA<StateError>()));
    final firstFailure = client.getQueryState(source)!.failure;
    final pending = client.fetchQuery(source);
    final cancelled = expectLater(
      pending,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();

    final loading = client.getQueryState(source)!;
    expect(loading.data.isAbsent, isTrue);
    expect(loading.status, QueryStatus.pending);
    expect(loading.fetchStatus, FetchStatus.fetching);
    expect(loading.failure, isNull);

    await client.cancelQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await cancelled;
    final restored = client.getQueryState(source)!;
    expect(restored.data.isAbsent, isTrue);
    expect(restored.status, QueryStatus.error);
    expect(restored.fetchStatus, FetchStatus.idle);
    expect(restored.failure, same(firstFailure));

    retry.complete(2);
    await _pump();
    client.dispose();
  });

  test('exact write rebases cancellation rollback to the manual value',
      () async {
    final transport = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'rebase-exact']),
      fetch: (_) => transport.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(source, 1);
    final pending = client.fetchQuery(source);
    final cancelled = expectLater(
      pending,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();

    client.setQueryData(source, 9);
    await client.cancelQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await cancelled;

    final restored = client.getQueryState(source)!;
    expect(restored.data.requireValue(), 9);
    expect(restored.status, QueryStatus.success);
    expect(restored.fetchStatus, FetchStatus.idle);
    transport.complete(10);
    await _pump();
    client.dispose();
  });

  test('conditional restore rebases cancellation rollback', () async {
    final transport = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'rebase-restore']),
      fetch: (_) => transport.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(source, 1);
    final checkpoint = client.snapshotQueryData(source);
    client.setQueryData(source, 2);
    final pending = client.fetchQuery(source);
    final cancelled = expectLater(
      pending,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();

    expect(
      client.restoreQueryData(
        source,
        checkpoint,
        ifRevision: client.getQueryState(source)!.revision,
      ),
      isTrue,
    );
    await client.cancelQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await cancelled;

    final restored = client.getQueryState(source)!;
    expect(restored.data.requireValue(), 1);
    expect(restored.fetchStatus, FetchStatus.idle);
    transport.complete(3);
    await _pump();
    client.dispose();
  });

  test('bulk writes rebase every matching cancellation rollback', () async {
    final firstTransport = Completer<int>();
    final secondTransport = Completer<int>();
    final first = query<int>(
      key: QueryKey(<Object?>['data-lane', 'rebase-bulk', 1]),
      fetch: (_) => firstTransport.future,
      retry: RetryPolicy.none,
    );
    final second = query<int>(
      key: QueryKey(<Object?>['data-lane', 'rebase-bulk', 2]),
      fetch: (_) => secondTransport.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient()
      ..setQueryData(first, 1)
      ..setQueryData(second, 2);
    final firstPending = client.fetchQuery(first);
    final secondPending = client.fetchQuery(second);
    final firstCancelled = expectLater(
      firstPending,
      throwsA(isA<QueryCancelledException>()),
    );
    final secondCancelled = expectLater(
      secondPending,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();

    client.setQueriesData<int>(
      TypedQueryFilter<int>(
        key: QueryKey(<Object?>['data-lane', 'rebase-bulk']),
      ),
      9,
    );
    await client.cancelQueries(
      filter: QueryFilter(
        key: QueryKey(<Object?>['data-lane', 'rebase-bulk']),
      ),
    );
    await Future.wait<void>(<Future<void>>[
      firstCancelled,
      secondCancelled,
    ]);

    expect(client.getQueryData(first).requireValue(), 9);
    expect(client.getQueryData(second).requireValue(), 9);
    expect(client.getQueryState(first)!.fetchStatus, FetchStatus.idle);
    expect(client.getQueryState(second)!.fetchStatus, FetchStatus.idle);
    firstTransport.complete(10);
    secondTransport.complete(20);
    await _pump();
    client.dispose();
  });

  test('exact write preserves an active fetch and its later result wins',
      () async {
    final transport = Completer<int>();
    late QueryCancellationToken token;
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'exact']),
      fetch: (context) {
        token = context.cancellationToken;
        return transport.future;
      },
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(source, 1);

    final pending = client.fetchQuery(source);
    await _pump();
    client.setQueryData(source, 9);

    final whileFetching = client.getQueryState(source)!;
    expect(whileFetching.data.requireValue(), 9);
    expect(whileFetching.status, QueryStatus.success);
    expect(whileFetching.fetchStatus, FetchStatus.fetching);
    expect(token.isCancelled, isFalse);

    transport.complete(10);
    expect(await pending, 10);
    expect(client.getQueryData(source).requireValue(), 10);
    client.dispose();
  });

  test('manual value remains when the retained active fetch fails', () async {
    final transport = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'failure']),
      fetch: (_) => transport.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(source, 1);

    final pending = client.fetchQuery(source);
    await _pump();
    client.updateQueryData(source, (_) => 9);
    transport.completeError(StateError('network'));

    await expectLater(pending, throwsA(isA<StateError>()));
    final failed = client.getQueryState(source)!;
    expect(failed.data.requireValue(), 9);
    expect(failed.status, QueryStatus.error);
    expect(failed.fetchStatus, FetchStatus.idle);
    expect(failed.failure?.error, isA<StateError>());
    client.dispose();
  });

  test('write during retry delay preserves transient failure and progress',
      () async {
    final timers = FakeQueryTimerScheduler();
    final client = QueryClient(
      runtime: QueryRuntime(
        clock: FakeQueryClock(),
        timers: timers,
        random: FakeQueryRandomSource(),
        notifications: FakeQueryNotificationScheduler(),
      ),
    );
    final secondAttempt = Completer<int>();
    var attempts = 0;
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'retry-progress']),
      fetch: (_) {
        attempts += 1;
        if (attempts == 1) throw StateError('retry');
        return secondAttempt.future;
      },
      retry: RetryPolicy.none,
    ).retry(
      (retry) => retry.strategy(
        retryIf: retry.exceptions & retry.maxRetries(1),
        delay: DelayPolicy.fixed(const Duration(seconds: 5)),
      ),
    );
    client.setQueryData(source, 1);

    final pending = client.fetchQuery(source);
    await _pump();
    final retrying = client.getQueryState(source)!;
    expect(retrying.fetchStatus, FetchStatus.fetching);
    expect(retrying.failureCount, 1);
    expect(retrying.transientFailure?.error, isA<StateError>());

    client.setQueryData(source, 9);
    final written = client.getQueryState(source)!;
    expect(written.data.requireValue(), 9);
    expect(written.fetchStatus, FetchStatus.fetching);
    expect(written.failureCount, retrying.failureCount);
    expect(written.transientFailure, same(retrying.transientFailure));

    timers.elapse(const Duration(seconds: 5));
    await _pump();
    expect(attempts, 2);
    secondAttempt.complete(10);
    expect(await pending, 10);
    client.dispose();
  });

  test('write preserves an offline-paused operation and its continuation',
      () async {
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'offline-pause']),
      fetch: (_) => 10,
      retry: RetryPolicy.none,
      networkMode: NetworkMode.online,
    );
    final client = QueryClient()..setQueryData(source, 1);
    client.onlineManager.isOnline = false;

    final pending = client.fetchQuery(source);
    await _pump();
    client.setQueryData(source, 9);

    final paused = client.getQueryState(source)!;
    expect(paused.data.requireValue(), 9);
    expect(paused.fetchStatus, FetchStatus.paused);
    expect(paused.pauseReason, PauseReason.offline);

    client.onlineManager.isOnline = true;
    expect(await pending, 10);
    expect(client.getQueryData(source).requireValue(), 10);
    client.dispose();
  });

  test('typed bulk writes preserve every matching active operation', () async {
    final transports = <String, Completer<int>>{
      'a': Completer<int>(),
      'b': Completer<int>(),
    };
    final tokens = <String, QueryCancellationToken>{};
    Query<int> source(String name) => query<int>(
          key: QueryKey(<Object?>['data-lane', 'bulk', name]),
          fetch: (context) {
            tokens[name] = context.cancellationToken;
            return transports[name]!.future;
          },
          retry: RetryPolicy.none,
        );
    final first = source('a');
    final second = source('b');
    final client = QueryClient()
      ..setQueryData(first, 1)
      ..setQueryData(second, 2);

    final firstPending = client.fetchQuery(first);
    final secondPending = client.fetchQuery(second);
    await _pump();
    final written = client.setQueriesData<int>(
      TypedQueryFilter<int>(key: QueryKey(<Object?>['data-lane', 'bulk'])),
      9,
    );

    expect(written.map((match) => match.snapshot.data.requireValue()),
        <int>[9, 9]);
    expect(client.countFetching(), 2);
    expect(tokens.values.every((token) => !token.isCancelled), isTrue);

    transports['a']!.complete(10);
    transports['b']!.complete(20);
    expect(await firstPending, 10);
    expect(await secondPending, 20);
    expect(client.getQueryData(first).requireValue(), 10);
    expect(client.getQueryData(second).requireValue(), 20);
    client.dispose();
  });

  test('absent checkpoint restores the data lane without removing active work',
      () async {
    final transport = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'restore-absent']),
      fetch: (_) => transport.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final absent = client.snapshotQueryData(source);
    final pending = client.fetchQuery(source);
    await _pump();

    final activeRevision = client.getQueryState(source)!.revision;
    expect(
      client.restoreQueryData(
        source,
        absent,
        ifRevision: activeRevision,
      ),
      isTrue,
    );
    final restored = client.getQueryState(source)!;
    expect(restored.data.isAbsent, isTrue);
    expect(restored.status, QueryStatus.pending);
    expect(restored.fetchStatus, FetchStatus.fetching);

    transport.complete(7);
    expect(await pending, 7);
    expect(client.getQueryData(source).requireValue(), 7);
    client.dispose();
  });

  test('absent checkpoint to a missing entry is a lineage-guarded no-op', () {
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'missing-checkpoint']),
      fetch: (_) => 1,
    );
    final client = QueryClient();
    final absent = client.snapshotQueryData(source);

    expect(
      client.restoreQueryData(source, absent, ifRevision: absent.revision),
      isTrue,
    );
    expect(client.queryCache.snapshots, isEmpty);

    client.queryCache.clear();
    expect(
      client.restoreQueryData(source, absent, ifRevision: absent.revision),
      isFalse,
    );
    expect(client.queryCache.snapshots, isEmpty);
    client.dispose();
  });

  test('awaiting cancellation before a write protects it from late completion',
      () async {
    final transport = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['data-lane', 'cancel-before-write']),
      fetch: (_) => transport.future,
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(source, 1);
    final pending = client.fetchQuery(source);
    final cancelled = expectLater(
      pending,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();

    await client.cancelQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await cancelled;
    client.setQueryData(source, 9);

    transport.complete(10);
    await _pump();
    expect(client.getQueryData(source).requireValue(), 9);
    client.dispose();
  });

  test('query cache clear isolates active mutation and both cache streams',
      () async {
    final queryTransport = Completer<int>();
    final mutationTransport = Completer<int>();
    final source = query<int>(
      key: QueryKey(<Object?>['cache-isolation', 'query']),
      fetch: (_) => queryTransport.future,
      retry: RetryPolicy.none,
    );
    final command = mutation<int, int, void>(
      mutate: (_, __) => mutationTransport.future,
    );
    final client = QueryClient();
    final mutationCache = client.mutationCache;
    var queryEventsClosed = false;
    var mutationEventsClosed = false;
    final querySubscription = client.queryCache.events.listen(
      (_) {},
      onDone: () => queryEventsClosed = true,
    );
    final mutationSubscription = mutationCache.events.listen(
      (_) {},
      onDone: () => mutationEventsClosed = true,
    );

    final queryPending = client.fetchQuery(source);
    final queryCancelled = expectLater(
      queryPending,
      throwsA(isA<QueryCancelledException>()),
    );
    final mutationPending = client.execute(command, 1);
    var mutationCompleted = false;
    unawaited(mutationPending.then((_) => mutationCompleted = true));
    await _pump();

    client.queryCache.clear();
    await queryCancelled;
    await _pump();

    expect(client.queryCache.snapshots, isEmpty);
    expect(mutationCache.snapshots, hasLength(1));
    expect(mutationCache.snapshots.single.isPending, isTrue);
    expect(mutationCompleted, isFalse);
    expect(queryEventsClosed, isFalse);
    expect(mutationEventsClosed, isFalse);

    mutationTransport.complete(2);
    expect(await mutationPending, 2);
    queryTransport.complete(3);
    await _pump();
    expect(client.getQueryState(source), isNull);

    client.setQueryData(source, 4);
    expect(client.getQueryData(source).requireValue(), 4);
    client.dispose();
    await _pump();
    expect(queryEventsClosed, isTrue);
    expect(mutationEventsClosed, isTrue);
    await querySubscription.cancel();
    await mutationSubscription.cancel();
  });
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
