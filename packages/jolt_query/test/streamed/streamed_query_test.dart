import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('streamedListQuery accumulates chunks into an inferred typed IList',
      () async {
    final QueryFunction<IList<int>> fetch = streamedListQuery<int>(
      stream: (_) => Stream<int>.fromIterable(<int>[1, 2, 3]),
    );
    final raw = query<IList<int>>(
      QueryKey(<Object?>['stream', 'list-helper']),
      fetch,
      retry: RetryPolicy.none,
    );
    final client = QueryClient();

    expect(await client.fetchQuery(raw), <int>[1, 2, 3]);
    expect(client.getQueryData(raw).requireValue(), isA<IList<int>>());
    client.dispose();
  });

  test('ordinary query recipe reuses the streamed cache identity', () async {
    final key = QueryKey(<Object?>['stream', 'ordinary-reuse']);
    final streamed = query<List<int>>(
      key,
      streamedQuery<int, List<int>>(
        stream: (_) => Stream<int>.value(1),
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    var ordinaryCalls = 0;
    final ordinary = query<List<int>>(
      QueryKey(<Object?>['stream', 'ordinary-reuse']),
      (_) => <int>[++ordinaryCalls + 8],
      retry: RetryPolicy.none,
    );
    final client = QueryClient();

    expect(await client.fetchQuery(streamed), <int>[1]);
    expect(client.getQueryData(ordinary).requireValue(), <int>[1]);
    expect(client.queryCache.snapshots, hasLength(1));

    expect(await client.fetchQuery(ordinary), <int>[9]);
    expect(ordinaryCalls, 1);
    expect(client.getQueryData(streamed).requireValue(), <int>[9]);
    expect(client.queryCache.snapshots, hasLength(1));
    client.dispose();
  });

  test('reentrant initial cancellation prevents the stream factory', () async {
    late QueryClient client;
    var streamCalls = 0;
    final key = QueryKey(<Object?>['stream', 'cancel-in-initial']);
    final raw = query<List<int>>(
      key,
      streamedQuery<int, List<int>>(
        stream: (_) {
          streamCalls += 1;
          return const Stream<int>.empty();
        },
        initial: () {
          unawaited(
            client.cancelQueries(
              filter: QueryFilter(key: key, exact: true),
            ),
          );
          return <int>[];
        },
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    client = QueryClient();

    await expectLater(
      client.fetchQuery(raw),
      throwsA(isA<QueryCancelledException>()),
    );

    expect(streamCalls, 0);
    client.dispose();
  });

  test('reentrant stream-factory cancellation prevents subscription', () async {
    late QueryClient client;
    late _AdversarialStream<int> returnedSource;
    final key = QueryKey(<Object?>['stream', 'cancel-in-factory']);
    final raw = query<List<int>>(
      key,
      streamedQuery<int, List<int>>(
        stream: (_) {
          returnedSource = _AdversarialStream<int>();
          unawaited(
            client.cancelQueries(
              filter: QueryFilter(key: key, exact: true),
            ),
          );
          return returnedSource;
        },
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    client = QueryClient();

    await expectLater(
      client.fetchQuery(raw),
      throwsA(isA<QueryCancelledException>()),
    );

    expect(returnedSource.hasListener, isFalse);
    client.dispose();
  });

  test('reentrant reconciliation cannot publish a stale partial value',
      () async {
    late QueryClient client;
    late Query<List<int>> replacement;
    Future<List<int>>? replacementRun;
    final replacementTransport = Completer<List<int>>();
    final source = StreamController<int>(sync: true);
    final key = QueryKey(<Object?>['stream', 'replace-in-reconciler']);
    var didReplace = false;
    final raw = query<List<int>>(
      key,
      streamedQuery<int, List<int>>(
        stream: (_) => source.stream,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.append,
      ),
      retry: RetryPolicy.none,
      reconciler: DataReconciler<List<int>>.custom((previous, next) {
        if (!didReplace) {
          didReplace = true;
          replacementRun = client.fetchQuery(
            replacement,
            cancelRefetch: true,
          );
        }
        return next;
      }),
    );
    replacement = query<List<int>>(
      key,
      (_) => replacementTransport.future,
      retry: RetryPolicy.none,
    );
    client = QueryClient()..setQueryData(raw, <int>[0]);

    final staleRun = expectLater(
      client.fetchQuery(raw),
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();
    source.add(1);
    await _pump();

    expect(client.getQueryData(raw).requireValue(), <int>[0]);
    replacementTransport.complete(<int>[9]);
    expect(await replacementRun, <int>[9]);
    await staleRun;
    await source.close();
    client.dispose();
  });

  test('reset publishes chunks before normal close', () async {
    final source = StreamController<int>(sync: true);
    var initialCalls = 0;
    var streamCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'reset']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          streamCalls += 1;
          return source.stream;
        },
        initial: () {
          initialCalls += 1;
          return <int>[];
        },
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(raw);
    await _pump();

    expect(initialCalls, 1);
    expect(streamCalls, 1);
    expect(observer.data.isAbsent, isTrue);
    expect(observer.isLoading, isTrue);

    source.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[1]);
    expect(observer.isSuccess, isTrue);
    expect(observer.isFetching, isTrue);

    source.add(2);
    await source.close();
    await _pump();
    expect(observer.data.requireValue(), <int>[1, 2]);
    expect(observer.fetchStatus, FetchStatus.idle);
    client.dispose();
  });

  test('reset start does not count an initial-data seed as fetched', () async {
    final source = StreamController<int>(sync: true);
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'initial-seed-completion']),
      streamedQuery<int, List<int>>(
        stream: (_) => source.stream,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(raw.withInitialData(<int>[0]));
    await _pump();

    expect(observer.data.requireValue(), <int>[0]);
    expect(observer.isFetched, isFalse);
    expect(observer.isFetchedAfterMount, isFalse);

    source.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[0, 1]);
    expect(observer.isFetched, isTrue);
    expect(observer.isFetchedAfterMount, isTrue);

    await source.close();
    observer.dispose();
    client.dispose();
  });

  test('fetched reset refetch restores configured initial data each attempt',
      () async {
    final streams = <StreamController<int>>[];
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'reset-configured-initial']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          final source = StreamController<int>(sync: true);
          streams.add(source);
          return source.stream;
        },
        initial: () => <int>[99],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(
      raw.withInitialData(<int>[0]).withObserver(enabled: false),
    );

    final first = observer.refetch();
    await _pump();
    expect(observer.data.requireValue(), <int>[0]);
    expect(observer.isFetched, isFalse);
    streams.single.add(1);
    await streams.single.close();
    await first;
    expect(observer.data.requireValue(), <int>[0, 1]);
    expect(observer.isFetched, isTrue);

    final second = observer.refetch();
    await _pump();
    expect(streams, hasLength(2));
    expect(observer.data.requireValue(), <int>[0]);
    expect(observer.isFetched, isFalse);
    expect(observer.isFetching, isTrue);

    streams.last.add(2);
    await streams.last.close();
    await second;
    expect(observer.data.requireValue(), <int>[0, 2]);
    expect(observer.isFetched, isTrue);
    observer.dispose();
    client.dispose();
  });

  test('configured initial data classifies an empty reset failure as refetch',
      () async {
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'reset-initial-error']),
      streamedQuery<int, List<int>>(
        stream: (_) => Stream<int>.error(StateError('stream')),
        initial: () => <int>[99],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(
      raw.withInitialData(<int>[0]).withObserver(enabled: false),
    );

    final result = await observer.refetch();

    expect(result.data.requireValue(), <int>[0]);
    expect(result.isRefetchError, isTrue);
    expect(result.isLoadingError, isFalse);
    expect(result.failure?.error, isA<StateError>());
    observer.dispose();
    client.dispose();
  });

  test('append retry rebuilds from logical baseline without duplication',
      () async {
    final streams = <StreamController<int>>[];
    var initialCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'append-retry']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          final source = StreamController<int>(sync: true);
          streams.add(source);
          return source.stream;
        },
        initial: () {
          initialCalls += 1;
          return <int>[];
        },
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.append,
      ),
      retry: RetryPolicy.none,
    ).withRetry(
      (retry) => retry.strategy(
        delay: DelayPolicy.none(),
        retryIf: retry.exceptions & retry.maxRetries(1),
      ),
    );
    final client = QueryClient()..setQueryData(raw, <int>[0]);
    final observer = client.observeQuery(
      raw.withObserver(enabled: false),
    );
    final pending = observer.refetch();
    await _pump();

    streams.single.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[0, 1]);
    streams.single.addError(StateError('retry'));
    await _pump();

    expect(streams, hasLength(2));
    expect(initialCalls, 2);
    expect(observer.data.requireValue(), <int>[0, 1]);
    streams.last.add(1);
    await streams.last.close();
    await pending;
    await _pump();

    expect(observer.data.requireValue(), <int>[0, 1]);
    expect(observer.failureCount, 0);
    client.dispose();
  });

  test('append publishes every chunk from the preceding accumulated value',
      () async {
    final source = StreamController<int>(sync: true);
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'append-multiple']),
      streamedQuery<int, List<int>>(
        stream: (_) => source.stream,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.append,
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(raw, <int>[0]);
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();

    source.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[0, 1]);
    source.add(2);
    await _pump();
    expect(observer.data.requireValue(), <int>[0, 1, 2]);

    await source.close();
    await pending;
    observer.dispose();
    client.dispose();
  });

  test('a reducer error enters exception retry without committing its step',
      () async {
    var attempts = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'reducer-retry']),
      streamedQuery<int, List<int>>(
        stream: (_) => Stream<int>.value(++attempts),
        initial: () => <int>[],
        reduce: (current, chunk) {
          if (chunk == 1) throw StateError('reducer');
          return <int>[...current, chunk];
        },
      ),
      retry: RetryPolicy.none,
    ).withRetry(
      (retry) => retry.strategy(
        delay: DelayPolicy.none(),
        retryIf: retry.exceptions & retry.maxRetries(1),
      ),
    );
    final client = QueryClient();

    expect(await client.fetchQuery(raw), <int>[2]);
    expect(attempts, 2);
    expect(client.getQueryData(raw).requireValue(), <int>[2]);
    expect(client.getQueryState(raw)!.failureCount, 0);
    client.dispose();
  });

  test('reset retry restores reset state before the next attempt', () async {
    final streams = <StreamController<int>>[];
    var initialCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'reset-retry']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          final source = StreamController<int>(sync: true);
          streams.add(source);
          return source.stream;
        },
        initial: () => <int>[++initialCalls * 10],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    ).withRetry(
      (retry) => retry.strategy(
        delay: DelayPolicy.none(),
        retryIf: retry.exceptions & retry.maxRetries(1),
      ),
    );
    final client = QueryClient()..setQueryData(raw, <int>[0]);
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();

    expect(observer.data.isAbsent, isTrue);
    streams.single.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[10, 1]);

    streams.single.addError(StateError('retry reset'));
    await _pump();
    expect(streams, hasLength(2));
    expect(initialCalls, 2);
    expect(observer.data.isAbsent, isTrue);

    streams.last.add(2);
    await _pump();
    expect(observer.data.requireValue(), <int>[20, 2]);
    await streams.last.close();
    await pending;
    expect(observer.data.requireValue(), <int>[20, 2]);
    expect(observer.failure, isNull);
    await streams.first.close();
    observer.dispose();
    client.dispose();
  });

  test('replace accumulates privately and commits atomically', () async {
    final source = StreamController<int>(sync: true);
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'replace']),
      streamedQuery<int, List<int>>(
        stream: (_) => source.stream,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.replace,
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(raw, <int>[9]);
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();

    source.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[9]);
    expect(observer.isFetching, isTrue);

    await source.close();
    await pending;
    await _pump();
    expect(observer.data.requireValue(), <int>[1]);
    client.dispose();
  });

  test('replace retry discards failed private data and commits once', () async {
    final streams = <StreamController<int>>[];
    var initialCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'replace-retry']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          final source = StreamController<int>(sync: true);
          streams.add(source);
          return source.stream;
        },
        initial: () => <int>[++initialCalls * 10],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.replace,
      ),
      retry: RetryPolicy.none,
    ).withRetry(
      (retry) => retry.strategy(
        delay: DelayPolicy.none(),
        retryIf: retry.exceptions & retry.maxRetries(1),
      ),
    );
    final client = QueryClient()..setQueryData(raw, <int>[9]);
    final before = client.getQueryState(raw)!;
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();

    streams.single.add(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[9]);
    expect(client.getQueryState(raw)!.dataUpdateCount, before.dataUpdateCount);

    streams.single.addError(StateError('retry replace'));
    await _pump();
    expect(streams, hasLength(2));
    expect(initialCalls, 2);
    expect(observer.data.requireValue(), <int>[9]);

    streams.last.add(2);
    await _pump();
    expect(observer.data.requireValue(), <int>[9]);
    expect(client.getQueryState(raw)!.dataUpdateCount, before.dataUpdateCount);
    await streams.last.close();
    await pending;

    expect(observer.data.requireValue(), <int>[20, 2]);
    expect(
      client.getQueryState(raw)!.dataUpdateCount,
      before.dataUpdateCount + 1,
    );
    await streams.first.close();
    observer.dispose();
    client.dispose();
  });

  test('empty streams use each mode baseline rule', () async {
    Future<List<int>> run(
      String name,
      StreamRefetchMode mode, {
      List<int>? baseline,
    }) async {
      final raw = query<List<int>>(
        QueryKey(<Object?>['stream', 'empty', name]),
        streamedQuery<int, List<int>>(
          stream: (_) => const Stream<int>.empty(),
          initial: () => <int>[7],
          reduce: (current, chunk) => <int>[...current, chunk],
          mode: mode,
        ),
        retry: RetryPolicy.none,
      );
      final client = QueryClient();
      if (baseline != null) client.setQueryData(raw, baseline);
      final result = await client.fetchQuery(raw);
      client.dispose();
      return result;
    }

    expect(await run('reset', StreamRefetchMode.reset), <int>[7]);
    expect(
      await run('append-present', StreamRefetchMode.append, baseline: <int>[1]),
      <int>[1],
    );
    expect(await run('append-absent', StreamRefetchMode.append), <int>[7]);
    expect(
      await run('replace', StreamRefetchMode.replace, baseline: <int>[1]),
      <int>[7],
    );
  });

  test('result retry predicate runs only after close and accepts exhaustion',
      () async {
    var resultChecks = 0;
    var attempts = 0;
    var initialCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'result-retry']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          attempts += 1;
          return Stream<int>.fromIterable(<int>[1, 2]);
        },
        initial: () {
          initialCalls += 1;
          return <int>[];
        },
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.replace,
      ),
      retry: RetryPolicy.none,
    ).withRetry(
      (retry) => retry.strategy(
        delay: DelayPolicy.none(),
        retryIf: retry.result((data) {
              resultChecks += 1;
              return true;
            }) &
            retry.maxRetries(1),
      ),
    );
    final client = QueryClient();

    expect(await client.fetchQuery(raw), <int>[1, 2]);
    expect(attempts, 2);
    expect(initialCalls, 2);
    expect(resultChecks, 2);
    expect(client.getQueryState(raw)!.status, QueryStatus.success);
    client.dispose();
  });

  test('external cache write stays visible until a later partial is accepted',
      () async {
    final source = _AdversarialStream<int>();
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'external-write']),
      streamedQuery<int, List<int>>(
        stream: (_) => source,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();
    source.emitData(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[1]);

    var completed = false;
    unawaited(pending.then((_) => completed = true));
    client.setQueryData(raw, <int>[99]);
    await _pump();
    expect(completed, isFalse);
    expect(source.subscription.cancelRequested, isFalse);
    expect(client.getQueryData(raw).requireValue(), <int>[99]);

    source.emitData(2);
    await _pump();
    expect(client.getQueryData(raw).requireValue(), <int>[1, 2]);
    source.emitDone();
    final result = await pending;
    await _pump();
    expect(result.data.requireValue(), <int>[1, 2]);
    expect(result.failure, isNull);
    expect(result.failureCount, 0);
    client.dispose();
  });

  test('external write stays visible until replace commits its final result',
      () async {
    final source = _AdversarialStream<int>();
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'replace-external-write']),
      streamedQuery<int, List<int>>(
        stream: (_) => source,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.replace,
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(raw, <int>[9]);
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();

    source.emitData(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[9]);
    client.setQueryData(raw, <int>[7]);
    await _pump();
    expect(observer.data.requireValue(), <int>[7]);
    expect(source.subscription.cancelRequested, isFalse);

    source
      ..emitData(2)
      ..emitDone();
    await pending;
    await _pump();

    expect(client.getQueryData(raw).requireValue(), <int>[1, 2]);
    expect(observer.data.requireValue(), <int>[1, 2]);
    expect(observer.failure, isNull);
    expect(observer.failureCount, 0);
    observer.dispose();
    client.dispose();
  });

  test(
      'explicit cancellation fires token awaits subscription and rejects late callbacks',
      () async {
    final cancelGate = Completer<void>();
    final source = _AdversarialStream<int>(cancelGate: cancelGate);
    late QueryCancellationToken cancellationToken;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'cancel']),
      streamedQuery<int, List<int>>(
        stream: (context) {
          cancellationToken = context.cancellationToken;
          return source;
        },
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(raw, <int>[0]);
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();
    source.emitData(1);
    await _pump();
    expect(observer.data.requireValue(), <int>[1]);

    var cancelQueriesCompleted = false;
    var pendingCompleted = false;
    final cancelling = client.cancelQueries(
      filter: QueryFilter(key: raw.key, exact: true),
    );
    unawaited(
      cancelling.then((_) {
        cancelQueriesCompleted = true;
      }),
    );
    unawaited(
      pending.then((_) {
        pendingCompleted = true;
      }),
    );
    await _pump();

    expect(cancellationToken.isCancelled, isTrue);
    expect(source.subscription.cancelRequested, isTrue);
    expect(cancelQueriesCompleted, isFalse);
    expect(pendingCompleted, isFalse);
    expect(observer.data.requireValue(), <int>[0]);

    cancelGate.complete();
    final cancelled = await cancelling;
    await pending;
    await _pump();
    expect(cancelled.affected, 1);
    expect(cancelQueriesCompleted, isTrue);
    expect(pendingCompleted, isTrue);
    expect(observer.data.requireValue(), <int>[0]);
    expect(observer.failure, isNull);
    expect(observer.failureCount, 0);
    client.setQueryData(raw, <int>[99]);
    final protected = client.getQueryState(raw)!;

    source
      ..emitData(2)
      ..emitError(StateError('late cancellation error'))
      ..emitDone();
    await _pump();
    expect(observer.data.requireValue(), <int>[99]);
    _expectStreamStateUnchanged(client, raw, protected);
    client.dispose();
  });

  test(
      'detached stream releases its lane before cancellation cleanup completes',
      () async {
    final cancelGate = Completer<void>();
    final streams = <_AdversarialStream<int>>[];
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'detach-cancel-gate']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          final source = _AdversarialStream<int>(
            cancelGate: streams.isEmpty ? cancelGate : null,
          );
          streams.add(source);
          return source;
        },
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final first = client.observeQuery(raw);
    await _pump();
    expect(streams, hasLength(1));

    first.dispose();
    await _pump();
    expect(streams.first.subscription.cancelRequested, isTrue);
    expect(cancelGate.isCompleted, isFalse);

    final second = client.observeQuery(raw);
    await _pump();
    expect(streams, hasLength(2));
    streams.last
      ..emitData(2)
      ..emitDone();
    await _pump();
    expect(second.data.requireValue(), <int>[2]);

    cancelGate.complete();
    await _pump();
    expect(second.data.requireValue(), <int>[2]);
    expect(client.getQueryData(raw).requireValue(), <int>[2]);
    second.dispose();
    client.dispose();
  });

  test('reset releases a stream lane but still awaits subscription cleanup',
      () async {
    final cancelGate = Completer<void>();
    final source = _AdversarialStream<int>(cancelGate: cancelGate);
    final key = QueryKey(<Object?>['stream', 'reset-cancel-gate']);
    final streamed = query<List<int>>(
      key,
      streamedQuery<int, List<int>>(
        stream: (_) => source,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final replacement = query<List<int>>(
      key,
      (_) => <int>[9],
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(streamed, <int>[0]);
    final observer = client.observeQuery(
      streamed.withObserver(enabled: false),
    );
    final pending = observer.refetch();
    var pendingCompleted = false;
    unawaited(pending.then((_) => pendingCompleted = true));
    await _pump();
    source.emitData(1);
    await _pump();

    await client.resetQueries(
      filter: QueryFilter(key: key, exact: true),
      refetchType: QueryRefetchTarget.none,
    );
    await _pump();
    expect(source.subscription.cancelRequested, isTrue);
    expect(pendingCompleted, isFalse);
    expect(client.getQueryData(streamed).isAbsent, isTrue);

    expect(await client.fetchQuery(replacement), <int>[9]);
    cancelGate.complete();
    await pending;
    await _pump();

    expect(pendingCompleted, isTrue);
    expect(client.getQueryData(replacement).requireValue(), <int>[9]);
    observer.dispose();
    client.dispose();
  });

  test('manual value survives exhausted retry with retained-data failure',
      () async {
    final source = _AdversarialStream<int>();
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'manual-before-exhaustion']),
      streamedQuery<int, List<int>>(
        stream: (_) => source,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();

    source.emitData(1);
    await _pump();
    client.setQueryData(raw, <int>[99]);
    source.emitError(StateError('exhausted'));
    await pending;
    await _pump();

    expect(observer.data.requireValue(), <int>[99]);
    expect(observer.status, QueryStatus.error);
    expect(observer.failure?.error, isA<StateError>());
    observer.dispose();
    client.dispose();
  });

  test(
      'replacement settles an awaited cancelled stream without touching new data',
      () async {
    final cancelGate = Completer<void>();
    final source = _AdversarialStream<int>(cancelGate: cancelGate);
    final key = QueryKey(<Object?>['stream', 'awaited-replacement']);
    final streamed = query<List<int>>(
      key,
      streamedQuery<int, List<int>>(
        stream: (_) => source,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final replacement = query<List<int>>(
      key,
      (_) => <int>[9],
      retry: RetryPolicy.none,
    );
    final client = QueryClient()..setQueryData(streamed, <int>[0]);
    final first = client.fetchQuery(streamed);
    var firstSettled = false;
    unawaited(
      first.then<void>(
        (_) => firstSettled = true,
        onError: (_, __) => firstSettled = true,
      ),
    );
    await _pump();
    source.emitData(1);
    await _pump();
    expect(client.getQueryData(streamed).requireValue(), <int>[1]);

    expect(
      await client.fetchQuery(replacement, cancelRefetch: true),
      <int>[9],
    );
    await _pump();
    expect(source.subscription.cancelRequested, isTrue);
    expect(firstSettled, isFalse);
    expect(client.getQueryData(streamed).requireValue(), <int>[9]);

    final cancelled =
        expectLater(first, throwsA(isA<QueryCancelledException>()));
    cancelGate.complete();
    await cancelled;
    await _pump();

    source
      ..emitData(2)
      ..emitDone();
    await _pump();
    expect(firstSettled, isTrue);
    expect(client.getQueryData(streamed).requireValue(), <int>[9]);
    client.dispose();
  });

  test('remove and recreate rejects every late stream event', () async {
    final source = _AdversarialStream<int>();
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'recreate']),
      streamedQuery<int, List<int>>(
        stream: (_) => source,
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final observer = client.observeQuery(raw.withObserver(enabled: false));
    final pending = observer.refetch();
    await _pump();
    source.emitData(1);
    await _pump();

    expect(
      client.removeQueries(QueryFilter(key: raw.key, exact: true)),
      1,
    );
    await pending;
    await _pump();
    client.setQueryData(raw, <int>[9]);
    final recreated = client.getQueryState(raw)!;
    expect(source.subscription.cancelRequested, isTrue);

    source
      ..emitData(2)
      ..emitError(StateError('late recreated-entry error'))
      ..emitDone();
    await _pump();

    expect(client.getQueryData(raw).requireValue(), <int>[9]);
    expect(observer.data.requireValue(), <int>[9]);
    _expectStreamStateUnchanged(client, raw, recreated);
    client.dispose();
  });

  test('exception before a chunk obeys reset append replace failure matrix',
      () async {
    Future<QuerySnapshot<List<int>>> run(
      String name,
      StreamRefetchMode mode, {
      List<int>? baseline,
    }) async {
      final raw = query<List<int>>(
        QueryKey(<Object?>['stream', 'failure', name]),
        streamedQuery<int, List<int>>(
          stream: (_) => Stream<int>.error(StateError(name)),
          initial: () => <int>[7],
          reduce: (current, chunk) => <int>[...current, chunk],
          mode: mode,
        ),
        retry: RetryPolicy.none,
      );
      final client = QueryClient();
      if (baseline != null) client.setQueryData(raw, baseline);
      await expectLater(client.fetchQuery(raw), throwsA(isA<StateError>()));
      final snapshot = client.getQueryState(raw)!;
      client.dispose();
      return snapshot;
    }

    final reset = await run(
      'reset',
      StreamRefetchMode.reset,
      baseline: <int>[1],
    );
    final append = await run(
      'append',
      StreamRefetchMode.append,
      baseline: <int>[1],
    );
    final replace = await run(
      'replace',
      StreamRefetchMode.replace,
      baseline: <int>[1],
    );
    final absent = await run('absent', StreamRefetchMode.append);
    final replaceAbsent = await run(
      'replace-absent',
      StreamRefetchMode.replace,
    );

    expect(reset.data.isAbsent, isTrue);
    expect(append.data.requireValue(), <int>[1]);
    expect(replace.data.requireValue(), <int>[1]);
    expect(absent.data.isAbsent, isTrue);
    expect(replaceAbsent.data.isAbsent, isTrue);
    expect(<QueryStatus>[
      reset.status,
      append.status,
      replace.status,
      absent.status,
      replaceAbsent.status,
    ], everyElement(QueryStatus.error));
  });

  test('exhausted retries keep only the final mode-owned partial state',
      () async {
    Future<QuerySnapshot<List<int>>> run(
      String name,
      StreamRefetchMode mode,
    ) async {
      final streams = <StreamController<int>>[];
      final raw = query<List<int>>(
        QueryKey(<Object?>['stream', 'partial-exhausted', name]),
        streamedQuery<int, List<int>>(
          stream: (_) {
            final source = StreamController<int>(sync: true);
            streams.add(source);
            return source.stream;
          },
          initial: () => <int>[],
          reduce: (current, chunk) => <int>[...current, chunk],
          mode: mode,
        ),
        retry: RetryPolicy.none,
      ).withRetry(
        (retry) => retry.strategy(
          delay: DelayPolicy.none(),
          retryIf: retry.exceptions & retry.maxRetries(1),
        ),
      );
      final client = QueryClient()..setQueryData(raw, <int>[0]);
      final observer = client.observeQuery(raw.withObserver(enabled: false));
      final pending = observer.refetch();
      await _pump();

      streams.single.add(1);
      await _pump();
      streams.single.addError(StateError('first $name'));
      await _pump();
      expect(streams, hasLength(2));

      streams.last.add(2);
      await _pump();
      streams.last.addError(StateError('final $name'));
      await pending;
      await _pump();

      final snapshot = client.getQueryState(raw)!;
      expect(snapshot.failure?.error, isA<StateError>());
      for (final source in streams) {
        await source.close();
      }
      observer.dispose();
      client.dispose();
      return snapshot;
    }

    final reset = await run('reset', StreamRefetchMode.reset);
    final append = await run('append', StreamRefetchMode.append);
    final replace = await run('replace', StreamRefetchMode.replace);

    expect(reset.data.requireValue(), <int>[2]);
    expect(append.data.requireValue(), <int>[0, 2]);
    expect(replace.data.requireValue(), <int>[0]);
    expect(<QueryStatus>[reset.status, append.status, replace.status],
        everyElement(QueryStatus.error));
  });

  test('two observers share one active stream subscription', () async {
    final source = StreamController<int>(sync: true);
    var subscriptions = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'shared']),
      streamedQuery<int, List<int>>(
        stream: (_) {
          subscriptions += 1;
          return source.stream;
        },
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    final first = client.observeQuery(raw);
    final second = client.observeQuery(raw);
    await _pump();
    expect(subscriptions, 1);

    source.add(3);
    await _pump();
    expect(first.data.requireValue(), <int>[3]);
    expect(second.data.requireValue(), <int>[3]);
    await source.close();
    await _pump();
    client.dispose();
  });

  test('invalidation executes the retained streamed plan in append mode',
      () async {
    var streamCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'invalidate']),
      streamedQuery<int, List<int>>(
        stream: (_) => Stream<int>.value(++streamCalls),
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.append,
      ),
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
    );
    final client = QueryClient();
    final observer = client.observeQuery(raw);
    await _pump();
    expect(observer.data.requireValue(), <int>[1]);

    final result = await client.invalidateQueries(
      filter: QueryFilter(key: raw.key, exact: true),
    );
    await _pump();

    expect(result.matched, 1);
    expect(result.affected, 1);
    expect(result.failures, isEmpty);
    expect(streamCalls, 2);
    expect(observer.data.requireValue(), <int>[1, 2]);
    observer.dispose();
    client.dispose();
  });

  test('polling and focus reuse the retained ordinary streamed plan', () async {
    final timers = FakeQueryTimerScheduler();
    final notifications = FakeQueryNotificationScheduler();
    var streamCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'ordinary-triggers']),
      streamedQuery<int, List<int>>(
        stream: (_) => Stream<int>.value(++streamCalls),
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
        mode: StreamRefetchMode.append,
      ),
      retry: RetryPolicy.none,
    ).withInitialData(<int>[]).withObserver(
      refetchOnMount: RefetchPolicy.never,
      refetchOnFocus: RefetchPolicy.always,
      pollingInterval: const Duration(seconds: 5),
    );
    final client = QueryClient(
      runtime: QueryRuntime(
        clock: FakeQueryClock(),
        timers: timers,
        random: FakeQueryRandomSource(),
        notifications: notifications,
      ),
    );
    final observer = client.observeQuery(raw);
    expect(streamCalls, 0);

    timers.elapse(const Duration(seconds: 5));
    await _pump();
    notifications.flushAll();
    expect(streamCalls, 1);
    expect(observer.data.requireValue(), <int>[1]);

    client.focusManager.isFocused = false;
    client.focusManager.isFocused = true;
    await _pump();
    notifications.flushAll();
    expect(streamCalls, 2);
    expect(observer.data.requireValue(), <int>[1, 2]);

    observer.dispose();
    client.dispose();
  });

  test('reattaching before streamed entry GC preserves committed data',
      () async {
    final timers = FakeQueryTimerScheduler();
    final notifications = FakeQueryNotificationScheduler();
    var streamCalls = 0;
    final raw = query<List<int>>(
      QueryKey(<Object?>['stream', 'gc-reattach']),
      streamedQuery<int, List<int>>(
        stream: (_) => Stream<int>.value(++streamCalls),
        initial: () => <int>[],
        reduce: (current, chunk) => <int>[...current, chunk],
      ),
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
      retention: RetentionPolicy.duration(const Duration(seconds: 10)),
    );
    final client = QueryClient(
      runtime: QueryRuntime(
        clock: FakeQueryClock(),
        timers: timers,
        random: FakeQueryRandomSource(),
        notifications: notifications,
      ),
    );
    final first = client.observeQuery(raw);
    await _pump();
    notifications.flushAll();
    expect(first.data.requireValue(), <int>[1]);

    first.dispose();
    final staleGc = timers.handles.single;
    timers.elapse(const Duration(seconds: 9));
    expect(client.queryCache.snapshots, hasLength(1));

    final reattached = client.observeQuery(raw);
    expect(reattached.data.requireValue(), <int>[1]);
    expect(streamCalls, 1);
    staleGc.fire(evenIfCancelled: true);
    expect(client.queryCache.snapshots, hasLength(1));

    reattached.dispose();
    timers.elapse(const Duration(seconds: 10));
    expect(client.queryCache.snapshots, isEmpty);
    client.dispose();
  });
}

