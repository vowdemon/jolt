import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/jolt.dart' show Effect, Signal;
import 'package:jolt_query/jolt_query.dart';

import '../support/fake_runtime.dart';

void main() {
  test('next on absent data starts initial loading with next metadata',
      () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final page = Completer<int>();
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-direction', 'absent-next']),
      (context) => page.future,
      initialPageParam: 7,
      getNextPageParam: (data) => PageCursor.end,
      retry: RetryPolicy.none,
    );
    final observer = client.observeInfiniteQuery(
      source.observer(enabled: false),
    );

    final pending = observer.fetchNextPage();

    expect(observer.isLoading, isTrue);
    expect(observer.isFetchingNextPage, isTrue);
    expect(observer.isFetchingPreviousPage, isFalse);

    page.complete(7);
    final result = await pending;

    expect(result.data.requireValue().pages, <int>[7]);
    expect(result.isFetchingNextPage, isFalse);
    expect(result.isSuccess, isTrue);
  });

  test('previous on absent data classifies an initial failure as directional',
      () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final error = StateError('initial page failed');
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-direction', 'absent-previous-error']),
      (context) => throw error,
      initialPageParam: 0,
      getNextPageParam: (data) => PageCursor.end,
      retry: RetryPolicy.none,
    );
    final observer = client.observeInfiniteQuery(
      source.observer(enabled: false),
    );

    final result = await observer.fetchPreviousPage();

    expect(result.failure?.error, same(error));
    expect(result.isFetchPreviousPageError, isTrue);
    expect(result.isFetchNextPageError, isFalse);
    expect(result.isLoadingError, isTrue);
    expect(result.isRefetchError, isFalse);
  });

  test('retained directional failure is not a whole-window refetch error',
      () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final error = StateError('previous page failed');
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-direction', 'retained-previous-error']),
      (context) {
        if (context.direction == InfiniteDirection.backward) throw error;
        return context.pageParam;
      },
      initialPageParam: 1,
      getNextPageParam: (data) => PageCursor.end,
      getPreviousPageParam: (data) => const PageCursor<int>.more(0),
      retry: RetryPolicy.none,
    );
    final observer = client.observeInfiniteQuery(
      source
          .initialData(
            InfiniteData<int, int>(
              pages: <int>[1],
              pageParams: <int>[1],
            ),
          )
          .observer(enabled: false),
    );

    final result = await observer.fetchPreviousPage();

    expect(result.data.requireValue().pages, <int>[1]);
    expect(result.failure?.error, same(error));
    expect(result.isFetchPreviousPageError, isTrue);
    expect(result.isRefetchError, isFalse);
  });

  test('shared observers never publish a next-page failure as a refetch error',
      () async {
    await _expectSharedDirectionalFailure(InfiniteDirection.forward);
  });

  test(
      'shared observers never publish a previous-page failure as a refetch error',
      () async {
    await _expectSharedDirectionalFailure(InfiniteDirection.backward);
  });

  test('reverted whole-window fetch restores shared directional provenance',
      () async {
    final client = QueryClient();
    final refreshPage = Completer<int>();
    final directionError = StateError('next page failed');
    var refreshing = false;
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>[
        'infinite-direction',
        'shared-error',
        'cancel-rollback',
      ]),
      (context) {
        if (context.pageParam == 1) throw directionError;
        return refreshing ? refreshPage.future : context.pageParam;
      },
      initialPageParam: 0,
      getNextPageParam: (data) => const PageCursor<int>.more(1),
      retry: RetryPolicy.none,
    );
    final target = source
        .initialData(
          InfiniteData<int, int>(
            pages: <int>[0],
            pageParams: <int>[0],
          ),
        )
        .observer(enabled: false);
    final first = client.observeInfiniteQuery(target);
    final second = client.observeInfiniteQuery(target);
    final firstStates = <_DirectionalPresentation>[];
    final secondStates = <_DirectionalPresentation>[];
    final firstEffect = Effect(() {
      firstStates.add(_DirectionalPresentation.from(first.value));
    });
    final secondEffect = Effect(() {
      secondStates.add(_DirectionalPresentation.from(second.value));
    });
    addTearDown(() {
      firstEffect.dispose();
      secondEffect.dispose();
      first.dispose();
      second.dispose();
      client.dispose();
    });

    await first.fetchNextPage();
    await _pumpMicrotasks();
    expect(first.isFetchNextPageError, isTrue);
    expect(second.isFetchNextPageError, isTrue);

    refreshing = true;
    final refresh = first.refetch();
    await _pumpMicrotasks();
    expect(
      secondStates.any((state) => state.isRefetchError),
      isTrue,
    );

    await client.cancelQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await refresh;
    await _pumpMicrotasks();

    for (final observer in <InfiniteQueryObserver<InfiniteData<int, int>>>[
      first,
      second,
    ]) {
      expect(observer.failure?.error, same(directionError));
      expect(observer.isFetchNextPageError, isTrue);
      expect(observer.isFetchPreviousPageError, isFalse);
      expect(observer.isRefetchError, isFalse);
    }
    for (final states in <List<_DirectionalPresentation>>[
      firstStates,
      secondStates,
    ]) {
      expect(states.last.isFetchNextPageError, isTrue);
      expect(states.last.isFetchPreviousPageError, isFalse);
      expect(states.last.isRefetchError, isFalse);
    }

    refreshPage.complete(0);
  });

  test('restarted direction keeps shared provenance and reverts atomically',
      () async {
    final client = QueryClient();
    final retryPage = Completer<int>();
    final directionError = StateError('first next page failed');
    var directionCalls = 0;
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>[
        'infinite-direction',
        'shared-error',
        'direction-retry-cancel',
      ]),
      (context) {
        directionCalls += 1;
        if (directionCalls == 1) throw directionError;
        return retryPage.future;
      },
      initialPageParam: 0,
      getNextPageParam: (data) => const PageCursor<int>.more(1),
      retry: RetryPolicy.none,
    );
    final target = source
        .initialData(
          InfiniteData<int, int>(
            pages: <int>[0],
            pageParams: <int>[0],
          ),
        )
        .observer(enabled: false);
    final first = client.observeInfiniteQuery(target);
    final second = client.observeInfiniteQuery(target);
    final firstStates = <_DirectionalPresentation>[];
    final secondStates = <_DirectionalPresentation>[];
    final firstEffect = Effect(() {
      firstStates.add(_DirectionalPresentation.from(first.value));
    });
    final secondEffect = Effect(() {
      secondStates.add(_DirectionalPresentation.from(second.value));
    });
    addTearDown(() {
      firstEffect.dispose();
      secondEffect.dispose();
      first.dispose();
      second.dispose();
      client.dispose();
    });

    await first.fetchNextPage();
    await _pumpMicrotasks();
    firstStates.clear();
    secondStates.clear();

    final retry = first.fetchNextPage();
    await _pumpMicrotasks();
    for (final observer in <InfiniteQueryObserver<InfiniteData<int, int>>>[
      first,
      second,
    ]) {
      expect(observer.isFetchingNextPage, isTrue);
      expect(observer.isFetchNextPageError, isTrue);
      expect(observer.isRefetchError, isFalse);
    }
    for (final states in <List<_DirectionalPresentation>>[
      firstStates,
      secondStates,
    ]) {
      expect(states.where((state) => state.isRefetchError), isEmpty);
    }

    await client.cancelQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await retry;
    await _pumpMicrotasks();

    for (final observer in <InfiniteQueryObserver<InfiniteData<int, int>>>[
      first,
      second,
    ]) {
      expect(observer.failure?.error, same(directionError));
      expect(observer.isFetchNextPageError, isTrue);
      expect(observer.isRefetchError, isFalse);
    }

    retryPage.complete(1);
  });

  test('bulk replacement is never presented as the replaced direction',
      () async {
    final client = QueryClient();
    final directionPage = Completer<int>();
    final fullPage = Completer<int>();
    final fullStarted = Completer<void>();
    var fullWindow = false;
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>[
        'infinite-direction',
        'bulk-replacement',
      ]),
      (context) {
        if (fullWindow) {
          if (!fullStarted.isCompleted) fullStarted.complete();
          return fullPage.future;
        }
        if (context.pageParam == 1) return directionPage.future;
        return context.pageParam;
      },
      initialPageParam: 0,
      getNextPageParam: (data) => const PageCursor<int>.more(1),
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
    );
    final target = source
        .initialData(
          InfiniteData<int, int>(
            pages: <int>[0],
            pageParams: <int>[0],
          ),
        )
        .observer(
          enabled: true,
          refetchOnMount: RefetchPolicy.never,
        );
    final first = client.observeInfiniteQuery(target);
    final second = client.observeInfiniteQuery(target);
    addTearDown(() {
      first.dispose();
      second.dispose();
      client.dispose();
    });

    final direction = first.fetchNextPage();
    await _pumpMicrotasks();
    expect(first.isFetchingNextPage, isTrue);
    expect(second.isFetchingNextPage, isTrue);

    fullWindow = true;
    final replacement = client.invalidateQueries(
      filter: QueryFilter(key: source.key, exact: true),
    );
    await fullStarted.future;
    await _pumpMicrotasks();

    for (final observer in <InfiniteQueryObserver<InfiniteData<int, int>>>[
      first,
      second,
    ]) {
      expect(observer.isFetching, isTrue);
      expect(observer.isRefetching, isTrue);
      expect(observer.isFetchingNextPage, isFalse);
      expect(observer.isFetchingPreviousPage, isFalse);
    }
    final cancelledDirection = await direction;
    expect(cancelledDirection.isFetchingNextPage, isFalse);
    expect(cancelledDirection.isFetchingPreviousPage, isFalse);

    fullPage.complete(10);
    final batch = await replacement;
    await _pumpMicrotasks();

    expect(batch.failures, isEmpty);
    expect(first.data.requireValue().pages, <int>[10]);
    expect(second.data.requireValue().pages, <int>[10]);
    directionPage.complete(1);
    await _pumpMicrotasks();
    expect(first.data.requireValue().pages, <int>[10]);
  });

  test('cursor resolver key switch cannot execute the new plan on the old key',
      () async {
    final useSecond = Signal<bool>(false);
    final client = QueryClient();
    var firstPageCalls = 0;
    var secondPageCalls = 0;
    var switchOnCursor = false;
    final first = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-direction', 'cursor-switch', 'first']),
      (context) {
        firstPageCalls += 1;
        return context.pageParam;
      },
      initialPageParam: 0,
      getNextPageParam: (data) {
        if (switchOnCursor) useSecond.value = true;
        return const PageCursor<int>.more(1);
      },
      retry: RetryPolicy.none,
    );
    final second = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-direction', 'cursor-switch', 'second']),
      (context) {
        secondPageCalls += 1;
        return context.pageParam;
      },
      initialPageParam: 10,
      getNextPageParam: (data) => const PageCursor<int>.more(11),
      retry: RetryPolicy.none,
    );
    final firstTarget = first
        .initialData(
          InfiniteData<int, int>(
            pages: <int>[0],
            pageParams: <int>[0],
          ),
        )
        .observer(enabled: false);
    final secondTarget = second
        .initialData(
          InfiniteData<int, int>(
            pages: <int>[10],
            pageParams: <int>[10],
          ),
        )
        .observer(enabled: false);
    final observer = client.watchInfiniteQuery(
      () => useSecond.value ? secondTarget : firstTarget,
    );
    addTearDown(() {
      observer.dispose();
      client.dispose();
      useSecond.dispose();
    });

    switchOnCursor = true;
    final result = await observer.fetchNextPage();
    await _pumpMicrotasks();

    expect(result.key, second.key);
    expect(observer.key, second.key);
    expect(client.getQueryData(first).requireValue().pages, <int>[0]);
    expect(client.getQueryData(second).requireValue().pages, <int>[10]);
    expect(firstPageCalls, 0);
    expect(secondPageCalls, 0);
  });

  test('state-derived polling uses the ordinary observer lifecycle', () async {
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
    addTearDown(client.dispose);
    var calls = 0;
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-polling', 'state-derived']),
      (context) => ++calls,
      initialPageParam: 0,
      getNextPageParam: (data) => PageCursor.end,
      retry: RetryPolicy.none,
    );
    final observer = client.observeInfiniteQuery(
      source
          .initialData(
            InfiniteData<int, int>(
              pages: <int>[0],
              pageParams: <int>[0],
            ),
          )
          .observer(
            refetchOnMount: RefetchPolicy.never,
            pollingIntervalResolver: (result) {
              final data = result.data.valueOrNull;
              return data != null && data.pages.single == 0
                  ? const Duration(seconds: 1)
                  : null;
            },
          ),
    );
    notifications.flushAll();

    expect(observer.isEnabled, isTrue);
    timers.elapse(const Duration(seconds: 1));
    for (var turn = 0; turn < 4; turn += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }

    expect(calls, 1);
    expect(observer.data.requireValue().pages, <int>[1]);

    timers.elapse(const Duration(seconds: 10));
    for (var turn = 0; turn < 2; turn += 1) {
      await Future<void>.delayed(Duration.zero);
      notifications.flushAll();
    }
    expect(calls, 1);
  });

  test('invalidation without cancellation joins direction work once', () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final thirdPage = Completer<int>();
    final seen = <int>[];
    final source = infiniteQuery<int, int>(
      QueryKey(<Object?>['infinite-invalidation', 'join-direction']),
      (context) {
        seen.add(context.pageParam);
        return context.pageParam == 2 ? thirdPage.future : context.pageParam;
      },
      initialPageParam: 0,
      getNextPageParam: (data) => data.pageParams.last < 2
          ? PageCursor.more(data.pageParams.last + 1)
          : PageCursor.end,
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
    );
    await client.prefetchInfiniteQuery(source, pages: 2);
    final observer = client.observeInfiniteQuery(
      source.observer(
        refetchOnMount: RefetchPolicy.never,
      ),
    );

    final direction = observer.fetchNextPage(cancelRefetch: false);
    await Future<void>.delayed(Duration.zero);
    final invalidation = client.invalidateQueries(
      filter: QueryFilter(key: source.key, exact: true),
      cancelRefetch: false,
    );
    thirdPage.complete(2);

    await direction;
    final batch = await invalidation;

    expect(batch.failures, isEmpty);
    expect(seen, <int>[0, 1, 2]);
    expect(observer.data.requireValue().pages, <int>[0, 1, 2]);
    expect(observer.isInvalidated, isFalse);
  });
}

