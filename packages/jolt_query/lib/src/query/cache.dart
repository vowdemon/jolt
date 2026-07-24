import 'dart:async';
import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../foundation/notification_orchestrator.dart';
import '../foundation/query_failure.dart';
import '../foundation/query_runtime.dart' show QueryScheduledHandle;
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import 'cache_models.dart';
import 'policies.dart';
import 'recipe.dart';
import 'state.dart';

const ConfigList _snapshotListConfig = ConfigList(
  isDeepEquals: true,
  cacheHashCode: true,
);

/// Public query-cache state, events, and cache-local clearing.
///
/// The owning QueryClient remains active after [clear]. Only disposing that
/// client can terminate query work or close [events].
final class QueryCache {
  QueryCache._(this._controller);

  final QueryCacheControllerInternal _controller;

  /// Immutable erased entries in stable insertion order.
  IList<QueryCacheSnapshot> get snapshots => _controller.snapshots;

  /// Broadcast committed cache events.
  ///
  /// Clearing entries does not close this stream. Owner disposal closes it.
  Stream<QueryCacheEvent> get events => _controller.events;

  /// Whether this cache's owning client has been disposed.
  bool get isDisposed => _controller.isDisposed;

  /// Clears only query-cache entries while leaving the owner and stream alive.
  void clear() => _controller.clearFromPublic();
}

/// Internal observer attachment used without exposing mutable entries.
abstract interface class QueryEntryListenerInternal {
  /// Whether this observer currently makes the entry active.
  bool get isQueryEntryActiveInternal;

  /// Whether this active observer suppresses automatic and bulk refetch.
  bool get blocksQueryRefetchInternal;

  /// Whether this attached observer currently considers [entry] stale.
  bool isQueryEntryStaleInternal(QueryEntryInternal entry);

  void onQueryEntryChangedInternal(
    QueryEntryInternal entry,
    QueryCacheEventKind kind,
  );

  void onQueryEntryRemovedInternal(QueryEntryInternal entry);
}

/// Package-private mutable state for one structural key.
final class QueryEntryInternal {
  QueryEntryInternal({
    required this.key,
    required this.incarnation,
    required this.lineageToken,
  });

  final QueryKey key;
  final int incarnation;
  final Object lineageToken;
  QueryValue<Object?> data = const QueryValue<Object?>.absent();
  QueryStatus status = QueryStatus.pending;
  FetchStatus fetchStatus = FetchStatus.idle;
  PauseReason? pauseReason;
  QueryFailure? failure;
  QueryFailure? transientFailure;
  int failureCount = 0;
  DateTime? dataUpdatedAt;
  DateTime? failureUpdatedAt;
  int dataUpdateCount = 0;
  int failureUpdateCount = 0;
  int completionSequence = 0;
  int visibleCompletionSequence = 0;
  int revision = 0;
  int invalidationRevision = 0;
  bool isInvalidated = false;
  ResolvedQueryPlanBase? retainedPlan;
  ResolvedInitialData? initialData;
  QueryValue<Object?> initialValue = const QueryValue<Object?>.absent();
  DateTime? initialUpdatedAt;
  final Set<QueryEntryListenerInternal> listeners =
      <QueryEntryListenerInternal>{};
  QueryOperationInternal? operation;
  int operationSequence = 0;
  int operationCompletionCount = 0;
  Duration longestRetention = Duration.zero;
  bool retainForever = false;
  int gcGeneration = 0;
  QueryScheduledHandle? gcHandle;
  bool aggregateIsStale = true;

  int get observerCount => listeners.length;
  int get activeObserverCount =>
      listeners.where((listener) => listener.isQueryEntryActiveInternal).length;
  bool get isObserved => listeners.isNotEmpty;
  bool get isActive => activeObserverCount > 0;
  bool get isFetched => dataUpdateCount + failureUpdateCount > 0;
  bool get isDisabled => isObserved ? !isActive : !isFetched;
  bool get isStatic =>
      isObserved &&
      listeners.any((listener) => listener.blocksQueryRefetchInternal);

  Map<String, Object?> get metadata =>
      retainedPlan?.metadata ?? const <String, Object?>{};

  void receiveRetention(RetentionPolicy policy) {
    final duration = policy.duration;
    if (duration == null) {
      retainForever = true;
    } else if (duration > longestRetention) {
      longestRetention = duration;
    }
  }

  void recordCompletion() {
    visibleCompletionSequence = ++completionSequence;
  }
}

/// The active-operation surface retained by an entry.
abstract interface class QueryOperationInternal {
  int get id;
  int get entryIncarnation;
  int get invalidationRevisionAtStart;
  bool get isSettled;
  bool get cancellationWasConsumed;
  bool get dependsOnObserverActivity;
  bool get isTransitioning;
  Future<Object?> get future;
  void retainBeyondObserverActivity();
  void stopRetries();
  void pauseRetries();
  void resumeRetries();
  void cancel({required Object reason, required bool revert});
}

/// Internal mutable store behind [QueryCache].
final class QueryCacheControllerInternal implements Disposable {
  QueryCacheControllerInternal({
    required NotificationOrchestrator notifications,
    required void Function() clearOwnerCache,
    void Function()? onCommittedEvent,
  })  : _notifications = notifications,
        _clearOwnerCache = clearOwnerCache,
        _onCommittedEvent = onCommittedEvent {
    public = QueryCache._(this);
  }

  final NotificationOrchestrator _notifications;
  final void Function() _clearOwnerCache;
  final void Function()? _onCommittedEvent;
  final LinkedHashMap<QueryKey, QueryEntryInternal> _entries =
      LinkedHashMap<QueryKey, QueryEntryInternal>();
  final Map<QueryKey, Object> _lineages = <QueryKey, Object>{};
  final StreamController<QueryCacheEvent> _events =
      StreamController<QueryCacheEvent>.broadcast(sync: true);
  int _nextIncarnation = 0;
  bool _isDisposed = false;

