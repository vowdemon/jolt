import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jolt_flutter/jolt_flutter.dart' show Signal, batch;
import 'package:jolt_query/jolt_query.dart';
import 'package:retry_plus/retry_plus.dart' show DelayPolicy;

const todoWriteScope = MutationScope('todo-writes');

typedef CounterRollback = ({
  QueryDataSnapshot<int> before,
  int optimisticRevision,
});

enum DemoStalePreset {
  immediate,
  fiveSeconds,
  untilInvalidated,
  immutable,
}

extension DemoStalePresetPresentation on DemoStalePreset {
  String get label => switch (this) {
        DemoStalePreset.immediate => '0 seconds',
        DemoStalePreset.fiveSeconds => '5 seconds',
        DemoStalePreset.untilInvalidated => 'Until invalidated',
        DemoStalePreset.immutable => 'Immutable',
      };

  String get codeLabel => switch (this) {
        DemoStalePreset.immediate => 'immediate',
        DemoStalePreset.fiveSeconds => 'duration(const Duration(seconds: 5))',
        DemoStalePreset.untilInvalidated => 'untilInvalidated',
        DemoStalePreset.immutable => 'immutable',
      };

  StalePolicy get policy => switch (this) {
        DemoStalePreset.immediate => StalePolicy.immediate,
        DemoStalePreset.fiveSeconds =>
          StalePolicy.duration(const Duration(seconds: 5)),
        DemoStalePreset.untilInvalidated => StalePolicy.untilInvalidated,
        DemoStalePreset.immutable => StalePolicy.immutable,
      };
}

int _projectPageFromKey(QueryKey key) => key.parts[1]! as int;

/// Owns the complete feature-tour runtime independently from Flutter widgets.
final class DemoController extends ChangeNotifier {
  DemoController() {
    client = QueryClient(
      queryCallbacks: QueryCacheCallbacks(
        onSuccess: (data, snapshot) {
          _recordQueryCallback('onSuccess', snapshot);
        },
        onError: (failure, snapshot) {
          _recordQueryCallback('onError', snapshot);
        },
        onSettled: (data, failure, snapshot) {
          _recordQueryCallback('onSettled', snapshot);
        },
      ),
      mutationCallbacks: MutationCacheCallbacks(
        onSettled: (
          data,
          failure,
          variables,
          onMutateResult,
          context,
        ) {
          final outcome = failure == null ? 'success' : 'error';
          _record(
            'Mutation lifecycle onSettled: '
            '${context.key ?? 'anonymous mutation'} ($outcome).',
          );
        },
      ),
    );
    client.bindFlutterLifecycle();
    client.registerQueryDefaults(
      const QueryDefaults(
        staleTime: StalePolicy.untilInvalidated,
        retention: RetentionPolicy.forever,
        refetchOnFocus: RefetchPolicy.stale,
        refetchOnReconnect: RefetchPolicy.stale,
      ),
      key: QueryKey(<Object?>['todos']),
    );
    client.registerMutationDefaults(
      const MutationDefaults(retention: RetentionPolicy.forever),
      key: MutationKey(<Object?>['todos']),
    );

    todosQuery = TodosQuery(api);
    todosObserver = client.observeQuery(
      todosQuery.observer(enabled: false),
    );
    todoCountObserver = client.observeQuery(
      todosQuery
          .select((collection) => collection.items.length)
          .observer(enabled: false),
    );

    pollingQuery = query<int>(
      key: QueryKey(<Object?>['demo', 'polling']),
      fetch: (_) => api.nextPoll(),
      retry: RetryPolicy.none,
    );
    pollingObserver = client.observeQuery(
      pollingQuery.initialData(0).observer(
            refetchOnMount: RefetchPolicy.never,
            refetchOnFocus: RefetchPolicy.never,
            pollingIntervalResolver: _pollingIntervalFor,
            pollingEnabled: true,
            pollInBackground: false,
          ),
    );

    greetingQuery = query<String>(
      key: QueryKey(<Object?>['demo', 'greeting']),
      fetch: (_) => api.loadUnstableGreeting(),
    ).retry(
      (retry) => retry.strategy(
        name: 'greeting',
        retryIf: retry.exceptions & retry.maxRetries(2),
        delay: DelayPolicy.none(),
        onRetry: (attempt) {
          _record('Query retry after attempt ${attempt.attemptNumber}.');
        },
      ),
    );

    renameMutation = RenameTodo(api, todosQuery, 1);
    synchronizeAction = action<String, void>(
      key: MutationKey(<Object?>['todos', 'synchronize']),
      scope: todoWriteScope,
      mutate: (_) => api.synchronizeTodos(),
    );

    counterQuery = query<int>(
      key: QueryKey(<Object?>['counter']),
      fetch: (_) => api.counter,
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
    );
    client.setQueryData(counterQuery, api.counter);
    counterObserver = client.observeQuery(
      counterQuery.observer(enabled: false),
    );
    incrementMutation = mutation<int, int, CounterRollback>(
      key: MutationKey(<Object?>['counter', 'increment']),
      onMutate: (delta, context) {
        final before = context.client.snapshotQueryData(counterQuery);
        final optimistic = context.client.setQueryData(
          counterQuery,
          before.data.requireValue() + delta,
        );
        return (
          before: before,
          optimisticRevision: optimistic.revision,
        );
      },
      mutate: (delta, context) => api.incrementCounter(delta),
      onSuccess: (data, delta, onMutateResult, context) {
        context.client.setQueryData(counterQuery, data);
      },
      onError: (failure, delta, onMutateResult, context) {
        if (onMutateResult.isAbsent) return;
        final rollback = onMutateResult.requireValue();
        final restored = context.client.restoreQueryData(
          counterQuery,
          rollback.before,
          ifRevision: rollback.optimisticRevision,
        );
        _record('Counter rollback restored=$restored.');
      },
    ).retry(
      (retry) => retry.strategy(
        name: 'idempotent-counter',
        retryIf: retry.exceptions & retry.maxRetries(1),
        delay: DelayPolicy.none(),
        onRetry: (attempt) {
          _record('Mutation retry after attempt ${attempt.attemptNumber}.');
        },
      ),
    );

    dataLaneQuery = query<int>(
      key: QueryKey(<Object?>['demo', 'data-lane']),
      fetch: (_) => api.loadDataLaneValue(),
      retry: RetryPolicy.none,
      staleTime: StalePolicy.immediate,
    );
    client.setQueryData(dataLaneQuery, 0);
    dataLaneObserver = client.observeQuery(
      dataLaneQuery.observer(enabled: false),
    );

    feedQuery = infiniteQuery<String, int>(
      QueryKey(<Object?>['feed']),
      (context) => api.loadFeedPage(context.pageParam),
      client: client,
      initialPageParam: 0,
      getNextPageParam: (data) {
        final current = data.pageParams.last;
        if (current >= 5) return PageCursor.end;
        return PageCursor<int>.more(current + 1);
      },
      maxPages: 3,
      retry: RetryPolicy.none,
      staleTime: StalePolicy.untilInvalidated,
    );

    streamQueries = <StreamRefetchMode, Query<IList<int>>>{
      for (final mode in StreamRefetchMode.values)
        mode: query<IList<int>>(
          key: QueryKey(<Object?>['stream', mode.name]),
          fetch: streamedListQuery<int>(
            stream: (_) => api.numberStream(mode),
            mode: mode,
          ),
        ).retry(
          (retry) => retry.strategy(
            name: 'stream-${mode.name}',
            retryIf: retry.exceptions & retry.maxRetries(1),
            delay: DelayPolicy.fixed(const Duration(milliseconds: 800)),
            onRetry: (attempt) {
              _record(
                '${mode.name} stream failure accepted for retry; '
                'the next attempt will apply that mode’s baseline rule.',
              );
            },
          ),
        ),
    };
    streamObservers = <StreamRefetchMode, QueryObserver<IList<int>>>{
      for (final entry in streamQueries.entries)
        entry.key: client.observeQuery(
          entry.value.observer(enabled: false).placeholderData(IList<int>()),
        ),
    };

    _queryEvents = client.queryCache.events.listen(_onQueryEvent);
    _mutationEvents = client.mutationCache.events.listen(_onMutationEvent);
    _record('Runtime ready. Every card below uses the same QueryClient.');
  }

