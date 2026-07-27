import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('query data-lane operation preservation', () {
    test('update during fetch is synchronous and preserves active work',
        () async {
      final harness = _QueryContractHarness();
      addTearDown(harness.dispose);
      final transport = Completer<int>();
      QueryCancellationToken? operationToken;
      var queryCalls = 0;
      final source = query<int>(
        key: QueryKey(<Object?>['strict-data-lane', 'update']),
        fetch: (context) {
          queryCalls += 1;
          operationToken = context.cancellationToken;
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(source, 1);

      final pending = harness.client.fetchQuery(source);
      await harness.pump();
      final token = operationToken!;
      final before = harness.client.getQueryState(source)!;
      var updaterReturned = false;

      final written = harness.client.updateQueryData(
        source,
        (previous) {
          expect(previous.requireValue(), 1);
          return 9;
        },
        updatedAt: DateTime.utc(2026, 7, 22, 1),
      );
      updaterReturned = true;

      final during = harness.client.getQueryState(source)!;
      expect(updaterReturned, isTrue);
      expect(written.data.requireValue(), 9);
      expect(queryCalls, 1);
      expect(identical(operationToken, token), isTrue);
      expect(token.isCancelled, isFalse);
      expect(during.fetchStatus, before.fetchStatus);
      expect(during.pauseReason, before.pauseReason);
      expect(during.transientFailure, before.transientFailure);
      expect(during.failureCount, before.failureCount);
      expect(harness.client.countFetching(), 1);

      transport.complete(10);
      expect(await pending, 10);
      expect(harness.client.getQueryData(source).requireValue(), 10);
    });

    test('restore during fetch restores timestamp and preserves active work',
        () async {
      final harness = _QueryContractHarness();
      addTearDown(harness.dispose);
      final transport = Completer<int>();
      QueryCancellationToken? operationToken;
      final source = query<int>(
        key: QueryKey(<Object?>['strict-data-lane', 'restore']),
        fetch: (context) {
          operationToken = context.cancellationToken;
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      final capturedAt = DateTime.utc(2026, 7, 20);
      harness.client.setQueryData(source, 1, updatedAt: capturedAt);
      final checkpoint = harness.client.snapshotQueryData(source);
      final optimistic = harness.client.setQueryData(
        source,
        9,
        updatedAt: DateTime.utc(2026, 7, 21),
      );

      final pending = harness.client.fetchQuery(source);
      await harness.pump();
      final token = operationToken!;
      final beforeRestore = harness.client.getQueryState(source)!;

      expect(
        harness.client.restoreQueryData(
          source,
          checkpoint,
          ifRevision: optimistic.revision,
        ),
        isTrue,
      );

      final restored = harness.client.getQueryState(source)!;
      expect(restored.data.requireValue(), 1);
      expect(restored.dataUpdatedAt, capturedAt);
      expect(restored.fetchStatus, beforeRestore.fetchStatus);
      expect(restored.pauseReason, beforeRestore.pauseReason);
      expect(restored.transientFailure, beforeRestore.transientFailure);
      expect(restored.failureCount, beforeRestore.failureCount);
      expect(identical(operationToken, token), isTrue);
      expect(token.isCancelled, isFalse);
      expect(harness.client.countFetching(), 1);

      transport.complete(10);
      expect(await pending, 10);
      expect(harness.client.getQueryData(source).requireValue(), 10);
    });
  });

  group('failed restore is observably inert', () {
    test('a newer write rejects restore without changing target cache',
        () async {
      final harness = _QueryContractHarness();
      addTearDown(harness.dispose);
      final source = query<int>(
        key: QueryKey(<Object?>['strict-restore', 'newer-write']),
        fetch: (_) => 0,
      );
      harness.client.setQueryData(
        source,
        1,
        updatedAt: DateTime.utc(2026, 7, 20),
      );
      final checkpoint = harness.client.snapshotQueryData(source);
      harness.client.setQueryData(
        source,
        2,
        updatedAt: DateTime.utc(2026, 7, 21),
      );
      await harness.pump();
      final stateBefore = harness.client.getQueryState(source)!;
      final cacheBefore = harness.client.queryCache.snapshots.single;
      final events = <QueryCacheEvent>[];
      final subscription = harness.client.queryCache.events.listen(events.add);
      addTearDown(subscription.cancel);

      expect(
        harness.client.restoreQueryData(
          source,
          checkpoint,
          ifRevision: checkpoint.revision,
        ),
        isFalse,
      );
      await harness.pump();

      _expectQueryStateUnchanged(
        harness.client.getQueryState(source)!,
        stateBefore,
      );
      _expectCacheStateUnchanged(
        harness.client.queryCache.snapshots.single,
        cacheBefore,
      );
      expect(events, isEmpty);
    });

    test('another key or client rejects restore without changing either cache',
        () async {
      final first = _QueryContractHarness();
      final second = _QueryContractHarness();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final origin = query<int>(
        key: QueryKey(<Object?>['strict-restore', 'origin']),
        fetch: (_) => 0,
      );
      final otherKey = query<int>(
        key: QueryKey(<Object?>['strict-restore', 'other-key']),
        fetch: (_) => 0,
      );
      first.client.setQueryData(origin, 1);
      final checkpoint = first.client.snapshotQueryData(origin);
      final otherKeyRevision = first.client.setQueryData(otherKey, 2).revision;
      final otherClientRevision =
          second.client.setQueryData(origin, 3).revision;
      await Future.wait(<Future<void>>[first.pump(), second.pump()]);
      final firstOriginBefore = first.client.getQueryState(origin)!;
      final firstTargetBefore = first.client.getQueryState(otherKey)!;
      final secondTargetBefore = second.client.getQueryState(origin)!;
      final firstCacheBefore = first.client.queryCache.snapshots.toList();
      final secondCacheBefore = second.client.queryCache.snapshots.toList();
      final firstEvents = <QueryCacheEvent>[];
      final secondEvents = <QueryCacheEvent>[];
      final firstSubscription = first.client.queryCache.events.listen(
        firstEvents.add,
      );
      final secondSubscription = second.client.queryCache.events.listen(
        secondEvents.add,
      );
      addTearDown(firstSubscription.cancel);
      addTearDown(secondSubscription.cancel);

      expect(
        first.client.restoreQueryData(
          otherKey,
          checkpoint,
          ifRevision: otherKeyRevision,
        ),
        isFalse,
      );
      expect(
        second.client.restoreQueryData(
          origin,
          checkpoint,
          ifRevision: otherClientRevision,
        ),
        isFalse,
      );
      await Future.wait(<Future<void>>[first.pump(), second.pump()]);

      _expectQueryStateUnchanged(
        first.client.getQueryState(origin)!,
        firstOriginBefore,
      );
      _expectQueryStateUnchanged(
        first.client.getQueryState(otherKey)!,
        firstTargetBefore,
      );
      _expectQueryStateUnchanged(
        second.client.getQueryState(origin)!,
        secondTargetBefore,
      );
      _expectCacheListsUnchanged(
        first.client.queryCache.snapshots.toList(),
        firstCacheBefore,
      );
      _expectCacheListsUnchanged(
        second.client.queryCache.snapshots.toList(),
        secondCacheBefore,
      );
      expect(firstEvents, isEmpty);
      expect(secondEvents, isEmpty);
    });

    test('a recreated lineage rejects restore without changing new state',
        () async {
      final harness = _QueryContractHarness();
      addTearDown(harness.dispose);
      final source = query<int>(
        key: QueryKey(<Object?>['strict-restore', 'lineage']),
        fetch: (_) => 0,
      );
      harness.client.setQueryData(source, 1);
      final oldCheckpoint = harness.client.snapshotQueryData(source);
      harness.client.removeQueries(
        QueryFilter(key: source.key, exact: true),
      );
      final recreatedRevision = harness.client
          .setQueryData(
            source,
            2,
            updatedAt: DateTime.utc(2026, 7, 22),
          )
          .revision;
      await harness.pump();
      final stateBefore = harness.client.getQueryState(source)!;
      final cacheBefore = harness.client.queryCache.snapshots.single;
      final events = <QueryCacheEvent>[];
      final subscription = harness.client.queryCache.events.listen(events.add);
      addTearDown(subscription.cancel);

      expect(
        harness.client.restoreQueryData(
          source,
          oldCheckpoint,
          ifRevision: recreatedRevision,
        ),
        isFalse,
      );
      await harness.pump();

      _expectQueryStateUnchanged(
        harness.client.getQueryState(source)!,
        stateBefore,
      );
      _expectCacheStateUnchanged(
        harness.client.queryCache.snapshots.single,
        cacheBefore,
      );
      expect(events, isEmpty);
    });
  });

  group('client cache lifecycle', () {
    test('client clear cancels queries but detaches continuing mutations',
        () async {
      final harness = _QueryContractHarness();
      addTearDown(harness.dispose);
      final queryTransport = Completer<int>();
      final mutationTransport = Completer<int>();
      var queryCalls = 0;
      final source = query<int>(
        key: QueryKey(<Object?>['strict-clear', 'query']),
        fetch: (_) {
          queryCalls += 1;
          return queryCalls == 1 ? queryTransport.future : 12;
        },
        retry: RetryPolicy.none,
      );
      final command = mutation<int, int, void>(
        mutate: (variables, _) =>
            variables == 1 ? mutationTransport.future : variables * 10,
      );
      final queryCache = harness.client.queryCache;
      final mutationCache = harness.client.mutationCache;
      var queryEventsClosed = false;
      var mutationEventsClosed = false;
      final querySubscription = queryCache.events.listen(
        (_) {},
        onDone: () => queryEventsClosed = true,
      );
      final mutationSubscription = mutationCache.events.listen(
        (_) {},
        onDone: () => mutationEventsClosed = true,
      );
      addTearDown(querySubscription.cancel);
      addTearDown(mutationSubscription.cancel);

      final queryFuture = harness.client.fetchQuery(source);
      final queryFailure = expectLater(
        queryFuture,
        throwsA(isA<QueryCancelledException>()),
      );
      final mutationFuture = harness.client.execute(command, 1);
      await harness.pump();
      expect(queryCache.snapshots, hasLength(1));
      expect(mutationCache.snapshots, hasLength(1));

      harness.client.clear();
      await queryFailure;
      await harness.pump();

      expect(queryCache.snapshots, isEmpty);
      expect(mutationCache.snapshots, isEmpty);
      expect(queryEventsClosed, isFalse);
      expect(mutationEventsClosed, isFalse);

      mutationTransport.complete(7);
      expect(await mutationFuture, 7);
      queryTransport.complete(99);
      await harness.pump();
      expect(queryCache.snapshots, isEmpty);
      expect(mutationCache.snapshots, isEmpty);

      expect(await harness.client.fetchQuery(source), 12);
      expect(await harness.client.execute(command, 2), 20);
      await harness.pump();
      expect(queryCache.snapshots.single.data.requireValue(), 12);
      expect(mutationCache.snapshots.single.data.requireValue(), 20);
    });

    test('query execution after clear publishes to the original subscription',
        () async {
      final harness = _QueryContractHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final source = query<int>(
        key: QueryKey(<Object?>['strict-clear', 'later-execute']),
        fetch: (_) => ++calls,
        retry: RetryPolicy.none,
      );
      final events = <QueryCacheEvent>[];
      var eventsClosed = false;
      final subscription = harness.client.queryCache.events.listen(
        events.add,
        onDone: () => eventsClosed = true,
      );
      addTearDown(subscription.cancel);

      expect(await harness.client.fetchQuery(source), 1);
      await harness.pump();
      harness.client.clear();
      await harness.pump();
      final laterBoundary = events.length;

      expect(await harness.client.fetchQuery(source), 2);
      await harness.pump();

      expect(eventsClosed, isFalse);
      expect(
        events.skip(laterBoundary).map((event) => event.kind),
        <QueryCacheEventKind>[
          QueryCacheEventKind.added,
          QueryCacheEventKind.updated,
          QueryCacheEventKind.updated,
        ],
      );
      expect(
        events.skip(laterBoundary).last.snapshot.data.requireValue(),
        2,
      );
    });

    test('dispose fails active query closes events and rejects late completion',
        () async {
      final harness = _QueryContractHarness();
      final transport = Completer<int>();
      QueryCancellationToken? token;
      var queryCalls = 0;
      final source = query<int>(
        key: QueryKey(<Object?>['strict-dispose', 'active-query']),
        fetch: (context) {
          queryCalls += 1;
          token = context.cancellationToken;
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      final cache = harness.client.queryCache;
      final events = <QueryCacheEvent>[];
      final eventsClosed = Completer<void>();
      final subscription = cache.events.listen(
        events.add,
        onDone: eventsClosed.complete,
      );
      addTearDown(subscription.cancel);
      final future = harness.client.fetchQuery(source);
      final failure = expectLater(
        future,
        throwsA(isA<QueryClientDisposedException>()),
      );
      await harness.pump();
      final eventBoundary = events.length;

      harness.client.dispose();
      await failure;
      await eventsClosed.future;

      expect(token!.isCancelled, isTrue);
      expect(cache.isDisposed, isTrue);
      expect(cache.snapshots, isEmpty);
      expect(queryCalls, 1);

      transport.complete(9);
      await harness.pump();

      expect(cache.snapshots, isEmpty);
      expect(events, hasLength(eventBoundary));
      expect(queryCalls, 1);
    });
  });
}

void _expectQueryStateUnchanged<T>(
  QuerySnapshot<T> actual,
  QuerySnapshot<T> before,
) {
  expect(actual.key, before.key);
  expect(actual.data, before.data);
  expect(actual.status, before.status);
  expect(actual.fetchStatus, before.fetchStatus);
  expect(actual.pauseReason, before.pauseReason);
  expect(actual.failure, before.failure);
  expect(actual.transientFailure, before.transientFailure);
  expect(actual.failureCount, before.failureCount);
  expect(actual.dataUpdatedAt, before.dataUpdatedAt);
  expect(actual.failureUpdatedAt, before.failureUpdatedAt);
  expect(actual.dataUpdateCount, before.dataUpdateCount);
  expect(actual.failureUpdateCount, before.failureUpdateCount);
  expect(actual.revision, before.revision);
  expect(actual.invalidationRevision, before.invalidationRevision);
  expect(actual.isInvalidated, before.isInvalidated);
  expect(actual.metadata, before.metadata);
}

void _expectCacheStateUnchanged(
  QueryCacheSnapshot actual,
  QueryCacheSnapshot before,
) {
  expect(actual.key, before.key);
  expect(actual.data, before.data);
  expect(actual.status, before.status);
  expect(actual.fetchStatus, before.fetchStatus);
  expect(actual.pauseReason, before.pauseReason);
  expect(actual.failure, before.failure);
  expect(actual.transientFailure, before.transientFailure);
  expect(actual.failureCount, before.failureCount);
  expect(actual.dataUpdatedAt, before.dataUpdatedAt);
  expect(actual.failureUpdatedAt, before.failureUpdatedAt);
  expect(actual.dataUpdateCount, before.dataUpdateCount);
  expect(actual.failureUpdateCount, before.failureUpdateCount);
  expect(actual.revision, before.revision);
  expect(actual.invalidationRevision, before.invalidationRevision);
  expect(actual.isInvalidated, before.isInvalidated);
  expect(actual.observerCount, before.observerCount);
  expect(actual.isStale, before.isStale);
  expect(actual.metadata, before.metadata);
}

void _expectCacheListsUnchanged(
  List<QueryCacheSnapshot> actual,
  List<QueryCacheSnapshot> before,
) {
  expect(actual, hasLength(before.length));
  for (var index = 0; index < before.length; index += 1) {
    _expectCacheStateUnchanged(actual[index], before[index]);
  }
}

final class _QueryContractHarness {
  _QueryContractHarness()
      : clock = FakeQueryClock(),
        timers = FakeQueryTimerScheduler(),
        notifications = FakeQueryNotificationScheduler() {
    client = QueryClient(
      runtime: QueryRuntime(
        clock: clock,
        timers: timers,
        random: FakeQueryRandomSource(<double>[
          0.5,
          0.5,
          0.5,
          0.5,
          0.5,
          0.5,
          0.5,
          0.5,
        ]),
        notifications: notifications,
      ),
    );
  }

  final FakeQueryClock clock;
  final FakeQueryTimerScheduler timers;
  final FakeQueryNotificationScheduler notifications;
  late final QueryClient client;

  Future<void> pump() async {
    for (var index = 0; index < 3; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() {
    if (!client.isDisposed) client.dispose();
  }
}