  late final QueryCache public;

  bool get isDisposed => _isDisposed;
  Stream<QueryCacheEvent> get events => _events.stream;

  IList<QueryCacheSnapshot> get snapshots =>
      IList<QueryCacheSnapshot>.withConfig(
        _entries.values.map(snapshotOf),
        _snapshotListConfig,
      );

  Iterable<QueryEntryInternal> get entries => _entries.values;

  QueryEntryInternal? lookup(QueryKey key) => _entries[key];

  Object lineageFor(QueryKey key) => _lineages.putIfAbsent(key, Object.new);

  QueryEntryInternal getOrCreate(
    QueryKey key, {
    QueryEntryListenerInternal? initialListener,
    void Function(QueryEntryInternal entry)? initialize,
  }) {
    _checkActive();
    final existing = _entries[key];
    if (existing != null) {
      if (initialListener != null) {
        existing.listeners.add(initialListener);
      }
      return existing;
    }
    final entry = QueryEntryInternal(
      key: key,
      incarnation: ++_nextIncarnation,
      lineageToken: lineageFor(key),
    );
    if (initialListener != null) entry.listeners.add(initialListener);
    initialize?.call(entry);
    _entries[key] = entry;
    publish(entry, QueryCacheEventKind.added);
    return entry;
  }

  QueryCacheSnapshot snapshotOf(QueryEntryInternal entry) {
    return QueryCacheSnapshot(
      key: entry.key,
      data: entry.data,
      status: entry.status,
      fetchStatus: entry.fetchStatus,
      pauseReason: entry.pauseReason,
      failure: entry.failure,
      transientFailure: entry.transientFailure,
      failureCount: entry.failureCount,
      dataUpdatedAt: entry.dataUpdatedAt,
      failureUpdatedAt: entry.failureUpdatedAt,
      dataUpdateCount: entry.dataUpdateCount,
      failureUpdateCount: entry.failureUpdateCount,
      revision: entry.revision,
      invalidationRevision: entry.invalidationRevision,
      isInvalidated: entry.isInvalidated,
      observerCount: entry.observerCount,
      activeObserverCount: entry.activeObserverCount,
      isStale: entry.aggregateIsStale,
      metadata: entry.metadata,
    );
  }

  void publish(QueryEntryInternal entry, QueryCacheEventKind kind) {
    if (_isDisposed) return;
    entry.aggregateIsStale = _resolveAggregateFreshness(entry);
    _publishCommitted(entry, kind);
  }

  /// Publishes a pure observer-driven aggregate freshness transition once.
  void refreshObserverFreshnessInternal(QueryEntryInternal entry) {
    if (_isDisposed || !containsEntry(entry)) return;
    final isStale = _resolveAggregateFreshness(entry);
    if (entry.aggregateIsStale == isStale) return;
    entry.aggregateIsStale = isStale;
    _publishCommitted(entry, QueryCacheEventKind.freshnessChanged);
  }

  void _publishCommitted(
    QueryEntryInternal entry,
    QueryCacheEventKind kind,
  ) {
    final snapshot = snapshotOf(entry);
    final listeners = List<QueryEntryListenerInternal>.of(entry.listeners);
    _notifications.enqueue(() {
      if (_isDisposed) return;
      _onCommittedEvent?.call();
      _events.add(QueryCacheEvent(kind: kind, snapshot: snapshot));
      for (final listener in listeners) {
        listener.onQueryEntryChangedInternal(entry, kind);
      }
    });
  }

  QueryEntryInternal? remove(QueryKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    final snapshot = snapshotOf(entry);
    _lineages[key] = Object();
    entry.gcGeneration += 1;
    entry.gcHandle?.cancel();
    entry.gcHandle = null;
    final listeners = List<QueryEntryListenerInternal>.of(entry.listeners);
    entry.listeners.clear();
    _notifications.enqueue(() {
      if (_isDisposed) return;
      _onCommittedEvent?.call();
      _events.add(
        QueryCacheEvent(
          kind: QueryCacheEventKind.removed,
          snapshot: snapshot,
        ),
      );
      for (final listener in listeners) {
        listener.onQueryEntryRemovedInternal(entry);
      }
    });
    return entry;
  }

  QueryEntryInternal? removeEntry(QueryEntryInternal entry) {
    if (!containsEntry(entry)) return null;
    return remove(entry.key);
  }

  /// Removes every query entry and invalidates every issued checkpoint lineage.
  List<QueryEntryInternal> clearEntries() {
    _checkActive();
    final knownKeys = List<QueryKey>.of(_lineages.keys);
    final removed = <QueryEntryInternal>[];
    for (final key in List<QueryKey>.of(_entries.keys)) {
      final entry = remove(key);
      if (entry != null) removed.add(entry);
    }
    for (final key in knownKeys) {
      _lineages[key] = Object();
    }
    return removed;
  }

  bool containsEntry(QueryEntryInternal entry) =>
      identical(_entries[entry.key], entry);

  void clearFromPublic() {
    _checkActive();
    _clearOwnerCache();
  }

  bool _resolveAggregateFreshness(QueryEntryInternal entry) {
    if (entry.isObserved) {
      for (final listener in entry.listeners) {
        if (listener.isQueryEntryStaleInternal(entry)) return true;
      }
      return false;
    }
    return entry.isInvalidated || entry.data.isAbsent;
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('QueryCache is disposed.');
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _entries.clear();
    _lineages.clear();
    unawaited(_events.close());
  }
}