  final DemoApi api = DemoApi();
  late final QueryClient client;

  final Signal<int> projectPage = Signal<int>(1);
  final Signal<DemoStalePreset> stalePreset =
      Signal<DemoStalePreset>(DemoStalePreset.fiveSeconds);
  final Signal<bool> keepPreviousProjects = Signal<bool>(true);
  late final TodosQuery todosQuery;
  late final QueryObserver<TodoCollection> todosObserver;
  late final QueryObserver<int> todoCountObserver;

  late final Query<int> pollingQuery;
  late final QueryObserver<int> pollingObserver;
  late final Query<String> greetingQuery;

  late final RenameTodo renameMutation;
  late final Mutation<NoVariables, String, void> synchronizeAction;

  late final Query<int> counterQuery;
  late final QueryObserver<int> counterObserver;
  late final Mutation<int, int, CounterRollback> incrementMutation;

  late final Query<int> dataLaneQuery;
  late final QueryObserver<int> dataLaneObserver;

  late final InfiniteQuery<String, int> feedQuery;

  late final Map<StreamRefetchMode, Query<IList<int>>> streamQueries;
  late final Map<StreamRefetchMode, QueryObserver<IList<int>>> streamObservers;

  late final StreamSubscription<QueryCacheEvent> _queryEvents;
  late final StreamSubscription<MutationCacheEvent> _mutationEvents;
  final Set<String> _busy = <String>{};
  final List<String> _activity = <String>[];
  var _disposed = false;
  var _scopeRun = 0;

  StreamRefetchMode streamMode = StreamRefetchMode.reset;
  String? lastGreeting;
  int? lastSingleFlightRequests;
  bool? serverOnlyCacheUnchanged;
  int? lastInvalidateRequests;
  bool? retainedDataAfterInvalidation;
  bool? retainedDataDuringRefetch;
  bool? consumersSynchronizedAfterRefetch;
  String dataLaneExplanation =
      'Run either experiment: both start the same delayed query, then write '
      'a manual cache value while it is active.';

