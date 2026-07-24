import 'dart:async';

import 'package:jolt/jolt.dart' show Effect, Readable, Signal;
import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  group('typed infinite client operations', () {
    test('raw infinite recipe carries all inherited exact cache operations',
        () {
      final source = infiniteQuery<String, int>(
        QueryKey(<Object?>['infinite-exact-cache']),
        (context) => 'page-${context.pageParam}',
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final QueryDataTarget<InfiniteData<String, int>> carrier = source;
      final client = QueryClient();
      final initial = InfiniteData<String, int>(
        pages: <String>['old'],
        pageParams: <int>[0],
      );

      final absent = client.snapshotQueryData(carrier);
      expect(client.getQueryData(source).isAbsent, isTrue);
      final written = client.setQueryData(source, initial);
      expect(written.data.requireValue(), initial);
      expect(client.getQueryData(source).requireValue(), initial);
      expect(client.getQueryState(source)!.data.requireValue(), initial);

      final updated = client.updateQueryData(source, (previous) {
        final current = previous.requireValue();
        return InfiniteData<String, int>(
          pages: <String>[...current.pages, 'new'],
          pageParams: <int>[...current.pageParams, 1],
        );
      });
      expect(updated.data.requireValue().pages, <String>['old', 'new']);

      expect(
        client.restoreQueryData(
          source,
          absent,
          ifRevision: updated.revision,
        ),
        isTrue,
      );
      final restored = client.getQueryState(source)!;
      expect(restored.data.isAbsent, isTrue);
      expect(restored.status, QueryStatus.pending);
      expect(restored.fetchStatus, FetchStatus.idle);
      client.dispose();
    });

    test('page context exposes the client that actually executes the query',
        () async {
      final configuredClient = QueryClient();
      final executingClient = QueryClient();
      QueryClient? seenClient;
      final source = infiniteQuery(
        QueryKey(<Object?>['executing-client']),
        (context) {
          seenClient = context.client;
          return context.pageParam;
        },
        client: configuredClient,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );

      final data = await executingClient.fetchInfiniteQuery(source);

      expect(seenClient, same(executingClient));
      expect(data.pages, <int>[0]);
      expect(configuredClient.getQueryData(source).isAbsent, isTrue);
      expect(executingClient.getQueryData(source).isPresent, isTrue);
      configuredClient.dispose();
      executingClient.dispose();
    });

    test('prefetch fetches the requested reachable pages in one aligned value',
        () async {
      final seen = <int>[];
      final source = infiniteQuery(
        QueryKey(<Object?>['prefetch']),
        (context) {
          seen.add(context.pageParam);
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => data.pageParams.last < 2
            ? PageCursor.more(data.pageParams.last + 1)
            : PageCursor.end,
      );
      final client = QueryClient();

      await client.prefetchInfiniteQuery(source, pages: 5);

      final data =
          client.getQueryData(source.ordinaryQueryInternal).requireValue();
      expect(seen, <int>[0, 1, 2]);
      expect(data.pages, <String>['page-0', 'page-1', 'page-2']);
      expect(data.pageParams, <int>[0, 1, 2]);
      client.dispose();
    });

    test('prefetch without a page count requests only the initial page',
        () async {
      final seen = <int>[];
      final source = infiniteQuery(
        QueryKey(<Object?>['prefetch-default']),
        (context) {
          seen.add(context.pageParam);
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => const PageCursor<int>.more(1),
      );
      final client = QueryClient();

      final Future<void> pending = client.prefetchInfiniteQuery(source);
      await pending;

      expect(seen, <int>[0]);
      expect(
        client.getQueryData(source.ordinaryQueryInternal).requireValue().pages,
        <String>['page-0'],
      );
      client.dispose();
    });

    test('fetch accepts a requested reachable page count', () async {
      final seen = <int>[];
      final source = infiniteQuery(
        QueryKey(<Object?>['fetch-pages']),
        (context) {
          seen.add(context.pageParam);
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => data.pageParams.last < 2
            ? PageCursor.more(data.pageParams.last + 1)
            : PageCursor.end,
      );
      final client = QueryClient();

      final data = await client.fetchInfiniteQuery(source, pages: 5);

      expect(seen, <int>[0, 1, 2]);
      expect(data.pages, <String>['page-0', 'page-1', 'page-2']);
      expect(data.pageParams, <int>[0, 1, 2]);
      client.dispose();
    });

    test('fetch joins an active retained-data refresh by default', () async {
      final refresh = Completer<int>();
      var calls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['fetch-join']),
        (context) {
          calls += 1;
          return calls == 1 ? 0 : refresh.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);

      final first = client.fetchInfiniteQuery(source);
      await Future<void>.delayed(Duration.zero);
      final second = client.fetchInfiniteQuery(source);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
      refresh.complete(1);
      expect((await first).pages, <int>[1]);
      expect((await second).pages, <int>[1]);
      expect(calls, 2);
      client.dispose();
    });

    test('nullable page parameters remain continuation values', () async {
      final seen = <int?>[];
      final source = infiniteQuery<String, int?>(
        QueryKey(<Object?>['nullable-prefetch']),
        (context) {
          seen.add(context.pageParam);
          return '${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) => data.length == 1
            ? const PageCursor<int?>.more(null)
            : PageCursor.end,
      );
      final client = QueryClient();

      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      expect(observer.hasNextPage, isTrue);
      final result = await observer.fetchNextPage();

      expect(seen, <int?>[1, null]);
      expect(result.data.requireValue().pageParams, <int?>[1, null]);
      expect(result.hasNextPage, isFalse);
      observer.dispose();
      client.dispose();
    });

    test('invalid requested page counts fail before invoking a page', () async {
      var calls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['invalid-prefetch']),
        (context) {
          calls += 1;
          return context.pageParam;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();

      await expectLater(
        client.prefetchInfiniteQuery(source, pages: 0),
        throwsArgumentError,
      );
      await expectLater(
        client.fetchInfiniteQuery(source, pages: 0),
        throwsArgumentError,
      );

      expect(calls, 0);
      expect(client.queryCache.snapshots, isEmpty);
      client.dispose();
    });

    test('ensure returns stale data immediately and refreshes in background',
        () async {
      final refresh = Completer<String>();
      var calls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['ensure']),
        (context) {
          calls += 1;
          return calls == 1 ? 'old' : refresh.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);

      final ensured = await client.ensureInfiniteQueryData(
        source,
        revalidateIfStale: true,
      );

      expect(ensured.pages.single, 'old');
      expect(calls, 2);
      expect(
        client.getQueryData(source.ordinaryQueryInternal).requireValue().pages,
        <String>['old'],
      );
      refresh.complete('new');
      await Future<void>.delayed(Duration.zero);
      expect(
        client.getQueryData(source.ordinaryQueryInternal).requireValue().pages,
        <String>['new'],
      );
      client.dispose();
    });

    test('whole-data reconciliation preserves an equal cached instance',
        () async {
      final source = infiniteQuery(
        QueryKey(<Object?>['sharing']),
        (context) => 'same',
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();

      final first = await client.fetchInfiniteQuery(source);
      final second = await client.fetchInfiniteQuery(source);

      expect(second, same(first));
      expect(
        client.getQueryData(source.ordinaryQueryInternal).requireValue(),
        same(first),
      );
      client.dispose();
    });

    test('whole-data reconciliation shares unchanged JSON-compatible pages',
        () async {
      var refreshing = false;
      final source = infiniteQuery<Map<String, Object?>, int>(
        QueryKey(<Object?>['page-sharing']),
        (context) => <String, Object?>{
          'id': context.pageParam,
          'value': refreshing && context.pageParam == 1 ? 'changed' : 'same',
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 2);
      final previous =
          client.getQueryData(source.ordinaryQueryInternal).requireValue();
      refreshing = true;

      final next = await client.fetchInfiniteQuery(source);

      expect(next, isNot(same(previous)));
      expect(next.pages.first, same(previous.pages.first));
      expect(next.pages.last, isNot(same(previous.pages.last)));
      client.dispose();
    });
  });

  group('selected infinite observer directions', () {
    test('mounting an absent recipe automatically fetches its initial page',
        () async {
      final source = infiniteQuery(
        QueryKey(<Object?>['mount-initial']),
        (context) => 'page-${context.pageParam}',
        initialPageParam: 7,
        getNextPageParam: (data) => PageCursor.end,
        retry: RetryPolicy.none,
      );
      final client = QueryClient();

      final observer = client.observeInfiniteQuery(source);
      expect(observer.isLoading, isTrue);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(observer.isSuccess, isTrue);
      expect(observer.data.requireValue().pages, <String>['page-7']);
      expect(observer.data.requireValue().pageParams, <int>[7]);
      observer.dispose();
      client.dispose();
    });

    test('the original recipe is directly observable with raw data typing',
        () async {
      final source = infiniteQuery(
        QueryKey(<Object?>['direct-observe']),
        (context) => context.pageParam,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);

      final observer = client.observeInfiniteQuery(source);

      _expectStaticType<InfiniteQueryObserver<InfiniteData<int, int>>>(
          observer);
      expect(observer.data.requireValue().pages, <int>[0]);
      observer.dispose();
      client.dispose();
    });

    test('watchInfiniteQuery reactively switches specialized targets',
        () async {
      InfiniteQuery<int, int> make(String name, int value) => infiniteQuery(
            QueryKey(<Object?>['watched', name]),
            (context) => value,
            initialPageParam: 0,
            getNextPageParam: (data) => PageCursor.end,
            staleTime: StalePolicy.untilInvalidated,
          );
      final first = make('first', 1);
      final second = make('second', 2);
      final client = QueryClient();
      await client.fetchInfiniteQuery(first);
      await client.fetchInfiniteQuery(second);
      final selected = Signal<int>(0);
      final observer = client.watchInfiniteQuery(
        () =>
            (selected.value == 0 ? first : second).withObserver(enabled: false),
      );
      expect(observer.data.requireValue().pages, <int>[1]);

      selected.value = 1;

      expect(observer.data.requireValue().pages, <int>[2]);
      observer.dispose();
      selected.dispose();
      client.dispose();
    });

    test('infinite key switch fetches stale cache despite mount policy',
        () async {
      final calls = <int, int>{};
      InfiniteQuery<int, int> make(int id) => infiniteQuery(
            QueryKey(<Object?>['watched-stale-switch', id]),
            (context) {
              calls.update(id, (value) => value + 1, ifAbsent: () => 1);
              return id * 10;
            },
            initialPageParam: 0,
            getNextPageParam: (data) => PageCursor.end,
            staleTime: StalePolicy.immediate,
          );
      final first = make(1);
      final second = make(2);
      final client = QueryClient();
      client
        ..setQueryData(
          first,
          InfiniteData<int, int>(
            pages: <int>[1],
            pageParams: <int>[0],
          ),
        )
        ..setQueryData(
          second,
          InfiniteData<int, int>(
            pages: <int>[2],
            pageParams: <int>[0],
          ),
        );
      final selected = Signal<int>(1);
      final observer = client.watchInfiniteQuery(
        () => (selected.value == 1 ? first : second).withObserver(
          refetchOnMount: RefetchPolicy.never,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);

      selected.value = 2;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls[2], 1);
      expect(observer.data.requireValue().pages, <int>[20]);
      observer.dispose();
      selected.dispose();
      client.dispose();
    });

    test('infinite key switch reuses fresh cache despite always mount policy',
        () async {
      final calls = <int, int>{};
      InfiniteQuery<int, int> make(int id) => infiniteQuery(
            QueryKey(<Object?>['watched-fresh-switch', id]),
            (context) {
              calls.update(id, (value) => value + 1, ifAbsent: () => 1);
              return id * 10;
            },
            initialPageParam: 0,
            getNextPageParam: (data) => PageCursor.end,
            staleTime: StalePolicy.untilInvalidated,
          );
      final first = make(1);
      final second = make(2);
      final client = QueryClient();
      client
        ..setQueryData(
          first,
          InfiniteData<int, int>(
            pages: <int>[1],
            pageParams: <int>[0],
          ),
        )
        ..setQueryData(
          second,
          InfiniteData<int, int>(
            pages: <int>[2],
            pageParams: <int>[0],
          ),
        );
      final selected = Signal<int>(1);
      final observer = client.watchInfiniteQuery(
        () => (selected.value == 1 ? first : second).withObserver(
          refetchOnMount: RefetchPolicy.always,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(calls[1], 1);

      selected.value = 2;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls[2], isNull);
      expect(observer.data.requireValue().pages, <int>[2]);
      observer.dispose();
      selected.dispose();
      client.dispose();
    });

    test('infinite key switch preserves previous presentation as placeholder',
        () async {
      final pending = Completer<int>();
      final first = infiniteQuery<int, int>(
        QueryKey(<Object?>['watched-placeholder', 1]),
        (context) => 1,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final second = infiniteQuery<int, int>(
        QueryKey(<Object?>['watched-placeholder', 2]),
        (context) => pending.future,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();
      client.setQueryData(
        first,
        InfiniteData<int, int>(
          pages: <int>[1],
          pageParams: <int>[0],
        ),
      );
      final selected = Signal<int>(1);
      final observer = client.watchInfiniteQuery(
        () => selected.value == 1
            ? first.withObserver(enabled: false)
            : second.withPlaceholder((previous) => previous),
      );
      expect(observer.data.requireValue().pages, <int>[1]);

      selected.value = 2;
      await Future<void>.delayed(Duration.zero);

      expect(observer.data.requireValue().pages, <int>[1]);
      expect(observer.isPlaceholderData, isTrue);
      expect(observer.isFetchedAfterMount, isFalse);
      expect(observer.fetchStatus, FetchStatus.fetching);

      pending.complete(2);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(observer.data.requireValue().pages, <int>[2]);
      expect(observer.isPlaceholderData, isFalse);
      expect(observer.isFetchedAfterMount, isTrue);
      observer.dispose();
      selected.dispose();
      client.dispose();
    });

    test('same-key target updates configuration without mounting again',
        () async {
      var firstCalls = 0;
      var secondCalls = 0;
      final key = QueryKey(<Object?>['watched-same-key']);
      final first = infiniteQuery(
        key,
        (context) {
          firstCalls += 1;
          return 1;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final second = infiniteQuery(
        key,
        (context) {
          secondCalls += 1;
          return 2;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(first);
      final useSecond = Signal<bool>(false);
      final observer = client.watchInfiniteQuery(
        () => (useSecond.value ? second : first).withObserver(
          enabled: true,
          staleTime: StalePolicy.immediate,
          refetchOnMount:
              useSecond.value ? RefetchPolicy.always : RefetchPolicy.never,
        ),
      );
      expect(observer.data.requireValue().pages, <int>[1]);
      final beforeRetarget = observer.snapshot;
      var resultEffectRuns = 0;
      final resultEffect = Effect(() {
        observer.value;
        resultEffectRuns += 1;
      });

      useSecond.value = true;

      expect(secondCalls, 0);
      expect(observer.data.requireValue().pages, <int>[1]);
      expect(observer.snapshot, same(beforeRetarget));
      expect(resultEffectRuns, 1);
      final refreshed = await observer.refetch();
      expect(secondCalls, 1);
      expect(refreshed.data.requireValue().pages, <int>[2]);
      expect(firstCalls, 1);
      resultEffect.dispose();
      observer.dispose();
      useSecond.dispose();
      client.dispose();
    });

    test('same-key disabled-to-enabled immutable query still loads absence',
        () async {
      var calls = 0;
      final enabled = Signal<bool>(false);
      final source = infiniteQuery<int, int>(
        QueryKey(<Object?>['infinite-enable-immutable-absence']),
        (context) {
          calls += 1;
          return context.pageParam;
        },
        initialPageParam: 7,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();
      final observer = client.watchInfiniteQuery(
        () => source.withObserver(
          enabled: enabled.value,
          staleTime: StalePolicy.immutable,
        ),
      );

      expect(calls, 0);
      expect(observer.data.isAbsent, isTrue);

      enabled.value = true;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(observer.data.requireValue().pages, <int>[7]);
      observer.dispose();
      enabled.dispose();
      client.dispose();
    });

    test('next fetch keeps selected data visible and returns selected result',
        () async {
      final next = Completer<String>();
      final source = infiniteQuery(
        QueryKey(<Object?>['selected-next']),
        (context) => context.pageParam == 0 ? 'zero' : next.future,
        initialPageParam: 0,
        getNextPageParam: (data) => data.pageParams.last == 0
            ? const PageCursor<int>.more(1)
            : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final target = source
          .select((data) => data.pages.join('|'))
          .withObserver(enabled: false);
      final observer = client.observeInfiniteQuery(target);

      _expectStaticType<InfiniteQueryObserver<String>>(observer);
      _expectStaticType<Readable<InfiniteQueryObserverResult<String>>>(
          observer);
      expect(observer.data.requireValue(), 'zero');
      expect(observer.hasNextPage, isTrue);

      final pending = observer.fetchNextPage();
      expect(observer.isFetchingNextPage, isTrue);
      expect(observer.data.requireValue(), 'zero');
      next.complete('one');
      final result = await pending;

      _expectStaticType<InfiniteQueryObserverResult<String>>(result);
      expect(result.data.requireValue(), 'zero|one');
      expect(result.isFetchingNextPage, isFalse);
      expect(result.hasNextPage, isFalse);
      observer.dispose();
      client.dispose();
    });

    test('no-cursor direction is an exact current-result cache no-op',
        () async {
      final source = infiniteQuery(
        QueryKey(<Object?>['end']),
        (context) => context.pageParam,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      final before = observer.peek;
      final revision =
          client.getQueryState(source.ordinaryQueryInternal)!.revision;

      final result = await observer.fetchNextPage();

      expect(result, same(before));
      expect(
        client.getQueryState(source.ordinaryQueryInternal)!.revision,
        revision,
      );
      observer.dispose();
      client.dispose();
    });

    test('bounded forward-only query omits reverse resolver as a no-op',
        () async {
      var calls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['bounded-forward-only']),
        (context) {
          calls += 1;
          return context.pageParam;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => const PageCursor<int>.more(1),
        maxPages: 2,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      final before = client.getQueryState(source.ordinaryQueryInternal)!;

      final result = await observer.fetchPreviousPage();

      expect(result.hasPreviousPage, isFalse);
      expect(result.data.requireValue().pages, <int>[0]);
      expect(calls, 1);
      expect(
        client.getQueryState(source.ordinaryQueryInternal)!.revision,
        before.revision,
      );
      observer.dispose();
      client.dispose();
    });

    test('previous failure retains data and uses the canonical failure',
        () async {
      final error = StateError('previous failed');
      final source = infiniteQuery(
        QueryKey(<Object?>['previous-error']),
        (context) {
          if (context.direction == InfiniteDirection.backward) throw error;
          return 'page-${context.pageParam}';
        },
        initialPageParam: 1,
        getNextPageParam: (data) => PageCursor.end,
        getPreviousPageParam: (data) => const PageCursor<int>.more(0),
        retry: RetryPolicy.none,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.select((data) => data.pages.single).withObserver(enabled: false),
      );

      final result = await observer.fetchPreviousPage();

      expect(result.data.requireValue(), 'page-1');
      expect(result.isFetchPreviousPageError, isTrue);
      expect(result.isFetchNextPageError, isFalse);
      expect(result.failure?.error, same(error));
      observer.dispose();
      client.dispose();
    });

    test('a disabled observer explicit refetch still performs retry', () async {
      var refreshing = false;
      var refreshAttempts = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['disabled-explicit-retry']),
        (context) {
          if (refreshing && refreshAttempts++ == 0) {
            throw StateError('refresh failed once');
          }
          return refreshing ? 'new' : 'old';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      refreshing = true;

      final result = await observer.refetch();

      expect(refreshAttempts, 2);
      expect(result.data.requireValue().pages, <String>['new']);
      expect(result.failure, isNull);
      observer.dispose();
      client.dispose();
    });

    test('default replacement ignores late completion from the old direction',
        () async {
      final calls = <Completer<int>>[];
      final source = infiniteQuery(
        QueryKey(<Object?>['replace-next']),
        (context) {
          if (context.pageParam == 0) return 0;
          final completer = Completer<int>();
          calls.add(completer);
          return completer.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      final replaced = observer.fetchNextPage();
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(1));
      final winner = observer.fetchNextPage();
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(2));
      calls[1].complete(20);
      final result = await winner;
      await replaced;
      calls[0].complete(10);
      await Future<void>.delayed(Duration.zero);

      expect(result.data.requireValue().pages, <int>[0, 20]);
      expect(observer.data.requireValue().pages, <int>[0, 20]);
      observer.dispose();
      client.dispose();
    });

    test('cancelRefetch false joins without appending a duplicate page',
        () async {
      final next = Completer<int>();
      var nextCalls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['join-next']),
        (context) {
          if (context.pageParam == 0) return 0;
          nextCalls += 1;
          return next.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      final first = observer.fetchNextPage(cancelRefetch: false);
      final second = observer.fetchNextPage(cancelRefetch: false);
      await Future<void>.delayed(Duration.zero);
      expect(nextCalls, 1);
      next.complete(1);

      expect((await first).data.requireValue().pages, <int>[0, 1]);
      expect((await second).data.requireValue().pages, <int>[0, 1]);
      expect(nextCalls, 1);
      observer.dispose();
      client.dispose();
    });

    test(
        'imperative infinite fetch joining mount work survives final detachment',
        () async {
      final firstPage = Completer<int>();
      final source = infiniteQuery<int, int>(
        QueryKey(<Object?>['join-infinite-mount']),
        (context) {
          context.queryContext.cancellationToken.isCancelled;
          return firstPage.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      final client = QueryClient();
      final observer = client.observeInfiniteQuery(source);
      await Future<void>.delayed(Duration.zero);

      final joined = client.fetchInfiniteQuery(source);
      observer.dispose();
      firstPage.complete(3);

      expect((await joined).pages, <int>[3]);
      expect(client.getQueryData(source).requireValue().pages, <int>[3]);
      client.dispose();
    });

    test('full refresh replaces direction work in the same operation lane',
        () async {
      final lateDirection = Completer<int>();
      var initialCalls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['refresh-overlap']),
        (context) {
          if (context.pageParam == 1) return lateDirection.future;
          initialCalls += 1;
          return initialCalls == 1 ? 0 : 100;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      final direction = observer.fetchNextPage();
      await Future<void>.delayed(Duration.zero);
      final refreshed = await observer.refetch();
      await direction;
      lateDirection.complete(1);
      await Future<void>.delayed(Duration.zero);

      expect(refreshed.data.requireValue().pages, <int>[100]);
      expect(observer.data.requireValue().pages, <int>[100]);
      observer.dispose();
      client.dispose();
    });

    test('full refresh with cancelRefetch false joins active direction work',
        () async {
      final next = Completer<int>();
      var initialCalls = 0;
      var nextCalls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['refresh-join-overlap']),
        (context) {
          if (context.pageParam == 1) {
            nextCalls += 1;
            return next.future;
          }
          initialCalls += 1;
          return 0;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      final direction = observer.fetchNextPage(cancelRefetch: false);
      await Future<void>.delayed(Duration.zero);
      final refresh = observer.refetch(cancelRefetch: false);
      await Future<void>.delayed(Duration.zero);
      expect(nextCalls, 1);
      expect(initialCalls, 1);

      next.complete(1);
      expect((await direction).data.requireValue().pages, <int>[0, 1]);
      expect((await refresh).data.requireValue().pages, <int>[0, 1]);
      expect(nextCalls, 1);
      expect(initialCalls, 1);
      observer.dispose();
      client.dispose();
    });

    test('invalidation replaces direction work with one full window refresh',
        () async {
      final directionPage = Completer<String>();
      var phase = 'initial';
      final seen = <String>[];
      final source = infiniteQuery<String, int>(
        QueryKey(<Object?>['invalidate-during-next']),
        (context) {
          seen.add('$phase:${context.pageParam}');
          if (phase == 'direction' && context.pageParam == 2) {
            return directionPage.future;
          }
          return '$phase-${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => data.pageParams.last < 2
            ? PageCursor.more(data.pageParams.last + 1)
            : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 2);
      final observer = client.observeInfiniteQuery(
        source.withObserver(
          enabled: true,
          refetchOnMount: RefetchPolicy.never,
        ),
      );

      phase = 'direction';
      final next = observer.fetchNextPage();
      await Future<void>.delayed(Duration.zero);
      expect(seen.last, 'direction:2');

      phase = 'refresh';
      final invalidation = client.invalidateQueries(
        filter: QueryFilter(key: source.key, exact: true),
      );
      directionPage.complete('direction-2');
      await next;
      final result = await invalidation;
      await Future<void>.delayed(Duration.zero);

      expect(result.failures, isEmpty);
      expect(
        observer.data.requireValue().pages,
        <String>['refresh-0', 'refresh-1'],
      );
      expect(
        seen.where((call) => call == 'refresh:2'),
        isEmpty,
      );
      observer.dispose();
      client.dispose();
    });

    test('final detach cancels consumed direction and rejects late recreation',
        () async {
      final lateDirection = Completer<int>();
      final source = infiniteQuery(
        QueryKey(<Object?>['infinite-detach-active']),
        (context) {
          if (context.pageParam == 1) {
            unawaited(context.cancellationToken.whenCancelled);
            return lateDirection.future;
          }
          return 0;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
        retention: RetentionPolicy.forever,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      final pending = observer.fetchNextPage();
      await Future<void>.delayed(Duration.zero);

      observer.dispose();
      await pending;
      expect(
        client.getQueryData(source.ordinaryQueryInternal).requireValue().pages,
        <int>[0],
      );
      expect(
        client.removeQueries(QueryFilter(key: source.key, exact: true)),
        1,
      );
      client.setQueryData(
        source.ordinaryQueryInternal,
        InfiniteData<int, int>(pages: <int>[99], pageParams: <int>[99]),
      );

      lateDirection.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(
        client.getQueryData(source.ordinaryQueryInternal).requireValue().pages,
        <int>[99],
      );
      client.dispose();
    });
  });

  group('atomic refresh and bounded retention', () {
    test('bounded refresh preserves the currently retained cursor window',
        () async {
      final seen = <int>[];
      final source = infiniteQuery(
        QueryKey(<Object?>['refresh-window']),
        (context) {
          seen.add(context.pageParam);
          return 'page-${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.more(data.pageParams.last + 1),
        maxPages: 2,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source, pages: 4);
      expect(
        client.getQueryData(source).requireValue().pageParams,
        <int>[2, 3],
      );
      seen.clear();

      final refreshed = await client.fetchInfiniteQuery(source);

      expect(seen, <int>[2, 3]);
      expect(refreshed.pageParams, <int>[2, 3]);
      client.dispose();
    });

    test('successful multi-page refresh commits one complete replacement',
        () async {
      var refreshing = false;
      final secondPageStarted = Completer<void>();
      final secondPage = Completer<String>();
      final source = infiniteQuery(
        QueryKey(<Object?>['refresh-success']),
        (context) {
          if (!refreshing) return 'old-${context.pageParam}';
          if (context.pageParam == 0) return 'new-0';
          secondPageStarted.complete();
          return secondPage.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        retry: RetryPolicy.none,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 2);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      final before = client.getQueryState(source.ordinaryQueryInternal)!;
      refreshing = true;

      final pending = observer.refetch();
      await secondPageStarted.future;

      final during = client.getQueryState(source.ordinaryQueryInternal)!;
      expect(
        observer.data.requireValue().pages,
        <String>['old-0', 'old-1'],
      );
      expect(
        observer.data.requireValue().pageParams,
        <int>[0, 1],
      );
      expect(during.revision, before.revision);
      expect(during.dataUpdateCount, before.dataUpdateCount);

      secondPage.complete('new-1');
      final result = await pending;

      final after = client.getQueryState(source.ordinaryQueryInternal)!;
      expect(
        result.data.requireValue().pages,
        <String>['new-0', 'new-1'],
      );
      expect(result.data.requireValue().pageParams, <int>[0, 1]);
      expect(
        observer.data.requireValue().pages,
        <String>['new-0', 'new-1'],
      );
      expect(after.revision, before.revision + 1);
      expect(after.dataUpdateCount, before.dataUpdateCount + 1);
      observer.dispose();
      client.dispose();
    });

    test('later refresh failure rolls back every earlier refreshed page',
        () async {
      var refreshing = false;
      final later = Completer<String>();
      final source = infiniteQuery(
        QueryKey(<Object?>['refresh-failure']),
        (context) {
          if (!refreshing) return 'old-${context.pageParam}';
          if (context.pageParam == 0) return 'new-0';
          return later.future;
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        retry: RetryPolicy.none,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 2);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      refreshing = true;

      final pending = observer.refetch();
      await Future<void>.delayed(Duration.zero);
      expect(
        observer.data.requireValue().pages,
        <String>['old-0', 'old-1'],
      );
      later.completeError(StateError('later failed'));
      final result = await pending;

      expect(result.data.requireValue().pages, <String>['old-0', 'old-1']);
      expect(result.isRefetchError, isTrue);
      expect(result.failure?.error, isA<StateError>());
      observer.dispose();
      client.dispose();
    });

    test('refresh recomputes cursors and atomically accepts an earlier end',
        () async {
      var refreshing = false;
      final source = infiniteQuery(
        QueryKey(<Object?>['refresh-end']),
        (context) => '${refreshing ? 'new' : 'old'}-${context.pageParam}',
        initialPageParam: 0,
        getNextPageParam: (data) {
          final last = data.pageParams.last;
          if (refreshing && last == 1) return PageCursor.end;
          return last < 2 ? PageCursor.more(last + 1) : PageCursor.end;
        },
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 3);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      refreshing = true;

      final result = await observer.refetch();

      expect(result.data.requireValue().pages, <String>['new-0', 'new-1']);
      expect(result.data.requireValue().pageParams, <int>[0, 1]);
      observer.dispose();
      client.dispose();
    });

    test('ordinary active invalidation retains infinite full-refresh behavior',
        () async {
      var refreshing = false;
      final source = infiniteQuery(
        QueryKey(<Object?>['invalidate-infinite']),
        (context) => '${refreshing ? 'new' : 'old'}-${context.pageParam}',
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 2);
      final observer = client.observeInfiniteQuery(
        source.withObserver(
          enabled: true,
          refetchOnMount: RefetchPolicy.never,
        ),
      );
      refreshing = true;

      final result = await client.invalidateQueries(
        filter: QueryFilter(key: source.key, exact: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(result.failures, isEmpty);
      expect(
        observer.data.requireValue().pages,
        <String>['new-0', 'new-1'],
      );
      observer.dispose();
      client.dispose();
    });

    test('a disabled infinite observer is inactive for active invalidation',
        () async {
      var calls = 0;
      final source = infiniteQuery(
        QueryKey(<Object?>['invalidate-disabled-infinite']),
        (context) {
          calls += 1;
          return 'page-$calls';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      await client.invalidateQueries(
        filter: QueryFilter(key: source.key, exact: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(observer.data.requireValue().pages, <String>['page-1']);
      expect(observer.isInvalidated, isTrue);
      observer.dispose();
      client.dispose();
    });

    test('infinite polling can explicitly disable an inherited interval',
        () async {
      final timers = FakeQueryTimerScheduler();
      final notifications = FakeQueryNotificationScheduler();
      final client = QueryClient(
        runtime: QueryRuntime(
          clock: FakeQueryClock(),
          timers: timers,
          random: FakeQueryRandomSource(),
          notifications: notifications,
        ),
      );
      var calls = 0;
      final source = infiniteQuery<int, int>(
        QueryKey(<Object?>['infinite-polling', 'explicit-off']),
        (context) => ++calls,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      );
      client.registerQueryDefaults(
        const QueryDefaults(pollingInterval: Duration(seconds: 2)),
        key: QueryKey(<Object?>['infinite-polling']),
      );
      final observer = client.observeInfiniteQuery(
        source
            .withInitialData(
              InfiniteData<int, int>(
                pages: <int>[0],
                pageParams: <int>[0],
              ),
            )
            .withObserver(
              refetchOnMount: RefetchPolicy.never,
              pollingEnabled: false,
            ),
      );
      notifications.flushAll();

      timers.elapse(const Duration(seconds: 20));
      for (var turn = 0; turn < 4; turn += 1) {
        await Future<void>.delayed(Duration.zero);
        notifications.flushAll();
      }

      expect(calls, 0);
      expect(observer.data.requireValue().pages, <int>[0]);
      observer.dispose();
      client.dispose();
    });

    test(
        'infinite resolver freshness recomputes on environment events without refetching',
        () async {
      final notifications = FakeQueryNotificationScheduler();
      final client = QueryClient(
        runtime: QueryRuntime(
          clock: FakeQueryClock(),
          timers: FakeQueryTimerScheduler(),
          random: FakeQueryRandomSource(),
          notifications: notifications,
        ),
      );
      var externallyStale = false;
      var calls = 0;
      final source = infiniteQuery<int, int>(
        QueryKey(<Object?>['infinite-resolver-environment']),
        (context) {
          calls += 1;
          return context.pageParam;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      )
          .withInitialData(
            InfiniteData<int, int>(
              pages: <int>[0],
              pageParams: <int>[0],
            ),
          )
          .withObserver(
            staleTime: StalePolicy.resolve((_) => externallyStale),
            refetchOnMount: RefetchPolicy.never,
            refetchOnFocus: RefetchPolicy.never,
            refetchOnReconnect: RefetchPolicy.never,
          );
      final observer = client.observeInfiniteQuery(source);
      notifications.flushAll();

      expect(observer.isStale, isFalse);
      expect(calls, 0);

      externallyStale = true;
      client.focusManager.isFocused = false;
      notifications.flushAll();
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();

      expect(observer.isStale, isTrue);
      expect(calls, 0);

      externallyStale = false;
      client.onlineManager.isOnline = false;
      notifications.flushAll();
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();

      expect(observer.isStale, isFalse);
      expect(calls, 0);
      observer.dispose();
      client.dispose();
    });

    test('fresh infinite cache hit reapplies longer received retention',
        () async {
      final timers = FakeQueryTimerScheduler();
      final notifications = FakeQueryNotificationScheduler();
      final client = QueryClient(
        runtime: QueryRuntime(
          clock: FakeQueryClock(),
          timers: timers,
          random: FakeQueryRandomSource(),
          notifications: notifications,
        ),
      );
      final source = infiniteQuery<int, int>(
        QueryKey(<Object?>['infinite-retention', 'longer-hit']),
        (context) => context.pageParam,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
        retention: RetentionPolicy.forever,
      );
      client.registerQueryDefaults(
        QueryDefaults(
          retention: RetentionPolicy.duration(const Duration(seconds: 2)),
        ),
        key: QueryKey(<Object?>['infinite-retention']),
      );
      client.setQueryData(
        source,
        InfiniteData<int, int>(
          pages: <int>[0],
          pageParams: <int>[0],
        ),
      );

      expect((await client.fetchInfiniteQuery(source)).pages, <int>[0]);
      timers.elapse(const Duration(seconds: 2));

      expect(client.getQueryData(source).requireValue().pages, <int>[0]);
      client.dispose();
    });

    test('lifecycle refresh retry resumes at its failed retained page',
        () async {
      var refreshing = false;
      var secondPageAttempts = 0;
      final seen = <int>[];
      final source = infiniteQuery(
        QueryKey(<Object?>['invalidate-infinite-retry']),
        (context) {
          if (refreshing) {
            seen.add(context.pageParam);
            if (context.pageParam == 1 && secondPageAttempts++ == 0) {
              throw StateError('page 1 failed once');
            }
          }
          return '${refreshing ? 'new' : 'old'}-${context.pageParam}';
        },
        initialPageParam: 0,
        getNextPageParam: (data) => data.pageParams.last < 2
            ? PageCursor.more(data.pageParams.last + 1)
            : PageCursor.end,
        staleTime: StalePolicy.untilInvalidated,
      ).withRetry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source, pages: 3);
      final observer = client.observeInfiniteQuery(
        source.withObserver(
          enabled: true,
          refetchOnMount: RefetchPolicy.never,
        ),
      );
      refreshing = true;

      final result = await client.invalidateQueries(
        filter: QueryFilter(key: source.key, exact: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(result.failures, isEmpty);
      expect(seen, <int>[0, 1, 1, 2]);
      expect(
        observer.data.requireValue().pages,
        <String>['new-0', 'new-1', 'new-2'],
      );
      observer.dispose();
      client.dispose();
    });

    test('next and previous trim aligned pairs from opposite edges', () async {
      final source = infiniteQuery(
        QueryKey(<Object?>['bounded']),
        (context) => 'page-${context.pageParam}',
        initialPageParam: 1,
        getNextPageParam: (data) => PageCursor.more(data.pageParams.last + 1),
        getPreviousPageParam: (data) =>
            PageCursor.more(data.pageParams.first - 1),
        maxPages: 2,
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.prefetchInfiniteQuery(source, pages: 2);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );

      final next = await observer.fetchNextPage();
      expect(next.data.requireValue().pages, <String>['page-2', 'page-3']);
      expect(next.data.requireValue().pageParams, <int>[2, 3]);
      final previous = await observer.fetchPreviousPage();
      expect(previous.data.requireValue().pages, <String>['page-1', 'page-2']);
      expect(previous.data.requireValue().pageParams, <int>[1, 2]);
      observer.dispose();
      client.dispose();
    });

    test('final infinite observer detachment uses ordinary zero-retention GC',
        () async {
      final source = infiniteQuery(
        QueryKey(<Object?>['infinite-gc']),
        (context) => context.pageParam,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        retention: RetentionPolicy.duration(Duration.zero),
        staleTime: StalePolicy.untilInvalidated,
      );
      final client = QueryClient();
      await client.fetchInfiniteQuery(source);
      final observer = client.observeInfiniteQuery(
        source.withObserver(enabled: false),
      );
      expect(client.queryCache.snapshots, hasLength(1));

      observer.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(client.queryCache.snapshots, isEmpty);
      client.dispose();
    });

    test('cancellation prevents a later page transport from starting',
        () async {
      final firstPage = Completer<int>();
      final seen = <int>[];
      final source = infiniteQuery<int, int>(
        QueryKey(<Object?>['infinite-cancel-between-pages']),
        (context) {
          seen.add(context.pageParam);
          if (context.pageParam == 0) {
            unawaited(context.cancellationToken.whenCancelled);
            return firstPage.future;
          }
          return context.pageParam;
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.more(data.pageParams.last + 1),
      );
      final client = QueryClient();
      final pending = client.fetchInfiniteQuery(source, pages: 3);
      final expectation = expectLater(
        pending,
        throwsA(isA<QueryCancelledException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, <int>[0]);

      await client.cancelQueries(
        filter: QueryFilter(key: source.key, exact: true),
      );
      firstPage.complete(0);
      await expectation;
      await Future<void>.delayed(Duration.zero);

      expect(seen, <int>[0]);
      client.dispose();
    });

    test('cursor resolver cancellation prevents the next page transport',
        () async {
      final seen = <int>[];
      late QueryClient client;
      Future<QueryBatchResult>? cancellation;
      final key = QueryKey(<Object?>['infinite-cancel-in-resolver']);
      final source = infiniteQuery<int, int>(
        key,
        (context) {
          seen.add(context.pageParam);
          return context.pageParam;
        },
        initialPageParam: 0,
        getNextPageParam: (data) {
          cancellation = client.cancelQueries(
            filter: QueryFilter(key: key, exact: true),
          );
          return PageCursor.more(data.pageParams.last + 1);
        },
      );
      client = QueryClient();

      await expectLater(
        client.fetchInfiniteQuery(source, pages: 2),
        throwsA(isA<QueryCancelledException>()),
      );
      await cancellation;

      expect(seen, <int>[0]);
      client.dispose();
    });
  });
}

void _expectStaticType<T>(T value) {}
