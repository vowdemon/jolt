import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  late QueryClient defaultClient;

  setUpAll(() {
    final disposed = QueryClient()..dispose();
    expect(
      () => QueryClient.setDefault(disposed),
      throwsArgumentError,
    );

    defaultClient = QueryClient();
    QueryClient.setDefault(defaultClient);
  });

  tearDownAll(() {
    defaultClient.dispose();
  });

  test('configured default is stable once a query resolves it', () {
    expect(QueryClient.defaultClient, same(defaultClient));
    expect(QueryClient.defaultClient, same(defaultClient));

    final replacement = QueryClient();
    addTearDown(replacement.dispose);

    expect(
      () => QueryClient.setDefault(replacement),
      throwsStateError,
    );
  });

  test('ordinary query stages preserve default and explicit clients', () {
    final explicitClient = QueryClient();
    addTearDown(explicitClient.dispose);

    final defaultRaw = const _ValueQuery();
    final defaultTargets = _ordinaryStages(defaultRaw);
    expect(
      defaultTargets.map((target) => target.client),
      everyElement(same(defaultClient)),
    );

    final explicitRaw = _ValueQuery(client: explicitClient);
    final explicitTargets = _ordinaryStages(explicitRaw);
    expect(
      explicitTargets.map((target) => target.client),
      everyElement(same(explicitClient)),
    );

    final inline = query(
      QueryKey(const <Object?>['inline-client']),
      (_) => 1,
      client: explicitClient,
    ).select((value) => '$value').withObserver(enabled: false);
    expect(inline.client, same(explicitClient));
  });

  test('infinite query stages preserve default and explicit clients', () {
    final explicitClient = QueryClient();
    addTearDown(explicitClient.dispose);

    final defaultRaw = const _PagesQuery();
    final defaultTargets = _infiniteStages(defaultRaw);
    expect(
      defaultTargets.map((target) => target.client),
      everyElement(same(defaultClient)),
    );

    final explicitRaw = _PagesQuery(client: explicitClient);
    final explicitTargets = _infiniteStages(explicitRaw);
    expect(
      explicitTargets.map((target) => target.client),
      everyElement(same(explicitClient)),
    );

    final inline = infiniteQuery(
      QueryKey(const <Object?>['inline-infinite-client']),
      (context) => context.pageParam,
      client: explicitClient,
      initialPageParam: 0,
      getNextPageParam: (_) => PageCursor.end,
    ).select((data) => data.length).withPlaceholderData(0);
    expect(inline.client, same(explicitClient));
  });

  test('explicit client operations use their receiver instead of the binding',
      () async {
    final boundClient = QueryClient();
    final receiver = QueryClient();
    addTearDown(boundClient.dispose);
    addTearDown(receiver.dispose);

    final ordinary = query(
      QueryKey(const <Object?>['receiver-ordinary']),
      (_) => 7,
      client: boundClient,
    );
    await receiver.fetchQuery(ordinary);

    expect(receiver.getQueryData(ordinary), const QueryValue<int>.present(7));
    expect(boundClient.getQueryData(ordinary), const QueryValue<int>.absent());

    final infinite = infiniteQuery(
      QueryKey(const <Object?>['receiver-infinite']),
      (context) => context.pageParam,
      client: boundClient,
      initialPageParam: 3,
      getNextPageParam: (_) => PageCursor.end,
    );
    await receiver.fetchInfiniteQuery(infinite);

    expect(receiver.getQueryData(infinite).isPresent, isTrue);
    expect(boundClient.getQueryData(infinite).isAbsent, isTrue);
  });
}

List<AnyQueryTarget> _ordinaryStages(Query<int> raw) {
  final retry = raw.withRetry(
    (builder) => builder.strategy(retryIf: builder.maxRetries(1)),
  );
  final initial = retry.withInitialData(0);
  final selected = initial.select((value) => '$value');
  final observed = selected.withObserver(enabled: false);
  final placeholder = observed.withPlaceholderData('loading');
  return <AnyQueryTarget>[
    raw,
    retry,
    initial,
    selected,
    observed,
    placeholder,
  ];
}

List<AnyQueryTarget> _infiniteStages(InfiniteQuery<int, int> raw) {
  final retry = raw.withRetry(
    (builder) => builder.strategy(retryIf: builder.maxRetries(1)),
  );
  final initial = retry.withInitialData(
    InfiniteData<int, int>(pages: const <int>[0], pageParams: const <int>[0]),
  );
  final selected = initial.select((data) => data.length);
  final observed = selected.withObserver(enabled: false);
  final placeholder = observed.withPlaceholderData(0);
  return <AnyQueryTarget>[
    raw,
    retry,
    initial,
    selected,
    observed,
    placeholder,
  ];
}

final class _ValueQuery extends Query<int> {
  const _ValueQuery({super.client});

  @override
  QueryKey get key => QueryKey(const <Object?>['class-first-client']);

  @override
  int fetch(QueryContext context) => 1;
}

final class _PagesQuery extends InfiniteQuery<int, int> {
  const _PagesQuery({super.client});

  @override
  QueryKey get key => QueryKey(const <Object?>['class-first-infinite-client']);

  @override
  int get initialPageParam => 0;

  @override
  int fetchPage(InfinitePageContext<int> context) => context.pageParam;

  @override
  PageCursor<int> getNextPageParam(InfiniteData<int, int> data) {
    return PageCursor.end;
  }
}