  bool get isOnline => client.onlineManager.isOnline;
  bool get isFocused => client.focusManager.isFocused;
  bool isBusy(String operation) => _busy.contains(operation);
  List<String> get activity => List<String>.unmodifiable(_activity);
  List<String> get transportLog => api.writeLog;
  int get queryEntryCount => client.queryCache.snapshots.length;
  int get mutationEntryCount => client.mutationCache.snapshots.length;
  int get projectPageCount => DemoApi.projectPageCount;
  int get projectTotalRequests => api.projectTotalRequests;
  int get projectServerRevision => api.projectServerRevision;
  bool get isProjectsBusy => const <String>{
        'projects-focus',
        'projects-reconnect',
        'projects-invalidate',
        'projects-refetch',
        'projects-reset',
      }.any(_busy.contains);
  Duration get nextPollingInterval =>
      _pollingIntervalFor(pollingObserver.snapshot);
  List<QueryCacheSnapshot> get projectCacheSnapshots {
    final prefix = QueryKey(<Object?>['projects']);
    final snapshots = client.queryCache.snapshots
        .where((snapshot) => snapshot.key.startsWith(prefix))
        .toList(growable: false)
      ..sort(
        (left, right) => _projectPageFromKey(left.key).compareTo(
          _projectPageFromKey(right.key),
        ),
      );
    return List<QueryCacheSnapshot>.unmodifiable(snapshots);
  }

  int projectRequestCount(int page) => api.projectRequestCount(page);
  int streamAttemptCount(StreamRefetchMode mode) =>
      api.streamAttemptCount(mode);

  static Duration _pollingIntervalFor(QueryObserverResult<int> result) {
    final value = result.data.valueOrNull ?? 0;
    return Duration(seconds: value.isEven ? 2 : 1);
  }

  QueryCacheSnapshot? projectCacheSnapshot(int page) {
    final key = QueryKey(<Object?>['projects', page]);
    for (final snapshot in projectCacheSnapshots) {
      if (snapshot.key == key) return snapshot;
    }
    return null;
  }

  bool get isQueryFlowBusy => isBusy('query-flow') || isBusy('cache');
  QueryCacheSnapshot? get todoCacheSnapshot {
    for (final snapshot in client.queryCache.snapshots) {
      if (snapshot.key == todosQuery.key) return snapshot;
    }
    return null;
  }

  int get exactTodoCacheEntries => client.queryCache.snapshots
      .where((snapshot) => snapshot.key == todosQuery.key)
      .length;
  QueryObserver<IList<int>> get selectedStreamObserver =>
      streamObservers[streamMode]!;

  void selectProjectPage(int page) {
    final nextPage = page.clamp(1, projectPageCount);
    if (projectPage.peek == nextPage) return;
    projectPage.value = nextPage;
    _record(
      'projectPage changed to $nextPage; QueryWidget received '
      "QueryKey(['projects', $nextPage]).",
    );
  }

  void previousProjectPage() => selectProjectPage(projectPage.peek - 1);

  void nextProjectPage() => selectProjectPage(projectPage.peek + 1);

  void selectStalePreset(DemoStalePreset preset) {
    if (stalePreset.peek == preset) return;
    stalePreset.value = preset;
    _record('staleTime changed to ${preset.label}.');
  }

  void toggleKeepPreviousProjects() {
    final next = !keepPreviousProjects.peek;
    keepPreviousProjects.value = next;
    _record(
      next
          ? 'Previous page data will be shown as placeholder while a new key '
              'loads.'
          : 'New keys will show their own pending state without placeholder '
              'data.',
    );
  }

  void changeProjectsOnServer() {
    final revision = api.changeProjectsOnServer();
    _record(
      'Fake server advanced to project revision $revision; cached data did '
      'not change.',
    );
  }

  Future<void> simulateProjectFocusCycle() {
    return _guard('projects-focus', () async {
      final requestsBefore = projectTotalRequests;
      client.focusManager.isFocused = false;
      _record('Simulated app background for the current project query.');
      await Future<void>.delayed(const Duration(milliseconds: 180));
      client.focusManager.isFocused = true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      _record(
        'Focus restored; stale policy started '
        '${projectTotalRequests - requestsBefore} request(s).',
      );
    });
  }

  Future<void> simulateProjectReconnect() {
    return _guard('projects-reconnect', () async {
      final requestsBefore = projectTotalRequests;
      client.onlineManager.isOnline = false;
      _record('Simulated an offline transition for the project query.');
      await Future<void>.delayed(const Duration(milliseconds: 180));
      client.onlineManager.isOnline = true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      _record(
        'Connectivity restored; stale policy started '
        '${projectTotalRequests - requestsBefore} request(s).',
      );
    });
  }

