import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('class-first query built-ins override matching client defaults',
      () async {
    final harness = _PolicyHarness();
    addTearDown(harness.dispose);
    final prefix = QueryKey(const <Object?>['class-query-policy']);
    harness.client.registerQueryDefaults(
      QueryDefaults(
        retry: RetryPolicy.standard,
        staleTime: StalePolicy.untilInvalidated,
        retention: RetentionPolicy.duration(Duration.zero),
        networkMode: NetworkMode.always,
      ),
      key: prefix,
    );

    var inheritedCalls = 0;
    final inherited = _ClassQuery(
      'inherited',
      () => ++inheritedCalls,
    );
    expect(await harness.client.fetchQuery(inherited), 1);
    expect(await harness.client.fetchQuery(inherited), 1);
    expect(inheritedCalls, 1);

    var explicitCalls = 0;
    final explicit = _ClassQuery(
      'explicit',
      () => ++explicitCalls,
      retry: RetryPolicy.none,
      staleTime: StalePolicy.immediate,
      retention: RetentionPolicy.standard,
      networkMode: NetworkMode.online,
    );
    expect(await harness.client.fetchQuery(explicit), 1);
    expect(await harness.client.fetchQuery(explicit), 2);
    expect(explicitCalls, 2);

    harness.timers.elapse(Duration.zero);
    expect(harness.client.getQueryState(inherited), isNull);
    expect(harness.client.getQueryData(explicit).requireValue(), 2);

    harness.client.onlineManager.isOnline = false;
    var offlineCalls = 0;
    final online = _ClassQuery(
      'online',
      () => ++offlineCalls,
      retry: RetryPolicy.none,
      staleTime: StalePolicy.immediate,
      retention: RetentionPolicy.standard,
      networkMode: NetworkMode.online,
    );
    final pending = harness.client.fetchQuery(online);
    await harness.pump();
    expect(offlineCalls, 0);
    expect(
      harness.client.getQueryState(online)!.pauseReason,
      PauseReason.offline,
    );

    harness.client.onlineManager.isOnline = true;
    expect(await pending, 1);

    var failedAttempts = 0;
    final noRetry = _ClassQuery(
      'no-retry',
      () {
        failedAttempts += 1;
        throw StateError('one attempt');
      },
      retry: RetryPolicy.none,
      staleTime: StalePolicy.immediate,
      retention: RetentionPolicy.standard,
      networkMode: NetworkMode.online,
    );
    await expectLater(
      harness.client.fetchQuery(noRetry),
      throwsA(isA<StateError>()),
    );
    expect(failedAttempts, 1);
  });

  test('class-first infinite built-in stale policy overrides defaults',
      () async {
    final harness = _PolicyHarness();
    addTearDown(harness.dispose);
    final prefix = QueryKey(const <Object?>['class-infinite-policy']);
    harness.client.registerQueryDefaults(
      QueryDefaults(staleTime: StalePolicy.untilInvalidated),
      key: prefix,
    );

    var inheritedCalls = 0;
    final inherited = _ClassInfiniteQuery(
      'inherited',
      () => ++inheritedCalls,
    );
    await harness.client.fetchInfiniteQuery(inherited);
    await harness.client.fetchInfiniteQuery(inherited);
    expect(inheritedCalls, 1);

    var explicitCalls = 0;
    final explicit = _ClassInfiniteQuery(
      'explicit',
      () => ++explicitCalls,
      staleTime: StalePolicy.immediate,
    );
    await harness.client.fetchInfiniteQuery(explicit);
    await harness.client.fetchInfiniteQuery(explicit);
    expect(explicitCalls, 2);
  });

  test('class-first mutation built-ins override matching defaults', () async {
    final harness = _PolicyHarness();
    addTearDown(harness.dispose);
    final prefix = MutationKey(const <Object?>['class-mutation-policy']);
    harness.client.registerMutationDefaults(
      MutationDefaults(
        retry: RetryPolicy.standard,
        retention: RetentionPolicy.duration(Duration.zero),
        networkMode: NetworkMode.always,
      ),
      key: prefix,
    );
    harness.client.onlineManager.isOnline = false;
    var attempts = 0;
    final definition = _ClassMutation(
      () {
        attempts += 1;
        throw StateError('one attempt');
      },
    );

    final pending = harness.client.execute(definition, 1);
    final failure = expectLater(pending, throwsA(isA<StateError>()));
    await harness.pump();
    expect(attempts, 0);
    expect(
      harness.client.mutationCache.snapshots.single.pauseReason,
      PauseReason.offline,
    );

    harness.client.onlineManager.isOnline = true;
    await failure;
    await harness.pump();
    expect(attempts, 1);
    harness.timers.elapse(Duration.zero);
    expect(harness.client.mutationCache.snapshots, hasLength(1));
  });

  test('action built-ins override matching mutation defaults', () async {
    final harness = _PolicyHarness();
    addTearDown(harness.dispose);
    final key = MutationKey(const <Object?>['action-policy', 'explicit']);
    harness.client.registerMutationDefaults(
      MutationDefaults(
        retry: RetryPolicy.standard,
        retention: RetentionPolicy.duration(Duration.zero),
        networkMode: NetworkMode.always,
      ),
      key: MutationKey(const <Object?>['action-policy']),
    );
    harness.client.onlineManager.isOnline = false;
    var attempts = 0;
    final definition = action<int, void>(
      key: key,
      retry: RetryPolicy.none,
      retention: RetentionPolicy.standard,
      networkMode: NetworkMode.online,
      mutate: (_) {
        attempts += 1;
        throw StateError('one attempt');
      },
    );

    final pending = harness.client.execute(definition, NoVariables.value);
    final failure = expectLater(pending, throwsA(isA<StateError>()));
    await harness.pump();
    expect(attempts, 0);

    harness.client.onlineManager.isOnline = true;
    await failure;
    await harness.pump();
    expect(attempts, 1);
    harness.timers.elapse(Duration.zero);
    expect(harness.client.mutationCache.snapshots, hasLength(1));
  });
}

