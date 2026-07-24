import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('target transformations and explicit receivers keep default lazy', () {
    final explicitClient = QueryClient();
    final receiver = QueryClient();
    final installedDefault = QueryClient();
    addTearDown(explicitClient.dispose);
    addTearDown(receiver.dispose);
    addTearDown(installedDefault.dispose);

    final ordinary = query(
      QueryKey(const <Object?>['explicit-before-default']),
      (_) => 1,
      client: explicitClient,
    ).select((value) => '$value').withPlaceholderData('loading');
    final infinite = infiniteQuery(
      QueryKey(const <Object?>['explicit-infinite-before-default']),
      (context) => context.pageParam,
      client: explicitClient,
      initialPageParam: 0,
      getNextPageParam: (_) => PageCursor.end,
    ).select((data) => data.length).withObserver(enabled: false);

    expect(ordinary.client, same(explicitClient));
    expect(infinite.client, same(explicitClient));

    final unboundOrdinary = query(
      QueryKey(const <Object?>['unbound-transformed']),
      (_) => 2,
    )
        .withInitialData(1)
        .select((value) => '$value')
        .withObserver(
          enabled: false,
        )
        .withPlaceholderData('loading');
    final ordinaryObserver = receiver.observeQuery(unboundOrdinary);
    addTearDown(ordinaryObserver.dispose);

    final unboundInfinite = infiniteQuery(
      QueryKey(const <Object?>['unbound-infinite-transformed']),
      (context) => context.pageParam,
      initialPageParam: 0,
      getNextPageParam: (_) => PageCursor.end,
    )
        .withInitialData(
          InfiniteData<int, int>(
            pages: const <int>[0],
            pageParams: const <int>[0],
          ),
        )
        .select((data) => data.length)
        .withObserver(enabled: false);
    final infiniteObserver = receiver.observeInfiniteQuery(unboundInfinite);
    addTearDown(infiniteObserver.dispose);

    QueryClient.setDefault(installedDefault);
    expect(QueryClient.defaultClient, same(installedDefault));
    expect(unboundOrdinary.client, same(installedDefault));
    expect(unboundInfinite.client, same(installedDefault));
  });
}