  Future<void> invalidateCurrentProjects(QueryKey key) {
    return _guard('projects-invalidate', () async {
      final requestsBefore = projectTotalRequests;
      final result = await client.invalidateQueries(
        filter: QueryFilter(key: key, exact: true),
        refetchType: QueryRefetchTarget.active,
        cancelRefetch: true,
      );
      _record(
        'Invalidated active $key; affected ${result.affected} cache entry and '
        'started ${projectTotalRequests - requestsBefore} request(s); '
        'skippedNonExecutable=${result.skippedNonExecutable}.',
      );
    });
  }

  Future<void> refetchCurrentProjects(QueryObserver<ProjectPage> observer) {
    return _guard('projects-refetch', () async {
      final requestsBefore = projectTotalRequests;
      final result = await observer.refetch();
      _record(
        'Explicit observer.refetch completed as ${result.status.name}; '
        'started ${projectTotalRequests - requestsBefore} request(s), even '
        'when immutable freshness makes bulk work static.',
      );
    });
  }

  Future<void> resetProjectsDemo() {
    return _guard('projects-reset', () async {
      api.resetProjectsServer();
      final result = await client.resetQueries(
        filter: QueryFilter(key: QueryKey(<Object?>['projects'])),
        refetchType: QueryRefetchTarget.none,
      );
      batch(() {
        projectPage.value = 1;
        stalePreset.value = DemoStalePreset.fiveSeconds;
        keepPreviousProjects.value = true;
      });
      _notify();
      await client.fetchQuery(
        ProjectsQuery(client: client, api: api, page: 1),
      );
      _record(
        'Reset the project server and ${result.affected} project cache '
        'entry/entries; page 1 was activated again.',
      );
    });
  }

  void toggleOnline() {
    client.onlineManager.isOnline = !isOnline;
    _record('Simulated connectivity: ${isOnline ? 'online' : 'offline'}.');
  }

  void toggleFocused() {
    client.focusManager.isFocused = !isFocused;
    _record('Simulated app focus: ${isFocused ? 'focused' : 'background'}.');
  }

  void selectStreamMode(StreamRefetchMode mode) {
    if (streamMode == mode || isBusy('stream')) return;
    streamMode = mode;
    _record('Selected StreamRefetchMode.${mode.name}.');
  }

  Future<void> loadTodos() {
    return _guard('query-flow', () async {
      final readsBefore = api.openTodoReads;
      retainedDataDuringRefetch = null;
      consumersSynchronizedAfterRefetch = null;
      _record(
        'Consumer A and Consumer B requested the same key concurrently.',
      );
      final rawLoad = todosObserver.refetch(cancelRefetch: false);
      final countLoad = todoCountObserver.refetch(cancelRefetch: false);
      final result = await rawLoad;
      await countLoad;
      lastSingleFlightRequests = api.openTodoReads - readsBefore;
      if (result.failure case final failure?) {
        _record('Todo query failed: ${failure.error}.');
      } else {
        _record(
          'Two consumers completed through $lastSingleFlightRequests '
          'network request(s).',
        );
      }
    });
  }

  Future<void> changeServerTodos() {
    return _guard('query-flow', () async {
      if (client.getQueryData(todosQuery).isAbsent) {
        _record('Run step 1 first so server and cache can visibly diverge.');
        return;
      }
      final cacheRevisionBefore = todoCacheSnapshot?.revision;
      final added = api.changeOpenTodosOnServer();
      serverOnlyCacheUnchanged =
          todoCacheSnapshot?.revision == cacheRevisionBefore;
      retainedDataDuringRefetch = null;
      consumersSynchronizedAfterRefetch = null;
      _record(
        'Fake server advanced to revision ${api.serverRevision} and added '
        '“${added.title}”; cache revision unchanged='
        '$serverOnlyCacheUnchanged.',
      );
    });
  }

  Future<void> invalidateTodos() {
    return _guard('query-flow', () async {
      final before = client.getQueryData(todosQuery);
      if (before.isAbsent) {
        _record('Run step 1 first so invalidation can retain cached data.');
        return;
      }
      final readsBefore = api.openTodoReads;
      final result = await client.invalidateQueries(
        filter: QueryFilter(key: todosQuery.key, exact: true),
        refetchType: QueryRefetchTarget.none,
      );
      final after = client.getQueryData(todosQuery);
      lastInvalidateRequests = api.openTodoReads - readsBefore;
      retainedDataAfterInvalidation = after.isPresent &&
          identical(before.requireValue(), after.requireValue());
      _record(
        'Invalidated ${result.affected} exact cache entry; retained data='
        '$retainedDataAfterInvalidation, requests=$lastInvalidateRequests.',
      );
    });
  }