Future<void> _pump([int turns = 8]) async {
  for (var index = 0; index < turns; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

void _expectStreamStateUnchanged<T>(
  QueryClient client,
  Query<T> query,
  QuerySnapshot<T> before,
) {
  final after = client.getQueryState(query)!;
  expect(after.data, before.data);
  expect(after.revision, before.revision);
  expect(after.failure, same(before.failure));
  expect(after.transientFailure, same(before.transientFailure));
  expect(after.failureCount, before.failureCount);
  expect(after.dataUpdateCount, before.dataUpdateCount);
  expect(after.failureUpdateCount, before.failureUpdateCount);
}

final class _AdversarialStream<T> extends Stream<T> {
  _AdversarialStream({this.cancelGate});

  final Completer<void>? cancelGate;
  // The StreamIterator under test owns and cancels this subscription.
  // ignore: cancel_subscriptions
  _AdversarialSubscription<T>? _subscription;

  bool get hasListener => _subscription != null;

  _AdversarialSubscription<T> get subscription => _subscription!;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_subscription != null) {
      throw StateError('The adversarial stream supports one subscription.');
    }
    return _subscription = _AdversarialSubscription<T>(
      onData: onData,
      onError: onError,
      onDone: onDone,
      cancelGate: cancelGate,
    );
  }

  void emitData(T value) => subscription.emitData(value);

  void emitError(Object error, [StackTrace? stackTrace]) {
    subscription.emitError(error, stackTrace ?? StackTrace.current);
  }

  void emitDone() => subscription.emitDone();
}

