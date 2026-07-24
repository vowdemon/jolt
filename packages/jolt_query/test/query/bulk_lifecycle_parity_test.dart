import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('invalidation replaces retained work by default', () async {
    final transports = <Completer<int>>[];
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['bulk-parity', 'invalidate-replace']),
      (_) {
        calls += 1;
        if (calls == 1) return 1;
        final transport = Completer<int>();
        transports.add(transport);
        return transport.future;
      },
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    addTearDown(client.dispose);

    expect(await client.fetchQuery(raw), 1);
    final replaced = client.fetchQuery(raw);
    final replacedExpectation = expectLater(
      replaced,
      throwsA(isA<QueryCancelledException>()),
    );
    await _pump();

    final invalidating = client.invalidateQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );
    await replacedExpectation;
    await _pump();

    expect(calls, 3);
    expect(transports, hasLength(2));
    transports.last.complete(3);
    final result = await invalidating;
    expect(result.affected, 1);
    expect(result.failures, isEmpty);
    expect(client.getQueryData(raw).requireValue(), 3);
    expect(client.getQueryState(raw)!.isInvalidated, isFalse);

    transports.first.complete(2);
    await _pump();
    expect(client.getQueryData(raw).requireValue(), 3);
  });

  test('cancelRefetch false joins retained work without a follow-up', () async {
    final refresh = Completer<int>();
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['bulk-parity', 'invalidate-join']),
      (_) {
        calls += 1;
        return calls == 1 ? 1 : refresh.future;
      },
      retry: RetryPolicy.none,
    );
    final client = QueryClient();
    addTearDown(client.dispose);

    expect(await client.fetchQuery(raw), 1);
    final fetching = client.fetchQuery(raw);
    await _pump();
    final invalidating = client.invalidateQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
      cancelRefetch: false,
    );
    await _pump();

    expect(calls, 2);
    refresh.complete(2);
    expect(await fetching, 2);
    final result = await invalidating;

    expect(result.affected, 1);
    expect(result.failures, isEmpty);
    expect(calls, 2);
    expect(client.getQueryData(raw).requireValue(), 2);
    expect(client.getQueryState(raw)!.isInvalidated, isFalse);
  });

  test('immediately paused bulk items return while cache work continues',
      () async {
    await _verifyPausedBatch(
      'invalidate',
      (client, raw) => client.invalidateQueries(
        filter: QueryFilter(key: raw.key, exact: true),
        refetchType: QueryRefetchTarget.all,
      ),
    );
    await _verifyPausedBatch(
      'refetch',
      (client, raw) => client.refetchQueries(
        filter: QueryFilter(key: raw.key, exact: true),
        refetchType: QueryRefetchTarget.all,
      ),
      failAfterResume: true,
    );
    await _verifyPausedBatch(
      'reset',
      (client, raw) => client.resetQueries(
        filter: QueryFilter(key: raw.key, exact: true),
        refetchType: QueryRefetchTarget.all,
      ),
    );
  });
}

Future<void> _verifyPausedBatch(
  String name,
  Future<QueryBatchResult> Function(QueryClient client, Query<int> raw)
      execute, {
  bool failAfterResume = false,
}) async {
  var calls = 0;
  final raw = query<int>(
    QueryKey(<Object?>['bulk-parity', 'paused', name]),
    (_) {
      calls += 1;
      if (calls == 2 && failAfterResume) {
        throw StateError('resumed failure');
      }
      return calls;
    },
    retry: RetryPolicy.none,
    networkMode: NetworkMode.online,
    staleTime: StalePolicy.untilInvalidated,
  );
  final client = QueryClient();
  final observer = client.observeQuery(
    raw.withObserver(refetchOnMount: RefetchPolicy.never),
  );
  try {
    expect(await client.fetchQuery(raw), 1);
    client.onlineManager.isOnline = false;

    final result = await execute(client, raw).timeout(
      const Duration(seconds: 1),
    );
    final paused = client.getQueryState(raw)!;
    expect(result.affected, 1, reason: name);
    expect(result.failures, isEmpty, reason: name);
    expect(paused.fetchStatus, FetchStatus.paused, reason: name);
    expect(paused.pauseReason, PauseReason.offline, reason: name);
    expect(calls, 1, reason: name);

    client.onlineManager.isOnline = true;
    await _pump();
    await _pump();

    expect(calls, 2, reason: name);
    final settled = client.getQueryState(raw)!;
    expect(settled.fetchStatus, FetchStatus.idle, reason: name);
    if (failAfterResume) {
      expect(settled.status, QueryStatus.error, reason: name);
      expect(settled.failure?.error, isA<StateError>(), reason: name);
    } else {
      expect(settled.data.requireValue(), 2, reason: name);
    }
  } finally {
    observer.dispose();
    client.dispose();
  }
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
