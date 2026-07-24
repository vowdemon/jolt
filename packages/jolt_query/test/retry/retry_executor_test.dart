import 'dart:async';

import 'package:jolt_query/src/foundation/environment_manager.dart';
import 'package:jolt_query/src/foundation/query_cancellation.dart';
import 'package:jolt_query/src/foundation/query_failure.dart';
import 'package:jolt_query/src/foundation/query_runtime.dart';
import 'package:jolt_query/src/foundation/timer_orchestrator.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:retry_plus/retry_plus.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('manual retry order', () {
    test('awaits predicate, onRetry, delay, then eventual-success give-up',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final events = <String>[];
      final contexts = <RetryAttemptContext<int>>[];
      var factoryCalls = 0;
      var attempts = 0;
      final policy = RetryPolicy<int>.custom((retry) {
        factoryCalls += 1;
        return retry.strategy(
          retryIf: retry.where((attempt) async {
            await Future<void>.value();
            contexts.add(attempt);
            events.add('predicate:${attempt.attemptNumber}');
            return attempt.outcome is AttemptOutcomeError<int>;
          }),
          delay: DelayPolicy.generated((attempt, random) async {
            await Future<void>.value();
            events.add('delay:${attempt.attemptNumber}');
            return Duration.zero;
          }),
          onRetry: (attempt) async {
            await Future<void>.value();
            events.add('onRetry:${attempt.attemptNumber}');
          },
          onGiveUp: (attempt) async {
            await Future<void>.value();
            events.add('onGiveUp:${attempt.attemptNumber}');
          },
        );
      });
      final executor = harness.executor(policy);

      final result = await executor.execute((token) {
        attempts += 1;
        events.add('attempt:$attempts');
        if (attempts == 1) throw StateError('retry me');
        return 42;
      });

      expect(result, 42);
      expect(factoryCalls, 1);
      expect(
        events,
        <String>[
          'attempt:1',
          'predicate:1',
          'onRetry:1',
          'delay:1',
          'attempt:2',
          'predicate:2',
          'onGiveUp:2',
        ],
      );
      expect(contexts.map((context) => context.retryIndex), <int>[0, 1]);
      expect(contexts.map((context) => context.attemptNumber), <int>[1, 2]);
    });

    test('does not invoke give-up when the first attempt is refused', () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      var onRetryCalls = 0;
      var onGiveUpCalls = 0;
      var delayCalls = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.never,
          delay: DelayPolicy.generated((attempt, random) {
            delayCalls += 1;
            return Duration.zero;
          }),
          onRetry: (attempt) => onRetryCalls += 1,
          onGiveUp: (attempt) => onGiveUpCalls += 1,
        ),
      );
      final error = StateError('final');

      await expectLater(
        harness.executor(policy).execute((token) => throw error),
        throwsA(same(error)),
      );
      expect(onRetryCalls, 0);
      expect(delayCalls, 0);
      expect(onGiveUpCalls, 0);
    });

    test('a throwing eventual-success give-up hook replaces the result',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final hookError = StateError('give-up failed');
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.result((result) => true) & retry.maxRetries(1),
          delay: DelayPolicy.none(),
          onGiveUp: (attempt) => throw hookError,
        ),
      );

      await expectLater(
        harness.executor(policy).execute((token) => ++attempts),
        throwsA(same(hookError)),
      );
      expect(attempts, 2);
    });

    test('result budget exhaustion returns the final handled result', () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      var attempts = 0;
      var giveUpResult = -1;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.result((result) => true) & retry.maxRetries(1),
          delay: DelayPolicy.none(),
          onGiveUp: (attempt) {
            giveUpResult =
                (attempt.outcome as AttemptOutcomeResult<int>).result;
          },
        ),
      );

      final result =
          await harness.executor(policy).execute((token) => ++attempts);

      expect(result, 2);
      expect(giveUpResult, 2);
    });

    test('predicate, onRetry, and delay failures stop at their stage',
        () async {
      for (final stage in _ThrowingStage.values) {
        final harness = _RetryHarness<int>();
        final error = StateError(stage.name);
        var delayCalls = 0;
        var attemptCalls = 0;
        var giveUpCalls = 0;
        final policy = RetryPolicy<int>.custom(
          (retry) => retry.strategy(
            retryIf: retry.where((attempt) {
              if (stage == _ThrowingStage.predicate) throw error;
              return true;
            }),
            onRetry: (attempt) {
              if (stage == _ThrowingStage.onRetry) throw error;
            },
            delay: DelayPolicy.generated((attempt, random) {
              delayCalls += 1;
              if (stage == _ThrowingStage.delay) throw error;
              return Duration.zero;
            }),
            onGiveUp: (attempt) => giveUpCalls += 1,
          ),
        );

        await expectLater(
          harness.executor(policy).execute((token) => ++attemptCalls),
          throwsA(same(error)),
          reason: stage.name,
        );
        expect(attemptCalls, 1, reason: stage.name);
        expect(
          delayCalls,
          stage == _ThrowingStage.delay ? 1 : 0,
          reason: stage.name,
        );
        expect(giveUpCalls, 0, reason: stage.name);
        harness.dispose();
      }
    });
  });

  group('defaults and policy coverage', () {
    test('none performs exactly one attempt', () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      var attempts = 0;
      final error = StateError('once');

      await expectLater(
        harness.executor(RetryPolicy.none).execute((token) {
          attempts += 1;
          throw error;
        }),
        throwsA(same(error)),
      );

      expect(attempts, 1);
      expect(harness.scheduler.handles, isEmpty);
    });

    test('standard retries three times at 1s, 2s, and 4s', () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      var attempts = 0;
      final error = StateError('always');
      final future = harness.executor(RetryPolicy.standard).execute((token) {
        attempts += 1;
        throw error;
      });

      await _pump();
      expect(attempts, 1);
      expect(harness.pendingDelay, const Duration(seconds: 1));

      harness.advance(const Duration(seconds: 1));
      await _pump();
      expect(attempts, 2);
      expect(harness.pendingDelay, const Duration(seconds: 2));

      harness.advance(const Duration(seconds: 2));
      await _pump();
      expect(attempts, 3);
      expect(harness.pendingDelay, const Duration(seconds: 4));

      harness.advance(const Duration(seconds: 4));
      await expectLater(future, throwsA(same(error)));
      expect(attempts, 4);
    });

    test('supports deterministic jitter through the injected random source',
        () async {
      final harness = _RetryHarness<int>(randomValues: <double>[0.25]);
      addTearDown(harness.dispose);
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.exponential(
            initial: const Duration(seconds: 10),
            jitter: Jitter.full(),
          ),
        ),
      );
      final future = harness.executor(policy).execute((token) {
        attempts += 1;
        if (attempts == 1) throw StateError('retry');
        return 7;
      });

      await _pump();
      expect(harness.pendingDelay, const Duration(milliseconds: 2500));
      harness.advance(const Duration(milliseconds: 2500));

      expect(await future, 7);
    });

    test('stateful decorrelated jitter spans attempts in one operation',
        () async {
      final harness = _RetryHarness<int>(
        randomValues: <double>[0.5, 0.5],
      );
      addTearDown(harness.dispose);
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(2),
          delay: DelayPolicy.decorrelatedJitter(
            medianFirstRetryDelay: const Duration(seconds: 1),
          ),
        ),
      );
      final future = harness.executor(policy).execute((token) {
        attempts += 1;
        if (attempts < 3) throw StateError('retry');
        return attempts;
      });

      await _pump();
      expect(harness.pendingDelay, const Duration(seconds: 2));
      harness.advance(const Duration(seconds: 2));
      await _pump();
      expect(harness.pendingDelay, const Duration(milliseconds: 3500));
      harness.advance(const Duration(milliseconds: 3500));

      expect(await future, 3);
    });

    test('failure state counts thrown attempts but not handled results',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final failures = <QueryFailure>[];
      final counts = <int>[];
      var attempts = 0;
      final firstError = StateError('first');
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.any & retry.maxRetries(2),
          delay: DelayPolicy.none(),
        ),
      );

      final result = await harness.executor(
        policy,
        onAttemptFailure: (failure, count) {
          failures.add(failure);
          counts.add(count);
        },
      ).execute((token) {
        attempts += 1;
        if (attempts == 1) throw firstError;
        return attempts;
      });

      expect(result, 3);
      expect(failures.single.error, same(firstError));
      expect(counts, <int>[1]);
    });
  });

  group('owned context and lifecycle controls', () {
    test(
        'keeps one detached context per operation and resynchronizes elapsed '
        'each decision', () async {
      final harness = _RetryHarness<int>(
        randomValues: <double>[0.25, 0.75],
      );
      addTearDown(harness.dispose);
      final pipelineContexts = <RetryPipelineContext<int>>[];
      final elapsedValues = <Duration>[];
      final pipelineElapsedValues = <Duration>[];
      final injectedRandomValues = <double>[];
      final detachedNowValues = <DateTime>[];
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.where((attempt) {
            pipelineContexts.add(attempt.pipelineContext);
            elapsedValues.add(attempt.elapsed);
            pipelineElapsedValues.add(attempt.pipelineContext.elapsed);
            if (attempt.attemptNumber == 1) {
              expect(attempt.pipelineContext.phase, RetryPhase.pending);
              expect(attempt.pipelineContext.telemetry, isNull);
              expect(attempt.pipelineContext.isCancelled, isFalse);
              attempt.pipelineContext.elapsed = const Duration(days: 9);
              attempt.pipelineContext.setPhase(RetryPhase.cancelled);
              detachedNowValues.add(attempt.pipelineContext.now());
              expect(
                () => attempt.pipelineContext.cancelToken,
                throwsStateError,
              );
              expect(
                () => attempt.pipelineContext.throwIfCancelled(),
                throwsStateError,
              );
              return true;
            }
            expect(attempt.pipelineContext.phase, RetryPhase.cancelled);
            return false;
          }),
          delay: DelayPolicy.generated((attempt, random) {
            expect(attempt.pipelineContext.elapsed, const Duration(days: 9));
            injectedRandomValues.add(random());
            return const Duration(seconds: 1);
          }),
        ),
      );

      Future<int> runOperation() async {
        var attempts = 0;
        final future = harness.executor(policy).execute((token) {
          attempts += 1;
          harness.clock.advance(Duration(seconds: attempts + 1));
          if (attempts == 1) throw StateError('retry');
          return 9;
        });

        await _pump();
        expect(harness.pendingDelay, const Duration(seconds: 1));
        harness.advance(const Duration(seconds: 1));
        return future;
      }

      final firstResult = await runOperation();
      final secondResult = await runOperation();

      expect(firstResult, 9);
      expect(secondResult, 9);
      expect(identical(pipelineContexts[0], pipelineContexts[1]), isTrue);
      expect(identical(pipelineContexts[2], pipelineContexts[3]), isTrue);
      expect(identical(pipelineContexts[0], pipelineContexts[2]), isFalse);
      expect(
        elapsedValues,
        <Duration>[
          const Duration(seconds: 2),
          const Duration(seconds: 6),
          const Duration(seconds: 2),
          const Duration(seconds: 6),
        ],
      );
      expect(pipelineElapsedValues, elapsedValues);
      expect(injectedRandomValues, <double>[0.25, 0.75]);
      expect(detachedNowValues, hasLength(2));
    });

    test('cancellation during delay cancels its handle and prevents retry',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.fixed(const Duration(seconds: 5)),
        ),
      );
      final future = harness.executor(policy).execute((token) {
        attempts += 1;
        throw StateError('retry');
      });

      await _pump();
      final handle = harness.scheduler.handles.single;
      harness.cancellation.cancel('disposed');

      await expectLater(
        future,
        throwsA(
          isA<QueryCancelledException>().having(
            (error) => error.reason,
            'reason',
            'disposed',
          ),
        ),
      );
      expect(handle.isCancelled, isTrue);
      handle.fire(evenIfCancelled: true);
      await _pump();
      expect(attempts, 1);
    });

    test('late attempt completion cannot pass cancellation guards', () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final attemptCompleter = Completer<int>();
      var predicateCalls = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.where((attempt) {
            predicateCalls += 1;
            return false;
          }),
        ),
      );
      final future =
          harness.executor(policy).execute((token) => attemptCompleter.future);

      harness.cancellation.cancel('superseded');
      attemptCompleter.complete(4);

      await expectLater(future, throwsA(isA<QueryCancelledException>()));
      expect(predicateCalls, 0);
    });

    test('generation guard prevents a stale completion reaching policy',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final attemptCompleter = Completer<int>();
      final staleError = StateError('stale generation');
      var isCurrent = true;
      var predicateCalls = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.where((attempt) {
            predicateCalls += 1;
            return false;
          }),
        ),
      );
      final future = harness.executor(
        policy,
        guard: () {
          if (!isCurrent) throw staleError;
        },
      ).execute((token) => attemptCompleter.future);

      isCurrent = false;
      attemptCompleter.complete(4);

      await expectLater(future, throwsA(same(staleError)));
      expect(predicateCalls, 0);
    });

    test('stopRetries releases delay and preserves the current outcome',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final error = StateError('current outcome');
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions,
          delay: DelayPolicy.fixed(const Duration(days: 1)),
        ),
      );
      final executor = harness.executor(policy);
      final future = executor.execute((token) {
        attempts += 1;
        throw error;
      });

      await _pump();
      final handle = harness.scheduler.handles.single;
      executor.stopRetries();

      await expectLater(future, throwsA(same(error)));
      expect(handle.isCancelled, isTrue);
      expect(attempts, 1);
    });

    test('one executor cannot accidentally run two logical operations',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      final executor = harness.executor(RetryPolicy.none);

      expect(await executor.execute((token) => 1), 1);
      await expectLater(
        executor.execute((token) => 2),
        throwsStateError,
      );
    });
  });

  group('online gates', () {
    test('online mode pauses before its first attempt', () async {
      final harness = _RetryHarness<int>(initiallyOnline: false);
      addTearDown(harness.dispose);
      final pauses = <bool>[];
      var attempts = 0;
      final future = harness
          .executor(
            RetryPolicy.none,
            onOnlinePauseChanged: pauses.add,
          )
          .execute((token) => ++attempts);

      await _pump();
      expect(attempts, 0);
      expect(pauses, <bool>[true]);

      harness.onlineManager.isOnline = true;

      expect(await future, 1);
      expect(pauses, <bool>[true, false]);
    });

    test('offline-first allows attempt one then gates its retry', () async {
      final harness = _RetryHarness<int>(initiallyOnline: false);
      addTearDown(harness.dispose);
      final pauses = <bool>[];
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final future = harness
          .executor(
        policy,
        networkMode: RetryNetworkMode.offlineFirst,
        onOnlinePauseChanged: pauses.add,
      )
          .execute((token) {
        attempts += 1;
        if (attempts == 1) throw StateError('offline');
        return attempts;
      });

      await _pump();
      expect(attempts, 1);
      expect(pauses, <bool>[true]);

      harness.onlineManager.isOnline = true;

      expect(await future, 2);
      expect(pauses, <bool>[true, false]);
    });

    test('always mode ignores connectivity for retries', () async {
      final harness = _RetryHarness<int>(initiallyOnline: false);
      addTearDown(harness.dispose);
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );

      final result = await harness
          .executor(policy, networkMode: RetryNetworkMode.always)
          .execute((token) {
        attempts += 1;
        if (attempts == 1) throw StateError('offline');
        return attempts;
      });

      expect(result, 2);
    });

    test('retry requires focus and applicable online state at the same time',
        () async {
      final harness = _RetryHarness<int>();
      addTearDown(harness.dispose);
      harness.focusManager.isFocused = false;
      var attempts = 0;
      final policy = RetryPolicy<int>.custom(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final future = harness.executor(policy).execute((token) {
        attempts += 1;
        if (attempts == 1) throw StateError('retry me');
        return attempts;
      });

      await _pump();
      expect(attempts, 1);

      harness.onlineManager.isOnline = false;
      harness.focusManager.isFocused = true;
      await _pump();
      expect(attempts, 1);

      harness.onlineManager.isOnline = true;
      expect(await future, 2);
    });

    test('online wait is immediately cancellable', () async {
      final harness = _RetryHarness<int>(initiallyOnline: false);
      addTearDown(harness.dispose);
      var attempts = 0;
      final future =
          harness.executor(RetryPolicy.none).execute((token) => ++attempts);

      await _pump();
      final expectation =
          expectLater(future, throwsA(isA<QueryCancelledException>()));
      harness.cancellation.cancel('offline cancellation');

      await expectation;
      expect(attempts, 0);
    });
  });
}