  Future<void> backgroundRefetchTodos() {
    return _guard('query-flow', () async {
      if (todosObserver.data.isAbsent) {
        _record('Run step 1 first so the refetch has cached data to retain.');
        return;
      }
      final before = todosObserver.data.requireValue();
      final operation = todosObserver.refetch(cancelRefetch: false);
      await Future<void>.delayed(Duration.zero);
      final during = todosObserver.snapshot;
      retainedDataDuringRefetch = during.isRefetching &&
          during.data.isPresent &&
          during.data.requireValue().serverRevision == before.serverRevision;
      _record(
        retainedDataDuringRefetch!
            ? 'Background refetch kept cached revision '
                '${before.serverRevision} visible while fetching.'
            : 'Background refetch retention proof was not observed '
                '(current fetch status: ${during.fetchStatus.name}).',
      );
      final result = await operation;
      if (result.failure case final failure?) {
        _record('Background refetch failed: ${failure.error}.');
      } else if (result.data.isPresent) {
        await Future<void>.delayed(Duration.zero);
        final selected = todoCountObserver.snapshot.data;
        consumersSynchronizedAfterRefetch = selected.isPresent &&
            selected.requireValue() == result.data.requireValue().items.length;
        _record(
          'Both consumers synchronized to server revision '
          '${result.data.requireValue().serverRevision}: '
          '$consumersSynchronizedAfterRefetch.',
        );
      }
    });
  }

  Future<void> resetQueryDemo() {
    return _guard('query-flow', () async {
      final result = await client.resetQueries(
        filter: QueryFilter(key: todosQuery.key, exact: true),
        refetchType: QueryRefetchTarget.none,
      );
      api.resetTodoServer();
      lastSingleFlightRequests = null;
      serverOnlyCacheUnchanged = null;
      lastInvalidateRequests = null;
      retainedDataAfterInvalidation = null;
      retainedDataDuringRefetch = null;
      consumersSynchronizedAfterRefetch = null;
      _record(
        'Reset the fake server and ${result.affected} exact cache entry.',
      );
    });
  }

  Future<void> tagCachedTodos() {
    return _guard('cache', () async {
      final filter = QueryFilter(
        key: QueryKey(<Object?>['todos']),
        status: QueryStatus.success,
      ).typed<TodoCollection>();
      final matches = client.updateQueriesData(
        filter,
        (key, previous) {
          final collection = previous.requireValue();
          return collection.copyWith(
            items: <Todo>[
              for (final todo in collection.items)
                todo.copyWith(
                  title: todo.title.endsWith(' · cached')
                      ? todo.title
                      : '${todo.title} · cached',
                ),
            ],
          );
        },
      );
      _record('Typed prefix update touched ${matches.length} entries.');
    });
  }

  Future<void> previewRollback() {
    return _guard('cache', () async {
      final current = client.getQueryData(todosQuery);
      if (current.isAbsent) {
        _record('Load todos before running the rollback preview.');
        return;
      }
      final before = client.snapshotQueryData(todosQuery);
      final optimistic = client.updateQueryData(
        todosQuery,
        (previous) {
          final collection = previous.requireValue();
          return collection.copyWith(
            items: <Todo>[
              ...collection.items,
              const Todo(99, 'Revision-guarded preview'),
            ],
          );
        },
      );
      _record('Optimistic exact write at revision ${optimistic.revision}.');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final restored = client.restoreQueryData(
        todosQuery,
        before,
        ifRevision: optimistic.revision,
      );
      _record('Snapshot restore accepted=$restored.');
    });
  }

  Future<void> runGreetingRetry() {
    return _guard('retry', () async {
      api.resetGreetingAttempts();
      lastGreeting = await client.fetchQuery(
        greetingQuery,
        staleTime: StalePolicy.immediate,
      );
      _record('Retry query returned “$lastGreeting”.');
    });
  }

  Future<void> runCancellationDemo() {
    return _guard('cancel', () async {
      final cancellable = query<int>(
        key: QueryKey(<Object?>['demo', 'cancellable']),
        fetch: (context) async {
          await context.cancellationToken.whenCancelled;
          context.cancellationToken.throwIfCancelled();
          return 1;
        },
        retry: RetryPolicy.none,
      );
      final operation = client.fetchQuery(cancellable);
      final outcome = operation.then<Object>(
        (value) => value,
        onError: (Object error, StackTrace stackTrace) => error,
      );
      _record('Cancellable query started; cancelling in 450 ms.');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final result = await client.cancelQueries(
        filter: QueryFilter(key: cancellable.key, exact: true),
      );
      _record(
        'Cancelled ${result.affected} operation; '
        'future completed as ${(await outcome).runtimeType}.',
      );
    });
  }

  Future<void> runNonCancellingWriteDemo() {
    return _guard('data-lane', () async {
      await client.cancelQueries(
        filter: QueryFilter(key: dataLaneQuery.key, exact: true),
      );
      client.setQueryData(dataLaneQuery, 0);
      dataLaneExplanation =
          'Fetch started. In 300 ms, setQueryData writes 777 without '
          'cancelling it…';
      _notify();

      final operation = dataLaneObserver.refetch();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      client.setQueryData(dataLaneQuery, 777);
      final stillFetching = client.getQueryState(dataLaneQuery)?.fetchStatus ==
          FetchStatus.fetching;
      dataLaneExplanation =
          'Manual value 777 is visible and fetchStatus is still fetching='
          '$stillFetching. Waiting for the accepted server result…';
      _record('Data-lane write kept the active operation=$stillFetching.');

      final result = await operation;
      dataLaneExplanation =
          'The active query was not cancelled: its accepted result '
          '${_queryDataLabel(result.data)} replaced manual value 777.';
      _notify();
    });
  }

