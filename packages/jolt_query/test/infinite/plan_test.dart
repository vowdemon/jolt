import 'package:jolt_query/src/foundation/query_cancellation.dart';
import 'package:jolt_query/src/infinite/data.dart';
import 'package:jolt_query/src/infinite/recipe.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/client.dart';
import 'package:jolt_query/src/query/recipe.dart';
import 'package:test/test.dart';

void main() {
  group('resolved infinite fetch plans', () {
    test('initial pages are sequential and stop at a recomputed end cursor',
        () async {
      final seen = <int>[];
      final plan = ResolvedInfiniteQueryPlan<String, int>(
        initialPageParam: 0,
        fetchPage: (context) async {
          seen.add(context.pageParam);
          await Future<void>.delayed(Duration.zero);
          return 'page-${context.pageParam}';
        },
        getNextPageParam: (data) =>
            data.length < 2 ? PageCursor.more(data.length) : PageCursor.end,
        getPreviousPageParam: (data) => PageCursor.end,
      );

      final result = await plan.fetchPages(_context(), pages: 5);

      expect(seen, <int>[0, 1]);
      expect(result.pages, <String>['page-0', 'page-1']);
      expect(result.pageParams, <int>[0, 1]);
    });

    test('refresh starts at the first retained page parameter', () async {
      final plan = ResolvedInfiniteQueryPlan<String, int>(
        initialPageParam: 0,
        fetchPage: (context) => 'new-${context.pageParam}',
        getNextPageParam: (data) =>
            data.length == 1 ? const PageCursor<int>.more(11) : PageCursor.end,
        getPreviousPageParam: (data) => PageCursor.end,
      );
      final baseline = InfiniteData<String, int>(
        pages: <String>['old-10', 'old-11', 'old-12'],
        pageParams: <int>[10, 11, 12],
      );

      final refreshed = await plan.refresh(baseline, _context());

      expect(refreshed.pages, <String>['new-10', 'new-11']);
      expect(refreshed.pageParams, <int>[10, 11]);
      expect(baseline.pages, <String>['old-10', 'old-11', 'old-12']);
    });

    test('next and previous additions trim aligned opposite edges', () async {
      final plan = ResolvedInfiniteQueryPlan<String, int>(
        initialPageParam: 1,
        fetchPage: (context) => 'page-${context.pageParam}',
        getNextPageParam: (data) => PageCursor.more(
          data.pageParams.last + 1,
        ),
        getPreviousPageParam: (data) => PageCursor.more(
          data.pageParams.first - 1,
        ),
        maxPages: 2,
      );
      final baseline = InfiniteData<String, int>(
        pages: <String>['page-1', 'page-2'],
        pageParams: <int>[1, 2],
      );

      final next = await plan.fetchDirection(
        baseline,
        InfiniteDirection.forward,
        _context(),
      );
      final previous = await plan.fetchDirection(
        baseline,
        InfiniteDirection.backward,
        _context(),
      );

      expect(next.pages, <String>['page-2', 'page-3']);
      expect(next.pageParams, <int>[2, 3]);
      expect(previous.pages, <String>['page-0', 'page-1']);
      expect(previous.pageParams, <int>[0, 1]);
    });

    test('direction end returns the exact baseline without fetching', () async {
      var calls = 0;
      final plan = ResolvedInfiniteQueryPlan<String, int>(
        initialPageParam: 0,
        fetchPage: (context) {
          calls += 1;
          return 'unexpected';
        },
        getNextPageParam: (data) => PageCursor.end,
        getPreviousPageParam: (data) => PageCursor.end,
      );
      final baseline = InfiniteData<String, int>(
        pages: <String>['page-0'],
        pageParams: <int>[0],
      );

      final result = await plan.fetchDirection(
        baseline,
        InfiniteDirection.forward,
        _context(),
      );

      expect(result, same(baseline));
      expect(calls, 0);
    });
  });
}

QueryContext _context() {
  final client = QueryClient();
  addTearDown(client.dispose);
  return QueryContext(
    client: client,
    key: QueryKey(<Object?>['plan']),
    cancellationToken: QueryCancellationController().token,
  );
}