enum _ThrowingStage { predicate, onRetry, delay }

final class _RetryHarness<T> {
  _RetryHarness({
    bool initiallyOnline = true,
    Iterable<double> randomValues = const <double>[0.5],
  })  : onlineManager = OnlineManager(initiallyOnline: initiallyOnline),
        random = FakeQueryRandomSource(randomValues) {
    runtime = QueryRuntime(
      clock: clock,
      timers: scheduler,
      random: random,
      notifications: notifications,
    );
    timers = TimerOrchestrator(scheduler);
  }

  final FakeQueryClock clock = FakeQueryClock();
  final FakeQueryTimerScheduler scheduler = FakeQueryTimerScheduler();
  final FakeQueryNotificationScheduler notifications =
      FakeQueryNotificationScheduler();
  final FakeQueryRandomSource random;
  final OnlineManager onlineManager;
  final FocusManager focusManager = FocusManager();
  final QueryCancellationController cancellation =
      QueryCancellationController();
  late final QueryRuntime runtime;
  late final TimerOrchestrator timers;

  RetryExecutor<T> executor(
    RetryPolicy<T> policy, {
    RetryNetworkMode networkMode = RetryNetworkMode.online,
    RetryExecutionGuard? guard,
    bool Function()? canStartRetry,
    RetryAttemptFailureCallback? onAttemptFailure,
    RetryOnlinePauseCallback? onOnlinePauseChanged,
  }) {
    return RetryExecutor<T>(
      policy: policy,
      runtime: runtime,
      timers: timers,
      cancellation: cancellation,
      onlineManager: onlineManager,
      focusManager: focusManager,
      networkMode: networkMode,
      guard: guard,
      canStartRetry: canStartRetry,
      onAttemptFailure: onAttemptFailure,
      onOnlinePauseChanged: onOnlinePauseChanged,
    );
  }

  Duration? get pendingDelay {
    final active = scheduler.handles.where((handle) => !handle.isCancelled);
    if (active.isEmpty) return null;
    return active.last.due - scheduler.now;
  }

  void advance(Duration duration) {
    clock.advance(duration);
    scheduler.elapse(duration);
  }

  void dispose() {
    timers.dispose();
    focusManager.dispose();
    onlineManager.dispose();
  }
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);