Future<void> _expectSharedDirectionalFailure(
  InfiniteDirection direction,
) async {
  final client = QueryClient();
  final page = Completer<int>();
  final error = StateError('$direction page failed');
  final initialPageParam = direction == InfiniteDirection.forward ? 0 : 1;
  final source = infiniteQuery<int, int>(
    QueryKey(<Object?>[
      'infinite-direction',
      'shared-error',
      direction == InfiniteDirection.forward ? 'next' : 'previous',
    ]),
    (context) => page.future,
    initialPageParam: initialPageParam,
    getNextPageParam: (data) => direction == InfiniteDirection.forward
        ? const PageCursor<int>.more(1)
        : PageCursor.end,
    getPreviousPageParam: (data) => direction == InfiniteDirection.backward
        ? const PageCursor<int>.more(0)
        : PageCursor.end,
    retry: RetryPolicy.none,
  );
  final target = source
      .initialData(
        InfiniteData<int, int>(
          pages: <int>[initialPageParam],
          pageParams: <int>[initialPageParam],
        ),
      )
      .observer(enabled: false);
  final first = client.observeInfiniteQuery(target);
  final second = client.observeInfiniteQuery(target);
  final firstStates = <_DirectionalPresentation>[];
  final secondStates = <_DirectionalPresentation>[];
  final firstEffect = Effect(() {
    firstStates.add(_DirectionalPresentation.from(first.value));
  });
  final secondEffect = Effect(() {
    secondStates.add(_DirectionalPresentation.from(second.value));
  });
  addTearDown(() {
    firstEffect.dispose();
    secondEffect.dispose();
    first.dispose();
    second.dispose();
    client.dispose();
  });

  final pending = direction == InfiniteDirection.forward
      ? first.fetchNextPage()
      : first.fetchPreviousPage();
  await Future<void>.delayed(Duration.zero);
  page.completeError(error);
  final result = await pending;
  for (var turn = 0; turn < 4; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }

  final expectNext = direction == InfiniteDirection.forward;
  expect(result.failure?.error, same(error));
  expect(result.isFetchNextPageError, expectNext);
  expect(result.isFetchPreviousPageError, !expectNext);
  expect(second.failure?.error, same(error));
  expect(second.isFetchNextPageError, expectNext);
  expect(second.isFetchPreviousPageError, !expectNext);
  for (final states in <List<_DirectionalPresentation>>[
    firstStates,
    secondStates,
  ]) {
    expect(
      states.where((state) => state.isRefetchError),
      isEmpty,
      reason: '$direction was transiently published as a refetch error',
    );
    final errors = states.where((state) => state.isError);
    expect(errors, isNotEmpty);
    expect(
      errors.every(
        (state) =>
            state.isFetchNextPageError == expectNext &&
            state.isFetchPreviousPageError == !expectNext,
      ),
      isTrue,
    );
  }
}

final class _DirectionalPresentation {
  const _DirectionalPresentation({
    required this.isError,
    required this.isRefetchError,
    required this.isFetchNextPageError,
    required this.isFetchPreviousPageError,
  });

  factory _DirectionalPresentation.from(
    InfiniteQueryObserverResult<InfiniteData<int, int>> result,
  ) {
    return _DirectionalPresentation(
      isError: result.isError,
      isRefetchError: result.isRefetchError,
      isFetchNextPageError: result.isFetchNextPageError,
      isFetchPreviousPageError: result.isFetchPreviousPageError,
    );
  }

  final bool isError;
  final bool isRefetchError;
  final bool isFetchNextPageError;
  final bool isFetchPreviousPageError;
}

Future<void> _pumpMicrotasks() async {
  for (var turn = 0; turn < 4; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
