import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_query/jolt_query.dart';

void main() {
  group('InfiniteQueryWidget', () {
    testWidgets('retargets one observer and uses the new same-key recipe',
        (tester) async {
      final client = QueryClient();
      addTearDown(client.dispose);
      final key = QueryKey(<Object?>['infinite-widget', 'same-key']);
      final first = _infiniteTarget(client, key, value: 1);
      final second = _infiniteTarget(client, key, value: 2);
      final seen = <InfiniteQueryObserver<InfiniteData<int, int>>>[];

      Widget build(InfiniteQueryTarget<InfiniteData<int, int>> target) {
        return _host(
          InfiniteQueryWidget<InfiniteData<int, int>>(
            query: target,
            builder: (context, observer) {
              seen.add(observer);
              return Text('${observer.data.requireValue().pages.single}');
            },
          ),
        );
      }

      await tester.pumpWidget(build(first));
      final retained = seen.last;
      expect(find.text('0'), findsOneWidget);

      await tester.pumpWidget(build(second));
      expect(seen.last, same(retained));
      expect(find.text('0'), findsOneWidget);

      await retained.refetch();
      await tester.pump();
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('recreates the observer when the query client changes',
        (tester) async {
      final firstClient = QueryClient();
      final secondClient = QueryClient();
      addTearDown(firstClient.dispose);
      addTearDown(secondClient.dispose);
      final key = QueryKey(<Object?>['infinite-widget', 'client']);
      final observers = <InfiniteQueryObserver<InfiniteData<int, int>>>[];

      Widget build(QueryClient client, int seed) {
        return _host(
          InfiniteQueryWidget<InfiniteData<int, int>>(
            query: _infiniteTarget(client, key, value: seed),
            builder: (context, observer) {
              observers.add(observer);
              return Text('$seed');
            },
          ),
        );
      }

      await tester.pumpWidget(build(firstClient, 1));
      final original = observers.last;

      await tester.pumpWidget(build(secondClient, 2));

      expect(original.isDisposed, isTrue);
      expect(observers.last, isNot(same(original)));
      expect(firstClient.isDisposed, isFalse);
      expect(secondClient.isDisposed, isFalse);
    });
  });

  group('MutationWidget', () {
    testWidgets('same-key recipe updates preserve presentation',
        (tester) async {
      final client = QueryClient();
      addTearDown(client.dispose);
      final key = MutationKey(<Object?>['mutation-widget', 'same-key']);
      final first = mutation<int, String, void>(
        key: key,
        retention: RetentionPolicy.forever,
        mutate: (variables, context) => 'first-$variables',
      );
      final second = mutation<int, String, void>(
        key: key,
        retention: RetentionPolicy.forever,
        mutate: (variables, context) => 'second-$variables',
      );
      final observers = <MutationObserver<int, String, void>>[];

      Widget build(Mutation<int, String, void> recipe) {
        return _host(
          MutationWidget<int, String, void>(
            client: client,
            mutation: recipe,
            builder: (context, observer) {
              observers.add(observer);
              return Text(
                '${observer.status}:${observer.data.valueOrNull}',
              );
            },
          ),
        );
      }

      await tester.pumpWidget(build(first));
      final retained = observers.last;
      expect(retained.isIdle, isTrue);
      await retained.execute(1);
      await tester.pump();
      await tester.pump();
      expect(find.text('MutationStatus.success:first-1'), findsOneWidget);

      await tester.pumpWidget(build(second));
      expect(observers.last, same(retained));
      expect(find.text('MutationStatus.success:first-1'), findsOneWidget);

      await retained.execute(2);
      await tester.pump();
      await tester.pump();
      expect(find.text('MutationStatus.success:second-2'), findsOneWidget);
    });

    testWidgets('changed key resets and changed client recreates',
        (tester) async {
      final firstClient = QueryClient();
      final secondClient = QueryClient();
      addTearDown(firstClient.dispose);
      addTearDown(secondClient.dispose);
      final observers = <MutationObserver<int, int, void>>[];

      Widget build(QueryClient client, String key) {
        return _host(
          MutationWidget<int, int, void>(
            client: client,
            mutation: mutation<int, int, void>(
              key: MutationKey(<Object?>['mutation-widget', key]),
              retention: RetentionPolicy.forever,
              mutate: (variables, context) => variables,
            ),
            builder: (context, observer) {
              observers.add(observer);
              return Text('${observer.status}');
            },
          ),
        );
      }

      await tester.pumpWidget(build(firstClient, 'first'));
      final original = observers.last;
      await original.execute(1);
      await tester.pump();
      await tester.pump();
      expect(original.isSuccess, isTrue);

      await tester.pumpWidget(build(firstClient, 'second'));
      expect(observers.last, same(original));
      expect(original.isIdle, isTrue);

      await tester.pumpWidget(build(secondClient, 'second'));
      expect(original.isDisposed, isTrue);
      expect(observers.last, isNot(same(original)));
      expect(observers.last.isIdle, isTrue);
      expect(firstClient.isDisposed, isFalse);
      expect(secondClient.isDisposed, isFalse);
    });
  });
}

InfiniteQueryTarget<InfiniteData<int, int>> _infiniteTarget(
  QueryClient client,
  QueryKey key, {
  required int value,
}) {
  return infiniteQuery<int, int>(
    key,
    (context) => value,
    client: client,
    initialPageParam: 0,
    getNextPageParam: (data) => PageCursor.end,
    retry: RetryPolicy.none,
    retention: RetentionPolicy.forever,
  )
      .initialData(
        InfiniteData<int, int>(
          pages: <int>[0],
          pageParams: <int>[0],
        ),
      )
      .observer(enabled: false);
}

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: child,
  );
}
