import 'package:jolt_query/src/foundation/environment_manager.dart';
import 'package:jolt_query/src/foundation/query_cancellation.dart';
import 'package:jolt_query/src/foundation/query_runtime.dart';
import 'package:jolt_query/src/foundation/query_value.dart';
import 'package:jolt_query/src/foundation/timer_orchestrator.dart';
import 'package:jolt_query/src/keys/query_key.dart';
import 'package:jolt_query/src/query/policies.dart';
import 'package:jolt_query/src/query/recipe.dart';
import 'package:jolt_query/src/retry/retry_policy.dart';
import 'package:jolt_query/jolt_query.dart'
    show
        QueryClient,
        QueryClientObserverMethods,
        QueryObserver,
        QueryObserverResult;
import 'package:jolt/jolt.dart' show Effect, Signal;
import 'package:test/test.dart';

void main() {
  group('class-first query recipes', () {
    test('minimal external subclass runs through typed client and observer',
        () async {
      final recipe = _UserQuery();
      final client = QueryClient();
      addTearDown(client.dispose);

      _expectStaticType<Query<_User>>(recipe);
      expect(recipe.key, QueryKey(<Object?>['user', 1]));
      expect(recipe.retryPolicy, isNull);
      expect(recipe.stalePolicy, same(StalePolicy.immediate));
      expect(recipe.retentionPolicy, same(RetentionPolicy.standard));
      expect(recipe.networkMode, NetworkMode.online);
      expect(recipe.metadata, isEmpty);

      final Future<_User> fetched = client.fetchQuery(recipe);
      expect(await fetched, const _User(1, 'Ada'));

      final QueryObserver<_User> observer = client.observeQuery(recipe);
      addTearDown(observer.dispose);
      final Future<QueryObserverResult<_User>> refreshing = observer.refetch();
      final result = await refreshing;

      expect(result.data.requireValue(), const _User(1, 'Ada'));
      expect(result.isSuccess, isTrue);
    });

    test('inline factory infers raw data from fetch', () {
      final recipe = query(
        key: QueryKey(<Object?>['user', 2]),
        fetch: (context) async => const _User(2, 'Grace'),
      );

      _expectStaticType<Query<_User>>(recipe);
      expect(recipe.resolved.plan, isA<ResolvedQueryPlan<_User>>());
      expect(recipe.resolved.plan.configuredRetry, isNull);
    });

    test('explicit marker remains distinct from execution default', () {
      final inherited = query(
        key: QueryKey(<Object?>['inherited']),
        fetch: (context) => 1,
      );
      final explicitNone = query(
        key: QueryKey(<Object?>['none']),
        fetch: (context) => 1,
        retry: RetryPolicy.none,
      );
      final explicitStandard = query(
        key: QueryKey(<Object?>['standard']),
        fetch: (context) => 1,
        retry: RetryPolicy.standard,
      );

      expect(inherited.resolved.plan.configuredRetry, isNull);
      expect(
        explicitNone.resolved.plan.configuredRetry,
        same(RetryPolicy.none),
      );
      expect(
        explicitStandard.resolved.plan.configuredRetry,
        same(RetryPolicy.standard),
      );
    });

    test('inline marker slot rejects a custom Never retry strategy', () {
      final customMarker = RetryPolicy<Never>.custom(
        (retry) => retry.strategy(retryIf: retry.never),
      );

      expect(
        () => query<int>(
          key: QueryKey(<Object?>['invalid-marker']),
          fetch: (context) => 1,
          retry: customMarker,
        ),
        throwsArgumentError,
      );
    });

    test('typed retry is added after inference without widening data', () {
      final recipe = query(
        key: QueryKey(<Object?>['user']),
        fetch: (context) => const _User(1, 'Ada'),
      ).retry(
        (retry) => retry.strategy(retryIf: retry.maxRetries(2)),
      );

      _expectStaticType<Query<_User>>(recipe);
      expect(
        recipe.resolved.plan.configuredRetry,
        isA<RetryPolicy<_User>>(),
      );
    });

    test('legal transformations retain raw plan and exact view types', () {
      final raw = _UserQuery().retry(
        (retry) => retry.strategy(retryIf: retry.maxRetries(2)),
      );
      final initialized = raw.initialData(const _User(0, 'Loading'));
      final selected =
          initialized.select((user) => user.name).select((name) => name.length);
      final terminal = selected.observer(
        enabled: false,
        staleTime: StalePolicy.untilInvalidated,
        refetchOnMount: RefetchPolicy.always,
        pollingInterval: const Duration(seconds: 30),
        equality: (previous, next) => previous == next,
      );

      _expectStaticType<QueryView<_User>>(initialized);
      _expectStaticType<QueryView<int>>(selected);
      _expectStaticType<QueryTarget<int>>(terminal);
      expect(raw.resolved.plan.configuredRetry, isA<RetryPolicy<_User>>());
      expect(selected, isNot(isA<Query<Object?>>()));
      expect(terminal, isNot(isA<QueryView<int>>()));
      expect(terminal.key, raw.key);
      expect(
        terminal.resolved.initialData?.data,
        const _User(0, 'Loading'),
      );
      expect(terminal.resolved.select(const _User(1, 'Ada')), 3);
      expect(terminal.resolved.observer.enabled, isFalse);
      expect(
        terminal.resolved.observer.staleTime,
        same(StalePolicy.untilInvalidated),
      );
      expect(
        terminal.resolved.observer.refetchOnMount,
        RefetchPolicy.always,
      );
    });

    test('raw nullable initial and final placeholder preserve presence', () {
      final raw = query<String?>(
        key: QueryKey(<Object?>['nullable']),
        fetch: (context) => null,
      );
      final initialized = raw.initialData(null);
      final placeholder = initialized.placeholderData(null);

      expect(initialized.resolved.initialData, isNotNull);
      expect(initialized.resolved.initialData?.data, isNull);
      final resolved = placeholder.resolved.resolvePlaceholder(
        const QueryValue<String?>.absent(),
      );
      expect(resolved.isPresent, isTrue);
      expect(resolved.requireValue(), isNull);
    });

    test('placeholder resolver receives exact previous presence', () {
      final previous = QueryValue<String>.present('old');
      final target = query(
        key: QueryKey(<Object?>['value']),
        fetch: (context) => 'new',
      ).placeholder((value) => value);

      expect(target.resolved.resolvePlaceholder(previous), same(previous));
      expect(
        target.resolved.resolvePlaceholder(const QueryValue<String>.absent()),
        const QueryValue<String>.absent(),
      );
    });

    test('resolved plan freezes metadata and executes in its raw type',
        () async {
      final sourceMetadata = <String, Object?>{'source': 'test'};
      QueryContext? seenContext;
      final recipe = query(
        key: QueryKey(<Object?>['user']),
        fetch: (context) {
          seenContext = context;
          return const _User(1, 'Ada');
        },
        metadata: sourceMetadata,
      );
      final plan = recipe.resolved.plan;
      sourceMetadata['later'] = true;

      expect(plan.metadata, <String, Object?>{'source': 'test'});
      expect(
        () => plan.metadata['illegal'] = true,
        throwsUnsupportedError,
      );

      final runtime = QueryRuntime.system();
      final timers = TimerOrchestrator(runtime.timers);
      final online = OnlineManager();
      final focus = FocusManager();
      final client = QueryClient(runtime: runtime);
      final cancellation = QueryCancellationController();
      addTearDown(timers.dispose);
      addTearDown(online.dispose);
      addTearDown(focus.dispose);
      addTearDown(client.dispose);

      final operation = plan.createOperation(
        QueryPlanExecution(
          client: client,
          runtime: runtime,
          timers: timers,
          cancellation: cancellation,
          onlineManager: online,
          focusManager: focus,
          defaultPolicy: RetryPolicy.none,
        ),
      );

      expect(await operation.result, const _User(1, 'Ada'));
      expect(seenContext?.key, recipe.key);
      expect(seenContext?.cancellationToken, same(cancellation.token));
      expect(seenContext?.metadata, <String, Object?>{'source': 'test'});
    });

    test('heterogeneous targets expose only non-generic base', () {
      final targets = <AnyQueryTarget>[
        query(key: QueryKey(<Object?>['number']), fetch: (context) => 1),
        query(key: QueryKey(<Object?>['text']), fetch: (context) => 'value')
            .select((value) => value.length)
            .observer(
              enabled: false,
              equality: (previous, next) => previous.abs() == next.abs(),
            )
            .placeholderData(-1),
      ];

      expect(targets.map((target) => target.key).toList(), <QueryKey>[
        QueryKey(<Object?>['number']),
        QueryKey(<Object?>['text']),
      ]);
      expect(targets[0].resolved.selectObject(1), 1);
      expect(targets[1].resolved.selectObject('value'), 5);

      final erased = targets[1].resolved;
      expect(erased.observer.enabled, isFalse);
      expect(erased.observer.hasCustomEquality, isTrue);
      expect(erased.observer.areEqualObject(5, -5), isTrue);
      expect(erased.hasPlaceholder, isTrue);
      expect(
        erased.resolvePlaceholderObject(
          const QueryValue<Object?>.absent(),
        ),
        const QueryValue<Object?>.present(-1),
      );
    });

    test('presentation callbacks do not capture reactive dependencies', () {
      final dependency = Signal<int>(1);
      var runs = 0;
      final target = query(
        key: QueryKey(<Object?>['untracked']),
        fetch: (context) => 1,
      ).select((value) => value + dependency.value).observer(
        equality: (previous, next) {
          dependency.value;
          return previous == next;
        },
      ).placeholder((previous) {
        dependency.value;
        return previous;
      });
      final resolved = target.resolved;
      final effect = Effect(() {
        runs += 1;
        resolved.select(1);
        resolved.observer.areEqual(1, 1);
        resolved.resolvePlaceholder(const QueryValue<int>.absent());
      });
      addTearDown(effect.dispose);

      expect(runs, 1);
      dependency.value = 2;
      expect(runs, 1);
    });
  });

  group('query policies', () {
    final updatedAt = DateTime.utc(2025);

    test('staleness variants have deterministic behavior', () {
      final fresh = StaleState(
        now: updatedAt.add(const Duration(seconds: 5)),
        updatedAt: updatedAt,
        isInvalidated: false,
      );
      final invalidated = StaleState(
        now: updatedAt,
        updatedAt: updatedAt,
        isInvalidated: true,
      );

      expect(StalePolicy.immediate.isStale(fresh), isTrue);
      expect(StalePolicy.duration(const Duration(seconds: 10)).isStale(fresh),
          isFalse);
      expect(
          StalePolicy.duration(const Duration(seconds: 10)).isStale(
            StaleState(
              now: updatedAt.add(const Duration(seconds: 10)),
              updatedAt: updatedAt,
              isInvalidated: false,
            ),
          ),
          isTrue);
      expect(StalePolicy.untilInvalidated.isStale(fresh), isFalse);
      expect(StalePolicy.untilInvalidated.isStale(invalidated), isTrue);
      expect(StalePolicy.immutable.isStale(invalidated), isFalse);
      expect(StalePolicy.immutable.isImmutable, isTrue);
      expect(
          StalePolicy.resolve((state) => state.age.inSeconds.isOdd)
              .isStale(fresh),
          isTrue);
    });

    test('duration policies reject negative values', () {
      expect(
        () => StalePolicy.duration(const Duration(microseconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => RetentionPolicy.duration(const Duration(microseconds: -1)),
        throwsArgumentError,
      );
      expect(RetentionPolicy.standard.duration, const Duration(minutes: 5));
      expect(RetentionPolicy.forever.isForever, isTrue);
    });

    test('observer rejects non-positive polling intervals', () {
      final target = query(
        key: QueryKey(<Object?>['poll']),
        fetch: (context) => 1,
      );

      expect(
        () => target.observer(pollingInterval: Duration.zero),
        throwsArgumentError,
      );
    });
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
  @override
  QueryKey get key => QueryKey(<Object?>['user', 1]);

  @override
  Future<_User> fetch(QueryContext context) async => const _User(1, 'Ada');
}