  Future<void> runProtectedWriteDemo() {
    return _guard('data-lane', () async {
      await client.cancelQueries(
        filter: QueryFilter(key: dataLaneQuery.key, exact: true),
      );
      client.setQueryData(dataLaneQuery, 0);
      dataLaneExplanation =
          'Fetch started. In 300 ms, cancelQueries will finish before the '
          'manual write…';
      _notify();

      final operation = dataLaneObserver.refetch();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await client.cancelQueries(
        filter: QueryFilter(key: dataLaneQuery.key, exact: true),
      );
      client.setQueryData(dataLaneQuery, 888);
      try {
        await operation;
      } on Object {
        // The cache state below is the user-visible outcome of cancellation.
      }
      await Future<void>.delayed(const Duration(milliseconds: 850));
      dataLaneExplanation =
          'cancelQueries completed before setQueryData: value 888 remains '
          'authoritative and the late server completion was ignored.';
      _record('Explicit cancel-before-write protected manual value 888.');
    });
  }

  Future<void> runScopedWrites(
    MutationObserver<String, Todo, void> renameObserver,
  ) {
    return _guard('scope', () async {
      _scopeRun += 1;
      api.clearWriteLog();
      final first = renameObserver.execute('Run $_scopeRun · first');
      final second = client.execute(renameMutation, 'Run $_scopeRun · second');
      final sync = client.executeAction(synchronizeAction);
      _record('Submitted two mutations and one action to one FIFO scope.');
      await Future.wait<Object>(<Future<Object>>[first, second, sync]);
      _record('FIFO scope drained in submission order.');
    });
  }

  Future<void> changeCounter(
    MutationObserver<int, int, CounterRollback> incrementObserver,
    int delta,
  ) {
    return _guard('counter', () async {
      api.resetCounterAttempts();
      try {
        final value = await incrementObserver.execute(
          delta,
          onSuccess: (data, variables, result, context) {
            _record(
              'Mutation per-call onSuccess observed '
              '${incrementObserver.status.name} before Future completion.',
            );
          },
          onError: (failure, variables, result, context) {
            _record(
              'Mutation per-call onError observed '
              '${incrementObserver.status.name} before Future completion.',
            );
          },
        );
        _record('Mutation Future completed with server value $value.');
      } on Object catch (error) {
        _record(
          'Mutation Future completed with ${error.runtimeType} after the '
          'terminal observer callback.',
        );
      }
    });
  }

  Future<void> loadFeed(
    InfiniteQueryObserver<InfiniteData<String, int>> feedObserver,
  ) {
    return _guard('feed', () async {
      final result = await feedObserver.refetch();
      _record(
        result.failure == null
            ? 'Infinite query loaded its initial page.'
            : 'Infinite query failed: ${result.failure!.error}.',
      );
    });
  }

  Future<void> fetchNextPage(
    InfiniteQueryObserver<InfiniteData<String, int>> feedObserver,
  ) {
    return _guard('feed', () async {
      if (feedObserver.data.isAbsent) {
        await feedObserver.refetch();
      }
      final result = await feedObserver.fetchNextPage();
      final count =
          result.data.isPresent ? result.data.requireValue().pages.length : 0;
      _record('Directional fetch completed; $count page(s) retained.');
    });
  }

  Future<void> fetchPreviousPage(
    InfiniteQueryObserver<InfiniteData<String, int>> feedObserver,
  ) {
    return _guard('feed', () async {
      await feedObserver.fetchPreviousPage();
      _record('Previous-page resolver is omitted, so this was a safe no-op.');
    });
  }

  Future<void> runStream() {
    return _guard('stream', () async {
      final mode = streamMode;
      final query = streamQueries[mode]!;
      final observer = streamObservers[mode]!;
      api.resetStreamAttempts(mode);
      client.setQueryData(query, IList<int>(<int>[0]));
      _record(
        '${mode.name} stream started from [0]; its first attempt will fail '
        'after chunk 1.',
      );
      final operation = observer.refetch();
      await Future<void>.delayed(const Duration(milliseconds: 750));
      client.setQueryData(query, IList<int>(<int>[99]));
      final stillFetching =
          client.getQueryState(query)?.fetchStatus == FetchStatus.fetching;
      _record(
        'Manual [99] became visible during retry delay without cancelling the '
        'stream (still fetching=$stillFetching).',
      );
      final result = await operation;
      if (result.failure case final failure?) {
        _record('Stream failed: ${failure.error}.');
      } else {
        _record(
          '${mode.name} stream accepted later output and closed normally.',
        );
      }
    });
  }

  Future<void> _guard(
    String operation,
    Future<void> Function() action,
  ) async {
    if (_disposed || !_busy.add(operation)) return;
    _notify();
    try {
      await action();
    } on Object catch (error) {
      _record('$operation failed: $error.');
    } finally {
      _busy.remove(operation);
      _notify();
    }
  }

