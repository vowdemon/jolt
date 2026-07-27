import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('query without production initial data or placeholder remains absent',
      () {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final source = query<int>(
      key: QueryKey(<Object?>['canonical-absence']),
      fetch: (_) => 1,
    );

    final observer = harness.client.observeQuery(
      source.observer(enabled: false),
    );

    expect(observer.data, const QueryAbsent<int>());
    expect(harness.client.getQueryData(source), const QueryAbsent<int>());
    expect(
        harness.client.getQueryState(source)!.data, const QueryAbsent<int>());
  });

  test('nullable query success stores present-null in observer and cache',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final source = query<String?>(
      key: QueryKey(<Object?>['nullable-success']),
      fetch: (_) => null,
    );

    final observer = harness.client.observeQuery(source);
    await harness.pump();
    final QueryValue<String?> cached = harness.client.getQueryData(source);

    expect(observer.status, QueryStatus.success);
    expect(observer.data, const QueryPresent<String?>(null));
    expect(cached, const QueryPresent<String?>(null));
  });

  test('selected QueryView is observed directly with its selected type',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final QueryView<String> selected = query<int>(
      key: QueryKey(<Object?>['direct-selected-view']),
      fetch: (_) => 7,
    ).select((value) => 'value:$value');

    final QueryObserver<String> observer =
        harness.client.observeQuery(selected);
    await harness.pump();

    expect(observer.status, QueryStatus.success);
    expect(observer.data, const QueryPresent<String>('value:7'));
  });

  test('selected query retries raw data before applying selection', () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    var attempts = 0;
    final handledRawValues = <int>[];
    final selected = query<int>(
      key: QueryKey(<Object?>['selected-raw-retry']),
      fetch: (_) => ++attempts,
      retry: RetryPolicy.none,
    )
        .retry(
          (retry) => retry.strategy(
            retryIf: retry.result((data) {
                  handledRawValues.add(data);
                  return data == 1;
                }) &
                retry.maxRetries(1),
            delay: DelayPolicy.none(),
          ),
        )
        .select((data) => 'view:$data');

    final observer = harness.client.observeQuery(selected);
    await harness.pump();

    expect(attempts, 2);
    expect(handledRawValues, <int>[1, 2]);
    expect(observer.data.requireValue(), 'view:2');
  });

  test('query function preserves a thrown non-Exception object and stack',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final thrown = Object();
    final stack = StackTrace.fromString('non-exception-query-stack');
    final source = query<int>(
      key: QueryKey(<Object?>['non-exception-failure']),
      fetch: (_) => Error.throwWithStackTrace(thrown, stack),
    );

    try {
      await harness.client.fetchQuery(source);
      fail('fetchQuery should throw');
    } catch (error, caughtStack) {
      expect(error, same(thrown));
      expect(caughtStack, same(stack));
    }

    final failure = harness.client.getQueryState(source)!.failure!;
    expect(failure.error, same(thrown));
    expect(failure.stackTrace, same(stack));
  });

  test('raw nullable write creates a revisioned present-null snapshot', () {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final source = query<String?>(
      key: QueryKey(<Object?>['nullable-write']),
      fetch: (_) => 'network',
    );
    final before = harness.client.snapshotQueryData(source);

    final QueryDataSnapshot<String?> written =
        harness.client.setQueryData(source, null);

    expect(written.data, const QueryPresent<String?>(null));
    expect(written.revision, greaterThan(before.revision));
    expect(written.updatedAt, harness.clock.wallNow());
    expect(
      harness.client.getQueryData(source),
      const QueryPresent<String?>(null),
    );
  });

  test('updateQueryData exposes absence before committing a present value', () {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final source = query<int>(
      key: QueryKey(<Object?>['update-absence']),
      fetch: (_) => 0,
    );
    QueryValue<int>? received;

    final updated = harness.client.updateQueryData(source, (previous) {
      received = previous;
      return previous.isAbsent ? 7 : previous.requireValue() + 1;
    });

    expect(received, const QueryAbsent<int>());
    expect(updated.data, const QueryPresent<int>(7));
    expect(harness.client.getQueryData(source), const QueryPresent<int>(7));
  });

  test('typed Object bulk witness updates heterogeneous structural matches',
      () {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final number = query<int>(
      key: QueryKey(<Object?>['heterogeneous', 'number']),
      fetch: (_) => 0,
    );
    final text = query<String>(
      key: QueryKey(<Object?>['heterogeneous', 'text']),
      fetch: (_) => '',
    );
    final numberAsObject = query<Object?>(key: number.key, fetch: (_) => null);
    final textAsObject = query<Object?>(key: text.key, fetch: (_) => null);
    harness.client
      ..setQueryData(number, 1)
      ..setQueryData(text, 'two');

    final updated = harness.client.updateQueriesData<Object?>(
      TypedQueryFilter<Object?>(
        key: QueryKey(<Object?>['heterogeneous']),
      ),
      (key, previous) => '${key.parts.last}:${previous.requireValue()}',
    );

    expect(updated.map((match) => match.key), <QueryKey>[number.key, text.key]);
    expect(
      updated.map((match) => match.snapshot.data.requireValue()),
      <Object?>['number:1', 'text:two'],
    );
    expect(
      harness.client.getQueryData(numberAsObject).requireValue(),
      'number:1',
    );
    expect(
      harness.client.getQueryData(textAsObject).requireValue(),
      'text:two',
    );
  });

  test(
      'immutable invalidation remains visible and suppresses automatic and bulk refetch',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    var fetchCalls = 0;
    final raw = query<int>(
      key: QueryKey(<Object?>['immutable-invalidation']),
      fetch: (_) => ++fetchCalls,
      staleTime: StalePolicy.immutable,
    );
    final source = raw.initialData(1);
    final observer = harness.client.observeQuery(source);
    await harness.pump();
    expect(fetchCalls, 0);

    final invalidated = await harness.client.invalidateQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await harness.pump();

    expect(invalidated.matched, 1);
    expect(invalidated.affected, 1);
    expect(observer.isInvalidated, isTrue);
    expect(harness.client.getQueryState(raw)!.isInvalidated, isTrue);
    expect(fetchCalls, 0);

    final refetched = await harness.client.refetchQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await harness.pump();

    expect(refetched.matched, 1);
    expect(refetched.affected, 0);
    expect(fetchCalls, 0);
  });

  test(
      'Active queries are invalidated by default while inactive matches remain cache-only',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final activeRefetch = Completer<int>();
    var activeFetchCalls = 0;
    var inactiveFetchCalls = 0;
    final active = query<int>(
      key: QueryKey(<Object?>['default-invalidation', 'active']),
      fetch: (_) {
        activeFetchCalls += 1;
        if (activeFetchCalls == 1) return 1;
        return activeRefetch.future;
      },
    );
    final inactive = query<int>(
      key: QueryKey(<Object?>['default-invalidation', 'inactive']),
      fetch: (_) {
        inactiveFetchCalls += 1;
        return 2;
      },
    );
    final observer = harness.client.observeQuery(active);
    await harness.pump();
    harness.client.setQueryData(inactive, 10);

    expect(activeFetchCalls, 1);
    expect(inactiveFetchCalls, 0);
    final invalidating = harness.client.invalidateQueries();
    await harness.pump();

    expect(activeFetchCalls, 2);
    expect(inactiveFetchCalls, 0);
    expect(harness.client.getQueryState(active)!.isInvalidated, isTrue);
    expect(harness.client.getQueryState(inactive)!.isInvalidated, isTrue);
    expect(observer.isInvalidated, isTrue);

    activeRefetch.complete(2);
    final result = await invalidating;
    await harness.pump();

    expect(result.matched, 2);
    expect(result.affected, 2);
    expect(result.failures, isEmpty);
    expect(activeFetchCalls, 2);
    expect(inactiveFetchCalls, 0);
    expect(harness.client.getQueryState(active)!.isInvalidated, isFalse);
    expect(harness.client.getQueryState(inactive)!.isInvalidated, isTrue);
  });

  test('imperative fetch prefetch and ensure omit implicit retry', () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final attempts = <String, int>{};
    Query<int> failing(String operation) => query<int>(
          key: QueryKey(<Object?>['no-implicit-retry', operation]),
          fetch: (_) {
            attempts.update(operation, (count) => count + 1, ifAbsent: () => 1);
            throw StateError(operation);
          },
        );
    final fetched = failing('fetch');
    final prefetched = failing('prefetch');
    final ensured = failing('ensure');

    await expectLater(
      harness.client.fetchQuery(fetched),
      throwsA(isA<StateError>()),
    );
    await expectLater(harness.client.prefetchQuery(prefetched), completes);
    await expectLater(
      harness.client.ensureQueryData(ensured),
      throwsA(isA<StateError>()),
    );

    expect(attempts, <String, int>{
      'fetch': 1,
      'prefetch': 1,
      'ensure': 1,
    });
    expect(harness.client.getQueryState(fetched)!.failureCount, 1);
    expect(harness.client.getQueryState(prefetched)!.failureCount, 1);
    expect(harness.client.getQueryState(ensured)!.failureCount, 1);
  });

  test('exception-only retry without a budget continues until success',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    var attempts = 0;
    final source = query<int>(
      key: QueryKey(<Object?>['unlimited-exception-retry']),
      fetch: (_) {
        attempts += 1;
        if (attempts < 4) throw StateError('attempt $attempts');
        return 42;
      },
    ).retry(
      (retry) => retry.strategy(
        retryIf: retry.exceptions,
        delay: DelayPolicy.none(),
      ),
    );

    expect(await harness.client.fetchQuery(source), 42);
    expect(attempts, 4);
    expect(harness.client.getQueryData(source).requireValue(), 42);
    expect(harness.client.getQueryState(source)!.failureCount, 0);
  });

  test('cache events expose complete post-commit state for every change',
      () async {
    final harness = _QueryContractHarness();
    addTearDown(harness.dispose);
    final source = query<int>(
      key: QueryKey(<Object?>['cache-events-contract']),
      fetch: (_) => 1,
    );
    final events = <QueryCacheEvent>[];
    final subscription = harness.client.queryCache.events.listen(events.add);
    addTearDown(subscription.cancel);

    harness.client.setQueryData(source, 1);
    await harness.pump();

    final observer = harness.client.observeQuery(
      source.observer(enabled: false),
    );
    await harness.pump();

    await harness.client.invalidateQueries(
      filter: QueryFilter(key: source.key, exact: true),
      refetchType: QueryRefetchTarget.none,
    );
    await harness.pump();

    await harness.client.resetQueries(
      filter: QueryFilter(key: source.key, exact: true),
      refetchType: QueryRefetchTarget.none,
    );
    await harness.pump();

    observer.dispose();
    await harness.pump();
    harness.client.removeQueries(
      QueryFilter(key: source.key, exact: true),
    );
    await harness.pump();

    expect(
      events.map((event) => event.kind),
      <QueryCacheEventKind>[
        QueryCacheEventKind.added,
        QueryCacheEventKind.updated,
        QueryCacheEventKind.activityChanged,
        QueryCacheEventKind.invalidated,
        QueryCacheEventKind.reset,
        QueryCacheEventKind.activityChanged,
        QueryCacheEventKind.removed,
      ],
    );
    expect(events[0].snapshot.data, const QueryAbsent<Object?>());
    expect(events[1].snapshot.data, const QueryPresent<Object?>(1));
    expect(events[1].snapshot.status, QueryStatus.success);
    expect(events[2].snapshot.observerCount, 1);
    expect(events[3].snapshot.isInvalidated, isTrue);
    expect(events[4].snapshot.data, const QueryAbsent<Object?>());
    expect(events[4].snapshot.isInvalidated, isFalse);
    expect(events[5].snapshot.observerCount, 0);
    expect(events[6].snapshot.key, source.key);
  });
}

final class _QueryContractHarness {
  _QueryContractHarness()
      : clock = FakeQueryClock(),
        notifications = FakeQueryNotificationScheduler(),
        timers = FakeQueryTimerScheduler() {
    client = QueryClient(
      runtime: QueryRuntime(
        clock: clock,
        timers: timers,
        random: FakeQueryRandomSource(),
        notifications: notifications,
      ),
    );
  }

  final FakeQueryClock clock;
  final FakeQueryNotificationScheduler notifications;
  final FakeQueryTimerScheduler timers;
  late final QueryClient client;

  Future<void> pump() async {
    for (var index = 0; index < 5; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() => client.dispose();
}
