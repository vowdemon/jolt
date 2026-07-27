import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart' show Signal;
import 'package:jolt_query/jolt_query.dart';

void main() {
  testWidgets('builds from every complete observer result transition',
      (tester) async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final completion = Completer<int>();
    final target = query<int>(
      key: QueryKey(<Object?>['result-transition']),
      fetch: (_) => completion.future,
      client: client,
      retry: RetryPolicy.none,
      retention: RetentionPolicy.forever,
    );
    var builds = 0;
    late QueryObserver<int> borrowedObserver;

    await tester.pumpWidget(
      _host(
        QueryWidget<int>(
          query: target,
          builder: (context, observer) {
            borrowedObserver = observer;
            builds += 1;
            return Text(
              '${observer.status}:${observer.fetchStatus}:'
              '${observer.data.valueOrNull}',
            );
          },
        ),
      ),
    );

    expect(find.text('QueryStatus.pending:FetchStatus.fetching:null'),
        findsOneWidget);
    final buildsWhileLoading = builds;

    completion.complete(7);
    await tester.pumpAndSettle();

    expect(find.text('QueryStatus.success:FetchStatus.idle:7'), findsOneWidget);
    expect(builds, greaterThan(buildsWhileLoading));
    expect(borrowedObserver.isDisposed, isFalse);
  });

  testWidgets('retargets one observer while the query client stays identical',
      (tester) async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final first = query<int>(
      key: QueryKey(<Object?>['stable-observer', 1]),
      fetch: (_) => 1,
      client: client,
      retention: RetentionPolicy.forever,
    ).initialData(1).observer(enabled: false);
    final second = query<int>(
      key: QueryKey(<Object?>['stable-observer', 2]),
      fetch: (_) => 2,
      client: client,
      retention: RetentionPolicy.forever,
    ).initialData(2).observer(enabled: false);
    final observed = <QueryObserver<int>>[];

    Widget build(QueryTarget<int> target) {
      return _host(
        QueryWidget<int>(
          query: target,
          builder: (context, observer) {
            observed.add(observer);
            return Text('${observer.key}:${observer.data.requireValue()}');
          },
        ),
      );
    }

    await tester.pumpWidget(build(first));
    final original = observed.last;
    expect(find.text('${first.key}:1'), findsOneWidget);

    await tester.pumpWidget(build(second));
    expect(find.text('${second.key}:2'), findsOneWidget);
    expect(observed.last, same(original));
    expect(original.isDisposed, isFalse);

    await tester.pumpWidget(_host(const SizedBox()));
    expect(original.isDisposed, isTrue);
  });

  testWidgets('same-key retarget is not a new mount', (tester) async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final key = QueryKey(<Object?>['same-key-retarget']);
    var fetches = 0;
    final observed = <QueryObserver<int>>[];

    QueryTarget<int> createTarget() {
      return query<int>(
        key: key,
        fetch: (_) => ++fetches,
        client: client,
        retry: RetryPolicy.none,
        retention: RetentionPolicy.forever,
      ).observer(
        staleTime: StalePolicy.immediate,
        refetchOnMount: RefetchPolicy.always,
      );
    }

    Widget build(QueryTarget<int> target) {
      return _host(
        QueryWidget<int>(
          query: target,
          builder: (context, observer) {
            observed.add(observer);
            return Text('${observer.data.valueOrNull}');
          },
        ),
      );
    }

    await tester.pumpWidget(build(createTarget()));
    await tester.pumpAndSettle();
    final original = observed.last;
    expect(fetches, 1);
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(build(createTarget()));
    await tester.pumpAndSettle();

    expect(observed.last, same(original));
    expect(fetches, 1);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('key retarget keeps the previous view as placeholder',
      (tester) async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final completion = Completer<String>();
    final first = query<String>(
      key: QueryKey(<Object?>['placeholder-switch', 1]),
      fetch: (_) => 'first',
      client: client,
      retry: RetryPolicy.none,
      retention: RetentionPolicy.forever,
    ).initialData('first').observer(enabled: false);
    final second = query<String>(
      key: QueryKey(<Object?>['placeholder-switch', 2]),
      fetch: (_) => completion.future,
      client: client,
      retry: RetryPolicy.none,
      retention: RetentionPolicy.forever,
    ).placeholder((previous) => previous);
    late QueryObserver<String> current;

    Widget build(QueryTarget<String> target) {
      return _host(
        QueryWidget<String>(
          query: target,
          builder: (context, observer) {
            current = observer;
            return Text(
              '${observer.data.valueOrNull}:'
              '${observer.isPlaceholderData}:'
              '${observer.fetchStatus}',
            );
          },
        ),
      );
    }

    await tester.pumpWidget(build(first));
    final original = current;
    expect(find.text('first:false:FetchStatus.idle'), findsOneWidget);

    await tester.pumpWidget(build(second));
    expect(current, same(original));
    expect(find.text('first:true:FetchStatus.fetching'), findsOneWidget);

    completion.complete('second');
    await tester.pumpAndSettle();
    expect(find.text('second:false:FetchStatus.idle'), findsOneWidget);
  });

  testWidgets('recreates the observer without disposing either query client',
      (tester) async {
    final firstClient = QueryClient();
    final secondClient = QueryClient();
    addTearDown(firstClient.dispose);
    addTearDown(secondClient.dispose);
    final first = query<int>(
      key: QueryKey(<Object?>['client-change']),
      fetch: (_) => 1,
      client: firstClient,
      retention: RetentionPolicy.forever,
    ).initialData(1).observer(enabled: false);
    final second = query<int>(
      key: QueryKey(<Object?>['client-change']),
      fetch: (_) => 2,
      client: secondClient,
      retention: RetentionPolicy.forever,
    ).initialData(2).observer(enabled: false);
    late QueryObserver<int> current;

    Widget build(QueryTarget<int> target) {
      return _host(
        QueryWidget<int>(
          query: target,
          builder: (context, observer) {
            current = observer;
            return Text('${observer.data.requireValue()}');
          },
        ),
      );
    }

    await tester.pumpWidget(build(first));
    final oldObserver = current;

    await tester.pumpWidget(build(second));
    final newObserver = current;

    expect(newObserver, isNot(same(oldObserver)));
    expect(oldObserver.isDisposed, isTrue);
    expect(newObserver.isDisposed, isFalse);
    expect(firstClient.isDisposed, isFalse);
    expect(secondClient.isDisposed, isFalse);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tracks the whole observer but not unrelated builder reads',
      (tester) async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final unrelated = Signal<int>(0);
    addTearDown(unrelated.dispose);
    final raw = query<int>(
      key: QueryKey(<Object?>['whole-only']),
      fetch: (_) => 1,
      client: client,
      retention: RetentionPolicy.forever,
    );
    final target = raw.initialData(1).observer(enabled: false);
    var builds = 0;

    await tester.pumpWidget(
      _host(
        QueryWidget<int>(
          query: target,
          builder: (context, observer) {
            builds += 1;
            return Text('${observer.data.requireValue()}:${unrelated.value}');
          },
        ),
      ),
    );
    final initialBuilds = builds;

    unrelated.value = 1;
    await tester.pumpAndSettle();
    expect(builds, initialBuilds);
    expect(find.text('1:0'), findsOneWidget);

    client.setQueryData(raw, 2);
    await tester.pumpAndSettle();
    expect(builds, greaterThan(initialBuilds));
    expect(find.text('2:1'), findsOneWidget);
  });

  testWidgets('an unrelated query cache write does not rebuild the builder',
      (tester) async {
    final client = QueryClient();
    addTearDown(client.dispose);
    final displayedRaw = query<int>(
      key: QueryKey(<Object?>['cache-isolation', 'displayed']),
      fetch: (_) => 1,
      client: client,
      retention: RetentionPolicy.forever,
    );
    final displayed = displayedRaw.initialData(1).observer(enabled: false);
    final unrelated = query<int>(
      key: QueryKey(<Object?>['cache-isolation', 'unrelated']),
      fetch: (_) => 2,
      client: client,
      retention: RetentionPolicy.forever,
    );
    final unrelatedObserver = client.observeQuery(
      unrelated.observer(enabled: false),
    );
    addTearDown(unrelatedObserver.dispose);
    var builds = 0;

    await tester.pumpWidget(
      _host(
        QueryWidget<int>(
          query: displayed,
          builder: (context, observer) {
            builds += 1;
            return Text('${observer.data.requireValue()}');
          },
        ),
      ),
    );
    final initialBuilds = builds;

    client.setQueryData(unrelated, 2);
    await tester.pumpAndSettle();

    expect(builds, initialBuilds);
    expect(find.text('1'), findsOneWidget);
    expect(client.getQueryData(unrelated).requireValue(), 2);
  });
}

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: child,
  );
}