  void _onQueryEvent(QueryCacheEvent event) {
    final snapshot = event.snapshot;
    final isStream = snapshot.key.startsWith(
      QueryKey(<Object?>['stream']),
    );
    final isTerminalUpdate = event.kind == QueryCacheEventKind.updated &&
        snapshot.fetchStatus == FetchStatus.idle;
    if (event.kind != QueryCacheEventKind.activityChanged &&
        (event.kind != QueryCacheEventKind.updated ||
            isTerminalUpdate ||
            isStream)) {
      _record(
        'Query cache ${event.kind.name}: ${snapshot.key} '
        '(${snapshot.status.name}/${snapshot.fetchStatus.name}).',
      );
    }
  }

  void _onMutationEvent(MutationCacheEvent event) {
    if (event.kind == MutationCacheEventKind.added ||
        event.snapshot.status != MutationStatus.pending) {
      _record(
        'Mutation cache ${event.kind.name}: '
        '${event.snapshot.key ?? 'anonymous'} '
        '(${event.snapshot.status.name}).',
      );
    }
  }

  void _recordQueryCallback(
    String callback,
    QueryCacheSnapshot snapshot,
  ) {
    if (snapshot.key == QueryKey(<Object?>['demo', 'polling'])) return;
    _record(
      'QueryCacheCallbacks.$callback post-commit: ${snapshot.key} '
      '(${snapshot.status.name}/${snapshot.fetchStatus.name}).',
    );
  }

  void _record(String message) {
    if (_disposed) return;
    final now = DateTime.now().toIso8601String().substring(11, 19);
    _activity.insert(0, '$now  $message');
    if (_activity.length > 80) _activity.removeLast();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_queryEvents.cancel());
    unawaited(_mutationEvents.cancel());
    client.dispose();
    projectPage.dispose();
    stalePreset.dispose();
    keepPreviousProjects.dispose();
    super.dispose();
  }
}

String _queryDataLabel<T>(QueryValue<T> data) {
  return data.isPresent ? '${data.requireValue()}' : 'absent';
}

final class Project {
  const Project(this.id, this.name);

  final int id;
  final String name;

  @override
  String toString() => '$id:$name';
}

final class ProjectPage {
  ProjectPage({
    required this.page,
    required this.serverRevision,
    required this.requestNumber,
    required Iterable<Project> items,
    required this.hasMore,
  }) : items = List<Project>.unmodifiable(items);

  final int page;
  final int serverRevision;
  final int requestNumber;
  final List<Project> items;
  final bool hasMore;
}

final class Todo {
  const Todo(this.id, this.title, {this.done = false});

  final int id;
  final String title;
  final bool done;

  Todo copyWith({String? title, bool? done}) {
    return Todo(
      id,
      title ?? this.title,
      done: done ?? this.done,
    );
  }

  @override
  String toString() => '$id:$title${done ? ' ✓' : ''}';
}

final class TodoCollection {
  TodoCollection({
    required this.serverRevision,
    required Iterable<Todo> items,
  }) : items = List<Todo>.unmodifiable(items);

  final int serverRevision;
  final List<Todo> items;

  TodoCollection copyWith({
    int? serverRevision,
    Iterable<Todo>? items,
  }) {
    return TodoCollection(
      serverRevision: serverRevision ?? this.serverRevision,
      items: items ?? this.items,
    );
  }
}

final class DemoApi {
  static const int projectPageCount = 3;

  final List<Todo> _openTodos = <Todo>[
    const Todo(1, 'Design query API'),
    const Todo(2, 'Build the Flutter Web example'),
  ];

  final List<String> _writeLog = <String>[];
  final Map<int, int> _projectRequestsByPage = <int, int>{};
  int projectTotalRequests = 0;
  int openTodoReads = 0;
  int counter = 0;
  int _projectServerRevision = 1;
  int _serverRevision = 1;
  int _nextTodoId = 3;
  int _polls = 0;
  int _greetingAttempts = 0;
  int _counterAttempts = 0;
  int _dataLaneRequests = 0;
  final Map<StreamRefetchMode, int> _streamAttempts =
      <StreamRefetchMode, int>{};

  List<String> get writeLog => List<String>.unmodifiable(_writeLog);
  int get projectServerRevision => _projectServerRevision;
  int get serverRevision => _serverRevision;
  TodoCollection get openTodosSnapshot => TodoCollection(
        serverRevision: _serverRevision,
        items: _openTodos,
      );

  int nextPoll() => ++_polls;

  int projectRequestCount(int page) => _projectRequestsByPage[page] ?? 0;
  int streamAttemptCount(StreamRefetchMode mode) => _streamAttempts[mode] ?? 0;

  int changeProjectsOnServer() => ++_projectServerRevision;

  void resetProjectsServer() {
    _projectServerRevision = 1;
    projectTotalRequests = 0;
    _projectRequestsByPage.clear();
  }

  void resetGreetingAttempts() => _greetingAttempts = 0;
  void resetCounterAttempts() => _counterAttempts = 0;
  void clearWriteLog() => _writeLog.clear();

  Todo changeOpenTodosOnServer() {
    _serverRevision += 1;
    final added = Todo(
      _nextTodoId++,
      'Server-only todo · revision $_serverRevision',
    );
    _openTodos.add(added);
    return added;
  }

