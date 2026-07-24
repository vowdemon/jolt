import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('mutation lifecycle scenario contracts', () {
    test('result-based retry does not increment failureCount', () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      var attempts = 0;
      final definition = mutation<int, int, void>(
        mutate: (variables, context) => ++attempts == 1 ? 0 : variables,
      ).withRetry(
        (retry) => retry.strategy(
          delay: DelayPolicy.fixed(const Duration(seconds: 1)),
          retryIf: retry.result((result) => result == 0) & retry.maxRetries(1),
        ),
      );

      final future = harness.client.execute(definition, 7);
      await harness.pump();
      expect(attempts, 1);
      expect(harness.client.mutationCache.snapshots.single.failureCount, 0);
      expect(harness.client.mutationCache.snapshots.single.failure, isNull);

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(await future, 7);
      expect(attempts, 2);
      expect(harness.client.mutationCache.snapshots.single.failureCount, 0);
    });

    test('failure preserves exact object, stack trace, and typed result',
        () async {
      final failureObject = Object();
      final knownStack = StackTrace.fromString('known mutation stack');
      final calls = <String>[];
      final harness = _MutationScenarioHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onMutate: (variables, context) => calls.add('cache.mutate'),
          onError: (failure, variables, result, context) {
            expect(failure.error, same(failureObject));
            expect(result.requireValue(), 'correlation');
            calls.add('cache.error');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(data.isAbsent, isTrue);
            expect(failure?.error, same(failureObject));
            expect(result.requireValue(), 'correlation');
            calls.add('cache.settled');
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, int, String>(
        onMutate: (variables, context) {
          calls.add('mutation.mutate-stage');
          return 'correlation';
        },
        mutate: (variables, context) {
          calls.add('function');
          Error.throwWithStackTrace(failureObject, knownStack);
        },
        onError: (failure, variables, result, context) {
          expect(failure.error, same(failureObject));
          expect(result.requireValue(), 'correlation');
          calls.add('mutation.error');
        },
        onSettled: (data, failure, variables, result, context) {
          expect(failure?.error, same(failureObject));
          expect(result.requireValue(), 'correlation');
          calls.add('mutation.settled');
        },
      );
      Object? caughtError;
      StackTrace? caughtStack;

      try {
        await harness.client.execute(definition, 1);
        fail('The mutation Future should reject.');
      } catch (error, stackTrace) {
        caughtError = error;
        caughtStack = stackTrace;
      }

      expect(caughtError, same(failureObject));
      expect(caughtStack, same(knownStack));
      final terminal = harness.client.mutationCache.snapshots.single;
      expect(terminal.failure?.error, same(failureObject));
      expect(terminal.failure?.stackTrace, same(knownStack));
      expect(terminal.onMutateResult.requireValue(), 'correlation');
      expect(
        calls,
        <String>[
          'cache.mutate',
          'mutation.mutate-stage',
          'function',
          'cache.error',
          'mutation.error',
          'cache.settled',
          'mutation.settled',
        ],
      );
    });

    test('scope successor waits for awaited lifecycle callbacks', () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      const scope = MutationScope('callback-lane');
      final callbackGate = Completer<void>();
      final callbackStarted = Completer<void>();
      final transports = <int>[];
      final definition = mutation<int, int, void>(
        scope: scope,
        mutate: (variables, context) {
          transports.add(variables);
          return variables;
        },
        onSuccess: (data, variables, result, context) {
          if (variables != 1) return Future<void>.value();
          callbackStarted.complete();
          return callbackGate.future;
        },
      );

      final first = harness.client.execute(definition, 1);
      final second = harness.client.execute(definition, 2);
      await callbackStarted.future;
      await harness.pump();

      expect(transports, <int>[1]);
      expect(
        harness.client.mutationCache.snapshots.last.pauseReason,
        PauseReason.scope,
      );

      callbackGate.complete();
      expect(await first, 1);
      expect(await second, 2);
      expect(transports, <int>[1, 2]);
    });

    test('per-call throw reaches submission Zone without changing success',
        () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      const scope = MutationScope('per-call-zone');
      final zoneFailure = Completer<Object>();
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          scope: scope,
          mutate: (variables, context) => variables,
        ),
      );
      late Future<int> first;

      runZonedGuarded<void>(
        () {
          first = observer.execute(
            1,
            onSuccess: (data, variables, result, context) {
              throw StateError('per-call');
            },
          );
        },
        (error, stackTrace) => zoneFailure.complete(error),
      );
      final second = harness.client.execute(observer.mutation, 2);

      expect(await first, 1);
      expect(
        await zoneFailure.future,
        isA<StateError>()
            .having((error) => error.message, 'message', 'per-call'),
      );
      expect(await second, 2);
      await harness.pump();
      expect(observer.data.requireValue(), 1);
    });
  });

  group('mutation scheduling scenario contracts', () {
    test('offline-first attempts once then gates retry until online', () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      harness.client.onlineManager.isOnline = false;
      var attempts = 0;
      final definition = mutation<int, int, void>(
        networkMode: NetworkMode.offlineFirst,
        retry: RetryPolicy.standard,
        mutate: (variables, context) {
          attempts += 1;
          if (attempts == 1) throw StateError('offline attempt');
          return variables;
        },
      );

      final future = harness.client.execute(definition, 4);
      await harness.pump();
      expect(attempts, 1);

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(attempts, 1);
      expect(
        harness.client.mutationCache.snapshots.single.pauseReason,
        PauseReason.offline,
      );

      harness.client.onlineManager.isOnline = true;
      await harness.pump();
      expect(await future, 4);
      expect(attempts, 2);
    });

    test('retried write keeps stable idempotency metadata', () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      var attempts = 0;
      final observedKeys = <Object?>[];
      final definition = mutation<int, int, void>(
        metadata: const <String, Object?>{
          'idempotencyKey': 'save-profile-42',
        },
        retry: RetryPolicy.standard,
        mutate: (variables, context) {
          attempts += 1;
          observedKeys.add(context.metadata['idempotencyKey']);
          if (attempts == 1) throw StateError('ambiguous transport');
          return variables;
        },
      );

      final future = harness.client.execute(definition, 42);
      await harness.pump();
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(await future, 42);
      expect(
        observedKeys,
        <Object?>['save-profile-42', 'save-profile-42'],
      );
    });
  });

  group('explicit query-update scenario contracts', () {
    test('onMutate may explicitly update and settled may invalidate', () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      final counter = query<int>(
        QueryKey(<Object?>['scenario', 'counter']),
        (context) => 0,
      );
      harness.client.setQueryData(counter, 1);
      final definition = mutation<int, int, QueryDataSnapshot<int>>(
        onMutate: (variables, context) {
          final before = context.client.snapshotQueryData(counter);
          context.client.setQueryData(counter, variables);
          return before;
        },
        mutate: (variables, context) => variables,
        onSettled: (data, failure, variables, result, context) async {
          expect(result.requireValue().data.requireValue(), 1);
          await context.client.invalidateQueries(
            filter: QueryFilter(key: counter.key, exact: true),
            refetchType: QueryRefetchTarget.none,
          );
        },
      );

      expect(await harness.client.execute(definition, 2), 2);
      expect(harness.client.getQueryData(counter).requireValue(), 2);
      expect(harness.client.getQueryState(counter)?.isInvalidated, isTrue);
    });

    test('conditional rollback rejects an intervening newer query write',
        () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      final counter = query<int>(
        QueryKey(<Object?>['scenario', 'rollback']),
        (context) => 0,
      );
      harness.client.setQueryData(counter, 1);
      final transport = Completer<int>();
      var rollbackAccepted = true;
      final definition = mutation<int, int,
          ({QueryDataSnapshot<int> before, int optimisticRevision})>(
        onMutate: (variables, context) {
          final before = context.client.snapshotQueryData(counter);
          final optimistic = context.client.setQueryData(counter, variables);
          return (before: before, optimisticRevision: optimistic.revision);
        },
        mutate: (variables, context) => transport.future,
        onError: (failure, variables, result, context) {
          final rollback = result.requireValue();
          rollbackAccepted = context.client.restoreQueryData(
            counter,
            rollback.before,
            ifRevision: rollback.optimisticRevision,
          );
        },
      );

      final future = harness.client.execute(definition, 2);
      await harness.pump();
      expect(harness.client.getQueryData(counter).requireValue(), 2);

      harness.client.setQueryData(counter, 99);
      transport.completeError(StateError('server rejected'));
      await expectLater(future, throwsA(isA<StateError>()));

      expect(rollbackAccepted, isFalse);
      expect(harness.client.getQueryData(counter).requireValue(), 99);
    });

    test('onSuccess may write canonical server data without refetch', () async {
      final harness = _MutationScenarioHarness();
      addTearDown(harness.dispose);
      var fetchCalls = 0;
      final item = query<_CanonicalItem>(
        QueryKey(<Object?>['scenario', 'item', 1]),
        (context) {
          fetchCalls += 1;
          return (id: 1, revision: 999, title: 'refetched');
        },
      );
      harness.client.setQueryData(
        item,
        (id: 1, revision: 1, title: 'before'),
      );
      final definition = mutation<String, _CanonicalItem, void>(
        mutate: (title, context) => (id: 1, revision: 2, title: title),
        onSuccess: (data, title, result, context) {
          context.client.setQueryData(item, data);
        },
      );

      final canonical =
          await harness.client.execute(definition, 'server title');

      expect(canonical, (id: 1, revision: 2, title: 'server title'));
      expect(harness.client.getQueryData(item).requireValue(), canonical);
      expect(fetchCalls, 0);
    });
  });
}

typedef _CanonicalItem = ({int id, int revision, String title});

final class _MutationScenarioHarness {
  _MutationScenarioHarness({
    MutationCacheCallbacks mutationCallbacks = const MutationCacheCallbacks(),
  }) : runtime = QueryRuntime(
          clock: FakeQueryClock(),
          timers: FakeQueryTimerScheduler(),
          random: FakeQueryRandomSource(<double>[
            0.5,
            0.5,
            0.5,
            0.5,
            0.5,
            0.5,
          ]),
          notifications: FakeQueryNotificationScheduler(),
        ) {
    client = QueryClient(
      runtime: runtime,
      mutationCallbacks: mutationCallbacks,
    );
  }

  final QueryRuntime runtime;
  late final QueryClient client;

  FakeQueryTimerScheduler get timers =>
      runtime.timers as FakeQueryTimerScheduler;

  FakeQueryNotificationScheduler get notifications =>
      runtime.notifications as FakeQueryNotificationScheduler;

  Future<void> pump() async {
    for (var index = 0; index < 6; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() {
    if (!client.isDisposed) client.dispose();
  }
}
