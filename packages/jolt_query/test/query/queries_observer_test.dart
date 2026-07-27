import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    show IList;
import 'package:jolt/jolt.dart' show Effect, Readable, Signal;
import 'package:jolt_query/src/foundation/query_runtime.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/client.dart';
import 'package:jolt_query/src/query/filters.dart';
import 'package:jolt_query/src/query/observer_result.dart';
import 'package:jolt_query/src/query/policies.dart';
import 'package:jolt_query/src/query/queries_observer.dart';
import 'package:jolt_query/src/query/recipe.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('fixed heterogeneous queries', () {
    test('preserves order while duplicate keys share one operation', () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final completion = Completer<int>();
      var numberCalls = 0;
      final number = query(
        key: QueryKey(<Object?>['shared-number']),
        fetch: (context) {
          numberCalls += 1;
          return completion.future;
        },
        retry: RetryPolicy.none,
      );
      final text = query(
        key: QueryKey(<Object?>['text']),
        fetch: (context) => 'ready',
        retry: RetryPolicy.none,
      );
      final observer = harness.client.observeQueries(<AnyQueryTarget>[
        number.select((value) => 'number:$value'),
        text,
        number,
      ]);
      _expectStaticType<Readable<IList<ErasedQueryObserverResult>>>(observer);
      _expectStaticType<Disposable>(observer);

      await harness.pump();
      expect(numberCalls, 1);
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == number.key)
            .observerCount,
        2,
      );

      completion.complete(4);
      await harness.pump();
      final results = observer.snapshot;
      expect(results.map((result) => result.key).toList(), <QueryKey>[
        number.key,
        text.key,
        number.key,
      ]);
      expect(results[0].data.requireValue(), 'number:4');
      expect(results[1].data.requireValue(), 'ready');
      expect(results[2].data.requireValue(), 4);
      expect(results.every((result) => result.isSuccess), isTrue);
      expect(results.every((result) => result.isFetched), isTrue);

      observer.dispose();
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == number.key)
            .observerCount,
        0,
      );
    });

    test('placeholder and selector failures remain position-local', () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final missing = query(
        key: QueryKey(<Object?>['missing-shared']),
        fetch: (context) => 1,
        retry: RetryPolicy.none,
      );
      final placeholders = harness.client.observeQueries(<AnyQueryTarget>[
        missing.placeholderData(10).observer(enabled: false),
        missing
            .select((value) => 'value:$value')
            .placeholderData('loading')
            .observer(enabled: false),
      ]);

      expect(placeholders.snapshot[0].data.requireValue(), 10);
      expect(placeholders.snapshot[1].data.requireValue(), 'loading');
      expect(placeholders.snapshot[0].isPlaceholderData, isTrue);
      expect(placeholders.snapshot[1].isPlaceholderData, isTrue);
      expect(harness.client.getQueryData(missing).isAbsent, isTrue);

      final present = query(
        key: QueryKey(<Object?>['selector-shared']),
        fetch: (context) => 2,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(present, 2);
      final selections = harness.client.observeQueries(<AnyQueryTarget>[
        present
            .select<int>((_) => throw StateError('bad selector'))
            .observer(enabled: false),
        present.select((value) => value * 2).observer(enabled: false),
      ]);
      await harness.pump();

      expect(selections.snapshot[0].status, QueryStatus.error);
      expect(selections.snapshot[0].failure?.error, isA<StateError>());
      expect(selections.snapshot[1].data.requireValue(), 4);
      expect(
          harness.client.getQueryState(present)?.status, QueryStatus.success);
    });
  });

  group('reactive target lists', () {
    test('adds removes and reorders stable targets in input order', () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final firstRaw = query(
        key: QueryKey(<Object?>['reactive', 1]),
        fetch: (context) => 1,
        retry: RetryPolicy.none,
      );
      final secondRaw = query(
        key: QueryKey(<Object?>['reactive', 2]),
        fetch: (context) => 2,
        retry: RetryPolicy.none,
      );
      harness.client
        ..setQueryData(firstRaw, 1)
        ..setQueryData(secondRaw, 2);
      final first = firstRaw.observer(enabled: false);
      final second = secondRaw.observer(enabled: false);
      final targets = Signal<List<AnyQueryTarget>>(
        <AnyQueryTarget>[first, second],
      );
      final observer = harness.client.watchQueries(() => targets.value);

      expect(
        observer.snapshot.map((result) => result.data.requireValue()).toList(),
        <Object?>[1, 2],
      );
      targets.value = <AnyQueryTarget>[second, first];
      expect(
        observer.snapshot.map((result) => result.data.requireValue()).toList(),
        <Object?>[2, 1],
      );
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == firstRaw.key)
            .observerCount,
        1,
      );

      targets.value = <AnyQueryTarget>[second];
      await harness.pump();
      expect(observer.snapshot.single.key, secondRaw.key);
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == firstRaw.key)
            .observerCount,
        0,
      );
    });

    test('removed children leave an executable retained plan', () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final raw = query(
        key: QueryKey(<Object?>['retained-plan']),
        fetch: (context) => ++calls,
        retry: RetryPolicy.none,
      );
      final target = raw.observer(enabled: false);
      final targets = Signal<List<AnyQueryTarget>>(
        <AnyQueryTarget>[target],
      );
      harness.client.watchQueries(() => targets.value);
      harness.client.setQueryData(raw, 0);

      targets.value = <AnyQueryTarget>[];
      await harness.pump();
      final snapshot = harness.client.queryCache.snapshots.single;
      expect(snapshot.observerCount, 0);

      final report = await harness.client.refetchQueries(
        filter: QueryFilter(key: raw.key, exact: true),
      );
      await harness.pump();
      expect(report.affected, 1);
      expect(report.skippedNonExecutable, 0);
      expect(calls, 1);
    });

    test(
        'new same-key target instances reuse duplicate observers by occurrence',
        () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final revision = Signal<int>(0);
      var fetchCalls = 0;
      final raw = query(
        key: QueryKey(<Object?>['same-key-occurrences']),
        fetch: (_) => ++fetchCalls,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, 1);

      final observer = harness.client.watchQueries(() {
        final current = revision.value;
        return <AnyQueryTarget>[
          raw.select((value) => 'first-$current:$value').observer(
                staleTime: StalePolicy.duration(const Duration(hours: 1)),
                refetchOnMount:
                    current == 0 ? RefetchPolicy.never : RefetchPolicy.always,
              ),
          raw.select((value) => 'second-$current:$value').observer(
                staleTime: StalePolicy.duration(const Duration(hours: 1)),
                refetchOnMount:
                    current == 0 ? RefetchPolicy.never : RefetchPolicy.always,
              ),
        ];
      });
      await harness.pump();
      expect(fetchCalls, 0);

      revision.value = 1;
      await harness.pump();

      expect(
        observer.snapshot.map((result) => result.data.requireValue()).toList(),
        <Object?>['first-1:1', 'second-1:1'],
      );
      expect(fetchCalls, 0);
      expect(
        harness.client.queryCache.snapshots.single.observerCount,
        2,
      );
    });

    test('same-key list updates preserve each occurrence mount baseline',
        () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final revision = Signal<int>(0);
      final raw = query(
        key: QueryKey(<Object?>['occurrence-mount-baseline']),
        fetch: (_) => 1,
        retry: RetryPolicy.none,
      );
      final observer = harness.client.watchQueries(() {
        final current = revision.value;
        return <AnyQueryTarget>[
          raw.select((value) => 'first-$current:$value').observer(
                enabled: false,
              ),
          raw.select((value) => 'second-$current:$value').observer(
                enabled: false,
              ),
        ];
      });

      harness.client.setQueryData(raw, 1);
      await harness.pump();
      expect(
        observer.snapshot.map((result) => result.isFetchedAfterMount).toList(),
        <bool>[true, true],
      );

      revision.value = 1;

      expect(
        observer.snapshot.map((result) => result.isFetchedAfterMount).toList(),
        <bool>[true, true],
      );
      expect(
        observer.snapshot.map((result) => result.data.requireValue()).toList(),
        <Object?>['first-1:1', 'second-1:1'],
      );
    });
  });

  group('combined queries', () {
    test('reconciles equal combined values and publishes changes atomically',
        () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final first = query(
        key: QueryKey(<Object?>['combined', 1]),
        fetch: (context) => 1,
        retry: RetryPolicy.none,
      );
      final second = query(
        key: QueryKey(<Object?>['combined', 2]),
        fetch: (context) => 2,
        retry: RetryPolicy.none,
      );
      harness.client
        ..setQueryData(first, 1)
        ..setQueryData(second, 2);
      final unrelated = Signal<int>(0);
      var combineCalls = 0;
      final observer = harness.client.observeCombinedQueries<int>(
        <AnyQueryTarget>[
          first.observer(enabled: false),
          second.observer(enabled: false),
        ],
        (results) {
          combineCalls += 1;
          unrelated.value;
          return results.fold<int>(
            0,
            (total, result) => total + (result.data.requireValue() as int),
          );
        },
      );
      var publishedRuns = 0;
      final effect = Effect(() {
        observer.value;
        publishedRuns += 1;
      });
      addTearDown(effect.dispose);

      expect(observer.snapshot, 3);
      expect(publishedRuns, 1);
      unrelated.value = 1;
      expect(combineCalls, 1);
      expect(publishedRuns, 1);
      harness.client
        ..setQueryData(first, 2)
        ..setQueryData(second, 1);
      await harness.pump();

      expect(observer.snapshot, 3);
      expect(combineCalls, 2);
      expect(publishedRuns, 1);

      harness.client.setQueryData(first, 3);
      await harness.pump();
      expect(observer.snapshot, 4);
      expect(publishedRuns, 2);
    });

    test('duplicate focus and reconnect triggers share one active operation',
        () async {
      final harness = _QueriesHarness();
      addTearDown(harness.dispose);
      final completion = Completer<int>();
      var calls = 0;
      final raw = query(
        key: QueryKey(<Object?>['environment-storm']),
        fetch: (context) {
          calls += 1;
          return completion.future;
        },
        retry: RetryPolicy.none,
      );
      final target = raw.initialData(0).observer(
            refetchOnMount: RefetchPolicy.never,
            refetchOnFocus: RefetchPolicy.always,
            refetchOnReconnect: RefetchPolicy.always,
          );
      harness.client.observeQueries(<AnyQueryTarget>[target, target]);

      harness.client.focusManager.isFocused = false;
      harness.client.focusManager.isFocused = true;
      harness.client.onlineManager.isOnline = false;
      harness.client.onlineManager.isOnline = true;
      await harness.pump();

      expect(calls, 1);
      completion.complete(1);
      await harness.pump();
    });
  });
}

T _expectStaticType<T>(T value) => value;

final class _QueriesHarness {
  _QueriesHarness()
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
