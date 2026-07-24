import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('query cancellation and guarded completion', () {
    test('explicit cancellation reverts retained data without failure count',
        () async {
      final transport = Completer<int>();
      final raw = query<int>(
        QueryKey(<Object?>['cancel', 'revert']),
        (_) => transport.future,
        retry: RetryPolicy.none,
      );
      final client = QueryClient()..setQueryData(raw, 1);
      final fetching = client.fetchQuery(raw);
      final fetchingExpectation =
          expectLater(fetching, throwsA(isA<QueryCancelledException>()));
      await _pump();

      final result = await client.cancelQueries(
        filter: QueryFilter(key: raw.key, exact: true),
      );
      await fetchingExpectation;
      final snapshot = client.getQueryState(raw)!;
      expect(result.affected, 1);
      expect(snapshot.data.requireValue(), 1);
      expect(snapshot.status, QueryStatus.success);
      expect(snapshot.fetchStatus, FetchStatus.idle);
      expect(snapshot.failure, isNull);
      expect(snapshot.failureCount, 0);

      transport.complete(2);
      await _pump();
      expect(client.getQueryData(raw).requireValue(), 1);
      client.dispose();
    });

    test(
        'external cache write does not cancel a completion in the same microtask',
        () async {
      final transport = Completer<int>.sync();
      final raw = query<int>(
        QueryKey(<Object?>['race', 'write']),
        (_) => transport.future,
        retry: RetryPolicy.none,
      );
      final client = QueryClient();
      final fetching = client.fetchQuery(raw);
      await _pump();

      client.setQueryData(raw, 9);
      expect(client.getQueryData(raw).requireValue(), 9);
      transport.complete(1);
      expect(await fetching, 1);
      await _pump();
      expect(client.getQueryData(raw).requireValue(), 1);
      expect(client.getQueryState(raw)!.failureCount, 0);
      client.dispose();
    });

    test('retained-data refetch failure remains a refetch error', () async {
      var shouldFail = false;
      final raw = query<int>(
        QueryKey(<Object?>['failure', 'retained']),
        (_) {
          if (shouldFail) throw StateError('refresh failed');
          return 1;
        },
        retry: RetryPolicy.none,
      );
      final client = QueryClient();
      expect(await client.fetchQuery(raw), 1);
      final observer = client.observeQuery(raw.withObserver(enabled: false));
      shouldFail = true;

      final result = await observer.refetch();
      expect(result.data.requireValue(), 1);
      expect(result.isRefetchError, isTrue);
      expect(result.isLoadingError, isFalse);
      expect(result.failureCount, 1);
      client.dispose();
    });

    test('client disposal cancels live work and guards every late callback',
        () async {
      const retryDelay = Duration(seconds: 11);
      const pollingInterval = Duration(seconds: 23);
      const gcDelay = Duration(seconds: 37);
      final timers = FakeQueryTimerScheduler();
      final notifications = FakeQueryNotificationScheduler();
      final runtime = QueryRuntime(
        clock: FakeQueryClock(),
        timers: timers,
        random: FakeQueryRandomSource(),
        notifications: notifications,
      );
      final client = QueryClient(runtime: runtime);
      final cacheEvents = <QueryCacheEvent>[];
      final cacheSubscription = client.queryCache.events.listen(
        cacheEvents.add,
      );
      var queuedPublications = 0;

      var retryAttempts = 0;
      final retrySource = query<int>(
        QueryKey(<Object?>['dispose', 'retry']),
        (_) {
          retryAttempts += 1;
          throw StateError('wait before retry');
        },
        retry: RetryPolicy.none,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.fixed(retryDelay),
        ),
      );
      final retrying = client.fetchQuery(retrySource);
      await _pump();
      expect(retryAttempts, 1);

      var pollingAttempts = 0;
      final pollingSource = query<int>(
        QueryKey(<Object?>['dispose', 'polling']),
        (_) => ++pollingAttempts,
        retry: RetryPolicy.none,
      ).withInitialData(0).withObserver(
            refetchOnMount: RefetchPolicy.never,
            pollingInterval: pollingInterval,
          );
      final pollingObserver = client.observeQuery(pollingSource);

      final gcSource = query<int>(
        QueryKey(<Object?>['dispose', 'gc']),
        (_) => 0,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.duration(gcDelay),
      ).withInitialData(0).withObserver(
            refetchOnMount: RefetchPolicy.never,
          );
      client.observeQuery(gcSource).dispose();

      var transportAttempts = 0;
      final transportStarted = Completer<void>();
      final transport = Completer<int>();
      final transportSource = query<int>(
        QueryKey(<Object?>['dispose', 'transport']),
        (_) {
          transportAttempts += 1;
          transportStarted.complete();
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      final fetching = client.fetchQuery(transportSource);
      await transportStarted.future;
      client.notificationsInternal.enqueue(() => queuedPublications += 1);
      await _pump();

      final retryHandle = timers.handles.singleWhere(
        (handle) =>
            !handle.isCancelled &&
            handle.interval == null &&
            handle.due == retryDelay,
      );
      final pollingHandle = timers.handles.singleWhere(
        (handle) =>
            !handle.isCancelled &&
            handle.interval == null &&
            handle.due == pollingInterval,
      );
      final gcHandle = timers.handles.singleWhere(
        (handle) =>
            !handle.isCancelled &&
            handle.interval == null &&
            handle.due == gcDelay,
      );
      final notificationHandle = notifications.handles.singleWhere(
        (handle) => !handle.isCancelled,
      );
      expect(
        timers.handles.where((handle) => !handle.isCancelled),
        hasLength(3),
      );
      expect(client.queryCache.snapshots, hasLength(4));
      expect(pollingAttempts, 0);
      expect(cacheEvents, isEmpty);
      expect(queuedPublications, 0);

      final retryFailure = expectLater(
        retrying,
        throwsA(isA<QueryClientDisposedException>()),
      );
      final transportFailure = expectLater(
        fetching,
        throwsA(isA<QueryClientDisposedException>()),
      );

      client.dispose();
      expect(retryHandle.isCancelled, isTrue);
      expect(pollingHandle.isCancelled, isTrue);
      expect(gcHandle.isCancelled, isTrue);
      expect(notificationHandle.isCancelled, isTrue);
      expect(pollingObserver.isDisposed, isTrue);
      expect(timers.handles.every((handle) => handle.isCancelled), isTrue);
      expect(
        notifications.handles.every((handle) => handle.isCancelled),
        isTrue,
      );
      await Future.wait(<Future<void>>[retryFailure, transportFailure]);

      retryHandle.fire(evenIfCancelled: true);
      pollingHandle.fire(evenIfCancelled: true);
      gcHandle.fire(evenIfCancelled: true);
      notificationHandle.fire(evenIfCancelled: true);
      transport.complete(1);
      await _pump();

      expect(retryAttempts, 1);
      expect(pollingAttempts, 0);
      expect(transportAttempts, 1);
      expect(timers.handles.every((handle) => handle.isCancelled), isTrue);
      expect(
        notifications.handles.every((handle) => handle.isCancelled),
        isTrue,
      );
      expect(cacheEvents, isEmpty);
      expect(queuedPublications, 0);
      expect(client.queryCache.isDisposed, isTrue);
      expect(client.queryCache.snapshots, isEmpty);
      await cacheSubscription.cancel();
    });

    test('reentrant fetch during replacement joins the reserved winner',
        () async {
      late QueryClient client;
      late Future<int> reentrant;
      var reentrantCalls = 0;
      final key = QueryKey(<Object?>['cancel', 'reentrant-replacement']);
      final pendingTransport = Completer<int>();
      final reentrantQuery = query<int>(
        key,
        (_) {
          reentrantCalls += 1;
          return 3;
        },
        retry: RetryPolicy.none,
      );
      final firstQuery = query<int>(
        key,
        (context) {
          context.cancellationToken.addListener((_) {
            reentrant = client.fetchQuery(
              reentrantQuery,
              cancelRefetch: true,
            );
          });
          return pendingTransport.future;
        },
        retry: RetryPolicy.none,
      );
      final winnerQuery = query<int>(
        key,
        (_) => 2,
        retry: RetryPolicy.none,
      );
      client = QueryClient()..setQueryData(firstQuery, 0);
      final first = client.fetchQuery(firstQuery);
      final firstCancelled =
          expectLater(first, throwsA(isA<QueryCancelledException>()));
      await _pump();

      expect(
        await client.fetchQuery(winnerQuery, cancelRefetch: true),
        2,
      );
      expect(await reentrant, 2);
      expect(reentrantCalls, 0);
      await firstCancelled;
      expect(client.getQueryData(winnerQuery).requireValue(), 2);
      client.dispose();
    });

    test('reentrant cancellation clears a replacement reservation', () async {
      late QueryClient client;
      Future<QueryBatchResult>? nestedCancellation;
      final key = QueryKey(<Object?>['cancel', 'reentrant-reservation-cancel']);
      final pendingTransport = Completer<int>();
      final firstQuery = query<int>(
        key,
        (context) {
          context.cancellationToken.addListener((_) {
            nestedCancellation = client.cancelQueries(
              filter: QueryFilter(key: key, exact: true),
            );
          });
          return pendingTransport.future;
        },
        retry: RetryPolicy.none,
      );
      final replacedQuery = query<int>(
        key,
        (_) => 2,
        retry: RetryPolicy.none,
      );
      final laterQuery = query<int>(
        key,
        (_) => 3,
        retry: RetryPolicy.none,
      );
      client = QueryClient()..setQueryData(firstQuery, 0);
      final first = expectLater(
        client.fetchQuery(firstQuery),
        throwsA(isA<QueryCancelledException>()),
      );
      await _pump();

      await expectLater(
        client.fetchQuery(replacedQuery, cancelRefetch: true),
        throwsA(isA<QueryCancelledException>()),
      );
      await nestedCancellation;
      await first;

      expect(
        await client.fetchQuery(laterQuery, cancelRefetch: true),
        3,
      );
      expect(client.getQueryData(laterQuery).requireValue(), 3);
      client.dispose();
    });

    test('remove detaches its incarnation before a token listener refetches',
        () async {
      late QueryClient client;
      late Future<int> reentrant;
      final key = QueryKey(<Object?>['cancel', 'remove-reentrant']);
      final pendingTransport = Completer<int>();
      final replacement = query<int>(
        key,
        (_) => 4,
        retry: RetryPolicy.none,
      );
      final firstQuery = query<int>(
        key,
        (context) {
          context.cancellationToken.addListener((_) {
            reentrant = client.fetchQuery(replacement);
          });
          return pendingTransport.future;
        },
        retry: RetryPolicy.none,
      );
      client = QueryClient();
      final first = expectLater(
        client.fetchQuery(firstQuery),
        throwsA(isA<QueryCancelledException>()),
      );
      await _pump();

      expect(
        client.removeQueries(QueryFilter(key: key, exact: true)),
        1,
      );
      expect(await reentrant, 4);
      await first;
      expect(client.getQueryData(replacement).requireValue(), 4);
      client.dispose();
    });

    test('cancellation commits rollback before a listener removes the entry',
        () async {
      final notifications = FakeQueryNotificationScheduler();
      final runtime = QueryRuntime(
        clock: FakeQueryClock(),
        timers: FakeQueryTimerScheduler(),
        random: FakeQueryRandomSource(),
        notifications: notifications,
      );
      late QueryClient client;
      final key = QueryKey(<Object?>['cancel', 'remove-event-order']);
      final transport = Completer<int>();
      final source = query<int>(
        key,
        (context) {
          context.cancellationToken.addListener((_) {
            client.removeQueries(
              QueryFilter(key: key, exact: true),
            );
          });
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      client = QueryClient(runtime: runtime)..setQueryData(source, 1);
      final kinds = <QueryCacheEventKind>[];
      final subscription = client.queryCache.events.listen(
        (event) => kinds.add(event.kind),
      );
      notifications.flushAll();
      kinds.clear();

      final fetching = expectLater(
        client.fetchQuery(source),
        throwsA(isA<QueryCancelledException>()),
      );
      await _pump();
      notifications.flushAll();
      kinds.clear();

      await client.cancelQueries(
        filter: QueryFilter(key: key, exact: true),
      );
      await fetching;
      notifications.flushAll();

      expect(
        kinds,
        <QueryCacheEventKind>[
          QueryCacheEventKind.updated,
          QueryCacheEventKind.removed,
        ],
      );
      expect(client.getQueryState(source), isNull);

      transport.complete(2);
      await _pump();
      expect(client.getQueryState(source), isNull);
      await subscription.cancel();
      client.dispose();
    });

    test('dispose rejects work started from a cancellation listener', () async {
      late QueryClient client;
      late Future<void> reentrantFailure;
      final key = QueryKey(<Object?>['dispose', 'reentrant']);
      final pendingTransport = Completer<int>();
      final later = query<int>(
        key,
        (_) => 2,
        retry: RetryPolicy.none,
      );
      final firstQuery = query<int>(
        key,
        (context) {
          context.cancellationToken.addListener((_) {
            reentrantFailure = expectLater(
              client.fetchQuery(later),
              throwsA(isA<QueryClientDisposedException>()),
            );
          });
          return pendingTransport.future;
        },
        retry: RetryPolicy.none,
      );
      client = QueryClient();
      final first = expectLater(
        client.fetchQuery(firstQuery),
        throwsA(isA<QueryClientDisposedException>()),
      );
      await _pump();

      client.dispose();

      await first;
      await reentrantFailure;
      pendingTransport.complete(1);
      await _pump();
    });

    test('reset commits before a cancellation listener starts new work',
        () async {
      late QueryClient client;
      late Future<int> reentrant;
      final nextTransport = Completer<int>();
      final key = QueryKey(<Object?>['reset', 'reentrant']);
      final nextQuery = query<int>(
        key,
        (_) => nextTransport.future,
        retry: RetryPolicy.none,
      );
      final firstTransport = Completer<int>();
      final firstQuery = query<int>(
        key,
        (context) {
          context.cancellationToken.addListener((_) {
            reentrant = client.fetchQuery(nextQuery);
          });
          return firstTransport.future;
        },
        retry: RetryPolicy.none,
      );
      client = QueryClient();
      final first = expectLater(
        client.fetchQuery(firstQuery),
        throwsA(isA<QueryCancelledException>()),
      );
      await _pump();

      await client.resetQueries(
        filter: QueryFilter(key: key, exact: true),
        refetchType: QueryRefetchTarget.none,
      );
      final duringReentrantWork = client.getQueryState(nextQuery)!;
      expect(duringReentrantWork.data.isAbsent, isTrue);
      expect(duringReentrantWork.status, QueryStatus.pending);
      expect(duringReentrantWork.fetchStatus, FetchStatus.fetching);

      nextTransport.complete(5);
      expect(await reentrant, 5);
      await first;
      expect(client.getQueryData(nextQuery).requireValue(), 5);
      client.dispose();
    });
  });

  group('final observer detach', () {
    test('consumed cancellation token cancels the active attempt', () async {
      final transport = Completer<int>();
      final raw = query<int>(
        QueryKey(<Object?>['detach', 'consumed']),
        (context) {
          unawaited(context.cancellationToken.whenCancelled);
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      final client = QueryClient();
      final observer = client.observeQuery(raw);
      await _pump();

      observer.dispose();
      await _pump();
      final snapshot = client.getQueryState(raw)!;
      expect(snapshot.fetchStatus, FetchStatus.idle);
      expect(snapshot.status, QueryStatus.pending);
      expect(snapshot.failureCount, 0);
      transport.complete(1);
      await _pump();
      expect(client.getQueryData(raw).isAbsent, isTrue);
      client.dispose();
    });

    test('unconsumed attempt may finish but cannot begin another retry',
        () async {
      final transport = Completer<int>();
      var calls = 0;
      final raw = query<int>(
        QueryKey(<Object?>['detach', 'stop-retries']),
        (_) {
          calls += 1;
          return transport.future;
        },
        retry: RetryPolicy.none,
      ).withRetry(
        (retry) => retry.strategy(
          delay: DelayPolicy.none(),
          retryIf: retry.exceptions,
        ),
      );
      final client = QueryClient();
      final observer = client.observeQuery(raw);
      await _pump();
      observer.dispose();
      transport.completeError(StateError('one attempt'));
      await _pump();

      expect(calls, 1);
      final snapshot = client.getQueryState(raw)!;
      expect(snapshot.status, QueryStatus.error);
      expect(snapshot.failureCount, 1);
      client.dispose();
    });

    test('paused absent operation is cancelled before becoming online',
        () async {
      var calls = 0;
      final raw = query<int>(
        QueryKey(<Object?>['detach', 'paused']),
        (_) => ++calls,
        retry: RetryPolicy.none,
      );
      final client = QueryClient()..onlineManager.isOnline = false;
      final observer = client.observeQuery(raw);
      await _pump();
      expect(observer.fetchStatus, FetchStatus.paused);

      observer.dispose();
      client.onlineManager.isOnline = true;
      await _pump();
      expect(calls, 0);
      expect(client.getQueryState(raw)!.fetchStatus, FetchStatus.idle);
      client.dispose();
    });
  });

  group('retention and GC generations', () {
    test('longest retention wins and stale timer cannot remove reattachment',
        () async {
      final timers = FakeQueryTimerScheduler();
      final runtime = _runtime(timers);
      final key = QueryKey(<Object?>['gc', 'longest']);
      final short = query<int>(
        key,
        (_) => 1,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.duration(const Duration(seconds: 5)),
      ).withInitialData(1).withObserver(enabled: false);
      final long = query<int>(
        key,
        (_) => 2,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.duration(const Duration(seconds: 10)),
      ).withInitialData(2).withObserver(enabled: false);
      final client = QueryClient(runtime: runtime);
      final first = client.observeQuery(short);
      final second = client.observeQuery(long);
      first.dispose();
      second.dispose();
      final staleHandle = timers.handles.single;

      timers.elapse(const Duration(seconds: 9));
      expect(client.queryCache.snapshots, hasLength(1));
      final reattached = client.observeQuery(long);
      staleHandle.fire(evenIfCancelled: true);
      expect(client.queryCache.snapshots, hasLength(1));
      reattached.dispose();
      timers.elapse(const Duration(seconds: 10));
      expect(client.queryCache.snapshots, isEmpty);
      client.dispose();
    });

    test('forever retention schedules no GC handle', () {
      final timers = FakeQueryTimerScheduler();
      final raw = query<int>(
        QueryKey(<Object?>['gc', 'forever']),
        (_) => 1,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.forever,
      ).withInitialData(1).withObserver(enabled: false);
      final client = QueryClient(runtime: _runtime(timers));

      client.observeQuery(raw).dispose();
      timers.elapse(const Duration(days: 365));
      expect(timers.handles, isEmpty);
      expect(client.queryCache.snapshots, hasLength(1));
      client.dispose();
    });

    test('zero retention waits for active operation to settle', () async {
      final timers = FakeQueryTimerScheduler();
      final transport = Completer<int>();
      final raw = query<int>(
        QueryKey(<Object?>['gc', 'active']),
        (_) => transport.future,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.duration(Duration.zero),
      );
      final client = QueryClient(runtime: _runtime(timers));
      final observer = client.observeQuery(raw);
      await _pump();
      observer.dispose();
      expect(timers.handles, isEmpty);

      transport.complete(1);
      await _pump();
      expect(client.queryCache.snapshots, hasLength(1));
      timers.elapse(Duration.zero);
      expect(client.queryCache.snapshots, isEmpty);
      client.dispose();
    });
  });
}

QueryRuntime _runtime(FakeQueryTimerScheduler timers) {
  return QueryRuntime(
    clock: FakeQueryClock(),
    timers: timers,
    random: FakeQueryRandomSource(),
    notifications: FakeQueryNotificationScheduler(),
  );
}

Future<void> _pump([int turns = 8]) async {
  for (var index = 0; index < turns; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
