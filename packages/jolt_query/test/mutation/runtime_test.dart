import 'dart:async';

import 'package:jolt_query/src/foundation/query_runtime.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/mutation/client_extension.dart';
import 'package:jolt_query/src/mutation/models.dart';
import 'package:jolt_query/src/mutation/recipe.dart';
import 'package:jolt_query/src/query/client.dart';
import 'package:jolt_query/src/query/policies.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('mutation lifecycle', () {
    test('preserves exact success order and one typed nullable result',
        () async {
      final calls = <String>[];
      final harness = _MutationHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onMutate: (variables, context) => calls.add('cache.mutate'),
          onSuccess: (data, variables, result, context) {
            expect(result, const QueryValue<Object?>.present(null));
            calls.add('cache.success');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(data, const QueryValue<Object?>.present(null));
            expect(result, const QueryValue<Object?>.present(null));
            calls.add('cache.settled');
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, String?, String?>(
        onMutate: (variables, context) {
          calls.add('mutation.mutate-stage');
          return null;
        },
        mutate: (variables, context) {
          calls.add('function');
          return null;
        },
        onSuccess: (data, variables, result, context) {
          expect(result, const QueryValue<String?>.present(null));
          calls.add('mutation.success');
        },
        onSettled: (data, failure, variables, result, context) {
          expect(data, const QueryValue<String?>.present(null));
          expect(result, const QueryValue<String?>.present(null));
          calls.add('mutation.settled');
        },
      );
      final observer = harness.client.observeMutation(definition);

      final future = observer.execute(
        1,
        onSuccess: (data, variables, result, context) {
          expect(result, const QueryValue<String?>.present(null));
          calls.add('call.success');
        },
        onSettled: (data, failure, variables, result, context) {
          calls.add('call.settled');
        },
      );
      expect(observer.onMutateResult.isAbsent, isTrue);
      expect(await future, isNull);
      calls.add('future');
      await harness.pump();

      expect(
        calls,
        <String>[
          'cache.mutate',
          'mutation.mutate-stage',
          'function',
          'cache.success',
          'mutation.success',
          'cache.settled',
          'mutation.settled',
          'call.success',
          'call.settled',
          'future',
        ],
      );
      expect(observer.data, const QueryValue<String?>.present(null));
      expect(observer.onMutateResult, const QueryValue<String?>.present(null));
      expect(
        harness.client.mutationCache.snapshots.single.onMutateResult,
        const QueryValue<Object?>.present(null),
      );
    });

    test('omitted onMutate stays absent on every callback surface', () async {
      final cacheResults = <QueryValue<Object?>>[];
      final harness = _MutationHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onMutate: (variables, context) {},
          onSuccess: (data, variables, result, context) {
            cacheResults.add(result);
          },
          onSettled: (data, failure, variables, result, context) {
            cacheResults.add(result);
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, int, String>(
        mutate: (variables, context) => variables + 1,
        onSuccess: (data, variables, result, context) {
          expect(result.isAbsent, isTrue);
        },
        onSettled: (data, failure, variables, result, context) {
          expect(result.isAbsent, isTrue);
        },
      );
      final observer = harness.client.observeMutation(definition);
      final perCall = <QueryValue<String>>[];

      expect(
        await observer.execute(
          1,
          onSuccess: (data, variables, result, context) => perCall.add(result),
          onSettled: (data, failure, variables, result, context) =>
              perCall.add(result),
        ),
        2,
      );
      await harness.pump();

      expect(cacheResults, everyElement(isA<QueryAbsent<Object?>>()));
      expect(perCall, everyElement(isA<QueryAbsent<String>>()));
      expect(observer.onMutateResult.isAbsent, isTrue);
      expect(
        harness.client.mutationCache.snapshots.single.onMutateResult.isAbsent,
        isTrue,
      );
    });

    test('onMutate result is observable while transport is pending', () async {
      final transport = Completer<int>();
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      final beforeQueryEntries = harness.client.queryCache.snapshots;
      final observer = harness.client.observeMutation(
        mutation<int, int, String>(
          onMutate: (variables, context) => 'correlation:$variables',
          mutate: (variables, context) => transport.future,
        ),
      );

      final future = observer.execute(4);
      await harness.pump();

      expect(observer.snapshot.isPending, isTrue);
      expect(
        observer.onMutateResult,
        const QueryValue<String>.present('correlation:4'),
      );
      expect(
        harness.client.mutationCache.snapshots.single.onMutateResult,
        const QueryValue<Object?>.present('correlation:4'),
      );
      expect(harness.client.queryCache.snapshots, beforeQueryEntries);

      transport.complete(8);
      expect(await future, 8);
      expect(harness.client.queryCache.snapshots, beforeQueryEntries);
    });

    test('onMutate failure keeps result absent and skips transport', () async {
      final calls = <String>[];
      final harness = _MutationHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onError: (failure, variables, result, context) {
            expect(result.isAbsent, isTrue);
            calls.add('cache.error');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(result.isAbsent, isTrue);
            calls.add('cache.settled');
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, int, String>(
        onMutate: (variables, context) {
          calls.add('mutation.mutate-stage');
          throw ArgumentError('stop');
        },
        mutate: (variables, context) {
          calls.add('function');
          return variables;
        },
        onError: (failure, variables, result, context) {
          expect(result.isAbsent, isTrue);
          calls.add('mutation.error');
        },
        onSettled: (data, failure, variables, result, context) {
          expect(result.isAbsent, isTrue);
          calls.add('mutation.settled');
        },
      );

      await expectLater(
        harness.client.execute(definition, 1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        calls,
        <String>[
          'mutation.mutate-stage',
          'cache.error',
          'mutation.error',
          'cache.settled',
          'mutation.settled',
        ],
      );
    });

    test('success callback failure runs the error cleanup chain once',
        () async {
      final calls = <String>[];
      final secondary = <Object>[];
      final harness = _MutationHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onSuccess: (data, variables, result, context) {
            calls.add('cache.success');
            throw StateError('primary');
          },
          onError: (failure, variables, result, context) {
            calls.add('cache.error');
            throw StateError('secondary');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(data.isAbsent, isTrue);
            calls.add('cache.settled');
          },
        ),
      );
      addTearDown(harness.dispose);
      final definition = mutation<int, int, void>(
        mutate: (variables, context) => variables,
        onSuccess: (data, variables, result, context) {
          calls.add('mutation.success');
        },
        onError: (failure, variables, result, context) {
          calls.add('mutation.error');
        },
        onSettled: (data, failure, variables, result, context) {
          calls.add('mutation.settled');
        },
      );
      final terminal = Completer<Object>();

      runZonedGuarded<void>(
        () {
          unawaited(
            harness.client.execute(definition, 3).then<void>(
                  (value) => terminal.complete(value),
                  onError: (Object error, StackTrace stackTrace) =>
                      terminal.complete(error),
                ),
          );
        },
        (error, stackTrace) => secondary.add(error),
      );

      expect(
        await terminal.future,
        isA<StateError>()
            .having((error) => error.message, 'message', 'primary'),
      );
      await harness.pump();
      expect(
        calls,
        <String>[
          'cache.success',
          'cache.error',
          'mutation.error',
          'cache.settled',
          'mutation.settled',
        ],
      );
      expect(secondary, hasLength(1));
    });
  });

  group('cache, scopes, retry, and ownership', () {
    test('same scope remains FIFO behind an offline head', () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      harness.client.onlineManager.isOnline = false;
      const scope = MutationScope('writes');
      final calls = <String>[];
      final first = mutation<int, int, void>(
        scope: scope,
        mutate: (variables, context) {
          calls.add('first');
          return variables;
        },
      );
      final second = mutation<int, int, void>(
        scope: scope,
        networkMode: NetworkMode.always,
        mutate: (variables, context) {
          calls.add('second');
          return variables;
        },
      );

      final one = harness.client.execute(first, 1);
      final two = harness.client.execute(second, 2);
      await harness.pump();
      expect(calls, isEmpty);
      expect(
        harness.client.mutationCache.snapshots
            .map((snapshot) => snapshot.pauseReason),
        <PauseReason?>[PauseReason.offline, PauseReason.scope],
      );

      harness.client.onlineManager.isOnline = true;
      await harness.pump();
      expect(await one, 1);
      expect(await two, 2);
      expect(calls, <String>['first', 'second']);
    });

    test('defaults apply retry and retention by key prefix', () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      harness.client.registerMutationDefaults(
        const MutationDefaults(retry: RetryPolicy.standard),
      );
      harness.client.registerMutationDefaults(
        MutationDefaults(
          retention: RetentionPolicy.duration(const Duration(seconds: 2)),
          networkMode: NetworkMode.always,
        ),
        key: MutationKey(<Object?>['account']),
      );
      var attempts = 0;
      final definition = mutation<int, int, void>(
        key: MutationKey(<Object?>['account', 'save']),
        mutate: (variables, context) {
          attempts += 1;
          if (attempts == 1) throw StateError('retry');
          return variables;
        },
      );

      final future = harness.client.execute(definition, 7);
      await harness.pump();
      expect(harness.client.mutationCache.snapshots.single.failureCount, 1);
      expect(harness.client.mutationCache.snapshots.single.isPaused, isFalse);

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(await future, 7);
      expect(attempts, 2);

      harness.timers.elapse(const Duration(seconds: 2));
      expect(harness.client.mutationCache.snapshots, isEmpty);
    });

    test('explicit built-in mutation policies override matching defaults',
        () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      harness.client
        ..registerMutationDefaults(
          MutationDefaults(
            retry: RetryPolicy.standard,
            retention: RetentionPolicy.duration(Duration.zero),
            networkMode: NetworkMode.always,
          ),
          key: MutationKey(<Object?>['explicit-mutation']),
        )
        ..onlineManager.isOnline = false;
      var attempts = 0;
      final definition = mutation<int, int, void>(
        key: MutationKey(<Object?>['explicit-mutation', 'save']),
        retry: RetryPolicy.none,
        retention: RetentionPolicy.standard,
        networkMode: NetworkMode.online,
        mutate: (variables, context) {
          attempts += 1;
          throw StateError('one attempt');
        },
      );
      final pending = harness.client.execute(definition, 1);
      final expectation = expectLater(pending, throwsA(isA<StateError>()));
      await harness.pump();

      expect(attempts, 0);
      expect(
        harness.client.mutationCache.snapshots.single.pauseReason,
        PauseReason.offline,
      );

      harness.client.onlineManager.isOnline = true;
      await expectation;
      await harness.pump();

      expect(attempts, 1);
      harness.timers.elapse(Duration.zero);
      expect(harness.client.mutationCache.snapshots, hasLength(1));
    });

    test('mutation retry continuation waits for focus even in always mode',
        () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      harness.client.focusManager.isFocused = false;
      var attempts = 0;
      final definition = mutation<int, int, void>(
        networkMode: NetworkMode.always,
        retry: RetryPolicy.standard,
        mutate: (variables, context) {
          attempts += 1;
          if (attempts == 1) throw StateError('retry');
          return variables;
        },
      );

      final pending = harness.client.execute(definition, 2);
      await harness.pump();
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(attempts, 1);
      expect(
        harness.client.mutationCache.snapshots.single.pauseReason,
        PauseReason.focus,
      );

      harness.client.focusManager.isFocused = true;
      await harness.pump();

      expect(await pending, 2);
      expect(attempts, 2);
    });

    test('clear permanently detaches records while scope and retry continue',
        () async {
      final lifecycle = <String>[];
      final harness = _MutationHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onSuccess: (data, variables, result, context) {
            lifecycle.add('cache.success:$variables');
          },
        ),
      );
      addTearDown(harness.dispose);
      final cache = harness.client.mutationCache;
      final events = <MutationCacheEvent>[];
      final subscription = cache.events.listen(events.add);
      addTearDown(subscription.cancel);
      const scope = MutationScope('detached');
      var firstAttempts = 0;
      final definition = mutation<int, int, String>(
        scope: scope,
        retry: RetryPolicy.standard,
        onMutate: (variables, context) => 'result:$variables',
        mutate: (variables, context) {
          if (variables == 1 && firstAttempts++ == 0) {
            throw StateError('retry');
          }
          lifecycle.add('function:$variables');
          return variables;
        },
      );
      final observer = harness.client.observeMutation(definition);

      final one = observer.execute(1);
      final two = harness.client.execute(definition, 2);
      await harness.pump();
      expect(harness.client.countMutating(), 2);
      expect(harness.client.mutatingCount.peek, 2);
      final removedIds =
          cache.snapshots.map((snapshot) => snapshot.id).toList();
      final eventBoundary = events.length;

      cache.clear();
      expect(cache.snapshots, isEmpty);
      expect(harness.client.countMutating(), 0);
      await harness.pump();
      expect(harness.client.mutatingCount.peek, 0);
      expect(
        events
            .skip(eventBoundary)
            .where((event) => event.kind == MutationCacheEventKind.removed)
            .map((event) => event.snapshot.id),
        removedIds,
      );

      final postRemovalBoundary = events.length;
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(await one, 1);
      expect(await two, 2);
      await harness.pump();

      expect(observer.data, const QueryValue<int>.present(1));
      expect(cache.snapshots, isEmpty);
      expect(events.skip(postRemovalBoundary), isEmpty);
      expect(
        lifecycle,
        <String>[
          'function:1',
          'cache.success:1',
          'function:2',
          'cache.success:2',
        ],
      );

      expect(
        await harness.client.execute(
          mutation<int, int, void>(
            mutate: (variables, context) => variables + 1,
          ),
          4,
        ),
        5,
      );
      await harness.pump();
      expect(cache.snapshots, hasLength(1));
      expect(cache.snapshots.single.data.requireValue(), 5);
    });

    test('client clear detaches mutation state without cancelling work',
        () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      final completion = Completer<int>();
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          mutate: (variables, context) => completion.future,
        ),
      );

      final future = observer.execute(1);
      await harness.pump();
      harness.client.clear();
      await harness.pump();
      expect(harness.client.mutationCache.snapshots, isEmpty);

      completion.complete(6);
      expect(await future, 6);
      await harness.pump();
      expect(observer.data.requireValue(), 6);
      expect(harness.client.mutationCache.snapshots, isEmpty);
    });

    test('attached observer owns retention until it detaches', () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          retention: RetentionPolicy.duration(Duration.zero),
          mutate: (variables, context) => variables,
        ),
      );

      expect(await observer.execute(1), 1);
      harness.timers.elapse(Duration.zero);
      expect(harness.client.mutationCache.snapshots, hasLength(1));

      observer.dispose();
      harness.timers.elapse(Duration.zero);
      expect(harness.client.mutationCache.snapshots, isEmpty);
    });

    test('only client disposal is terminal for mutation work and events',
        () async {
      final harness = _MutationHarness();
      final transport = Completer<int>();
      final callbacks = <String>[];
      final eventsClosed = Completer<void>();
      final subscription = harness.client.mutationCache.events.listen(
        (_) {},
        onDone: eventsClosed.complete,
      );
      final future = harness.client.execute(
        mutation<int, int, void>(
          mutate: (variables, context) => transport.future,
          onSuccess: (data, variables, result, context) {
            callbacks.add('success');
          },
        ),
        1,
      );
      final failure = expectLater(
        future,
        throwsA(isA<QueryClientDisposedException>()),
      );

      await harness.pump();
      harness.client.dispose();
      await failure;
      await eventsClosed.future;
      transport.complete(1);
      await Future<void>.delayed(Duration.zero);

      expect(callbacks, isEmpty);
      await subscription.cancel();
    });
  });

  group('observer and action facades', () {
    test('latest call owns presentation and per-call callbacks', () async {
      final harness = _MutationHarness();
      addTearDown(harness.dispose);
      final first = Completer<int>();
      final second = Completer<int>();
      final callbacks = <String>[];
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          mutate: (variables, context) =>
              variables == 1 ? first.future : second.future,
        ),
      );

      final one = observer.execute(
        1,
        onSuccess: (data, variables, result, context) => callbacks.add('first'),
      );
      final two = observer.execute(
        2,
        onSuccess: (data, variables, result, context) =>
            callbacks.add('second'),
      );
      first.complete(10);
      expect(await one, 10);
      await harness.pump();
      expect(observer.variables.requireValue(), 2);
      expect(observer.snapshot.isPending, isTrue);
      expect(callbacks, isEmpty);

      second.complete(20);
      expect(await two, 20);
      await harness.pump();
      expect(observer.data.requireValue(), 20);
      expect(callbacks, <String>['second']);
    });

    test('reset detaches callbacks but leaves action lifecycle running',
        () async {
      final globalVariables = <Object?>[];
      final harness = _MutationHarness(
        mutationCallbacks: MutationCacheCallbacks(
          onSuccess: (data, variables, result, context) {
            globalVariables.add(variables);
          },
        ),
      );
      addTearDown(harness.dispose);
      final completion = Completer<int>();
      final lifecycle = <String>[];
      final perCall = <String>[];
      final observer = harness.client.observeMutation(
        action<int, String?>(
          onMutate: (context) => null,
          mutate: (context) => completion.future,
          onSuccess: (data, result, context) {
            expect(result, const QueryValue<String?>.present(null));
            lifecycle.add('success:$data');
          },
        ),
      );

      final future = observer.run(
        onSuccess: (data, result, context) => perCall.add('success'),
      );
      observer.reset();
      completion.complete(7);
      expect(await future, 7);
      await harness.pump();

      expect(observer.snapshot.isIdle, isTrue);
      expect(perCall, isEmpty);
      expect(lifecycle, <String>['success:7']);
      expect(globalVariables, <Object?>[NoVariables.value]);
    });
  });
}

final class _MutationHarness {
  _MutationHarness({
    MutationCacheCallbacks mutationCallbacks = const MutationCacheCallbacks(),
  }) : runtime = QueryRuntime(
          clock: FakeQueryClock(),
          timers: FakeQueryTimerScheduler(),
          random: FakeQueryRandomSource(<double>[0.5, 0.5, 0.5, 0.5]),
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
    for (var index = 0; index < 4; index += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
  }

  void dispose() {
    if (!client.isDisposed) client.dispose();
  }
}
