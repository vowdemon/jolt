import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import 'state.dart';

/// A complete immutable typed snapshot of one query entry.
final class QuerySnapshot<T> {
  /// Creates a typed query-state snapshot.
  factory QuerySnapshot({
    required QueryKey key,
    required QueryValue<T> data,
    required QueryStatus status,
    required FetchStatus fetchStatus,
    PauseReason? pauseReason,
    QueryFailure? failure,
    QueryFailure? transientFailure,
    int failureCount = 0,
    DateTime? dataUpdatedAt,
    DateTime? failureUpdatedAt,
    int dataUpdateCount = 0,
    int failureUpdateCount = 0,
    int revision = 0,
    int invalidationRevision = 0,
    bool isInvalidated = false,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    _validatePause(fetchStatus, pauseReason);
    _requireNonNegative('failureCount', failureCount);
    _requireNonNegative('dataUpdateCount', dataUpdateCount);
    _requireNonNegative('failureUpdateCount', failureUpdateCount);
    _requireNonNegative('revision', revision);
    _requireNonNegative('invalidationRevision', invalidationRevision);
    return QuerySnapshot<T>._(
      key: key,
      data: data,
      status: status,
      fetchStatus: fetchStatus,
      pauseReason: pauseReason,
      failure: failure,
      transientFailure: transientFailure,
      failureCount: failureCount,
      dataUpdatedAt: dataUpdatedAt,
      failureUpdatedAt: failureUpdatedAt,
      dataUpdateCount: dataUpdateCount,
      failureUpdateCount: failureUpdateCount,
      revision: revision,
      invalidationRevision: invalidationRevision,
      isInvalidated: isInvalidated,
      metadata: _freezeMetadata(metadata),
    );
  }

  const QuerySnapshot._({
    required this.key,
    required this.data,
    required this.status,
    required this.fetchStatus,
    required this.pauseReason,
    required this.failure,
    required this.transientFailure,
    required this.failureCount,
    required this.dataUpdatedAt,
    required this.failureUpdatedAt,
    required this.dataUpdateCount,
    required this.failureUpdateCount,
    required this.revision,
    required this.invalidationRevision,
    required this.isInvalidated,
    required this.metadata,
  });

  /// The normalized structural key owning this state.
  final QueryKey key;

  /// The typed cached data, including explicit absence and present-null.
  final QueryValue<T> data;

  /// The canonical data state.
  final QueryStatus status;

  /// The operation state, independent from [status].
  final FetchStatus fetchStatus;

  /// The current pause reason, present only while [fetchStatus] is paused.
  final PauseReason? pauseReason;

  /// The latest terminal operation failure, if any.
  final QueryFailure? failure;

  /// The latest retryable failure while an operation is still in progress.
  final QueryFailure? transientFailure;

  /// The number of failed attempts in the current or terminal operation.
  final int failureCount;

  /// When [data] was last accepted, or null when no time is recorded.
  final DateTime? dataUpdatedAt;

  /// When [failure] was last committed, or null when none is recorded.
  final DateTime? failureUpdatedAt;

  /// The number of accepted data updates for this entry lineage.
  final int dataUpdateCount;

  /// The number of terminal failure updates for this entry lineage.
  final int failureUpdateCount;

  /// The current data/write revision used by conditional updates.
  final int revision;

  /// The monotonic invalidation revision for guarded operations.
  final int invalidationRevision;

  /// Whether this snapshot is currently invalidated.
  final bool isInvalidated;

  /// Immutable recipe metadata associated with this entry.
  final Map<String, Object?> metadata;
}

/// A revisioned checkpoint of one query's cached-data lane.
///
/// Public fields describe the complete captured data state. Opaque provenance is held
/// privately and can only be supplied and checked through package-internal
/// helpers in this source library.
final class QueryDataSnapshot<T> {
  const QueryDataSnapshot._({
    required this.data,
    required this.updatedAt,
    required this.revision,
    required Object clientToken,
    required QueryKey provenanceKey,
    required Object lineageToken,
  })  : _clientToken = clientToken,
        _provenanceKey = provenanceKey,
        _lineageToken = lineageToken;

  /// The complete captured typed value, including absence and present-null.
  final QueryValue<T> data;

  /// The captured data update time.
  final DateTime? updatedAt;

  /// The captured data/write revision.
  final int revision;

