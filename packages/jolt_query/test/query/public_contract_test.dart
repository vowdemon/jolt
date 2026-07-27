import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  group('public class-first query contracts', () {
    test('external Query subclass runs through client and observer', () async {
      const source = _UserQuery();
      final client = QueryClient();
      addTearDown(client.dispose);

      _expectStaticType<Query<_User>>(source);

      final fetched = await client.fetchQuery(source);
      expect(fetched, const _User(1, 'Ada'));

      final QueryObserver<_User> observer = client.observeQuery(
        source.observer(enabled: false),
      );
      addTearDown(observer.dispose);

      final result = await observer.refetch();
      expect(result.data.requireValue(), const _User(1, 'Ada'));
      expect(result.isSuccess, isTrue);
    });

    test('external InfiniteQuery subclass runs through client and observer',
        () async {
      const source = _UserPages();
      final client = QueryClient();
      addTearDown(client.dispose);

      _expectStaticType<InfiniteQuery<_User, int>>(source);

      final initial = await client.fetchInfiniteQuery(source);
      expect(initial.pages, const <_User>[_User(0, 'user-0')]);
      expect(initial.pageParams, <int>[0]);

      final InfiniteQueryObserver<InfiniteData<_User, int>> observer =
          client.observeInfiniteQuery(
        source.observer(enabled: false),
      );
      addTearDown(observer.dispose);

      final next = await observer.fetchNextPage();
      expect(
        next.data.requireValue().pages,
        const <_User>[_User(0, 'user-0'), _User(1, 'user-1')],
      );
      expect(next.data.requireValue().pageParams, <int>[0, 1]);
    });
  });

  test('staged retry initial selection and presentation produce final view',
      () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final target = query(
      key: QueryKey(<Object?>['public-staged-query']),
      fetch: (_) => const _User(1, 'Ada'),
    )
        .retry(
          (retry) => retry.strategy(retryIf: retry.never),
        )
        .initialData(const _User(0, 'Loading'))
        .select((user) => user.name)
        .select((name) => name.length)
        .placeholderData(-1)
        .observer(enabled: false);

    _expectStaticType<QueryTarget<int>>(target);

    final QueryObserver<int> observer = client.observeQuery(target);
    addTearDown(observer.dispose);
    expect(observer.data.requireValue(), 'Loading'.length);

    final result = await observer.refetch();
    expect(result.data.requireValue(), 'Ada'.length);
    expect(observer.data.requireValue(), 'Ada'.length);
  });

  test('inline marker policies retain inferred concrete data', () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final none = query(
      key: QueryKey(<Object?>['public-marker-none']),
      fetch: (_) => const _User(1, 'None'),
      retry: RetryPolicy.none,
    );
    final standard = query(
      key: QueryKey(<Object?>['public-marker-standard']),
      fetch: (_) => const _User(2, 'Standard'),
      retry: RetryPolicy.standard,
    );

    _expectStaticType<Query<_User>>(none);
    _expectStaticType<Query<_User>>(standard);

    final noneResult = await client.fetchQuery(none);
    final standardResult = await client.fetchQuery(standard);
    _expectStaticType<_User>(noneResult);
    _expectStaticType<_User>(standardResult);
    expect(noneResult.name, 'None');
    expect(standardResult.name, 'Standard');
  });

  test('exception-only custom retry retains data type and retries', () async {
    final client = QueryClient();
    addTearDown(client.dispose);
    var attempts = 0;
    final source = query(
      key: QueryKey(<Object?>['public-custom-retry']),
      fetch: (_) {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('retry once');
        }
        return const _User(1, 'Retried');
      },
    ).retry(
      (retry) => retry.strategy(
        retryIf: retry.exceptionType<StateError>() & retry.maxRetries(1),
      ),
    );

    _expectStaticType<Query<_User>>(source);

    final result = await client.fetchQuery(source);
    _expectStaticType<_User>(result);
    expect(result, const _User(1, 'Retried'));
    expect(attempts, 2);
  });
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

final class _UserQuery extends Query<_User> {
  const _UserQuery();

  @override
  QueryKey get key => QueryKey(<Object?>['public-user', 1]);

  @override
  _User fetch(QueryContext context) => const _User(1, 'Ada');
}

final class _UserPages extends InfiniteQuery<_User, int> {
  const _UserPages();

  @override
  QueryKey get key => QueryKey(<Object?>['public-user-pages']);

  @override
  int get initialPageParam => 0;

  @override
  _User fetchPage(InfinitePageContext<int> context) {
    return _User(context.pageParam, 'user-${context.pageParam}');
  }

  @override
  PageCursor<int> getNextPageParam(InfiniteData<_User, int> data) {
    return data.length < 2
        ? PageCursor<int>.more(data.pageParams.last + 1)
        : PageCursor.end;
  }
}