  void resetTodoServer() {
    _serverRevision = 1;
    _nextTodoId = 3;
    openTodoReads = 0;
    _openTodos
      ..clear()
      ..addAll(const <Todo>[
        Todo(1, 'Design query API'),
        Todo(2, 'Build the Flutter Web example'),
      ]);
  }

  Future<TodoCollection> loadOpenTodos() async {
    openTodoReads += 1;
    await _delay(const Duration(milliseconds: 650));
    return openTodosSnapshot;
  }

  Future<ProjectPage> loadProjects(int page) async {
    if (page < 1 || page > projectPageCount) {
      throw RangeError.range(page, 1, projectPageCount, 'page');
    }
    projectTotalRequests += 1;
    final requestNumber = projectTotalRequests;
    _projectRequestsByPage.update(
      page,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    await _delay(const Duration(milliseconds: 650));
    final revision = _projectServerRevision;
    final firstId = (page - 1) * 3 + 1;
    return ProjectPage(
      page: page,
      serverRevision: revision,
      requestNumber: requestNumber,
      items: List<Project>.generate(3, (index) {
        final id = firstId + index;
        return Project(id, 'Project $id · server revision $revision');
      }),
      hasMore: page < projectPageCount,
    );
  }

  Future<String> loadUnstableGreeting() async {
    await _delay(const Duration(milliseconds: 350));
    _greetingAttempts += 1;
    if (_greetingAttempts == 1) {
      throw StateError('temporary greeting failure');
    }
    return 'hello after retry';
  }

  Future<Todo> renameTodo(int id, String title) async {
    _writeLog.add('rename:$title:start');
    await _delay(const Duration(milliseconds: 500));
    final index = _openTodos.indexWhere((todo) => todo.id == id);
    if (index < 0) throw StateError('todo $id does not exist');
    final renamed = _openTodos[index].copyWith(title: title);
    _openTodos[index] = renamed;
    _serverRevision += 1;
    _writeLog.add('rename:$title:end');
    return renamed;
  }

  Future<String> synchronizeTodos() async {
    _writeLog.add('sync:start');
    await _delay(const Duration(milliseconds: 500));
    _writeLog.add('sync:end');
    return 'synchronized';
  }

  Future<int> incrementCounter(int delta) async {
    await _delay(const Duration(milliseconds: 450));
    if (delta < 0) throw StateError('negative deltas are rejected');
    _counterAttempts += 1;
    if (_counterAttempts == 1) {
      throw StateError('temporary counter failure');
    }
    counter += delta;
    return counter;
  }

  Future<int> loadDataLaneValue() async {
    _dataLaneRequests += 1;
    final response = 100 + _dataLaneRequests;
    await _delay(const Duration(milliseconds: 1000));
    return response;
  }

  Future<String> loadFeedPage(int page) async {
    await _delay(const Duration(milliseconds: 450));
    return 'page-$page';
  }

  void resetStreamAttempts(StreamRefetchMode mode) {
    _streamAttempts[mode] = 0;
  }

  Stream<int> numberStream(StreamRefetchMode mode) async* {
    final attempt = (_streamAttempts[mode] ?? 0) + 1;
    _streamAttempts[mode] = attempt;
    for (final value in const <int>[1, 2, 3]) {
      await _delay(const Duration(milliseconds: 500));
      yield value;
      if (attempt == 1 && value == 1) {
        throw StateError('demo stream interruption');
      }
    }
  }

  Future<void> _delay(Duration duration) => Future<void>.delayed(duration);
}

final class ProjectsQuery extends Query<ProjectPage> {
  ProjectsQuery({
    required QueryClient client,
    required this.api,
    required this.page,
  }) : super(
          client: client,
          retention: RetentionPolicy.forever,
          metadata: <String, Object?>{
            'source': 'demo-api',
            'style': 'class-first',
            'page': page,
          },
        );

  final DemoApi api;
  final int page;

  @override
  QueryKey get key => QueryKey(<Object?>['projects', page]);

  @override
  Future<ProjectPage> fetch(QueryContext context) => api.loadProjects(page);
}

final class TodosQuery extends Query<TodoCollection> {
  TodosQuery(this.api)
      : super(
          staleTime: StalePolicy.untilInvalidated,
          metadata: const <String, Object?>{
            'source': 'demo-api',
            'style': 'class-first',
          },
        );

  final DemoApi api;

  @override
  QueryKey get key => QueryKey(<Object?>['todos', 'open']);

  @override
  Future<TodoCollection> fetch(QueryContext context) => api.loadOpenTodos();
}

final class RenameTodo extends Mutation<String, Todo, void> {
  RenameTodo(this.api, this.todos, this.id);

  final DemoApi api;
  final TodosQuery todos;
  final int id;

  @override
  MutationKey get key => MutationKey(<Object?>['todos', 'rename', id]);

  @override
  MutationScope get scope => todoWriteScope;

  @override
  Future<Todo> mutate(String variables, MutationContext context) {
    return api.renameTodo(id, variables);
  }

  @override
  void onSuccess(
    Todo data,
    String variables,
    QueryValue<void> onMutateResult,
    MutationContext context,
  ) {
    context.client.setQueryData(todos, api.openTodosSnapshot);
  }
}
