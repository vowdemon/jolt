import 'dart:async';

import 'package:jolt/jolt.dart' show Effect, Readable, Signal;
import 'package:jolt_query/src/foundation/query_runtime.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/cache_models.dart';
import 'package:jolt_query/src/query/client.dart';
import 'package:jolt_query/src/query/filters.dart';
import 'package:jolt_query/src/query/observer.dart';
import 'package:jolt_query/src/query/observer_result.dart';
import 'package:jolt_query/src/query/policies.dart';
import 'package:jolt_query/src/query/recipe.dart';
import 'package:jolt_query/src/query/state.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('QueryObserver lifecycle', () {
    test('fixed observation fetches and exposes complete snapshots', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final completion = Completer<int>();
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['fixed']),
        (context) {
          calls += 1;
          return completion.future;
        },
        retry: RetryPolicy.none,
      );

      final observer = harness.client.observeQuery(target);
      _expectStaticType<Readable<QueryObserverResult<int>>>(observer);
      _expectStaticType<Disposable>(observer);
      expect(observer.snapshot.status, QueryStatus.pending);
      expect(observer.snapshot.fetchStatus, FetchStatus.fetching);

      await harness.pump();
      expect(calls, 1);
      completion.complete(7);
      await harness.pump();

      expect(observer.data, const QueryValue<int>.present(7));
      expect(observer.isSuccess, isTrue);
      expect(observer.isFetched, isTrue);
      expect(observer.isFetchedAfterMount, isTrue);
      expect(observer.peek, same(observer.snapshot));

      observer
        ..dispose()
        ..dispose();
      expect(observer.isDisposed, isTrue);
      expect(harness.client.queryCache.snapshots.single.observerCount, 0);
    });

    test(
        'Observer is disposed twice and cancels polling before a late timer fire',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var fetchCalls = 0;
      final target = query(
        QueryKey(<Object?>['double-dispose-polling']),
        (context) => ++fetchCalls,
        retry: RetryPolicy.none,
      ).withInitialData(0).withObserver(
            refetchOnMount: RefetchPolicy.never,
            pollingInterval: const Duration(seconds: 1),
          );
      final observer = harness.client.observeQuery(target);
      var publicationRuns = 0;
      final publicationEffect = Effect(() {
        observer.value;
        publicationRuns += 1;
      });
      addTearDown(publicationEffect.dispose);
      await harness.pump();
      final pollingHandle = harness.timers.handles.singleWhere(
        (handle) => !handle.isCancelled,
      );
      final publicationsBeforeDispose = publicationRuns;

      observer
        ..dispose()
        ..dispose();

      expect(observer.isDisposed, isTrue);
      expect(harness.client.queryCache.snapshots.single.observerCount, 0);
      expect(pollingHandle.isCancelled, isTrue);

      pollingHandle.fire(evenIfCancelled: true);
      await harness.pump();

      expect(fetchCalls, 0);
      expect(publicationRuns, publicationsBeforeDispose);
    });

    test('watchQuery switches entries and carries previous view to placeholder',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final selectedKey = Signal<int>(1);
      var selectorCalls = 0;
      final seeded = query(
        QueryKey(<Object?>['watched', 1]),
        (context) => 1,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(seeded, 1);

      final observer = harness.client.watchQuery(() {
        final id = selectedKey.value;
        return query(
          QueryKey(<Object?>['watched', id]),
          (context) => id,
          retry: RetryPolicy.none,
        )
            .select((value) {
              selectorCalls += 1;
              return 'value:$value';
            })
            .withPlaceholder((previous) => previous)
            .withObserver(enabled: false);
      });

      expect(observer.data.requireValue(), 'value:1');
      expect(selectorCalls, 1);
      selectedKey.value = 2;

      expect(observer.key, QueryKey(<Object?>['watched', 2]));
      expect(observer.data.requireValue(), 'value:1');
      expect(observer.isPlaceholderData, isTrue);
      expect(selectorCalls, 1);
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == seeded.key)
            .observerCount,
        0,
      );
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == observer.key)
            .observerCount,
        1,
      );
      expect(
        harness.client.queryCache.snapshots
            .firstWhere((snapshot) => snapshot.key == observer.key)
            .data
            .isAbsent,
        isTrue,
      );
    });

    test('watchQuery key changes fetch once and reuse a fresh cached key',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final page = Signal<int>(1);
      final calls = <int, int>{};

      final observer = harness.client.watchQuery(() {
        final currentPage = page.value;
        return query(
          QueryKey(<Object?>['projects', currentPage]),
          (context) {
            calls.update(currentPage, (count) => count + 1, ifAbsent: () => 1);
            return 'page-$currentPage';
          },
          retry: RetryPolicy.none,
        ).withPlaceholder((previous) => previous).withObserver(
              staleTime: StalePolicy.duration(const Duration(minutes: 1)),
            );
      });

      expect(observer.key, QueryKey(<Object?>['projects', 1]));
      expect(observer.fetchStatus, FetchStatus.fetching);
      await harness.pump();
      expect(observer.data.requireValue(), 'page-1');
      expect(calls, <int, int>{1: 1});

      page.value = 2;
      expect(observer.key, QueryKey(<Object?>['projects', 2]));
      expect(observer.data.requireValue(), 'page-1');
      expect(observer.isPlaceholderData, isTrue);
      expect(observer.fetchStatus, FetchStatus.fetching);
      await harness.pump();
      expect(observer.data.requireValue(), 'page-2');
      expect(observer.isPlaceholderData, isFalse);
      expect(calls, <int, int>{1: 1, 2: 1});

      page.value = 1;
      expect(observer.key, QueryKey(<Object?>['projects', 1]));
      expect(observer.data.requireValue(), 'page-1');
      expect(observer.isPlaceholderData, isFalse);
      expect(observer.fetchStatus, FetchStatus.idle);
      await harness.pump();
      expect(calls, <int, int>{1: 1, 2: 1});
    });

    test(
        'key changes use stale optional fetching instead of mount refetch policy',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final selectedKey = Signal<int>(1);
      final calls = <int, int>{};
      Query<int> recipeFor(int id) => query(
            QueryKey(<Object?>['optional-key-change', id]),
            (_) {
              calls.update(id, (count) => count + 1, ifAbsent: () => 1);
              return id;
            },
            retry: RetryPolicy.none,
          );
      final first = recipeFor(1);
      final fresh = recipeFor(2);
      final stale = recipeFor(3);
      harness.client
        ..setQueryData(first, 1)
        ..setQueryData(fresh, 2)
        ..setQueryData(stale, 3);

      final observer = harness.client.watchQuery(() {
        final id = selectedKey.value;
        return switch (id) {
          1 => first.withObserver(
              staleTime: StalePolicy.duration(const Duration(hours: 1)),
              refetchOnMount: RefetchPolicy.never,
            ),
          2 => fresh.withObserver(
              staleTime: StalePolicy.duration(const Duration(hours: 1)),
              refetchOnMount: RefetchPolicy.always,
            ),
          _ => stale.withObserver(
              staleTime: StalePolicy.immediate,
              refetchOnMount: RefetchPolicy.never,
            ),
        };
      });

      await harness.pump();
      expect(calls, isEmpty);

      selectedKey.value = 2;
      await harness.pump();
      expect(observer.data.requireValue(), 2);
      expect(
        calls,
        isEmpty,
        reason: 'A fresh target does not fetch just because mount says always.',
      );

      selectedKey.value = 3;
      expect(observer.fetchStatus, FetchStatus.fetching);
      await harness.pump();
      expect(calls, <int, int>{3: 1});
      expect(
        observer.data.requireValue(),
        3,
        reason: 'A stale target fetches even when mount says never.',
      );
    });

    test(
        'same-key retarget updates presentation and options without remounting',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final revision = Signal<int>(0);
      var firstPlanCalls = 0;
      var secondPlanCalls = 0;
      final events = <QueryCacheEvent>[];
      final subscription = harness.client.queryCache.events.listen(events.add);
      addTearDown(subscription.cancel);

      final observer = harness.client.watchQuery(() {
        final currentRevision = revision.value;
        return query<int>(
          QueryKey(<Object?>['same-key-retarget']),
          (_) {
            if (currentRevision == 0) {
              firstPlanCalls += 1;
              return 1;
            }
            secondPlanCalls += 1;
            return 2;
          },
          retry: RetryPolicy.none,
        )
            .select(
              (value) =>
                  currentRevision == 0 ? 'first:$value' : 'second:$value',
            )
            .withObserver(
              staleTime: currentRevision == 0
                  ? StalePolicy.duration(const Duration(hours: 1))
                  : StalePolicy.immediate,
              refetchOnMount: currentRevision == 0
                  ? RefetchPolicy.stale
                  : RefetchPolicy.always,
            );
      });

      await harness.pump();
      expect(firstPlanCalls, 1);
      expect(secondPlanCalls, 0);
      expect(observer.data.requireValue(), 'first:1');
      expect(observer.isStale, isFalse);
      expect(observer.isFetchedAfterMount, isTrue);
      events.clear();

      revision.value = 1;

      expect(observer.data.requireValue(), 'second:1');
      expect(observer.isStale, isTrue);
      expect(observer.isFetchedAfterMount, isTrue);
      expect(secondPlanCalls, 0);
      expect(harness.client.queryCache.snapshots.single.observerCount, 1);

      await harness.pump();

      expect(secondPlanCalls, 0);
      expect(
        events.map((event) => event.kind),
        <QueryCacheEventKind>[QueryCacheEventKind.freshnessChanged],
      );

      await observer.refetch();
      await harness.pump();

      expect(secondPlanCalls, 1);
      expect(observer.data.requireValue(), 'second:2');
      expect(observer.isFetchedAfterMount, isTrue);
    });

    test('same-key disabled-to-enabled transition activates a stale query',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final enabled = Signal<bool>(false);
      var calls = 0;
      final raw = query(
        QueryKey(<Object?>['same-key-enable']),
        (_) => ++calls,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, 0);

      final observer = harness.client.watchQuery(
        () => raw.withObserver(
          enabled: enabled.value,
          staleTime: StalePolicy.immediate,
          refetchOnMount: RefetchPolicy.never,
        ),
      );

      await harness.pump();
      expect(calls, 0);
      expect(observer.fetchStatus, FetchStatus.idle);

      enabled.value = true;

      expect(observer.fetchStatus, FetchStatus.fetching);
      await harness.pump();
      expect(calls, 1);
      expect(observer.data.requireValue(), 1);
    });

    test('same-key plan updates preserve an unchanged polling schedule',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final revision = Signal<int>(0);
      final calls = <int>[];

      harness.client.watchQuery(() {
        final currentRevision = revision.value;
        return query(
          QueryKey(<Object?>['same-key-polling']),
          (_) {
            calls.add(currentRevision);
            return currentRevision;
          },
          retry: RetryPolicy.none,
        ).withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingInterval: const Duration(seconds: 5),
            );
      });

      harness.timers.elapse(const Duration(seconds: 4));
      revision.value = 1;
      harness.timers.elapse(const Duration(seconds: 1));
      await harness.pump();

      expect(calls, <int>[1]);
    });

    for (final removal in <String>['removeQueries', 'queryCache.clear']) {
      test('$removal can race a same-key retarget without losing observation',
          () async {
        final harness = _ObserverHarness();
        addTearDown(harness.dispose);
        final revision = Signal<int>(0);
        var secondPlanCalls = 0;
        final observer = harness.client.watchQuery(() {
          final currentRevision = revision.value;
          return query<int>(
            QueryKey(<Object?>['same-key-removal-race']),
            (_) {
              if (currentRevision == 1) secondPlanCalls += 1;
              return currentRevision + 10;
            },
            retry: RetryPolicy.none,
          ).select((value) => '$currentRevision:$value').withObserver(
                enabled: false,
              );
        });
        await harness.pump();

        if (removal == 'removeQueries') {
          expect(harness.client.removeQueries(), 1);
        } else {
          harness.client.queryCache.clear();
        }
        expect(harness.client.queryCache.snapshots, isEmpty);

        revision.value = 1;

        expect(harness.client.queryCache.snapshots.single.observerCount, 1);
        expect(observer.data, const QueryValue<String>.absent());
        await harness.pump();
        expect(harness.client.queryCache.snapshots.single.observerCount, 1);

        final result = await observer.refetch();
        await harness.pump();

        expect(secondPlanCalls, 1);
        expect(result.data.requireValue(), '1:11');
      });
    }
  });

  group('initial and placeholder data', () {
    test(
        'absent placeholder keeps observer and shared cache absent without placeholder state',
        () {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var resolverCalls = 0;
      final raw = query<int>(
        QueryKey(<Object?>['absent-placeholder']),
        (context) => 1,
        retry: RetryPolicy.none,
      );
      final target = raw.withPlaceholder((previous) {
        resolverCalls += 1;
        expect(previous, const QueryValue<int>.absent());
        return const QueryValue<int>.absent();
      }).withObserver(enabled: false);

      final observer = harness.client.observeQuery(target);

      expect(resolverCalls, 1);
      expect(observer.data, const QueryValue<int>.absent());
      expect(observer.isPlaceholderData, isFalse);
      expect(harness.client.getQueryData(raw), const QueryValue<int>.absent());
      expect(
        harness.client.getQueryState(raw)?.data,
        const QueryValue<int>.absent(),
      );
    });

    test('raw present-null initial data is shared before selection', () {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final updatedAt = DateTime.utc(2024, 6, 1);
      var fetchCalls = 0;
      final raw = query<String?>(
        QueryKey(<Object?>['nullable-initial']),
        (context) {
          fetchCalls += 1;
          return 'network';
        },
        retry: RetryPolicy.none,
      );
      final target = raw
          .withInitialData(null, updatedAt: updatedAt)
          .select((value) => value ?? 'selected-null')
          .withObserver(enabled: false);

      final observer = harness.client.observeQuery(target);

      expect(harness.client.getQueryData(raw).isPresent, isTrue);
      expect(harness.client.getQueryData(raw).requireValue(), isNull);
      expect(observer.data.requireValue(), 'selected-null');
      expect(observer.dataUpdatedAt, updatedAt);
      expect(fetchCalls, 0);
    });

    test('first initial writer wins for one structural key', () {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final first = query(
        QueryKey(<Object?>['first-writer']),
        (context) => 'network',
        retry: RetryPolicy.none,
      );
      final second = query(
        QueryKey(<Object?>['first-writer']),
        (context) => 'other',
        retry: RetryPolicy.none,
      );

      harness.client.observeQuery(
        first.withInitialData('first').withObserver(enabled: false),
      );
      harness.client.observeQuery(
        second.withInitialData('second').withObserver(enabled: false),
      );

      expect(harness.client.getQueryData(first).requireValue(), 'first');
      expect(harness.client.getQueryData(second).requireValue(), 'first');
    });

    test('final present-null placeholder bypasses selector and shared cache',
        () {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var selectorCalls = 0;
      final raw = query<int?>(
        QueryKey(<Object?>['nullable-placeholder']),
        (context) => 1,
        retry: RetryPolicy.none,
      );
      final target = raw
          .select<String?>((value) {
            selectorCalls += 1;
            return '$value';
          })
          .withPlaceholderData(null)
          .withObserver(enabled: false);

      final observer = harness.client.observeQuery(target);

      expect(observer.data.isPresent, isTrue);
      expect(observer.data.requireValue(), isNull);
      expect(observer.isPlaceholderData, isTrue);
      expect(observer.isSuccess, isTrue);
      expect(selectorCalls, 0);
      expect(harness.client.getQueryData(raw).isAbsent, isTrue);
    });
  });

  group('selection and fine-grained tracking', () {
    test('selector failure stays local to its observer', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final raw = query(
        QueryKey(<Object?>['selector-failure']),
        (context) => 1,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, 1);
      final failing = harness.client.observeQuery(
        raw.select((value) {
          if (value == 2) throw StateError('bad projection');
          return 'value:$value';
        }).withObserver(enabled: false),
      );
      final healthy = harness.client.observeQuery(
        raw.select((value) => value * 10).withObserver(enabled: false),
      );

      harness.client.setQueryData(raw, 2);
      await harness.pump();

      expect(failing.isError, isTrue);
      expect(failing.failure?.error, isA<StateError>());
      expect(failing.data.requireValue(), 'value:1');
      expect(healthy.data.requireValue(), 20);
      expect(harness.client.getQueryState(raw)?.status, QueryStatus.success);
      expect(harness.client.getQueryData(raw).requireValue(), 2);
    });

    test('selection memo and equality preserve data-only readers', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final firstRaw = _RawValue(1);
      final raw = query(
        QueryKey(<Object?>['selection-memo']),
        (context) => firstRaw,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, firstRaw);
      var selectorCalls = 0;
      final observer = harness.client.observeQuery(
        raw.select((value) {
          selectorCalls += 1;
          return _SelectedValue(value.id);
        }).withObserver(
          enabled: false,
          equality: (previous, next) => previous.id == next.id,
        ),
      );
      final original = observer.data.requireValue();
      var dataRuns = 0;
      final dataEffect = Effect(() {
        observer.data;
        dataRuns += 1;
      });
      addTearDown(dataEffect.dispose);

      harness.client.setQueryData(raw, _RawValue(1));
      await harness.pump();

      expect(selectorCalls, 2);
      expect(observer.data.requireValue(), same(original));
      expect(dataRuns, 1);
    });

    test('fetch-only transitions notify fetch and whole but not data',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final completion = Completer<int>();
      final raw = query(
        QueryKey(<Object?>['field-tracking']),
        (context) => completion.future,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, 1);
      final observer = harness.client.observeQuery(
        raw.withObserver(enabled: false),
      );
      var dataRuns = 0;
      var fetchRuns = 0;
      var wholeRuns = 0;
      final dataEffect = Effect(() {
        observer.data;
        dataRuns += 1;
      });
      final fetchEffect = Effect(() {
        observer.fetchStatus;
        fetchRuns += 1;
      });
      final wholeEffect = Effect(() {
        observer.value;
        wholeRuns += 1;
      });
      addTearDown(dataEffect.dispose);
      addTearDown(fetchEffect.dispose);
      addTearDown(wholeEffect.dispose);

      final refetch = observer.refetch();
      await harness.pump();
      expect(dataRuns, 1);
      expect(fetchRuns, 2);
      expect(wholeRuns, 2);
      expect(observer.isRefetching, isTrue);

      completion.complete(1);
      await refetch;
      await harness.pump();

      expect(dataRuns, 1);
      expect(fetchRuns, 3);
      expect(wholeRuns, 3);
      expect(observer.isSuccess, isTrue);
    });

    test('unchanged refreshes preserve the complete result identity', () {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final raw = query(
        QueryKey(<Object?>['stable-result-identity']),
        (_) => 1,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, 1);
      final observer = harness.client.observeQuery(
        raw.withObserver(
          enabled: false,
          staleTime: StalePolicy.immutable,
        ),
      );
      final original = observer.snapshot;

      harness.client.focusManager.isFocused = false;
      expect(observer.snapshot, same(original));

      harness.client.onlineManager.isOnline = false;
      expect(observer.snapshot, same(original));
    });

    test('manual data writes participate in fetched-after-mount state',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final beforeMount = query(
        QueryKey(<Object?>['manual-before-mount']),
        (_) => 1,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(beforeMount, 1);
      final existingObserver = harness.client.observeQuery(
        beforeMount.withObserver(enabled: false),
      );

      expect(existingObserver.isFetched, isTrue);
      expect(existingObserver.isFetchedAfterMount, isFalse);

      final afterMount = query(
        QueryKey(<Object?>['manual-after-mount']),
        (_) => 1,
        retry: RetryPolicy.none,
      );
      final emptyObserver = harness.client.observeQuery(
        afterMount.withObserver(enabled: false),
      );
      expect(emptyObserver.isFetched, isFalse);
      expect(emptyObserver.isFetchedAfterMount, isFalse);

      harness.client.setQueryData(afterMount, 1);
      await harness.pump();

      expect(emptyObserver.isFetched, isTrue);
      expect(emptyObserver.isFetchedAfterMount, isTrue);
    });
  });

  group('activation and environment policies', () {
    test('disabled observer can still be manually refetched', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['disabled']),
        (context) => ++calls,
        retry: RetryPolicy.none,
      ).withObserver(enabled: false);
      final observer = harness.client.observeQuery(target);

      await harness.pump();
      expect(calls, 0);
      expect(observer.fetchStatus, FetchStatus.idle);

      final result = await observer.refetch();
      await harness.pump();
      expect(calls, 1);
      expect(result.data.requireValue(), 1);
    });

    test('retryOnMount controls remount after an initial failure', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final raw = query<int>(
        QueryKey(<Object?>['retry-on-mount']),
        (context) {
          calls += 1;
          throw StateError('failed');
        },
        retry: RetryPolicy.none,
      );
      final first = harness.client.observeQuery(raw);
      await harness.pump();
      expect(first.isError, isTrue);
      expect(calls, 1);
      first.dispose();

      final disabledRetry = harness.client.observeQuery(
        raw.withObserver(retryOnMount: false),
      );
      await harness.pump();
      expect(disabledRetry.isError, isTrue);
      expect(calls, 1);
      disabledRetry.dispose();

      harness.client.observeQuery(raw.withObserver(retryOnMount: true));
      await harness.pump();
      expect(calls, 2);
    });

    test(
        'Duration-based data is fresh across mount focus and reconnect triggers',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['duration-fresh-environment']),
        (context) => ++calls,
        retry: RetryPolicy.none,
      )
          .withInitialData(
            1,
            updatedAt: harness.clock.wallNow(),
          )
          .withObserver(
            staleTime: StalePolicy.duration(const Duration(hours: 1)),
            refetchOnMount: RefetchPolicy.stale,
            refetchOnFocus: RefetchPolicy.stale,
            refetchOnReconnect: RefetchPolicy.stale,
          );

      final observer = harness.client.observeQuery(target);
      await harness.pump();
      expect(observer.isStale, isFalse);
      expect(calls, 0);

      harness.client.focusManager.isFocused = false;
      harness.client.focusManager.isFocused = true;
      await harness.pump();
      expect(observer.isStale, isFalse);
      expect(calls, 0);

      harness.client.onlineManager.isOnline = false;
      harness.client.onlineManager.isOnline = true;
      await harness.pump();
      expect(observer.isStale, isFalse);
      expect(calls, 0);
    });

    test('disabled resolver remains fresh across environment transitions',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var externallyStale = false;
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['resolver-environment-events']),
        (_) => ++calls,
        retry: RetryPolicy.none,
      ).withInitialData(1).withObserver(
            enabled: false,
            staleTime: StalePolicy.resolve((_) => externallyStale),
          );
      final events = <QueryCacheEvent>[];
      final subscription = harness.client.queryCache.events.listen(events.add);
      addTearDown(subscription.cancel);
      final observer = harness.client.observeQuery(target);
      await harness.pump();
      expect(observer.isStale, isFalse);
      events.clear();

      externallyStale = true;
      harness.client.focusManager.isFocused = false;
      await harness.pump();
      expect(observer.isStale, isFalse);
      expect(events, isEmpty);

      events.clear();
      externallyStale = false;
      harness.client.onlineManager.isOnline = false;
      await harness.pump();
      expect(observer.isStale, isFalse);
      expect(events, isEmpty);
      expect(calls, 0);
    });

    test('duration expiry publishes stale state without fetching', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['duration-expiry']),
        (context) => ++calls,
        retry: RetryPolicy.none,
      ).withInitialData(1, updatedAt: harness.clock.wallNow()).withObserver(
            staleTime: StalePolicy.duration(const Duration(seconds: 5)),
          );
      final cacheEvents = <QueryCacheEvent>[];
      final subscription = harness.client.queryCache.events.listen(
        cacheEvents.add,
      );
      addTearDown(subscription.cancel);
      final observer = harness.client.observeQuery(target);
      final staleStates = <bool>[];
      final effect = Effect(() => staleStates.add(observer.isStale));
      addTearDown(effect.dispose);

      await harness.pump();
      expect(staleStates, <bool>[false]);
      expect(calls, 0);
      cacheEvents.clear();

      harness.clock.advance(const Duration(seconds: 5));
      harness.timers.elapse(const Duration(seconds: 5));
      await harness.pump();

      expect(staleStates, <bool>[false, true]);
      expect(observer.fetchStatus, FetchStatus.idle);
      expect(observer.data.requireValue(), 1);
      expect(calls, 0);
      expect(
        cacheEvents.map((event) => event.kind),
        <QueryCacheEventKind>[QueryCacheEventKind.freshnessChanged],
      );
      expect(cacheEvents.single.snapshot.isStale, isTrue);
    });

    test('disabled observers never make aggregate cache state stale', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final raw = query(
        QueryKey(<Object?>['aggregate-freshness']),
        (_) => 2,
        retry: RetryPolicy.none,
      );
      harness.client.setQueryData(raw, 1);
      await harness.pump();
      final cacheEvents = <QueryCacheEvent>[];
      final subscription = harness.client.queryCache.events.listen(
        cacheEvents.add,
      );
      addTearDown(subscription.cancel);

      final fresh = harness.client.observeQuery(
        raw.withObserver(
          enabled: false,
          staleTime: StalePolicy.duration(const Duration(hours: 1)),
        ),
      );
      await harness.pump();
      cacheEvents.clear();

      final stale = harness.client.observeQuery(
        raw.withObserver(
          enabled: false,
          staleTime: StalePolicy.immediate,
        ),
      );
      await harness.pump();

      final staleSnapshot = harness.client.queryCache.snapshots.single;
      expect(staleSnapshot.observerCount, 2);
      expect(staleSnapshot.activeObserverCount, 0);
      expect(staleSnapshot.isStale, isFalse);
      expect(
          const QueryFilter(freshness: QueryFreshness.stale).matches(
            staleSnapshot,
          ),
          isFalse);
      expect(
        cacheEvents.map((event) => event.kind),
        <QueryCacheEventKind>[QueryCacheEventKind.activityChanged],
      );
      expect(cacheEvents.single.snapshot.observerCount, 2);
      expect(cacheEvents.single.snapshot.activeObserverCount, 0);
      expect(cacheEvents.single.snapshot.isStale, isFalse);

      cacheEvents.clear();
      stale.dispose();
      await harness.pump();

      expect(harness.client.queryCache.snapshots.single.isStale, isFalse);
      expect(
        cacheEvents.map((event) => event.kind),
        <QueryCacheEventKind>[QueryCacheEventKind.activityChanged],
      );
      expect(cacheEvents.single.snapshot.observerCount, 1);
      expect(cacheEvents.single.snapshot.isStale, isFalse);

      cacheEvents.clear();
      fresh.dispose();
      await harness.pump();
      final unobserved = harness.client.queryCache.snapshots.single;
      expect(unobserved.observerCount, 0);
      expect(unobserved.isStale, isFalse);
      expect(
        cacheEvents.map((event) => event.kind),
        <QueryCacheEventKind>[QueryCacheEventKind.activityChanged],
      );
      expect(cacheEvents.single.snapshot.observerCount, 0);
      expect(cacheEvents.single.snapshot.isStale, isFalse);

      cacheEvents.clear();
      final laterStale = harness.client.observeQuery(
        raw.withObserver(
          enabled: false,
          staleTime: StalePolicy.immediate,
        ),
      );
      addTearDown(laterStale.dispose);
      await harness.pump();

      final reobserved = harness.client.queryCache.snapshots.single;
      expect(reobserved.observerCount, 1);
      expect(reobserved.activeObserverCount, 0);
      expect(reobserved.isStale, isFalse);
      expect(laterStale.isStale, isFalse);
      expect(
        cacheEvents.map((event) => event.kind),
        <QueryCacheEventKind>[QueryCacheEventKind.activityChanged],
      );
      expect(cacheEvents.single.snapshot.isStale, isFalse);
    });

    test('focus regain refetches after duration data becomes stale', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['duration-focus-refetch']),
        (context) => 1 + ++calls,
        retry: RetryPolicy.none,
      ).withInitialData(1, updatedAt: harness.clock.wallNow()).withObserver(
            staleTime: StalePolicy.duration(const Duration(seconds: 5)),
            refetchOnMount: RefetchPolicy.never,
            refetchOnFocus: RefetchPolicy.stale,
          );
      final observer = harness.client.observeQuery(target);

      harness.client.focusManager.isFocused = false;
      harness.clock.advance(const Duration(seconds: 5));
      harness.timers.elapse(const Duration(seconds: 5));
      await harness.pump();

      expect(observer.isStale, isTrue);
      expect(observer.data.requireValue(), 1);
      expect(calls, 0);

      harness.client.focusManager.isFocused = true;
      await harness.pump();

      expect(calls, 1);
      expect(observer.data.requireValue(), 2);
      expect(observer.isStale, isFalse);
      expect(observer.fetchStatus, FetchStatus.idle);
    });

    test('freshness, focus, and immutable overrides control auto fetch',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var freshCalls = 0;
      final fresh = query(
        QueryKey(<Object?>['fresh']),
        (context) => ++freshCalls,
        retry: RetryPolicy.none,
      ).withInitialData(1, updatedAt: harness.clock.wallNow()).withObserver(
            staleTime: StalePolicy.duration(const Duration(hours: 1)),
          );
      harness.client.observeQuery(fresh);
      await harness.pump();
      expect(freshCalls, 0);

      var focusCalls = 0;
      final focus = query(
        QueryKey(<Object?>['focus']),
        (context) => ++focusCalls,
        retry: RetryPolicy.none,
      ).withInitialData(1).withObserver(
            refetchOnMount: RefetchPolicy.never,
            refetchOnFocus: RefetchPolicy.always,
          );
      harness.client.observeQuery(focus);
      harness.client.focusManager.isFocused = false;
      harness.client.focusManager.isFocused = true;
      await harness.pump();
      expect(focusCalls, 1);

      var immutableCalls = 0;
      final immutable = query(
        QueryKey(<Object?>['immutable']),
        (context) => ++immutableCalls,
        retry: RetryPolicy.none,
      ).withInitialData(1).withObserver(
            staleTime: StalePolicy.immutable,
            refetchOnMount: RefetchPolicy.always,
            refetchOnFocus: RefetchPolicy.always,
            pollingInterval: const Duration(seconds: 1),
          );
      harness.client.observeQuery(immutable);
      harness.client.focusManager.isFocused = false;
      harness.client.focusManager.isFocused = true;
      harness.timers.elapse(const Duration(seconds: 2));
      await harness.pump();
      expect(immutableCalls, 0);
    });

    test('online pause continues without a duplicate reconnect fetch',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      harness.client.onlineManager.isOnline = false;
      var calls = 0;
      final target = query(
        QueryKey(<Object?>['online-gate']),
        (context) => ++calls,
        retry: RetryPolicy.none,
        networkMode: NetworkMode.online,
      );
      final observer = harness.client.observeQuery(target);

      await harness.pump();
      expect(calls, 0);
      expect(observer.fetchStatus, FetchStatus.paused);
      expect(observer.pauseReason, PauseReason.offline);

      harness.client.onlineManager.isOnline = true;
      await harness.pump();
      expect(calls, 1);
      expect(observer.data.requireValue(), 1);
      expect(observer.isSuccess, isTrue);
    });

    test('offline-first performs its initial attempt while offline', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      harness.client.onlineManager.isOnline = false;
      var calls = 0;
      final observer = harness.client.observeQuery(
        query(
          QueryKey(<Object?>['offline-first']),
          (context) => ++calls,
          retry: RetryPolicy.none,
          networkMode: NetworkMode.offlineFirst,
        ),
      );

      await harness.pump();
      expect(calls, 1);
      expect(observer.fetchStatus, FetchStatus.idle);
      expect(observer.data.requireValue(), 1);
    });

    test('always mode suppresses default reconnect but allows an override',
        () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      var defaultCalls = 0;
      final defaultTarget = query(
        QueryKey(<Object?>['always-default']),
        (context) => ++defaultCalls,
        retry: RetryPolicy.none,
        networkMode: NetworkMode.always,
      ).withInitialData(1).withObserver(refetchOnMount: RefetchPolicy.never);
      harness.client.observeQuery(defaultTarget);

      var overrideCalls = 0;
      final overrideTarget = query(
        QueryKey(<Object?>['always-override']),
        (context) => ++overrideCalls,
        retry: RetryPolicy.none,
        networkMode: NetworkMode.always,
      ).withInitialData(1).withObserver(
            refetchOnMount: RefetchPolicy.never,
            refetchOnReconnect: RefetchPolicy.always,
          );
      harness.client.observeQuery(overrideTarget);

      harness.client.onlineManager.isOnline = false;
      harness.client.onlineManager.isOnline = true;
      await harness.pump();

      expect(defaultCalls, 0);
      expect(overrideCalls, 1);
    });
  });

  group('polling', () {
    test('multiple pollers deduplicate and never overlap entry work', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final completions = <Completer<int>>[];
      var calls = 0;
      final raw = query(
        QueryKey(<Object?>['poll']),
        (context) {
          calls += 1;
          final completion = Completer<int>();
          completions.add(completion);
          return completion.future;
        },
        retry: RetryPolicy.none,
      );
      final fiveSecondTarget = raw.withInitialData(0).withObserver(
            refetchOnMount: RefetchPolicy.never,
            pollingInterval: const Duration(seconds: 5),
          );
      final sevenSecondTarget = raw.withInitialData(0).withObserver(
            refetchOnMount: RefetchPolicy.never,
            pollingInterval: const Duration(seconds: 7),
          );
      harness.client.observeQuery(fiveSecondTarget);
      harness.client.observeQuery(sevenSecondTarget);

      harness.timers.elapse(const Duration(seconds: 5));
      await harness.pump();
      expect(calls, 1);

      harness.timers.elapse(const Duration(seconds: 10));
      await harness.pump();
      expect(calls, 1);

      completions.single.complete(1);
      await harness.pump();
      harness.timers.elapse(const Duration(seconds: 5));
      await harness.pump();
      expect(calls, 2);
    });

    test('reactive polling intervals replace timers and honor focus', () async {
      final harness = _ObserverHarness();
      addTearDown(harness.dispose);
      final interval = Signal<Duration?>(null);
      var calls = 0;
      final raw = query(
        QueryKey(<Object?>['dynamic-poll']),
        (context) => ++calls,
        retry: RetryPolicy.none,
      );
      harness.client.watchQuery(
        () => raw.withInitialData(0).withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingInterval: interval.value,
            ),
      );

      harness.timers.elapse(const Duration(seconds: 10));
      expect(calls, 0);
      interval.value = const Duration(seconds: 2);
      harness.client.focusManager.isFocused = false;
      harness.timers.elapse(const Duration(seconds: 2));
      await harness.pump();
      expect(calls, 0);

      harness.client.focusManager.isFocused = true;
      harness.timers.elapse(const Duration(seconds: 2));
      await harness.pump();
      expect(calls, 1);
    });
  });
}

T _expectStaticType<T>(T value) => value;

final class _ObserverHarness {
  _ObserverHarness()
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

  FakeQueryClock get clock => runtime.clock as FakeQueryClock;
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

final class _RawValue {
  const _RawValue(this.id);

  final int id;
}

final class _SelectedValue {
  const _SelectedValue(this.id);

  final int id;
}
