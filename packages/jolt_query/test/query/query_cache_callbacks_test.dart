import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

void main() {
  test('present-null success callbacks observe one post-commit snapshot',
      () async {
    final order = <String>[];
    final snapshots = <QueryCacheSnapshot>[];
    var futureSettled = false;
    final client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onSuccess: (data, snapshot) {
          expect(futureSettled, isFalse);
          expect(data, isNull);
          expect(snapshot.data.isPresent, isTrue);
          expect(snapshot.data.requireValue(), isNull);
          expect(snapshot.status, QueryStatus.success);
          expect(snapshot.fetchStatus, FetchStatus.idle);
          order.add('success');
          snapshots.add(snapshot);
        },
        onSettled: (data, failure, snapshot) {
          expect(futureSettled, isFalse);
          expect(data.isPresent, isTrue);
          expect(data.requireValue(), isNull);
          expect(failure, isNull);
          order.add('settled');
          snapshots.add(snapshot);
        },
      ),
    );
    addTearDown(client.dispose);
    final raw = query<int?>(
      key: QueryKey(<Object?>['callbacks', 'present-null']),
      fetch: (_) => null,
      retry: RetryPolicy.none,
    );

    final pending = client.fetchQuery(raw);
    unawaited(pending.then((_) => futureSettled = true));
    expect(await pending, isNull);
    await _pump();

    expect(order, <String>['success', 'settled']);
    expect(snapshots, hasLength(2));
    expect(snapshots.last, same(snapshots.first));
    expect(futureSettled, isTrue);
  });

  test('retained failure callbacks keep data and run exactly once', () async {
    final order = <String>[];
    QueryFailure? callbackFailure;
    QueryValue<Object?>? settledData;
    final snapshots = <QueryCacheSnapshot>[];
    final client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onError: (failure, snapshot) {
          order.add('error');
          callbackFailure = failure;
          snapshots.add(snapshot);
        },
        onSettled: (data, failure, snapshot) {
          order.add('settled');
          expect(failure, same(callbackFailure));
          settledData = data;
          snapshots.add(snapshot);
        },
      ),
    );
    addTearDown(client.dispose);
    final raw = query<int>(
      key: QueryKey(<Object?>['callbacks', 'retained-error']),
      fetch: (_) => throw StateError('transport'),
      retry: RetryPolicy.none,
    );

    client.setQueryData(raw, 7);
    expect(order, isEmpty);
    await expectLater(client.fetchQuery(raw), throwsA(isA<StateError>()));

    expect(order, <String>['error', 'settled']);
    expect(callbackFailure?.error, isA<StateError>());
    expect(settledData?.requireValue(), 7);
    expect(snapshots.last, same(snapshots.first));
    expect(snapshots, hasLength(2));
    expect(snapshots.first.data.requireValue(), 7);
    expect(snapshots.first.status, QueryStatus.error);
    expect(snapshots.first.fetchStatus, FetchStatus.idle);
    expect(snapshots.first.failure, same(callbackFailure));
  });

  test('transient retry failures do not invoke terminal error callbacks',
      () async {
    final order = <String>[];
    var attempts = 0;
    final client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onSuccess: (_, __) => order.add('success'),
        onError: (_, __) => order.add('error'),
        onSettled: (_, __, ___) => order.add('settled'),
      ),
    );
    addTearDown(client.dispose);
    final raw = query<int>(
      key: QueryKey(<Object?>['callbacks', 'retry']),
      fetch: (_) {
        attempts += 1;
        if (attempts == 1) throw StateError('transient');
        return 2;
      },
      retry: RetryPolicy.none,
    ).retry(
      (retry) => retry.strategy(
        retryIf: retry.exceptions & retry.maxRetries(1),
        delay: DelayPolicy.none(),
      ),
    );

    expect(await client.fetchQuery(raw), 2);
    expect(attempts, 2);
    expect(order, <String>['success', 'settled']);
  });

  test(
      'manual writes, initial data, cancellation, and stream partials '
      'are not terminal callbacks', () async {
    final order = <String>[];
    final client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onSuccess: (_, __) => order.add('success'),
        onError: (_, __) => order.add('error'),
        onSettled: (_, __, ___) => order.add('settled'),
      ),
    );
    addTearDown(client.dispose);

    final cancelledTransport = Completer<int>();
    final cancelled = query<int>(
      key: QueryKey(<Object?>['callbacks', 'cancelled']),
      fetch: (_) => cancelledTransport.future,
      retry: RetryPolicy.none,
    );
    client.setQueryData(cancelled, 1);
    final seeded = query<int>(
      key: QueryKey(<Object?>['callbacks', 'initial-data']),
      fetch: (_) => 0,
      retry: RetryPolicy.none,
    );
    client
        .observeQuery(
          seeded.initialData(0).observer(enabled: false),
        )
        .dispose();
    expect(order, isEmpty);

    final pendingCancelled = client.fetchQuery(cancelled);
    final cancellationExpectation = expectLater(
      pendingCancelled,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();
    await client.cancelQueries(
      filter: QueryFilter(key: cancelled.key, exact: true),
    );
    await cancellationExpectation;
    expect(order, isEmpty);

    final source = StreamController<int>(sync: true);
    final streamed = query<List<int>>(
      key: QueryKey(<Object?>['callbacks', 'stream']),
      fetch: streamedQuery<int, List<int>>(
        stream: (_) => source.stream,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final pendingStream = client.fetchQuery(streamed);
    await _pump();
    source.add(1);
    await _pump();
    expect(order, isEmpty);

    await source.close();
    expect(await pendingStream, <int>[1]);
    expect(order, <String>['success', 'settled']);

    cancelledTransport.complete(2);
    await _pump();
    expect(order, <String>['success', 'settled']);
  });

  test('superseded operations do not receive terminal callbacks', () async {
    final successfulData = <Object?>[];
    final firstRefresh = Completer<int>();
    var calls = 0;
    final client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onSuccess: (data, _) => successfulData.add(data),
      ),
    );
    addTearDown(client.dispose);
    final raw = query<int>(
      key: QueryKey(<Object?>['callbacks', 'superseded']),
      fetch: (_) {
        calls += 1;
        return switch (calls) {
          1 => 1,
          2 => firstRefresh.future,
          _ => 3,
        };
      },
      retry: RetryPolicy.none,
    );

    expect(await client.fetchQuery(raw), 1);
    successfulData.clear();
    final loser = client.fetchQuery(raw);
    final loserExpectation = expectLater(
      loser,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();
    expect(await client.fetchQuery(raw, cancelRefetch: true), 3);
    await loserExpectation;

    firstRefresh.complete(2);
    await _pump();
    expect(successfulData, <Object?>[3]);
  });

  test('callback failures go to the captured Zone without changing success',
      () async {
    final callbackErrors = <Object>[];
    final order = <String>[];
    final transport = Completer<int>();
    final client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onSuccess: (_, __) {
          order.add('success');
          throw StateError('callback');
        },
        onSettled: (_, __, ___) => order.add('settled'),
      ),
    );
    addTearDown(client.dispose);
    final raw = query<int>(
      key: QueryKey(<Object?>['callbacks', 'zone']),
      fetch: (_) => transport.future,
      retry: RetryPolicy.none,
    );
    late Future<int> pending;

    runZonedGuarded(
      () {
        pending = client.fetchQuery(raw);
      },
      (error, _) => callbackErrors.add(error),
    );
    transport.complete(5);

    expect(await pending, 5);
    expect(order, <String>['success', 'settled']);
    expect(callbackErrors, hasLength(1));
    expect(callbackErrors.single, isA<StateError>());
    expect(client.getQueryData(raw).requireValue(), 5);
  });
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
