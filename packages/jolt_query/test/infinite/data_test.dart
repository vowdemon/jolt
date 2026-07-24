import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:jolt_query/src/foundation/query_cancellation.dart';
import 'package:jolt_query/src/infinite/data.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/client.dart';
import 'package:jolt_query/src/query/recipe.dart';
import 'package:test/test.dart';

void main() {
  group('InfiniteData', () {
    test('stores aligned pages and exact page parameters', () {
      final data = InfiniteData<String, int>(
        pages: <String>['first', 'second'],
        pageParams: <int>[0, 1],
      );

      expect(data.pages, <String>['first', 'second']);
      expect(data.pageParams, <int>[0, 1]);
      expect(data.length, 2);
      expect(data.isEmpty, isFalse);
      expect(data.isNotEmpty, isTrue);
    });

    test('defensively isolates mutable source collections', () {
      final pages = <String>['first'];
      final pageParams = <int>[0];
      final data = InfiniteData<String, int>(
        pages: pages,
        pageParams: pageParams,
      );

      pages
        ..clear()
        ..add('mutated');
      pageParams
        ..clear()
        ..add(99);

      expect(data.pages, <String>['first']);
      expect(data.pageParams, <int>[0]);
    });

    test('rejects either form of unequal length', () {
      expect(
        () => InfiniteData<String, int>(
          pages: <String>['one'],
          pageParams: const <int>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => InfiniteData<String, int>(
          pages: const <String>[],
          pageParams: <int>[1],
        ),
        throwsArgumentError,
      );
    });

    test('allows aligned nullable pages and parameters', () {
      final data = InfiniteData<String?, int?>(
        pages: <String?>[null],
        pageParams: <int?>[null],
      );

      expect(data.pages.single, isNull);
      expect(data.pageParams.single, isNull);
    });

    test('uses fixed deep FIC config independent of global defaults', () {
      final oldConfig = IList.defaultConfig;
      addTearDown(() => IList.defaultConfig = oldConfig);
      IList.defaultConfig = const ConfigList(
        isDeepEquals: false,
        cacheHashCode: true,
      );

      final left = InfiniteData<String, int>(
        pages: <String>['same'],
        pageParams: <int>[3],
      );
      final right = InfiniteData<String, int>(
        pages: <String>['same'],
        pageParams: <int>[3],
      );

      expect(
        left.pages.config,
        const ConfigList(isDeepEquals: true, cacheHashCode: false),
      );
      expect(left.pageParams.config, left.pages.config);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });
  });

  group('InfinitePageContext', () {
    test('delegates ordinary query capabilities without losing null', () {
      final cancellation = QueryCancellationController();
      final client = QueryClient();
      addTearDown(client.dispose);
      final key = QueryKey(<Object?>['nullable-page']);
      final queryContext = QueryContext(
        client: client,
        key: key,
        cancellationToken: cancellation.token,
        metadata: <String, Object?>{'source': 'test'},
      );
      final context = InfinitePageContext<String?>(
        pageParam: null,
        direction: InfiniteDirection.backward,
        queryContext: queryContext,
      );

      expect(context.pageParam, isNull);
      expect(context.direction, InfiniteDirection.backward);
      expect(context.queryContext, same(queryContext));
      expect(context.client, same(client));
      expect(context.key, same(key));
      expect(context.cancellationToken, same(cancellation.token));
      expect(context.metadata, <String, Object?>{'source': 'test'});
    });
  });

  group('PageCursor', () {
    test('more(null) is an explicit nullable continuation', () {
      const PageCursor<String?> cursor = PageCursor.more(null);

      expect(cursor, isA<PageCursorMore<String?>>());
      expect(cursor.isMore, isTrue);
      expect(cursor.isEnd, isFalse);
      expect(cursor.pageParamOrNull, isNull);
      expect(cursor.requirePageParam(), isNull);
      expect(_describeCursor(cursor), 'more:null');
    });

    test('end is covariantly assignable without a cast or type argument', () {
      PageCursor<String?> resolveEnd() => PageCursor.end;

      final PageCursor<String?> cursor = resolveEnd();
      expect(cursor, const PageCursorEnd());
      expect(cursor.isEnd, isTrue);
      expect(cursor.isMore, isFalse);
      expect(cursor.pageParamOrNull, isNull);
      expect(cursor.requirePageParam, throwsStateError);
      expect(_describeCursor(cursor), 'end');
    });

    test('more preserves ordinary values and value equality', () {
      const PageCursor<int> first = PageCursor.more(3);
      const PageCursor<int> second = PageCursorMore<int>(3);

      expect(first, second);
      expect(first.requirePageParam(), 3);
      expect(first.hashCode, second.hashCode);
    });
  });
}

String _describeCursor(PageCursor<String?> cursor) {
  return switch (cursor) {
    PageCursorEnd() => 'end',
    PageCursorMore<String?>(:final pageParam) => 'more:$pageParam',
  };
}
