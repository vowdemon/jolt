import 'dart:async';

import 'package:jolt/jolt.dart' show Watcher;
import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('mutation observer terminal presentation', () {
    test(
      'success is visible to callbacks and await without queued duplication',
      () async {
        final harness = _MutationObserverHarness();
        addTearDown(harness.dispose);
        final observer = harness.client.observeMutation(
          mutation<int, int, void>(
            mutate: (variables, context) => variables + 1,
          ),
        );
        final transitions = <MutationStatus>[];
        final watcher = Watcher(
          () => observer.value,
          (result, _) => transitions.add(result.status),
        );
        addTearDown(watcher.dispose);
        final callbacks = <String>[];

        expect(observer.isIdle, isTrue);
        final future = observer.execute(
          4,
          onSuccess: (data, variables, result, context) {
            expect(observer.isSuccess, isTrue);
            expect(observer.data.requireValue(), 5);
            callbacks.add('success');
          },
          onSettled: (data, failure, variables, result, context) {
            expect(observer.isSuccess, isTrue);
            expect(data.requireValue(), 5);
            expect(failure, isNull);
            callbacks.add('settled');
          },
        );

        expect(observer.isPending, isTrue);
        expect(await future, 5);
        expect(observer.isSuccess, isTrue);
        expect(observer.data.requireValue(), 5);
        expect(callbacks, <String>['success', 'settled']);
        expect(
          transitions,
          <MutationStatus>[MutationStatus.pending, MutationStatus.success],
        );

        harness.notifications.flushAll();
        harness.notifications.flushAll();

        expect(
          transitions,
          <MutationStatus>[MutationStatus.pending, MutationStatus.success],
        );
      },
    );

    test('error is visible to callbacks and rejected await', () async {
      final harness = _MutationObserverHarness();
      addTearDown(harness.dispose);
      final error = StateError('save failed');
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          mutate: (variables, context) => throw error,
        ),
      );
      final callbacks = <String>[];

      final future = observer.execute(
        4,
        onError: (failure, variables, result, context) {
          expect(observer.isError, isTrue);
          expect(identical(observer.failure?.error, error), isTrue);
          callbacks.add('error');
        },
        onSettled: (data, failure, variables, result, context) {
          expect(observer.isError, isTrue);
          expect(data.isAbsent, isTrue);
          expect(identical(failure?.error, error), isTrue);
          callbacks.add('settled');
        },
      );

      expect(observer.isPending, isTrue);
      await expectLater(future, throwsA(same(error)));
      expect(observer.isError, isTrue);
      expect(identical(observer.failure?.error, error), isTrue);
      expect(callbacks, <String>['error', 'settled']);
    });
  });

  group('mutation observer recipe updates', () {
    test(
      'equal structural key preserves presentation and in-flight recipe',
      () async {
        final harness = _MutationObserverHarness();
        addTearDown(harness.dispose);
        final oldTransport = Completer<int>();
        final lifecycle = <String>[];
        final oldRecipe = mutation<int, int, String>(
          key: MutationKey(<Object?>[
            'save',
            <String, Object?>{'id': 1},
          ]),
          onMutate: (variables, context) {
            lifecycle.add('old.onMutate');
            return 'old:$variables';
          },
          mutate: (variables, context) {
            lifecycle.add('old.mutate');
            return oldTransport.future;
          },
          onSuccess: (data, variables, result, context) {
            lifecycle.add('old.onSuccess:${result.requireValue()}');
          },
        );
        final newRecipe = mutation<int, int, String>(
          key: MutationKey(<Object?>[
            'save',
            <String, Object?>{'id': 1},
          ]),
          onMutate: (variables, context) {
            lifecycle.add('new.onMutate');
            return 'new:$variables';
          },
          mutate: (variables, context) {
            lifecycle.add('new.mutate');
            return variables + 100;
          },
          onSuccess: (data, variables, result, context) {
            lifecycle.add('new.onSuccess:${result.requireValue()}');
          },
        );
        final observer = harness.client.observeMutation(oldRecipe);
        final first = observer.execute(
          1,
          onSuccess: (data, variables, result, context) {
            lifecycle.add('old.perCall:${result.requireValue()}');
          },
        );
        final pendingPresentation = observer.snapshot;

        observer.updateMutation(newRecipe);

        expect(identical(observer.mutation, newRecipe), isTrue);
        expect(identical(observer.snapshot, pendingPresentation), isTrue);
        expect(observer.isPending, isTrue);

        oldTransport.complete(11);
        expect(await first, 11);
        expect(observer.onMutateResult.requireValue(), 'old:1');
        expect(
          lifecycle,
          <String>[
            'old.onMutate',
            'old.mutate',
            'old.onSuccess:old:1',
            'old.perCall:old:1',
          ],
        );

        expect(await observer.execute(2), 102);
        expect(observer.onMutateResult.requireValue(), 'new:2');
        expect(
          lifecycle.skip(4),
          <String>[
            'new.onMutate',
            'new.mutate',
            'new.onSuccess:new:2',
          ],
        );
      },
    );

    test('two absent keys preserve presentation and use the new recipe',
        () async {
      final harness = _MutationObserverHarness();
      addTearDown(harness.dispose);
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          mutate: (variables, context) => variables + 1,
        ),
      );

      expect(await observer.execute(1), 2);
      final successfulPresentation = observer.snapshot;
      observer.updateMutation(
        mutation<int, int, void>(
          mutate: (variables, context) => variables + 10,
        ),
      );

      expect(identical(observer.snapshot, successfulPresentation), isTrue);
      expect(await observer.execute(1), 11);
    });

    test('null-to-present key resets while the old recipe continues', () async {
      final harness = _MutationObserverHarness();
      addTearDown(harness.dispose);
      final oldTransport = Completer<int>();
      final lifecycle = <String>[];
      final perCall = <String>[];
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          mutate: (variables, context) => oldTransport.future,
          onSuccess: (data, variables, result, context) {
            lifecycle.add('old:$data');
          },
        ),
      );
      final nextRecipe = mutation<int, int, void>(
        key: MutationKey(<Object?>['save']),
        mutate: (variables, context) => variables + 20,
        onSuccess: (data, variables, result, context) {
          lifecycle.add('new:$data');
        },
      );
      final oldFuture = observer.execute(
        1,
        onSuccess: (data, variables, result, context) {
          perCall.add('old:$data');
        },
      );

      observer.updateMutation(nextRecipe);

      expect(observer.isIdle, isTrue);
      expect(observer.variables.isAbsent, isTrue);
      expect(observer.data.isAbsent, isTrue);
      expect(observer.onMutateResult.isAbsent, isTrue);

      oldTransport.complete(3);
      expect(await oldFuture, 3);
      expect(lifecycle, <String>['old:3']);
      expect(perCall, isEmpty);
      expect(observer.isIdle, isTrue);

      expect(await observer.execute(2), 22);
      expect(lifecycle, <String>['old:3', 'new:22']);
    });

    test('present-to-null key resets a settled presentation', () async {
      final harness = _MutationObserverHarness();
      addTearDown(harness.dispose);
      final observer = harness.client.observeMutation(
        mutation<int, int, void>(
          key: MutationKey(<Object?>['save']),
          mutate: (variables, context) => variables,
        ),
      );

      expect(await observer.execute(1), 1);
      expect(observer.isSuccess, isTrue);

      observer.updateMutation(
        mutation<int, int, void>(
          mutate: (variables, context) => variables + 1,
        ),
      );

      expect(observer.isIdle, isTrue);
      expect(await observer.execute(1), 2);
    });
  });
}

final class _MutationObserverHarness {
  _MutationObserverHarness()
      : runtime = QueryRuntime(
          clock: FakeQueryClock(),
          timers: FakeQueryTimerScheduler(),
          random: FakeQueryRandomSource(List<double>.filled(16, 0.5)),
          notifications: FakeQueryNotificationScheduler(),
        ) {
    client = QueryClient(runtime: runtime);
  }

  final QueryRuntime runtime;
  late final QueryClient client;

  FakeQueryNotificationScheduler get notifications =>
      runtime.notifications as FakeQueryNotificationScheduler;

  void dispose() {
    if (!client.isDisposed) client.dispose();
  }
}
