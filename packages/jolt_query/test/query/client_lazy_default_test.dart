import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('default client is created lazily and shared by unbound queries', () {
    final first = QueryClient.defaultClient;
    addTearDown(first.dispose);

    final ordinary = query(
      key: QueryKey(const <Object?>['lazy-default']),
      fetch: (_) => 1,
    );
    final infinite = infiniteQuery(
      QueryKey(const <Object?>['lazy-default-infinite']),
      (context) => context.pageParam,
      initialPageParam: 0,
      getNextPageParam: (_) => PageCursor.end,
    );

    expect(first.isDisposed, isFalse);
    expect(QueryClient.defaultClient, same(first));
    expect(ordinary.client, same(first));
    expect(infinite.client, same(first));
  });
}
