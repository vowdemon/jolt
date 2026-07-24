import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('unified mutation execution contracts', () {
    test('class-first VDR executes through client and observer', () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      const definition = _SaveTitleMutation();
      const firstInput = (id: 1, title: 'first');

      final _SavedTitle first = await harness.client.execute(
        definition,
        firstInput,
      );
      final MutationObserver<_SaveTitle, _SavedTitle, void> observer =
          harness.client.observeMutation(definition);
      final _SavedTitle second = await observer.execute(
        (id: 2, title: 'second'),
      );
      await harness.pump();

      expect(first, (id: 1, title: 'first'));
      expect(second, (id: 2, title: 'second'));
      expect(observer.variables.requireValue(), (id: 2, title: 'second'));
      expect(observer.data.requireValue(), second);
      expect(observer.onMutateResult.isAbsent, isTrue);
    });

    test('equal mutation keys remain concurrent and filterable', () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      final firstTransport = Completer<int>();
      final secondTransport = Completer<int>();
      final started = <int>[];

      Mutation<int, int, void> definition(
        MutationKey key,
        Completer<int> transport,
      ) {
        return mutation<int, int, void>(
          key: key,
          mutate: (variables, context) {
            started.add(variables);
            return transport.future;
          },
        );
      }

      final first = harness.client.execute(
        definition(
          MutationKey(<Object?>['todos', 'add']),
          firstTransport,
        ),
        1,
      );
      final second = harness.client.execute(
        definition(
          MutationKey(<Object?>['todos', 'add']),
          secondTransport,
        ),
        2,
      );
      await harness.pump();

      expect(started, <int>[1, 2]);
      final matches = harness.client.mutationCache.findAll(
        filter: MutationFilter(
          key: MutationKey(<Object?>['todos', 'add']),
          exact: true,
          status: MutationStatus.pending,
          predicate: (snapshot) => snapshot.submittedAt == DateTime.utc(2025),
        ),
      );
      expect(matches, hasLength(2));
      expect(matches.map((snapshot) => snapshot.variables), <Object?>[1, 2]);
      expect(started, <int>[1, 2]);

      secondTransport.complete(20);
      firstTransport.complete(10);
      expect(await first, 10);
      expect(await second, 20);
    });

    test('latest observer ignores an earlier execution that settles last',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      final firstTransport = Completer<int>();
      final secondTransport = Completer<int>();
      final perCall = <String>[];
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          mutate: (variables, context) =>
              variables == 1 ? firstTransport.future : secondTransport.future,
        ),
      );

      final first = observer.execute(
        1,
        onSuccess: (data, variables, result, context) =>
            perCall.add('first:$data'),
      );
      final second = observer.execute(
        2,
        onSuccess: (data, variables, result, context) =>
            perCall.add('second:$data'),
      );
      secondTransport.complete(20);
      expect(await second, 20);
      await harness.pump();
      expect(observer.variables.requireValue(), 2);
      expect(observer.data.requireValue(), 20);

      firstTransport.complete(10);
      expect(await first, 10);
      await harness.pump();

      expect(observer.variables.requireValue(), 2);
      expect(observer.data.requireValue(), 20);
      expect(perCall, <String>['second:20']);
    });

    test('disposing observer during retry detaches only presentation',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      var attempts = 0;
      final lifecycle = <String>[];
      final perCall = <String>[];
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          retry: RetryPolicy.standard,
          mutate: (variables, context) {
            attempts += 1;
            if (attempts == 1) throw StateError('retry');
            return variables;
          },
          onSuccess: (data, variables, result, context) {
            lifecycle.add('success:$data');
          },
        ),
      );

      final future = observer.execute(
        7,
        onSuccess: (data, variables, result, context) {
          perCall.add('success:$data');
        },
      );
      await harness.pump();
      expect(attempts, 1);
      expect(
        harness.client.mutationCache.snapshots.single.failureCount,
        1,
      );

      observer.dispose();
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(await future, 7);
      expect(attempts, 2);
      expect(lifecycle, <String>['success:7']);
      expect(perCall, isEmpty);
      expect(
        harness.client.mutationCache.snapshots.single.status,
        MutationStatus.success,
      );
    });

    test('user-thrown cancellation-shaped error participates in retry',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      var attempts = 0;
      final definition = mutation<int, int, void>(
        mutate: (variables, context) {
          attempts += 1;
          if (attempts == 1) {
            throw const QueryCancelledException('application failure');
          }
          return variables;
        },
      ).withRetry(
        (retry) => retry.strategy(
          delay: DelayPolicy.fixed(const Duration(seconds: 1)),
          retryIf: retry.exceptionType<QueryCancelledException>() &
              retry.maxRetries(1),
        ),
      );

      final future = harness.client.execute(definition, 9);
      await harness.pump();
      final retrying = harness.client.mutationCache.snapshots.single;
      expect(retrying.status, MutationStatus.pending);
      expect(retrying.failureCount, 1);
      expect(retrying.failure?.error, isA<QueryCancelledException>());

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(await future, 9);
      expect(attempts, 2);
      final terminal = harness.client.mutationCache.snapshots.single;
      expect(terminal.status, MutationStatus.success);
      expect(terminal.failureCount, 0);
      expect(terminal.failure, isNull);
    });

    test('cache onMutate failure skips recipe setup and transport', () async {
      final calls = <String>[];
      final harness = _MutationContractHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onMutate: (variables, context) {
            calls.add('cache.mutate');
            throw StateError('cache setup failed');
          },
          onError: (failure, variables, result, context) {
            expect(result.isAbsent, isTrue);
            calls.add('cache.error');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(data.isAbsent, isTrue);
            expect(result.isAbsent, isTrue);
            calls.add('cache.settled');
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, int, String>(
        onMutate: (variables, context) {
          calls.add('recipe.mutate');
          return 'token';
        },
        mutate: (variables, context) {
          calls.add('transport');
          return variables;
        },
        onError: (failure, variables, result, context) {
          expect(result.isAbsent, isTrue);
          calls.add('recipe.error');
        },
        onSettled: (data, failure, variables, result, context) {
          expect(data.isAbsent, isTrue);
          expect(result.isAbsent, isTrue);
          calls.add('recipe.settled');
        },
      );

      await expectLater(
        harness.client.execute(definition, 1),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'cache setup failed',
          ),
        ),
      );

      expect(
        calls,
        <String>[
          'cache.mutate',
          'cache.error',
          'recipe.error',
          'cache.settled',
          'recipe.settled',
        ],
      );
      expect(
        harness.client.mutationCache.snapshots.single.onMutateResult.isAbsent,
        isTrue,
      );
    });

    test('success settled failure runs only remaining cleanup once', () async {
      final calls = <String>[];
      final harness = _MutationContractHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onSuccess: (data, variables, result, context) {
            calls.add('cache.success');
          },
          onError: (failure, variables, result, context) {
            calls.add('cache.error');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(data.isPresent, isTrue);
            expect(failure, isNull);
            calls.add('cache.settled.success');
            throw StateError('settled failed');
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, int, void>(
        mutate: (variables, context) {
          calls.add('transport');
          return variables;
        },
        onSuccess: (data, variables, result, context) {
          calls.add('recipe.success');
        },
        onError: (failure, variables, result, context) {
          expect(failure.error, isA<StateError>());
          calls.add('recipe.error');
        },
        onSettled: (data, failure, variables, result, context) {
          expect(data.isAbsent, isTrue);
          expect(failure?.error, isA<StateError>());
          calls.add('recipe.settled.error');
        },
      );

      await expectLater(
        harness.client.execute(definition, 3),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'settled failed',
          ),
        ),
      );

      expect(
        calls,
        <String>[
          'transport',
          'cache.success',
          'recipe.success',
          'cache.settled.success',
          'cache.error',
          'recipe.error',
          'recipe.settled.error',
        ],
      );
      expect(
        harness.client.mutationCache.snapshots.single.status,
        MutationStatus.error,
      );
    });

    test('per-call callback may submit the same scope synchronously', () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      const scope = MutationScope('callback-submit');
      final transports = <int>[];
      final definition = mutation<int, int, void>(
        scope: scope,
        mutate: (variables, context) {
          transports.add(variables);
          return variables;
        },
      );
      final observer = harness.client.observeMutation(definition);
      Future<int>? second;

      final first = observer.execute(
        1,
        onSuccess: (data, variables, result, context) {
          second = harness.client.execute(definition, 2);
        },
      );

      expect(await first, 1);
      expect(await second!, 2);
      expect(transports, <int>[1, 2]);
    });

    test('equal scope IDs stay local to each client', () async {
      final firstHarness = _MutationContractHarness();
      final secondHarness = _MutationContractHarness();
      addTearDown(firstHarness.dispose);
      addTearDown(secondHarness.dispose);
      const scope = MutationScope('client-local');
      final firstTransport = Completer<int>();
      final secondTransport = Completer<int>();
      final started = <String>[];
      final firstDefinition = mutation<int, int, void>(
        scope: scope,
        mutate: (variables, context) {
          started.add('first');
          return firstTransport.future;
        },
      );
      final secondDefinition = mutation<int, int, void>(
        scope: const MutationScope('client-local'),
        mutate: (variables, context) {
          started.add('second');
          return secondTransport.future;
        },
      );

      final first = firstHarness.client.execute(firstDefinition, 1);
      final second = secondHarness.client.execute(secondDefinition, 2);
      await Future.wait<void>(<Future<void>>[
        firstHarness.pump(),
        secondHarness.pump(),
      ]);

      expect(started, containsAll(<String>['first', 'second']));
      expect(started, hasLength(2));
      firstTransport.complete(10);
      secondTransport.complete(20);
      expect(await first, 10);
      expect(await second, 20);
    });
  });

  group('mutation snapshot and cache contracts', () {
    test('gated submission exposes variables and submittedAt immediately',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      harness.client.onlineManager.isOnline = false;
      final definition = mutation<int, int, void>(
        mutate: (variables, context) => variables,
      );

      final future = harness.client.execute(definition, 42);
      final pending = harness.client.mutationCache.snapshots.single;

      expect(pending.status, MutationStatus.pending);
      expect(pending.isPaused, isTrue);
      expect(pending.pauseReason, PauseReason.offline);
      expect(pending.variables, 42);
      expect(pending.submittedAt, DateTime.utc(2025));
      expect(pending.data.isAbsent, isTrue);
      expect(pending.onMutateResult.isAbsent, isTrue);

      harness.client.onlineManager.isOnline = true;
      await harness.pump();
      expect(await future, 42);
    });

    test('omitted onMutate stays absent in pending success and error',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      final transport = Completer<int>();
      final definition = mutation<int, int, void>(
        mutate: (variables, context) {
          if (variables < 0) throw StateError('rejected');
          return transport.future;
        },
      );

      final success = harness.client.execute(definition, 1);
      await harness.pump();
      expect(
        harness.client.mutationCache.snapshots.single.onMutateResult.isAbsent,
        isTrue,
      );

      transport.complete(2);
      expect(await success, 2);
      await harness.pump();
      expect(
        harness.client.mutationCache.snapshots.first.onMutateResult.isAbsent,
        isTrue,
      );
      expect(
        harness.client.mutationCache.snapshots.first.status,
        MutationStatus.success,
      );

      await expectLater(
        harness.client.execute(definition, -1),
        throwsA(isA<StateError>()),
      );
      await harness.pump();
      final failed = harness.client.mutationCache.snapshots.last;
      expect(failed.status, MutationStatus.error);
      expect(failed.onMutateResult.isAbsent, isTrue);
    });

    test('cache clear keeps event observation open for later submissions',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      final cache = harness.client.mutationCache;
      final events = <MutationCacheEvent>[];
      var streamClosed = false;
      final subscription = cache.events.listen(
        events.add,
        onDone: () => streamClosed = true,
      );
      addTearDown(subscription.cancel);
      final activeTransport = Completer<int>();
      final active = harness.client.execute(
        mutation<int, int, void>(
          mutate: (variables, context) => activeTransport.future,
        ),
        1,
      );
      await harness.pump();
      final removedId = cache.snapshots.single.id;

      cache.clear();
      await harness.pump();
      expect(cache.snapshots, isEmpty);
      expect(streamClosed, isFalse);
      expect(
        events.where(
          (event) =>
              event.kind == MutationCacheEventKind.removed &&
              event.snapshot.id == removedId,
        ),
        hasLength(1),
      );

      final laterBoundary = events.length;
      expect(
        await harness.client.execute(
          mutation<int, int, void>(
            mutate: (variables, context) => variables + 1,
          ),
          2,
        ),
        3,
      );
      await harness.pump();
      final laterEvents = events.skip(laterBoundary).toList();
      expect(
        laterEvents.any(
          (event) =>
              event.kind == MutationCacheEventKind.added &&
              event.snapshot.variables == 2,
        ),
        isTrue,
      );
      expect(
        laterEvents.any(
          (event) =>
              event.kind == MutationCacheEventKind.updated &&
              event.snapshot.data == const QueryValue<Object?>.present(3),
        ),
        isTrue,
      );
      expect(streamClosed, isFalse);

      activeTransport.complete(1);
      expect(await active, 1);
      await harness.pump();
      expect(cache.snapshots, hasLength(1));
      expect(cache.snapshots.single.variables, 2);
    });

    test('handled result becomes success when retry budget is exhausted',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      var attempts = 0;
      final definition = mutation<int, int, void>(
        mutate: (variables, context) => ++attempts,
      ).withRetry(
        (retry) => retry.strategy(
          delay: DelayPolicy.fixed(const Duration(seconds: 1)),
          retryIf: retry.result((result) => result > 0) & retry.maxRetries(1),
        ),
      );

      final future = harness.client.execute(definition, 0);
      await harness.pump();
      expect(attempts, 1);
      expect(
        harness.client.mutationCache.snapshots.single.failureCount,
        0,
      );

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(await future, 2);
      expect(attempts, 2);
      final terminal = harness.client.mutationCache.snapshots.single;
      expect(terminal.status, MutationStatus.success);
      expect(terminal.data.requireValue(), 2);
      expect(terminal.failureCount, 0);
    });
  });

  group('user-composed optimistic update contracts', () {
    test('conditional optimistic restore succeeds without a newer write',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      final counter = query<int>(
        QueryKey(<Object?>['contract', 'restore']),
        (context) => 0,
      );
      final baselineTime = DateTime.utc(2024, 5, 6);
      harness.client.setQueryData(counter, 0, updatedAt: baselineTime);
      var restored = false;
      final definition = mutation<int, int, _RollbackCheckpoint>(
        onMutate: (variables, context) {
          final before = context.client.snapshotQueryData(counter);
          final optimistic = context.client.setQueryData(counter, variables);
          return (before: before, optimisticRevision: optimistic.revision);
        },
        mutate: (variables, context) => throw StateError('rejected'),
        onError: (failure, variables, result, context) {
          final checkpoint = result.requireValue();
          restored = context.client.restoreQueryData(
            counter,
            checkpoint.before,
            ifRevision: checkpoint.optimisticRevision,
          );
        },
      );

      await expectLater(
        harness.client.execute(definition, 1),
        throwsA(isA<StateError>()),
      );

      final current = harness.client.snapshotQueryData(counter);
      expect(restored, isTrue);
      expect(current.data.requireValue(), 0);
      expect(current.updatedAt, baselineTime);
    });

    test('overlapping failures are not automatically rebased', () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      final counter = query<int>(
        QueryKey(<Object?>['contract', 'overlap']),
        (context) => 0,
      );
      harness.client.setQueryData(counter, 0);
      final transports = <int, Completer<int>>{
        1: Completer<int>(),
        2: Completer<int>(),
      };
      final rollbackResults = <bool>[];
      final definition = mutation<int, int, _RollbackCheckpoint>(
        onMutate: (variables, context) {
          final before = context.client.snapshotQueryData(counter);
          final optimistic = context.client.setQueryData(counter, variables);
          return (before: before, optimisticRevision: optimistic.revision);
        },
        mutate: (variables, context) => transports[variables]!.future,
        onError: (failure, variables, result, context) {
          final checkpoint = result.requireValue();
          rollbackResults.add(
            context.client.restoreQueryData(
              counter,
              checkpoint.before,
              ifRevision: checkpoint.optimisticRevision,
            ),
          );
        },
      );

      final first = harness.client.execute(definition, 1);
      final firstFailure = expectLater(first, throwsA(isA<StateError>()));
      final second = harness.client.execute(definition, 2);
      final secondFailure = expectLater(second, throwsA(isA<StateError>()));
      await harness.pump();
      expect(harness.client.getQueryData(counter).requireValue(), 2);

      transports[1]!.completeError(StateError('first rejected'));
      await firstFailure;
      expect(harness.client.getQueryData(counter).requireValue(), 2);

      transports[2]!.completeError(StateError('second rejected'));
      await secondFailure;

      expect(rollbackResults, <bool>[false, true]);
      expect(harness.client.getQueryData(counter).requireValue(), 1);
      expect(harness.client.getQueryData(counter).requireValue(), isNot(0));
    });
  });

  group('mutation scheduling and disposal contracts', () {
    test('connectivity resumes independent scope heads and preserves FIFO',
        () async {
      final harness = _MutationContractHarness();
      addTearDown(harness.dispose);
      harness.client.onlineManager.isOnline = false;
      final transports = <int, Completer<int>>{
        for (final value in <int>[1, 2, 3, 4]) value: Completer<int>(),
      };
      final started = <int>[];
      Mutation<int, int, void> definition(MutationScope scope) {
        return mutation<int, int, void>(
          scope: scope,
          mutate: (variables, context) {
            started.add(variables);
            return transports[variables]!.future;
          },
        );
      }

      final laneA = definition(const MutationScope('lane-a'));
      final laneB = definition(const MutationScope('lane-b'));
      final one = harness.client.execute(laneA, 1);
      final two = harness.client.execute(laneA, 2);
      final three = harness.client.execute(laneB, 3);
      final four = harness.client.execute(laneB, 4);
      await harness.pump();
      expect(started, isEmpty);
      expect(
        harness.client.mutationCache.snapshots
            .map((snapshot) => snapshot.pauseReason),
        <PauseReason?>[
          PauseReason.offline,
          PauseReason.scope,
          PauseReason.offline,
          PauseReason.scope,
        ],
      );

      harness.client.onlineManager.isOnline = true;
      await harness.pump();
      expect(started, unorderedEquals(<int>[1, 3]));

      transports[1]!.complete(1);
      transports[3]!.complete(3);
      expect(await one, 1);
      expect(await three, 3);
      await harness.pump();
      expect(started, containsAll(<int>[1, 2, 3, 4]));
      expect(started.indexOf(1), lessThan(started.indexOf(2)));
      expect(started.indexOf(3), lessThan(started.indexOf(4)));

      transports[2]!.complete(2);
      transports[4]!.complete(4);
      expect(await two, 2);
      expect(await four, 4);
    });

    test('client disposal rejects a queued mutation before transport',
        () async {
      final harness = _MutationContractHarness();
      const scope = MutationScope('dispose-queue');
      final headTransport = Completer<int>();
      final started = <int>[];
      final definition = mutation<int, int, void>(
        scope: scope,
        mutate: (variables, context) {
          started.add(variables);
          return variables == 1 ? headTransport.future : variables;
        },
      );

      final first = harness.client.execute(definition, 1);
      final second = harness.client.execute(definition, 2);
      final firstFailure = expectLater(
        first,
        throwsA(isA<QueryClientDisposedException>()),
      );
      final secondFailure = expectLater(
        second,
        throwsA(isA<QueryClientDisposedException>()),
      );
      await harness.pump();
      expect(started, <int>[1]);
      expect(
        harness.client.mutationCache.snapshots.last.pauseReason,
        PauseReason.scope,
      );

      harness.client.dispose();
      await firstFailure;
      await secondFailure;
      headTransport.complete(1);
      await Future<void>.delayed(Duration.zero);

      expect(started, <int>[1]);
    });

    test('client disposal during an awaited callback stops later stages',
        () async {
      final callbackGate = Completer<void>();
      final callbackStarted = Completer<void>();
      final callbackFinished = Completer<void>();
      final calls = <String>[];
      final harness = _MutationContractHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onSuccess: (data, variables, result, context) async {
            calls.add('cache.success.started');
            callbackStarted.complete();
            await callbackGate.future;
            calls.add('cache.success.finished');
            callbackFinished.complete();
          },
        ),
      );
      final definition = mutation<int, int, void>(
        mutate: (variables, context) => variables,
        onSuccess: (data, variables, result, context) {
          calls.add('recipe.success');
        },
        onSettled: (data, failure, variables, result, context) {
          calls.add('recipe.settled');
        },
      );
      final future = harness.client.execute(definition, 1);
      final failure = expectLater(
        future,
        throwsA(isA<QueryClientDisposedException>()),
      );
      await callbackStarted.future;

      harness.client.dispose();
      await failure;
      callbackGate.complete();
      await callbackFinished.future;
      await Future<void>.delayed(Duration.zero);

      expect(
        calls,
        <String>['cache.success.started', 'cache.success.finished'],
      );
    });
  });
}

typedef _SaveTitle = ({int id, String title});
typedef _SavedTitle = ({int id, String title});
typedef _RollbackCheckpoint = ({
  QueryDataSnapshot<int> before,
  int optimisticRevision,
});

final class _SaveTitleMutation extends Mutation<_SaveTitle, _SavedTitle, void> {
  const _SaveTitleMutation();

  @override
  _SavedTitle mutate(_SaveTitle variables, MutationContext context) {
    return (id: variables.id, title: variables.title);
  }
}

final class _MutationContractHarness {
  _MutationContractHarness({
    MutationCacheCallbacks mutationCallbacks = const MutationCacheCallbacks(),
  }) : runtime = QueryRuntime(
          clock: FakeQueryClock(),
          timers: FakeQueryTimerScheduler(),
          random: FakeQueryRandomSource(List<double>.filled(64, 0.5)),
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
    for (var index = 0; index < 8; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() {
    if (!client.isDisposed) client.dispose();
  }
}