final class _AdversarialSubscription<T> implements StreamSubscription<T> {
  _AdversarialSubscription({
    required void Function(T event)? onData,
    required Function? onError,
    required void Function()? onDone,
    required this.cancelGate,
  })  : _onData = onData,
        _onError = onError,
        _onDone = onDone;

  final Completer<void>? cancelGate;
  void Function(T event)? _onData;
  Function? _onError;
  void Function()? _onDone;
  bool _isPaused = false;
  bool cancelRequested = false;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> cancel() {
    cancelRequested = true;
    return cancelGate?.future ?? Future<void>.value();
  }

  @override
  void onData(void Function(T data)? handleData) {
    if (handleData != null) _onData = handleData;
  }

  @override
  void onError(Function? handleError) {
    if (handleError != null) _onError = handleError;
  }

  @override
  void onDone(void Function()? handleDone) {
    if (handleDone != null) _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _isPaused = true;
    if (resumeSignal != null) {
      unawaited(resumeSignal.whenComplete(resume));
    }
  }

  @override
  void resume() {
    _isPaused = false;
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    final previousDone = _onDone;
    final previousError = _onError;
    _onDone = () {
      previousDone?.call();
      if (!completer.isCompleted) completer.complete(futureValue as E);
    };
    _onError = (Object error, StackTrace stackTrace) {
      _invokeError(previousError, error, stackTrace);
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    };
    return completer.future;
  }

  void emitData(T value) => _onData?.call(value);

  void emitError(Object error, StackTrace stackTrace) {
    _invokeError(_onError, error, stackTrace);
  }

  void emitDone() => _onDone?.call();
}

void _invokeError(Function? handler, Object error, StackTrace stackTrace) {
  if (handler == null) {
    Zone.current.handleUncaughtError(error, stackTrace);
  } else if (handler is void Function(Object, StackTrace)) {
    handler(error, stackTrace);
  } else if (handler is void Function(Object)) {
    handler(error);
  } else {
    Function.apply(handler, <Object?>[error, stackTrace]);
  }
}