  final Object _clientToken;
  final QueryKey _provenanceKey;
  final Object _lineageToken;
}

/// Creates a provenance-bound data checkpoint for package internals.
///
/// This helper is deliberately omitted from the public package barrel while
/// remaining callable by the client and cache implementation libraries.
QueryDataSnapshot<T> createQueryDataSnapshotInternal<T>({
  required QueryValue<T> data,
  required DateTime? updatedAt,
  required int revision,
  required Object clientToken,
  required QueryKey key,
  required Object lineageToken,
}) {
  _requireNonNegative('revision', revision);
  return QueryDataSnapshot<T>._(
    data: data,
    updatedAt: updatedAt,
    revision: revision,
    clientToken: clientToken,
    provenanceKey: key,
    lineageToken: lineageToken,
  );
}

/// Whether [snapshot] belongs to the supplied client, key, and entry lineage.
///
/// Client and lineage tokens use identity. Structurally equal query keys are
/// compatible so separate Query instances can address the same cache entry.
bool queryDataSnapshotMatchesProvenanceInternal<T>(
  QueryDataSnapshot<T> snapshot, {
  required Object clientToken,
  required QueryKey key,
  required Object lineageToken,
}) =>
    identical(snapshot._clientToken, clientToken) &&
    snapshot._provenanceKey == key &&
    identical(snapshot._lineageToken, lineageToken);

/// A typed bulk-data result paired with the structural key it matched.
final class QueryDataMatch<T> {
  /// Creates a key-associated typed data snapshot.
  const QueryDataMatch({required this.key, required this.snapshot});

  /// The matched structural key.
  final QueryKey key;

