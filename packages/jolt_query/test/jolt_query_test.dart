import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_query/jolt_query.dart';

class UserQueryKey extends QueryKey {
  const UserQueryKey(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

class AdminQueryKey extends QueryKey {
  const AdminQueryKey(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

class UserParentKey extends QueryKey {
  const UserParentKey();

  @override
  List<Object?> get props => const [];

  @override
  bool isParentOf(QueryKey other) => other is UserQueryKey;
}

class _TestClock {
  _TestClock(this._now);

  DateTime _now;

  DateTime call() => _now;

  void elapse(Duration duration) {
    _now = _now.add(duration);
  }
}

void main() {
  group('query_key.dart', () {
    test('equality uses runtimeType and props', () {
      expect(const UserQueryKey(1), equals(const UserQueryKey(1)));
      expect(const UserQueryKey(1), isNot(equals(const UserQueryKey(2))));
      expect(const UserQueryKey(1), isNot(equals(const AdminQueryKey(1))));
    });
  });

  group('query_options.dart', () {
    test('withDefaults fills missing durations', () {
      final opts = QueryOptions<int>(
        queryKey: const UserQueryKey(1),
        queryFn: () async => 1,
        enabled: false,
      ).withDefaults(
        defaultStaleTime: const Duration(seconds: 3),
        defaultGcTime: const Duration(minutes: 2),
      );

      expect(opts.staleTime, const Duration(seconds: 3));
      expect(opts.gcTime, const Duration(minutes: 2));
      expect(opts.enabled, isFalse);
    });
  });

  group('query_state.dart', () {
    test('initialData marks fetched, placeholder does not', () {
      final initial = QueryState<int>(
        status: QueryStatus.success,
        data: 1,
        dataUpdatedAt: DateTime(2024),
        fetchState: QueryFetchState.idle,
        isPlaceholderData: false,
      );
      expect(initial.isFetched, isTrue);
      expect(initial.isPlaceholder, isFalse);

      final placeholder = QueryState<int>(
        status: QueryStatus.success,
        data: 1,
        dataUpdatedAt: null,
        fetchState: QueryFetchState.idle,
        isPlaceholderData: true,
      );
      expect(placeholder.isFetched, isFalse);
      expect(placeholder.isPlaceholder, isTrue);
    });

    test('derived flags for loading and refetching', () {
      final loading = QueryState<int>(
        status: QueryStatus.loading,
        fetchState: QueryFetchState.pending,
        isPlaceholderData: false,
      );
      expect(loading.isInitialLoading, isTrue);
      expect(loading.isFetching, isTrue);

      final refetch = QueryState<int>(
        status: QueryStatus.loading,
        fetchState: QueryFetchState.pending,
        fetchCount: 1,
        isPlaceholderData: false,
      );
      expect(refetch.isRefetching, isTrue);
    });
  });

  group('query.dart', () {
    test('initialData sets fresh success', () {
      final now = DateTime(2024, 1, 1);
      final query = Query<int>(
        options: QueryOptions(
          queryKey: const UserQueryKey(99),
          queryFn: () async => 7,
          initialData: 5,
          staleTime: const Duration(seconds: 10),
        ),
        now: () => now,
        online: () => true,
      );

      final snap = query.snapshot;
      expect(snap.data, 5);
      expect(snap.isSuccess, isTrue);
      expect(query.isStale, isFalse);
    });

    test('placeholderData is stale and not fetched', () {
      final query = Query<int>(
        options: QueryOptions(
          queryKey: const UserQueryKey(88),
          queryFn: () async => 1,
          placeholderData: 0,
        ),
        now: DateTime.now,
        online: () => true,
      );

      final snap = query.snapshot;
      expect(snap.isPlaceholder, isTrue);
      expect(snap.isFetched, isFalse);
      expect(query.isStale, isTrue);
    });

    test('offline fetch pauses and resumes when online', () {
      fakeAsync((async) {
        var online = false;
        var calls = 0;
        final query = Query<int>(
          options: QueryOptions(
            queryKey: const UserQueryKey(77),
            queryFn: () async => ++calls,
          ),
          now: DateTime.now,
          online: () => online,
        );

        var completed = false;
        final future = query.fetch()..then((_) => completed = true);
        async.flushMicrotasks();
        expect(completed, isFalse);
        expect(query.snapshot.isPaused, isTrue);

        online = true;
        query.resumeIfPaused();
        async.flushMicrotasks();
        expect(completed, isTrue);
        expect(query.snapshot.isPaused, isFalse);
        future.ignore(); // silence lints
      });
    });

    test('addObserver triggers refetch when stale', () async {
      var now = DateTime(2024, 1, 1);
      DateTime _now() => now;
      var calls = 0;
      final query = Query<int>(
        options: QueryOptions(
          queryKey: const UserQueryKey(55),
          queryFn: () async => ++calls,
          staleTime: const Duration(seconds: 1),
        ),
        now: _now,
        online: () => true,
      );

      await query.fetch();
      expect(calls, 1);

      // become stale
      now = now.add(const Duration(seconds: 2));
      query.addObserver();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      query.removeObserver(); // avoid timers
      query.dispose();
    });
  });

  group('query_client.dart', () {
    test('caches successful results until stale', () async {
      final clock = _TestClock(DateTime(2024, 1, 1));
      final client = QueryClient(
        defaultStaleTime: const Duration(seconds: 5),
        now: clock.call,
      );

      var calls = 0;
      final options = QueryOptions<int>(
        queryKey: const UserQueryKey(1),
        queryFn: () async => ++calls,
      );

      final first = await client.fetchQuery(options);
      final second = await client.fetchQuery(options);

      expect(first, 1);
      expect(second, 1);
      expect(calls, 1, reason: 'second fetch should use cache while fresh');

      clock.elapse(const Duration(seconds: 6));
      final third = await client.fetchQuery(options);
      expect(third, 2, reason: 'stale data triggers refetch');
      expect(calls, 2);
    });

    test('invalidate marks query stale and refetches when requested', () async {
      final client = QueryClient(defaultStaleTime: const Duration(hours: 1));
      final key = const UserQueryKey(2);
      var calls = 0;

      await client.fetchQuery<int>(QueryOptions(
        queryKey: key,
        queryFn: () async => ++calls,
      ));

      expect(client.getQueryData<int>(key), 1);

      client.invalidateQueries(key, refetch: true);
      // Allow async refetch to finish
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(client.getQueryData<int>(key), 2,
          reason: 'refetch should refresh data after invalidation');
      expect(calls, 2);
    });

    test('setQueryData seeds cache and notifies observers', () async {
      final client = QueryClient();
      final key = const UserQueryKey(3);
      client.setQueryData<int>(key, 10);

      final query = client.ensureQuery<int>(QueryOptions(
        queryKey: key,
        queryFn: () async => 99,
      ));

      final recorded = <int?>[];
      Effect(() => recorded.add(query.state.value.data));

      query.invalidate();
      await query.fetch();

      expect(recorded.whereType<int>(), containsAll(<int>[10, 99]));
    });

    test('invalidateQueries cascades to child keys via isParentOf', () async {
      final client = QueryClient(defaultStaleTime: const Duration(hours: 1));
      final parentKey = const UserParentKey();
      final childKey1 = const UserQueryKey(10);
      final childKey2 = const UserQueryKey(11);

      var fetch1 = 0;
      var fetch2 = 0;

      await client.fetchQuery<int>(QueryOptions(
        queryKey: childKey1,
        queryFn: () async => ++fetch1,
      ));
      await client.fetchQuery<int>(QueryOptions(
        queryKey: childKey2,
        queryFn: () async => ++fetch2,
      ));

      expect(fetch1, 1);
      expect(fetch2, 1);

      client.invalidateQueries(parentKey, refetch: true);

      // allow refetch to complete
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(client.getQueryData<int>(childKey1), 2);
      expect(client.getQueryData<int>(childKey2), 2);
      expect(fetch1, 2);
      expect(fetch2, 2);
    });

    test('offline then online resumes paused queries', () {
      fakeAsync((async) {
        var calls = 0;
        final key = const UserQueryKey(12);
        final client = QueryClient(
          networkStatus: QueryNetworkStatus.offline,
          defaultStaleTime: const Duration(seconds: 1),
        );

        var completed = false;
        final future = client.fetchQuery<int>(QueryOptions(
          queryKey: key,
          queryFn: () async => ++calls,
        ))
          ..then((_) => completed = true);

        async.flushMicrotasks();
        expect(completed, isFalse);

        client.setNetworkStatus(QueryNetworkStatus.online);
        async.flushMicrotasks();
        expect(completed, isTrue);
        expect(calls, 1);
        future.ignore();
      });
    });

    test('gcTime of zero disposes when last observer removed', () {
      fakeAsync((fake) {
        final client = QueryClient(
          defaultGcTime: Duration.zero,
        );
        final key = const UserQueryKey(50);
        final query = client.ensureQuery<int>(QueryOptions(
          queryKey: key,
          queryFn: () async => 1,
        ));

        query.addObserver();
        query.removeObserver();
        // dispose runs synchronously for gcTime zero; we just ensure no pending timers
        expect(fake.pendingTimers, isEmpty);
      });
    });
  });

  group('flutter/query_builder.dart', () {
    testWidgets('QueryBuilder rebuilds when the query updates', (tester) async {
      final client = QueryClient(
        defaultStaleTime: const Duration(hours: 1),
        defaultGcTime: Duration.zero,
      );
      final key = const UserQueryKey(4);
    var calls = 0;

    await tester.pumpWidget(
      QueryClientProvider(
        client: client,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: QueryBuilder<int>(
            queryKey: key,
            queryFn: () async {
              calls++;
              return calls * 2;
            },
            builder: (context, state) {
              return Text(
                '${state.status.name}:${state.data ?? '-'}',
              );
            },
          ),
        ),
      ),
    );

    // First pump runs the fetch
    await tester.pump();
    await tester.pump();

    expect(find.text('success:2'), findsOneWidget);
    expect(calls, 1);

    client.invalidateQueries(key, refetch: true);
    await tester.pump();
    await tester.pump();

      expect(find.text('success:4'), findsOneWidget,
          reason: 'widget should rebuild with new data');
      expect(calls, 2);
    });
  });
}
