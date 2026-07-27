import 'package:jolt_query/src/foundation/query_cancellation.dart';
import 'package:jolt_query/src/foundation/query_runtime.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/foundation/timer_orchestrator.dart';
import 'package:jolt_query/src/infinite/data.dart';
import 'package:jolt_query/src/infinite/recipe.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/policies.dart';
import 'package:jolt_query/src/query/recipe.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:jolt_query/jolt_query.dart'
    show
        InfiniteQueryObserver,
        InfiniteQueryObserverResult,
        QueryClient,
        QueryClientInfiniteMethods;
import 'package:retry_plus/retry_plus.dart' show DelayPolicy, RetryIf;
import 'package:test/test.dart';

void main() {
  group('class-first infinite recipes', () {
    test(
        'minimal external subclass binds Page and PageParam through client and observer',
        () async {
      final recipe = _UserPages();
      final client = QueryClient();
      addTearDown(client.dispose);

      _expectStaticType<InfiniteQuery<_User, int>>(recipe);
      _expectStaticType<ResolvedInfiniteQueryPlan<_User, int>>(
          recipe.infinitePlan);
      _expectStaticType<Query<InfiniteData<_User, int>>>(
        recipe.ordinaryQueryInternal,
      );
      expect(recipe.initialPageParam, 0);
      expect(recipe.maxPages, isNull);
      expect(recipe.retryPolicy, isNull);
      expect(recipe.stalePolicy, same(StalePolicy.immediate));
      expect(recipe.retentionPolicy, same(RetentionPolicy.standard));
      expect(recipe.networkMode, NetworkMode.online);
      expect(recipe.metadata, isEmpty);
      expect(
        recipe.getPreviousPageParam(
          InfiniteData<_User, int>(
            pages: const <_User>[],
            pageParams: const <int>[],
          ),
        ),
        PageCursor.end,
      );
      expect(
        recipe.resolved.plan,
        isA<ResolvedQueryPlan<InfiniteData<_User, int>>>(),
      );

      final Future<InfiniteData<_User, int>> fetched =
          client.fetchInfiniteQuery(recipe);
      final initial = await fetched;
      expect(initial.pages, const <_User>[_User(0, 'user-0')]);
      expect(initial.pageParams, <int>[0]);

      final InfiniteQueryObserver<InfiniteData<_User, int>> observer =
          client.observeInfiniteQuery(recipe);
      addTearDown(observer.dispose);
      final Future<InfiniteQueryObserverResult<InfiniteData<_User, int>>>
          refreshing = observer.refetch();
      final refreshed = await refreshing;
      expect(refreshed.data.requireValue().pages, initial.pages);

      final Future<InfiniteQueryObserverResult<InfiniteData<_User, int>>>
          fetchingNext = observer.fetchNextPage();
      final next = await fetchingNext;
      expect(
        next.data.requireValue().pages,
        const <_User>[_User(0, 'user-0'), _User(2, 'user-2')],
      );
      expect(next.data.requireValue().pageParams, <int>[0, 2]);
    });

    test('inline factory infers Page and PageParam from ordinary arguments',
        () async {
      InfinitePageContext<int>? seenContext;
      final recipe = infiniteQuery(
        QueryKey(<Object?>['users']),
        (context) {
          seenContext = context;
          return _User(context.pageParam, 'user-${context.pageParam}');
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.more(data.length),
      );

      _expectStaticType<InfiniteQuery<_User, int>>(recipe);
      final result = await _fetchResolved(recipe);

      expect(result.pages, const <_User>[_User(0, 'user-0')]);
      expect(result.pageParams, <int>[0]);
      expect(seenContext?.pageParam, 0);
      expect(seenContext?.direction, InfiniteDirection.forward);
      expect(seenContext?.key, recipe.key);
      expect(
        recipe.getPreviousPageParam(result),
        PageCursor.end,
      );
    });

    test('inline marker slot rejects a custom Never retry strategy', () {
      final customMarker = RetryPolicy<Never>.custom(
        (retry) => retry.strategy(retryIf: retry.never),
      );

      expect(
        () => infiniteQuery(
          QueryKey(<Object?>['invalid-infinite-marker']),
          (context) => context.pageParam,
          initialPageParam: 0,
          getNextPageParam: (data) => PageCursor.end,
          retry: customMarker,
        ),
        throwsArgumentError,
      );
    });

    test('optional previous resolver defaults to end and can be supplied', () {
      final forwardOnly = infiniteQuery(
        QueryKey(<Object?>['forward']),
        (context) => context.pageParam,
        initialPageParam: 2,
        getNextPageParam: (data) => PageCursor.end,
      );
      final bidirectional = infiniteQuery(
        QueryKey(<Object?>['both']),
        (context) => context.pageParam,
        initialPageParam: 2,
        getNextPageParam: (data) => PageCursor.more(3),
        getPreviousPageParam: (data) => PageCursor.more(1),
      );
      final data = InfiniteData<int, int>(
        pages: <int>[2],
        pageParams: <int>[2],
      );

      expect(forwardOnly.getPreviousPageParam(data), PageCursor.end);
      expect(
        bidirectional.getPreviousPageParam(data).requirePageParam(),
        1,
      );
    });

    test('nullable initial parameter remains a real parameter', () async {
      final recipe = infiniteQuery<String?, String?>(
        QueryKey(<Object?>['nullable']),
        (context) => context.pageParam,
        initialPageParam: null,
        getNextPageParam: (data) => PageCursor.more(null),
      );

      final result = await _fetchResolved(recipe);

      expect(result.pages.single, isNull);
      expect(result.pageParams.single, isNull);
      expect(
        recipe.getNextPageParam(result),
        const PageCursor<String?>.more(null),
      );
    });

    test('maxPages is absent or positive and captured in the resolved plan',
        () {
      final bounded = infiniteQuery(
        QueryKey(<Object?>['bounded']),
        (context) => context.pageParam,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        maxPages: 3,
      );

      expect(bounded.maxPages, 3);
      expect(bounded.infinitePlan.maxPages, 3);
      expect(
        () => infiniteQuery(
          QueryKey(<Object?>['zero']),
          (context) => context.pageParam,
          initialPageParam: 0,
          getNextPageParam: (data) => PageCursor.end,
          maxPages: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => infiniteQuery(
          QueryKey(<Object?>['negative']),
          (context) => context.pageParam,
          initialPageParam: 0,
          getNextPageParam: (data) => PageCursor.end,
          maxPages: -1,
        ),
        throwsArgumentError,
      );
      expect(() => _InvalidMaxPages().resolved, throwsArgumentError);
    });

    test('resolved ordinary plan freezes policies and metadata', () {
      final metadata = <String, Object?>{'source': 'infinite'};
      final recipe = infiniteQuery(
        QueryKey(<Object?>['configured']),
        (context) => context.pageParam,
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
        retry: RetryPolicy.none,
        staleTime: StalePolicy.untilInvalidated,
        retention: RetentionPolicy.forever,
        networkMode: NetworkMode.always,
        metadata: metadata,
      );
      final plan = recipe.resolved.plan;
      metadata['later'] = true;

      expect(plan.configuredRetry, same(RetryPolicy.none));
      expect(plan.stalePolicy, same(StalePolicy.untilInvalidated));
      expect(plan.retentionPolicy, same(RetentionPolicy.forever));
      expect(plan.networkMode, NetworkMode.always);
      expect(plan.metadata, <String, Object?>{'source': 'infinite'});
      expect(() => plan.metadata['illegal'] = true, throwsUnsupportedError);
    });
  });

  group('specialized infinite stages', () {
    test('initial, repeated select, observer, and placeholder retain direction',
        () {
      final raw = _UserPages();
      final initialData = InfiniteData<_User, int>(
        pages: const <_User>[_User(-1, 'loading')],
        pageParams: <int>[-1],
      );
      final initialized = raw.initialData(
        initialData,
        updatedAt: DateTime.utc(2025),
      );
      final selected = initialized
          .select((data) => data.pages.single.name)
          .select((name) => name.length);
      final terminal = selected
          .observer(
            enabled: false,
            staleTime: StalePolicy.untilInvalidated,
            refetchOnMount: RefetchPolicy.always,
            pollingInterval: const Duration(seconds: 30),
            equality: (previous, next) => previous == next,
          )
          .placeholderData(-1);

      _expectStaticType<InfiniteQueryView<InfiniteData<_User, int>>>(
          initialized);
      _expectStaticType<InfiniteQueryView<int>>(selected);
      _expectStaticType<InfiniteQueryTarget<int>>(terminal);
      expect(terminal, isNot(isA<InfiniteQueryView<int>>()));
      expect(selected.infinitePlan, same(initialized.infinitePlan));
      expect(terminal.infinitePlan, same(initialized.infinitePlan));
      expect(terminal.key, raw.key);
      expect(terminal.resolved.initialData?.data, same(initialData));
      expect(
        terminal.resolved.select(
          InfiniteData<_User, int>(
            pages: const <_User>[_User(1, 'Ada')],
            pageParams: <int>[1],
          ),
        ),
        3,
      );
      expect(terminal.resolved.observer.enabled, isFalse);
      expect(
        terminal.resolved.observer.staleTime,
        same(StalePolicy.untilInvalidated),
      );
      expect(
        terminal.resolved.resolvePlaceholder(
          const QueryValue<int>.absent(),
        ),
        const QueryValue<int>.present(-1),
      );
      final next = terminal.infinitePlan.getNextPageParamObject(
        InfiniteData<_User, int>(
          pages: const <_User>[_User(1, 'Ada')],
          pageParams: <int>[1],
        ),
      );
      expect(next.requirePageParam(), 2);
    });

    test('raw and selected infinite targets remain ordinary AnyQueryTargets',
        () {
      final raw = _UserPages();
      final selected = raw.select((data) => data.length);
      final targets = <AnyQueryTarget>[raw, selected];

      expect(targets.map((target) => target.key), everyElement(raw.key));
      expect(
        targets.first.resolved.plan,
        isA<ResolvedQueryPlan<InfiniteData<_User, int>>>(),
      );
      expect(
        targets.last.resolved.selectObject(
          InfiniteData<_User, int>(
            pages: const <_User>[_User(1, 'Ada')],
            pageParams: <int>[1],
          ),
        ),
        1,
      );
    });
  });

  group('whole-data retry typing', () {
    test('retry is typed to complete InfiniteData after inference', () {
      final recipe = infiniteQuery(
        QueryKey(<Object?>['typed-retry']),
        (context) => _User(context.pageParam, 'user'),
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      ).retry((retry) {
        final RetryIf<InfiniteData<_User, int>> wholeResults = retry.result(
          (data) {
            _expectStaticType<InfiniteData<_User, int>>(data);
            return data.pages.isEmpty;
          },
        );
        return retry.strategy(retryIf: wholeResults);
      });

      _expectStaticType<InfiniteQuery<_User, int>>(recipe);
      expect(
        recipe.resolved.plan.configuredRetry,
        isA<RetryPolicy<InfiniteData<_User, int>>>(),
      );
    });

    test('a thrown page validation failure enters ordinary retry', () async {
      var attempts = 0;
      final validationError = StateError('invalid page');
      final recipe = infiniteQuery(
        QueryKey(<Object?>['page-validation']),
        (context) {
          attempts += 1;
          if (attempts == 1) throw validationError;
          return _User(context.pageParam, 'valid');
        },
        initialPageParam: 7,
        getNextPageParam: (data) => PageCursor.end,
      ).retry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );

      final result = await _executeResolved(recipe);

      expect(attempts, 2);
      expect(result.pages, const <_User>[_User(7, 'valid')]);
      expect(result.pageParams, <int>[7]);
    });

    test('a thrown later page retry resumes at only the failed page', () async {
      final seen = <int>[];
      var secondPageAttempts = 0;
      final recipe = infiniteQuery(
        QueryKey(<Object?>['later-page-retry']),
        (context) {
          seen.add(context.pageParam);
          if (context.pageParam == 1 && secondPageAttempts++ == 0) {
            throw StateError('page 1 failed once');
          }
          return _User(context.pageParam, 'user-${context.pageParam}');
        },
        initialPageParam: 0,
        getNextPageParam: (data) => data.pageParams.last < 2
            ? PageCursor.more(data.pageParams.last + 1)
            : PageCursor.end,
      ).retry(
        (retry) => retry.strategy(
          retryIf: retry.exceptions & retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final client = QueryClient();

      final result = await client.fetchInfiniteQuery(recipe, pages: 3);

      expect(seen, <int>[0, 1, 1, 2]);
      expect(result.pageParams, <int>[0, 1, 2]);
      client.dispose();
    });

    test('result retry receives and rebuilds a complete InfiniteData',
        () async {
      var attempts = 0;
      final seen = <InfiniteData<_User, int>>[];
      final recipe = infiniteQuery(
        QueryKey(<Object?>['whole-result']),
        (context) {
          attempts += 1;
          return _User(attempts, 'attempt-$attempts');
        },
        initialPageParam: 0,
        getNextPageParam: (data) => PageCursor.end,
      ).retry(
        (retry) => retry.strategy(
          retryIf: retry.result((data) {
                seen.add(data);
                return data.pages.single.id == 1;
              }) &
              retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );

      final result = await _executeResolved(recipe);

      expect(attempts, 2);
      expect(seen, hasLength(2));
      expect(seen.every((data) => data.length == 1), isTrue);
      expect(result.pages.single.id, 2);
    });

    test('a rejected whole result rebuilds the complete page chain', () async {
      final seenPageParams = <int>[];
      var examinedResults = 0;
      final recipe = infiniteQuery(
        QueryKey(<Object?>['whole-result-chain']),
        (context) {
          seenPageParams.add(context.pageParam);
          return _User(
            seenPageParams.length,
            'page-${context.pageParam}',
          );
        },
        initialPageParam: 0,
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(1) : PageCursor.end,
      ).retry(
        (retry) => retry.strategy(
          retryIf: retry.result((data) {
                examinedResults += 1;
                return examinedResults == 1;
              }) &
              retry.maxRetries(1),
          delay: DelayPolicy.none(),
        ),
      );
      final client = QueryClient();

      final result = await client.fetchInfiniteQuery(recipe, pages: 2);

      expect(seenPageParams, <int>[0, 1, 0, 1]);
      expect(result.pageParams, <int>[0, 1]);
      expect(result.pages.map((page) => page.id), <int>[3, 4]);
      client.dispose();
    });
  });
}

Future<InfiniteData<Page, PageParam>> _fetchResolved<Page, PageParam>(
  InfiniteQuery<Page, PageParam> recipe,
) async {
  final client = QueryClient();
  try {
    final context = QueryContext(
      client: client,
      key: recipe.key,
      cancellationToken: QueryCancellationController().token,
    );
    return await recipe.resolved.plan.fetch(context)
        as InfiniteData<Page, PageParam>;
  } finally {
    client.dispose();
  }
}

Future<InfiniteData<Page, PageParam>> _executeResolved<Page, PageParam>(
  InfiniteQuery<Page, PageParam> recipe,
) async {
  final runtime = QueryRuntime.system();
  final timers = TimerOrchestrator(runtime.timers);
  final client = QueryClient(runtime: runtime);
  final cancellation = QueryCancellationController();
  try {
    final operation = recipe.resolved.plan.createOperation(
      QueryPlanExecution(
        client: client,
        runtime: runtime,
        timers: timers,
        cancellation: cancellation,
        onlineManager: client.onlineManager,
        focusManager: client.focusManager,
        defaultPolicy: RetryPolicy.none,
      ),
    );
    return await operation.result as InfiniteData<Page, PageParam>;
  } finally {
    timers.dispose();
    client.dispose();
  }
}

T _expectStaticType<T>(T value) => value;

final class _User {
  const _User(this.id, this.name);

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is _User && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

final class _UserPages extends InfiniteQuery<_User, int> {
  @override
  QueryKey get key => QueryKey(<Object?>['users']);

  @override
  int get initialPageParam => 0;

  @override
  Future<_User> fetchPage(InfinitePageContext<int> context) async {
    return _User(context.pageParam, 'user-${context.pageParam}');
  }

  @override
  PageCursor<int> getNextPageParam(InfiniteData<_User, int> data) {
    return PageCursor.more(data.length + 1);
  }
}

final class _InvalidMaxPages extends InfiniteQuery<int, int> {
  @override
  QueryKey get key => QueryKey(<Object?>['invalid-max']);

  @override
  int get initialPageParam => 0;

  @override
  int get maxPages => 0;

  @override
  int fetchPage(InfinitePageContext<int> context) => context.pageParam;

  @override
  PageCursor<int> getNextPageParam(InfiniteData<int, int> data) {
    return PageCursor.end;
  }
}
