import 'dart:async';

import 'package:jolt/jolt.dart' show Signal;
import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('initial data is a cache seed rather than a completed fetch', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['initial-data-completion']),
      (_) => ++calls,
      retry: RetryPolicy.none,
    );
    final observer = harness.client.observeQuery(
      raw.withInitialData(0).withObserver(enabled: false),
    );
    addTearDown(observer.dispose);

    expect(observer.data.requireValue(), 0);
    expect(observer.status, QueryStatus.success);
    expect(observer.isFetched, isFalse);
    expect(observer.isFetchedAfterMount, isFalse);
    expect(harness.client.getQueryState(raw)!.dataUpdateCount, 0);

    await observer.refetch();
    await harness.pump();

    expect(calls, 1);
    expect(observer.data.requireValue(), 1);
    expect(observer.isFetched, isTrue);
    expect(observer.isFetchedAfterMount, isTrue);
    expect(harness.client.getQueryState(raw)!.dataUpdateCount, 1);

    await harness.client.resetQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.none,
    );
    await harness.pump();

    expect(observer.data.requireValue(), 0);
    expect(observer.isFetched, isFalse);
    expect(observer.isFetchedAfterMount, isFalse);
    expect(harness.client.getQueryState(raw)!.dataUpdateCount, 0);
  });

  test('reset rebases fetched-after-mount completion counters', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final raw = query<int>(
      QueryKey(<Object?>['reset-completion-baseline']),
      (_) => 0,
      retry: RetryPolicy.none,
    );
    harness.client
      ..setQueryData(raw, 1)
      ..setQueryData(raw, 2);
    final observer = harness.client.observeQuery(
      raw.withObserver(enabled: false),
    );
    addTearDown(observer.dispose);

    expect(observer.isFetched, isTrue);
    expect(observer.isFetchedAfterMount, isFalse);

    await harness.client.resetQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.none,
    );
    await harness.pump();
    expect(observer.isFetched, isFalse);
    expect(observer.isFetchedAfterMount, isFalse);

    harness.client.setQueryData(raw, 3);
    await harness.pump();
    expect(observer.isFetched, isTrue);
    expect(observer.isFetchedAfterMount, isTrue);
  });

  test('queued reset notification cannot corrupt a later mount baseline',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final first = query<int>(
      QueryKey(<Object?>['reset-completion-remount', 1]),
      (_) => 1,
      retry: RetryPolicy.none,
    );
    final second = query<int>(
      QueryKey(<Object?>['reset-completion-remount', 2]),
      (_) => 2,
      retry: RetryPolicy.none,
    );
    harness.client
      ..setQueryData(first, 1)
      ..setQueryData(first, 2)
      ..setQueryData(second, 20);
    harness.notifications.flushAll();
    final useFirst = Signal<bool>(true);
    final observer = harness.client.watchQuery(
      () => (useFirst.value ? first : second).withObserver(enabled: false),
    );
    addTearDown(observer.dispose);
    harness.notifications.flushAll();

    await harness.client.resetQueries(
      filter: QueryFilter(key: first.key, exact: true),
      refetchType: QueryRefetchTarget.none,
    );
    harness.client.setQueryData(first, 3);
    useFirst.value = false;
    useFirst.value = true;
    await Future<void>.delayed(Duration.zero);

    expect(observer.data.requireValue(), 3);
    expect(observer.isFetched, isTrue);
    expect(observer.isFetchedAfterMount, isFalse);

    harness.notifications.flushAll();
    expect(observer.isFetchedAfterMount, isFalse);
  });

  group('configuration precedence', () {
    test('built-in, registered, recipe, and call freshness resolve in order',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final calls = <String, int>{};
      Query<int> source(
        String name, {
        List<Object?> prefix = const <Object?>[],
        StalePolicy? staleTime,
      }) {
        return query<int>(
          QueryKey(<Object?>[...prefix, name]),
          (_) => calls.update(name, (value) => value + 1, ifAbsent: () => 1),
          retry: RetryPolicy.none,
          staleTime: staleTime,
        );
      }

      harness.client
        ..registerQueryDefaults(
          QueryDefaults(staleTime: StalePolicy.untilInvalidated),
          key: QueryKey(<Object?>['defaults']),
        )
        ..registerQueryDefaults(
          QueryDefaults(staleTime: StalePolicy.immediate),
          key: QueryKey(<Object?>['defaults', 'specific']),
        );

      final builtIn = source('built-in');
      expect(await harness.client.fetchQuery(builtIn), 1);
      expect(await harness.client.fetchQuery(builtIn), 2);

      final inherited = source('inherited', prefix: <Object?>['defaults']);
      expect(await harness.client.fetchQuery(inherited), 1);
      expect(await harness.client.fetchQuery(inherited), 1);

      final specific = source(
        'specific',
        prefix: <Object?>['defaults', 'specific'],
      );
      expect(await harness.client.fetchQuery(specific), 1);
      expect(await harness.client.fetchQuery(specific), 2);

      final explicit = source(
        'explicit',
        prefix: <Object?>['defaults', 'specific'],
        staleTime: StalePolicy.untilInvalidated,
      );
      expect(await harness.client.fetchQuery(explicit), 1);
      expect(await harness.client.fetchQuery(explicit), 1);
      expect(
        await harness.client.fetchQuery(
          explicit,
          staleTime: StalePolicy.immediate,
        ),
        2,
      );

      final explicitBuiltIn = source(
        'explicit-built-in',
        prefix: <Object?>['defaults'],
        staleTime: StalePolicy.immediate,
      );
      expect(await harness.client.fetchQuery(explicitBuiltIn), 1);
      expect(await harness.client.fetchQuery(explicitBuiltIn), 2);
    });

    test('explicit recipe retention wins over a registered default', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final inherited = query<int>(
        QueryKey(<Object?>['retention-default', 'inherited']),
        (_) => 1,
        retry: RetryPolicy.none,
      );
      final explicit = query<int>(
        QueryKey(<Object?>['retention-default', 'explicit']),
        (_) => 2,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.standard,
      );
      harness.client.registerQueryDefaults(
        QueryDefaults(
          retention: RetentionPolicy.duration(const Duration(seconds: 2)),
        ),
        key: QueryKey(<Object?>['retention-default']),
      );

      await harness.client.fetchQuery(inherited);
      await harness.client.fetchQuery(explicit);
      harness.timers.elapse(const Duration(seconds: 2));

      expect(harness.client.getQueryState(inherited), isNull);
      expect(harness.client.getQueryData(explicit).requireValue(), 2);
    });

    test('explicit online recipe overrides an always-network default',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      harness.client
        ..registerQueryDefaults(
          const QueryDefaults(networkMode: NetworkMode.always),
          key: QueryKey(<Object?>['network-default']),
        )
        ..onlineManager.isOnline = false;
      var inheritedCalls = 0;
      var explicitCalls = 0;
      final inherited = query<int>(
        QueryKey(<Object?>['network-default', 'inherited']),
        (_) => ++inheritedCalls,
        retry: RetryPolicy.none,
      );
      final explicit = query<int>(
        QueryKey(<Object?>['network-default', 'explicit']),
        (_) => ++explicitCalls,
        retry: RetryPolicy.none,
        networkMode: NetworkMode.online,
      );

      expect(await harness.client.fetchQuery(inherited), 1);
      final pending = harness.client.fetchQuery(explicit);
      await harness.pump();

      expect(inheritedCalls, 1);
      expect(explicitCalls, 0);
      expect(
        harness.client.getQueryState(explicit)!.fetchStatus,
        FetchStatus.paused,
      );

      harness.client.onlineManager.isOnline = true;
      expect(await pending, 1);
      expect(explicitCalls, 1);
    });
  });

  test('terminal pollingEnabled false disables an inherited interval',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['polling', 'explicit-off']),
      (_) => ++calls,
      retry: RetryPolicy.none,
    );
    harness.client.registerQueryDefaults(
      const QueryDefaults(pollingInterval: Duration(seconds: 2)),
      key: QueryKey(<Object?>['polling']),
    );
    final observer = harness.client.observeQuery(
      raw.withInitialData(0).withObserver(
            refetchOnMount: RefetchPolicy.never,
            pollingEnabled: false,
          ),
    );
    addTearDown(observer.dispose);

    harness.timers.elapse(const Duration(seconds: 20));
    await harness.pump();

    expect(calls, 0);
    expect(observer.data.requireValue(), 0);
  });

  test(
      'disabled observer is observed but inactive and skipped by automatic bulk work',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['disabled', 'activity']),
      (_) => ++calls,
      retry: RetryPolicy.none,
      retention: RetentionPolicy.duration(const Duration(seconds: 3)),
    );
    final observer = harness.client.observeQuery(
      raw.withInitialData(0).withObserver(
            enabled: false,
            staleTime: StalePolicy.immediate,
          ),
    );
    final initial = harness.client.queryCache.snapshots.single;

    expect(initial.observerCount, 1);
    expect(initial.activeObserverCount, 0);
    expect(initial.isObserved, isTrue);
    expect(initial.isActive, isFalse);
    expect(initial.isStale, isFalse);
    expect(observer.isStale, isFalse);
    expect(
      const QueryFilter(activity: QueryActivity.active).matches(initial),
      isFalse,
    );
    expect(
      const QueryFilter(activity: QueryActivity.inactive).matches(initial),
      isTrue,
    );

    final invalidated = await harness.client.invalidateQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );
    final refetched = await harness.client.refetchQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );
    harness.client.focusManager.isFocused = false;
    harness.client.focusManager.isFocused = true;
    harness.client.onlineManager.isOnline = false;
    harness.client.onlineManager.isOnline = true;
    harness.timers.elapse(const Duration(seconds: 30));
    await harness.pump();

    expect(invalidated.matched, 1);
    expect(calls, 0);
    expect(refetched.affected, 0);
    expect(observer.isStale, isFalse);
    expect(harness.client.getQueryState(raw), isNotNull);

    final manual = await observer.refetch();
    expect(manual.data.requireValue(), 1);
    expect(calls, 1);

    observer.dispose();
    harness.timers.elapse(const Duration(seconds: 3));
    expect(harness.client.getQueryState(raw), isNull);
  });

  test('unobserved initial data stays disabled until a completion', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['disabled', 'never-fetched']),
      (_) => ++calls,
      retry: RetryPolicy.none,
    );
    harness.client
        .observeQuery(
          raw.withInitialData(0).withObserver(enabled: false),
        )
        .dispose();

    final result = await harness.client.refetchQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );

    expect(result.matched, 1);
    expect(result.affected, 0);
    expect(calls, 0);
    expect(harness.client.getQueryData(raw).requireValue(), 0);
  });

  test('unobserved fetched entries are bulk eligible and not recipe-static',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['static', 'unobserved-recipe']),
      (_) => ++calls,
      retry: RetryPolicy.none,
      staleTime: StalePolicy.immutable,
    );

    expect(await harness.client.fetchQuery(raw), 1);
    final result = await harness.client.refetchQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );

    expect(result.affected, 1);
    expect(result.failures, isEmpty);
    expect(calls, 2);
    expect(harness.client.getQueryData(raw).requireValue(), 2);
  });

  test('an unobserved terminal error counts as fetched for bulk eligibility',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['disabled', 'terminal-error']),
      (_) {
        calls += 1;
        if (calls == 1) throw StateError('first');
        return 2;
      },
      retry: RetryPolicy.none,
    );

    await expectLater(
      harness.client.fetchQuery(raw),
      throwsA(isA<StateError>()),
    );
    final result = await harness.client.refetchQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );

    expect(result.affected, 1);
    expect(result.failures, isEmpty);
    expect(calls, 2);
    expect(harness.client.getQueryData(raw).requireValue(), 2);
  });

  test('manual cache entries and fresh cache hits remain eligible for GC',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['gc', 'manual']),
      (_) => ++calls,
      retry: RetryPolicy.none,
    );
    harness.client.registerQueryDefaults(
      QueryDefaults(
        retention: RetentionPolicy.duration(const Duration(seconds: 5)),
      ),
      key: QueryKey(<Object?>['gc']),
    );
    harness.client.setQueryData(raw, 7);

    harness.timers.elapse(const Duration(seconds: 4));
    expect(
      await harness.client.fetchQuery(
        raw,
        staleTime: StalePolicy.untilInvalidated,
      ),
      7,
    );
    harness.timers.elapse(const Duration(seconds: 4));
    expect(harness.client.getQueryData(raw).requireValue(), 7);

    harness.timers.elapse(const Duration(seconds: 1));
    expect(harness.client.getQueryState(raw), isNull);
    expect(calls, 0);
  });

  test('ensure cache hit reapplies a longer received retention', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final key = QueryKey(<Object?>['gc', 'ensure-longer']);
    final manual = query<int>(key, (_) => 1, retry: RetryPolicy.none);
    final retained = query<int>(
      key,
      (_) => 2,
      retry: RetryPolicy.none,
      retention: RetentionPolicy.forever,
    );
    harness.client.registerQueryDefaults(
      QueryDefaults(
        retention: RetentionPolicy.duration(const Duration(seconds: 2)),
      ),
      key: QueryKey(<Object?>['gc']),
    );
    harness.client.setQueryData(manual, 7);

    expect(await harness.client.ensureQueryData(retained), 7);
    harness.timers.elapse(const Duration(seconds: 2));

    expect(harness.client.getQueryData(retained).requireValue(), 7);
  });

  test('imperative retained-data fetch joins unless replacement is requested',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final transport = Completer<int>();
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['fetch', 'join']),
      (_) {
        calls += 1;
        return transport.future;
      },
      retry: RetryPolicy.none,
    );
    harness.client.setQueryData(raw, 0);

    final first = harness.client.fetchQuery(raw);
    await harness.pump();
    final joined = harness.client.fetchQuery(raw);
    await harness.pump();

    expect(calls, 1);
    transport.complete(1);
    expect(await first, 1);
    expect(await joined, 1);
    expect(harness.client.getQueryData(raw).requireValue(), 1);
  });

  test('QueryContext exposes the actual receiver client', () async {
    final configured = QueryClient();
    final receiver = QueryClient();
    addTearDown(configured.dispose);
    addTearDown(receiver.dispose);
    QueryClient? executing;
    final raw = query<int>(
      QueryKey(<Object?>['context', 'receiver']),
      (context) {
        executing = context.client;
        return 1;
      },
      client: configured,
      retry: RetryPolicy.none,
    );

    expect(await receiver.fetchQuery(raw), 1);
    expect(identical(executing, receiver), isTrue);
    expect(configured.getQueryData(raw).isAbsent, isTrue);
    expect(receiver.getQueryData(raw).requireValue(), 1);
  });

  group('retry continuation', () {
    test('reattachment before the current attempt fails resumes retry',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final firstAttempt = Completer<int>();
      var attempts = 0;
      final raw = query<int>(
        QueryKey(<Object?>['retry', 'reattach']),
        (_) {
          attempts += 1;
          return attempts == 1 ? firstAttempt.future : 2;
        },
        retry: RetryPolicy.none,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final first = harness.client.observeQuery(raw);
      await harness.pump();
      first.dispose();
      final second = harness.client.observeQuery(
        raw.withObserver(refetchOnMount: RefetchPolicy.never),
      );
      addTearDown(second.dispose);

      firstAttempt.completeError(StateError('retry me'));
      await harness.pump();
      harness.timers.elapse(Duration.zero);
      await harness.pump();

      expect(attempts, 2);
      expect(second.data.requireValue(), 2);
      expect(second.isSuccess, isTrue);
    });

    test('detached retry resumes when reattached before its delay finishes',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      var attempts = 0;
      final raw = query<int>(
        QueryKey(<Object?>['retry', 'detached-delay']),
        (_) {
          attempts += 1;
          if (attempts == 1) throw StateError('retry me');
          return 2;
        },
        retry: RetryPolicy.none,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.fixed(const Duration(seconds: 3)),
        ),
      );
      final first = harness.client.observeQuery(raw);
      await harness.pump();
      first.dispose();

      harness.timers.elapse(const Duration(seconds: 2));
      await harness.pump();

      expect(attempts, 1);
      expect(
        harness.client.getQueryState(raw)!.transientFailure?.error,
        isA<StateError>(),
      );

      final second = harness.client.observeQuery(
        raw.withObserver(refetchOnMount: RefetchPolicy.never),
      );
      addTearDown(second.dispose);
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(attempts, 2);
      expect(second.data.requireValue(), 2);
      expect(second.isSuccess, isTrue);
    });

    test('inactive lifecycle work retries without an enabled observer',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final firstAttempt = Completer<int>();
      var attempts = 0;
      final raw = query<int>(
        QueryKey(<Object?>['retry', 'inactive-lifecycle']),
        (context) {
          attempts += 1;
          context.cancellationToken.isCancelled;
          if (attempts == 1) return firstAttempt.future;
          return 2;
        },
        retry: RetryPolicy.none,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      harness.client.observeQuery(raw.withObserver(enabled: false)).dispose();
      harness.client.setQueryData(raw, 0);

      final pending = harness.client.refetchQueries(
        filter: QueryFilter(key: raw.key, exact: true),
        refetchType: QueryRefetchTarget.inactive,
      );
      await harness.pump();
      final temporary = harness.client.observeQuery(
        raw.withObserver(enabled: false),
      );
      temporary.dispose();
      firstAttempt.completeError(StateError('retry me'));
      harness.timers.elapse(Duration.zero);
      final result = await pending;

      expect(result.affected, 1);
      expect(result.failures, isEmpty);
      expect(attempts, 2);
      expect(harness.client.getQueryData(raw).requireValue(), 2);
    });

    test(
        'lifecycle work joining an observer operation survives final detachment',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final transport = Completer<int>();
      final raw = query<int>(
        QueryKey(<Object?>['retry', 'joined-lifecycle-ownership']),
        (context) {
          context.cancellationToken.isCancelled;
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      final observer = harness.client.observeQuery(raw);
      await harness.pump();

      final joined = harness.client.refetchQueries(
        filter: QueryFilter(key: raw.key, exact: true),
        cancelRefetch: false,
      );
      observer.dispose();
      transport.complete(7);
      final result = await joined;

      expect(result.affected, 1);
      expect(result.failures, isEmpty);
      expect(harness.client.getQueryData(raw).requireValue(), 7);
    });

    test(
        'imperative fetch joining an observer operation survives final detachment',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final transport = Completer<int>();
      final raw = query<int>(
        QueryKey(<Object?>['retry', 'joined-fetch-ownership']),
        (context) {
          context.cancellationToken.isCancelled;
          return transport.future;
        },
        retry: RetryPolicy.none,
      );
      final observer = harness.client.observeQuery(raw);
      await harness.pump();

      final joined = harness.client.fetchQuery(raw);
      observer.dispose();
      transport.complete(9);

      expect(await joined, 9);
      expect(harness.client.getQueryData(raw).requireValue(), 9);
    });

    test(
        'retry waits for focus in always mode and fetching counts exclude the pause',
        () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final secondAttempt = Completer<int>();
      var attempts = 0;
      final raw = query<int>(
        QueryKey(<Object?>['retry', 'focus']),
        (_) {
          attempts += 1;
          if (attempts == 1) throw StateError('retry me');
          return secondAttempt.future;
        },
        retry: RetryPolicy.none,
        networkMode: NetworkMode.always,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      harness.client
        ..onlineManager.isOnline = false
        ..focusManager.isFocused = false;

      final pending = harness.client.fetchQuery(raw);
      await harness.pump();
      harness.timers.elapse(Duration.zero);
      await harness.pump();

      final paused = harness.client.getQueryState(raw)!;
      expect(attempts, 1);
      expect(paused.fetchStatus, FetchStatus.paused);
      expect(paused.pauseReason, PauseReason.focus);
      expect(harness.client.countFetching(), 0);
      expect(harness.client.fetchingCount.peek, 0);

      harness.client.focusManager.isFocused = true;
      await harness.pump();

      expect(attempts, 2);
      expect(
        harness.client.getQueryState(raw)!.fetchStatus,
        FetchStatus.fetching,
      );
      expect(harness.client.countFetching(), 1);
      expect(harness.client.fetchingCount.peek, 1);

      secondAttempt.complete(2);
      expect(await pending, 2);
      await harness.pump();
      expect(harness.client.countFetching(), 0);
      expect(harness.client.fetchingCount.peek, 0);
    });
  });

  test('retained-data failure remains stale for later revalidation', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['failure', 'retained-stale']),
      (_) {
        calls += 1;
        throw StateError('refresh failed');
      },
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
    );
    final observer = harness.client.observeQuery(
      raw.withInitialData(1).withObserver(
            refetchOnMount: RefetchPolicy.never,
          ),
    );
    addTearDown(observer.dispose);

    final result = await observer.refetch();
    await harness.pump();
    final snapshot = harness.client.queryCache.snapshots.single;

    expect(calls, 1);
    expect(result.data.requireValue(), 1);
    expect(result.isRefetchError, isTrue);
    expect(result.isStale, isTrue);
    expect(snapshot.isInvalidated, isTrue);
    expect(snapshot.isStale, isTrue);
  });

  test('active immutable observer blocks bulk but not manual refetch',
      () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['immutable', 'observer']),
      (_) => ++calls,
      retry: RetryPolicy.none,
    );
    final observer = harness.client.observeQuery(
      raw.withInitialData(0).withObserver(
            staleTime: StalePolicy.immutable,
            refetchOnMount: RefetchPolicy.never,
          ),
    );
    addTearDown(observer.dispose);

    final invalidated = await harness.client.invalidateQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );
    final bulk = await harness.client.refetchQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.all,
    );
    await harness.pump();

    expect(invalidated.affected, 1);
    expect(bulk.affected, 0);
    expect(calls, 0);
    expect(observer.isInvalidated, isTrue);
    expect(observer.isStale, isFalse);

    final manual = await observer.refetch();
    expect(manual.data.requireValue(), 1);
    expect(calls, 1);
  });

  test('one immutable observer blocks bulk for the shared query', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    var calls = 0;
    final raw = query<int>(
      QueryKey(<Object?>['immutable', 'mixed-observers']),
      (_) => ++calls,
      retry: RetryPolicy.none,
    );
    final immutable = harness.client.observeQuery(
      raw.withInitialData(0).withObserver(
            enabled: false,
            staleTime: StalePolicy.immutable,
            refetchOnMount: RefetchPolicy.never,
          ),
    );
    final stale = harness.client.observeQuery(
      raw.withObserver(
        staleTime: StalePolicy.immediate,
        refetchOnMount: RefetchPolicy.never,
      ),
    );
    addTearDown(immutable.dispose);
    addTearDown(stale.dispose);

    final result = await harness.client.invalidateQueries(
      filter: QueryFilter(key: raw.key, exact: true),
      refetchType: QueryRefetchTarget.active,
    );
    await harness.pump();

    expect(result.failures, isEmpty);
    expect(result.affected, 1);
    expect(calls, 0);
    expect(immutable.data.requireValue(), 0);
    expect(stale.data.requireValue(), 0);
  });
}

final class _Harness {
  _Harness()
      : clock = FakeQueryClock(),
        timers = FakeQueryTimerScheduler(),
        notifications = FakeQueryNotificationScheduler() {
    runtime = QueryRuntime(
      clock: clock,
      timers: timers,
      random: FakeQueryRandomSource(),
      notifications: notifications,
    );
    client = QueryClient(runtime: runtime);
  }

  final FakeQueryClock clock;
  final FakeQueryTimerScheduler timers;
  final FakeQueryNotificationScheduler notifications;
  late final QueryRuntime runtime;
  late final QueryClient client;

  Future<void> pump([int turns = 8]) async {
    for (var index = 0; index < turns; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() => client.dispose();
}