final class _ClassQuery extends Query<int> {
  _ClassQuery(
    this.id,
    this.run, {
    super.retry,
    super.staleTime,
    super.retention,
    super.networkMode,
  });

  final String id;
  final FutureOr<int> Function() run;

  @override
  QueryKey get key => QueryKey(<Object?>['class-query-policy', id]);

  @override
  FutureOr<int> fetch(QueryContext context) => run();
}

final class _ClassInfiniteQuery extends InfiniteQuery<int, int> {
  _ClassInfiniteQuery(
    this.id,
    this.run, {
    super.staleTime,
  });

  final String id;
  final int Function() run;

  @override
  QueryKey get key => QueryKey(<Object?>['class-infinite-policy', id]);

  @override
  int get initialPageParam => 0;

  @override
  int fetchPage(InfinitePageContext<int> context) => run();

  @override
  PageCursor<int> getNextPageParam(InfiniteData<int, int> data) {
    return PageCursor.end;
  }
}

final class _ClassMutation extends Mutation<int, int, void> {
  _ClassMutation(this.run)
      : super(
          retry: RetryPolicy.none,
          networkMode: NetworkMode.online,
          retention: RetentionPolicy.standard,
        );

  final int Function() run;

  @override
  MutationKey get key =>
      MutationKey(const <Object?>['class-mutation-policy', 'explicit']);

  @override
  int mutate(int variables, MutationContext context) => run();
}

final class _PolicyHarness {
  _PolicyHarness()
      : runtime = QueryRuntime(
          clock: FakeQueryClock(),
          timers: FakeQueryTimerScheduler(),
          random: FakeQueryRandomSource(),
          notifications: FakeQueryNotificationScheduler(),
        ) {
    client = QueryClient(runtime: runtime);
  }

  final QueryRuntime runtime;
  late final QueryClient client;

  FakeQueryTimerScheduler get timers =>
      runtime.timers as FakeQueryTimerScheduler;
  FakeQueryNotificationScheduler get notifications =>
      runtime.notifications as FakeQueryNotificationScheduler;

  Future<void> pump() async {
    for (var index = 0; index < 5; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() => client.dispose();
}