  /// The captured or post-write typed snapshot.
  final QueryDataSnapshot<T> snapshot;
}

/// An immutable erased query-cache view.
final class QueryCacheSnapshot {
  /// Creates an erased cache snapshot.
  factory QueryCacheSnapshot({
    required QueryKey key,
    required QueryValue<Object?> data,
    required QueryStatus status,
    required FetchStatus fetchStatus,
    required bool isStale,
    int observerCount = 0,
    int? activeObserverCount,
    PauseReason? pauseReason,
    QueryFailure? failure,
    QueryFailure? transientFailure,
    int failureCount = 0,
    DateTime? dataUpdatedAt,
    DateTime? failureUpdatedAt,
    int dataUpdateCount = 0,
    int failureUpdateCount = 0,
    int revision = 0,
    int invalidationRevision = 0,
    bool isInvalidated = false,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    _validatePause(fetchStatus, pauseReason);
    _requireNonNegative('observerCount', observerCount);
    final resolvedActiveObserverCount = activeObserverCount ?? observerCount;
    _requireNonNegative('activeObserverCount', resolvedActiveObserverCount);
    if (resolvedActiveObserverCount > observerCount) {
      throw ArgumentError.value(
        resolvedActiveObserverCount,
        'activeObserverCount',
        'Cannot exceed observerCount.',
      );
    }
    _requireNonNegative('failureCount', failureCount);
    _requireNonNegative('dataUpdateCount', dataUpdateCount);
    _requireNonNegative('failureUpdateCount', failureUpdateCount);
    _requireNonNegative('revision', revision);
    _requireNonNegative('invalidationRevision', invalidationRevision);
    return QueryCacheSnapshot._(
      key: key,
      data: data,
      status: status,
      fetchStatus: fetchStatus,
      pauseReason: pauseReason,
      failure: failure,
      transientFailure: transientFailure,
      failureCount: failureCount,
      dataUpdatedAt: dataUpdatedAt,
      failureUpdatedAt: failureUpdatedAt,
      dataUpdateCount: dataUpdateCount,
      failureUpdateCount: failureUpdateCount,
      revision: revision,
      invalidationRevision: invalidationRevision,
      isInvalidated: isInvalidated,
      observerCount: observerCount,
      activeObserverCount: resolvedActiveObserverCount,
      isStale: isStale,
      metadata: _freezeMetadata(metadata),
    );
  }

  const QueryCacheSnapshot._({
    required this.key,
    required this.data,
    required this.status,
    required this.fetchStatus,
    required this.pauseReason,
    required this.failure,
    required this.transientFailure,
    required this.failureCount,
    required this.dataUpdatedAt,
    required this.failureUpdatedAt,
    required this.dataUpdateCount,
    required this.failureUpdateCount,
    required this.revision,
    required this.invalidationRevision,
    required this.isInvalidated,
    required this.observerCount,
    required this.activeObserverCount,
    required this.isStale,
    required this.metadata,
  });

  /// The entry's normalized structural key.
  final QueryKey key;

  /// Erased cached-value presence.
  final QueryValue<Object?> data;

  /// The canonical data state.
  final QueryStatus status;

  /// The orthogonal operation state.
  final FetchStatus fetchStatus;

  /// The current pause reason, present only while [fetchStatus] is paused.
  final PauseReason? pauseReason;

  /// The latest terminal operation failure, if any.
  final QueryFailure? failure;

  /// The latest retryable failure while work remains active.
  final QueryFailure? transientFailure;

  /// The number of failed attempts in the current or terminal operation.
  final int failureCount;

  /// When [data] was last accepted.
  final DateTime? dataUpdatedAt;

  /// When [failure] was last committed.
  final DateTime? failureUpdatedAt;

  /// The number of accepted data updates for this entry lineage.
  final int dataUpdateCount;

  /// The number of terminal failure updates for this entry lineage.
  final int failureUpdateCount;

  /// The current data/write revision.
  final int revision;

  /// The monotonic invalidation revision.
  final int invalidationRevision;

  /// Whether this entry is explicitly invalidated.
  final bool isInvalidated;

  /// The number of currently attached observers.
  final int observerCount;

  /// The number of attached observers enabled for automatic work.
  final int activeObserverCount;

  /// Whether the cache's current observer-aware freshness view is stale.
  final bool isStale;

  /// Immutable recipe metadata associated with this entry.
  final Map<String, Object?> metadata;

  /// Whether at least one observer is currently attached.
  bool get isObserved => observerCount > 0;

  /// Whether at least one attached observer is enabled.
  bool get isActive => activeObserverCount > 0;
}

/// Global observation hook for one accepted query success.
typedef QueryCacheOnSuccess = void Function(
  Object? data,
  QueryCacheSnapshot snapshot,
);

/// Global observation hook for one terminal query failure.
typedef QueryCacheOnError = void Function(
  QueryFailure failure,
  QueryCacheSnapshot snapshot,
);

/// Global observation hook after either terminal query outcome.
typedef QueryCacheOnSettled = void Function(
  QueryValue<Object?> data,
  QueryFailure? failure,
  QueryCacheSnapshot snapshot,
);

/// Immutable global callbacks captured independently by each query operation.
final class QueryCacheCallbacks {
  /// Creates a global query lifecycle configuration.
  const QueryCacheCallbacks({
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  /// Called after a successful result is committed.
  final QueryCacheOnSuccess? onSuccess;

  /// Called after a terminal failure is committed.
  final QueryCacheOnError? onError;

  /// Called after either terminal result is committed.
  final QueryCacheOnSettled? onSettled;
}

/// The observable reason for a committed query-cache event.
enum QueryCacheEventKind {
  /// A cache entry was created.
  added,

  /// Committed entry state changed.
  updated,

  /// An entry was explicitly invalidated.
  invalidated,

  /// An entry was reset to its initial cache state.
  reset,

  /// An entry was removed.
  removed,

  /// The entry changed between active and inactive observation.
  activityChanged,

  /// Attached observers changed the entry's aggregate freshness only.
  freshnessChanged,
}

/// An immutable event emitted after a complete query-cache commit.
final class QueryCacheEvent {
  /// Creates a committed cache event.
  const QueryCacheEvent({required this.kind, required this.snapshot});

  /// The reason this event was emitted.
  final QueryCacheEventKind kind;

  /// The complete post-commit snapshot, or last snapshot for removal.
  final QueryCacheSnapshot snapshot;
}

Map<String, Object?> _freezeMetadata(Map<String, Object?> metadata) =>
    metadata.isEmpty
        ? const <String, Object?>{}
        : Map<String, Object?>.unmodifiable(metadata);

void _validatePause(FetchStatus status, PauseReason? reason) {
  if ((status == FetchStatus.paused) != (reason != null)) {
    throw ArgumentError(
      'pauseReason must be non-null exactly when fetchStatus is paused.',
    );
  }
}

void _requireNonNegative(String name, int value) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must not be negative.');
  }
}
