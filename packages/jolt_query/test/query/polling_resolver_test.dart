import 'dart:async';

import 'package:jolt/jolt.dart' show Effect, Signal;
import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('state-derived polling', () {
    test('fixed and resolved intervals are rejected in one configuration', () {
      final source = query(
        QueryKey(const <Object?>['polling-conflict']),
        (_) => 1,
      );

      expect(
        () => source.withObserver(
          pollingInterval: const Duration(seconds: 1),
          pollingIntervalResolver: (_) => const Duration(seconds: 2),
        ),
        throwsArgumentError,
      );
    });

    test('result changes replace the delay and can stop later polling',
        () async {
      final harness = _PollingHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final observer = harness.client.observeQuery(
        query(
          QueryKey(const <Object?>['state-derived-polling']),
          (_) => ++calls,
          retry: RetryPolicy.none,
        ).withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingIntervalResolver: (result) {
                final value = result.data.requireValue();
                return switch (value) {
                  0 => const Duration(seconds: 1),
                  1 => const Duration(seconds: 3),
                  _ => null,
                };
              },
            ),
      );

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(calls, 1);
      expect(observer.data.requireValue(), 1);

      harness.timers.elapse(const Duration(seconds: 2));
      await harness.pump();
      expect(calls, 1);

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(calls, 2);
      expect(observer.data.requireValue(), 2);

      harness.timers.elapse(const Duration(minutes: 1));
      await harness.pump();
      expect(calls, 2);
    });

    test('resolver reads are untracked and do not infer external dynamics',
        () async {
      final harness = _PollingHarness();
      addTearDown(harness.dispose);
      final externalInterval = Signal<Duration?>(null);
      var targetBuilds = 0;
      var calls = 0;
      harness.client.watchQuery(() {
        targetBuilds += 1;
        return query(
          QueryKey(const <Object?>['untracked-polling-resolver']),
          (_) => ++calls,
          retry: RetryPolicy.none,
        ).withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingIntervalResolver: (_) => externalInterval.value,
            );
      });

      expect(targetBuilds, 1);
      externalInterval.value = const Duration(seconds: 1);
      await harness.pump();
      expect(targetBuilds, 1);

      harness.timers.elapse(const Duration(seconds: 10));
      await harness.pump();
      expect(calls, 0);
    });

    test('same-key target update replaces the pending one-shot delay',
        () async {
      final harness = _PollingHarness();
      addTearDown(harness.dispose);
      final intervalSeconds = Signal<int>(5);
      var calls = 0;
      harness.client.watchQuery(() {
        final seconds = intervalSeconds.value;
        return query(
          QueryKey(const <Object?>['retarget-polling-resolver']),
          (_) => ++calls,
          retry: RetryPolicy.none,
        ).withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingIntervalResolver: (_) => Duration(seconds: seconds),
            );
      });

      harness.timers.elapse(const Duration(seconds: 2));
      await harness.pump();
      expect(calls, 0);

      intervalSeconds.value = 1;
      await harness.pump();
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(calls, 1);
    });

    test('resolver key switch cannot run the new plan against the old entry',
        () async {
      final harness = _PollingHarness();
      addTearDown(harness.dispose);
      final selected = Signal<String>('old');
      final calls = <String>[];
      var oldResolverCalls = 0;

      final observer = harness.client.watchQuery(() {
        final id = selected.value;
        return query(
          QueryKey(<Object?>['reentrant-polling-resolver', id]),
          (_) {
            calls.add(id);
            return '$id-fetched';
          },
          retry: RetryPolicy.none,
        ).withInitialData('$id-initial').withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingIntervalResolver: (_) {
                if (id == 'new') return null;
                oldResolverCalls += 1;
                if (oldResolverCalls == 2) selected.value = 'new';
                return const Duration(seconds: 1);
              },
            );
      });

      final oldQuery = query(
        QueryKey(const <Object?>['reentrant-polling-resolver', 'old']),
        (_) => 'unused',
      );
      final newQuery = query(
        QueryKey(const <Object?>['reentrant-polling-resolver', 'new']),
        (_) => 'unused',
      );

      expect(observer.key, oldQuery.key);
      expect(observer.data.requireValue(), 'old-initial');

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(observer.key, newQuery.key);
      expect(observer.data.requireValue(), 'new-fetched');
      expect(calls, <String>['new']);
      expect(
        harness.client.getQueryData(oldQuery).requireValue(),
        'old-initial',
      );
      expect(
        harness.client.getQueryData(newQuery).requireValue(),
        'new-fetched',
      );
    });

    test('resolver polling never overlaps active entry work', () async {
      final harness = _PollingHarness();
      addTearDown(harness.dispose);
      final completions = <Completer<int>>[];
      var calls = 0;
      harness.client.observeQuery(
        query(
          QueryKey(const <Object?>['non-overlapping-polling-resolver']),
          (_) {
            calls += 1;
            final completion = Completer<int>();
            completions.add(completion);
            return completion.future;
          },
          retry: RetryPolicy.none,
        ).withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingIntervalResolver: (_) => const Duration(seconds: 1),
            ),
      );

      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(calls, 1);

      harness.timers.elapse(const Duration(seconds: 10));
      await harness.pump();
      expect(calls, 1);

      completions.single.complete(1);
      await harness.pump();
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();
      expect(calls, 2);
    });

    test('explicit polling disable suppresses a resolver interval', () async {
      final harness = _PollingHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      harness.client.observeQuery(
        query(
          QueryKey(const <Object?>['disabled-polling-resolver']),
          (_) => ++calls,
          retry: RetryPolicy.none,
        ).withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingIntervalResolver: (_) => const Duration(seconds: 1),
              pollingEnabled: false,
            ),
      );

      harness.timers.elapse(const Duration(minutes: 1));
      await harness.pump();
      expect(calls, 0);
    });
  });

  test('observer publishes inherited enabled state and tracks changes',
      () async {
    final harness = _PollingHarness();
    addTearDown(harness.dispose);
    final key = QueryKey(const <Object?>['resolved-enabled']);
    harness.client.registerQueryDefaults(
      const QueryDefaults(enabled: false),
      key: key,
    );
    final source =
        query(key, (_) => 1, retry: RetryPolicy.none).withInitialData(0);
    final inherited = harness.client.observeQuery(source);

    expect(inherited.isEnabled, isFalse);
    expect(inherited.snapshot.isEnabled, isFalse);

    final enabled = Signal<bool>(false);
    final watched = harness.client.watchQuery(
      () => source.withObserver(enabled: enabled.value),
    );
    final states = <bool>[];
    final effect = Effect(() => states.add(watched.isEnabled));
    addTearDown(effect.dispose);

    expect(states, <bool>[false]);
    enabled.value = true;
    await harness.pump();
    expect(states, <bool>[false, true]);
    expect(watched.snapshot.isEnabled, isTrue);
  });
}

final class _PollingHarness {
  _PollingHarness()
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
