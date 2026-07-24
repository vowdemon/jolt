import 'dart:async';

import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import '../query/policies.dart';
import '../query/state.dart';
import '../retry/retry_policy.dart';
import 'recipe.dart';

/// The presentation and submitted-execution status of a mutation.
enum MutationStatus {
  /// No execution is currently presented by an observer.
  idle,

  /// A submitted execution is gated, running, retrying, or in lifecycle work.
  pending,

  /// The execution and every required success lifecycle stage completed.
  success,

  /// The execution or one of its required lifecycle stages failed.
  error,
}

/// A complete immutable erased view of one submitted mutation execution.
///
/// Cache snapshots never use [MutationStatus.idle]; idle exists only in
/// observer presentation before a submission or after reset.
final class MutationSnapshot {
  /// Creates and validates a submitted-execution snapshot.
  factory MutationSnapshot({
    required int id,
    required MutationStatus status,
    required Object? variables,
    required QueryValue<Object?> data,
    required DateTime submittedAt,
    MutationKey? key,
    bool isPaused = false,
    PauseReason? pauseReason,
    QueryFailure? failure,
    int failureCount = 0,
    QueryValue<Object?> onMutateResult = const QueryValue<Object?>.absent(),
    MutationScope? scope,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    if (id < 0) {
      throw ArgumentError.value(id, 'id', 'Must not be negative.');
    }
    if (failureCount < 0) {
      throw ArgumentError.value(
        failureCount,
        'failureCount',
        'Must not be negative.',
      );
    }
    if (status == MutationStatus.idle) {
      throw ArgumentError.value(
        status,
        'status',
        'Submitted mutation snapshots cannot be idle.',
      );
    }
    _validatePause(
      status: status,
      isPaused: isPaused,
      pauseReason: pauseReason,
      scope: scope,
    );
    _validateTerminalState(
      status: status,
      data: data,
      failure: failure,
      failureCount: failureCount,
    );
    return MutationSnapshot._(
      id: id,
      key: key,
      status: status,
      isPaused: isPaused,
      pauseReason: pauseReason,
      variables: variables,
      data: data,
      failure: failure,
      failureCount: failureCount,
      submittedAt: submittedAt,
      onMutateResult: onMutateResult,
      scope: scope,
      metadata: _freezeMetadata(metadata),
    );
  }

  const MutationSnapshot._({
    required this.id,
    required this.key,
    required this.status,
    required this.isPaused,
    required this.pauseReason,
    required this.variables,
    required this.data,
    required this.failure,
    required this.failureCount,
    required this.submittedAt,
    required this.onMutateResult,
    required this.scope,
    required this.metadata,
  });

  /// The client-local submission identifier.
  final int id;

  /// The optional structural key used for filtering and defaults.
  final MutationKey? key;

  /// The submitted execution status.
  final MutationStatus status;

  /// Whether pending work is waiting for online, focus, or scope eligibility.
  final bool isPaused;

  /// The current gate reason, present exactly while [isPaused].
  final PauseReason? pauseReason;

  /// The submitted variables with only their static generic erased.
  final Object? variables;

  /// Erased terminal data presence.
  final QueryValue<Object?> data;

  /// The current retryable or terminal failure, if any.
  final QueryFailure? failure;

  /// The number of thrown mutation-function attempts.
  final int failureCount;

  /// The wall-clock submission time.
  final DateTime submittedAt;

  /// Erased onMutate-result presence, including present-null.
  final QueryValue<Object?> onMutateResult;

  /// The optional same-client FIFO scope.
  final MutationScope? scope;

  /// Immutable application metadata captured at submission.
  final Map<String, Object?> metadata;

  /// Whether this execution is pending.
  bool get isPending => status == MutationStatus.pending;

  /// Whether this execution succeeded.
  bool get isSuccess => status == MutationStatus.success;

  /// Whether this execution failed.
  bool get isError => status == MutationStatus.error;
}

/// A read-only structural filter for submitted mutation snapshots.
final class MutationFilter {
  /// Creates a mutation filter.
  const MutationFilter({
    this.key,
    this.exact = false,
    this.status,
    this.isPaused,
    this.scope,
    this.predicate,
  });

  /// An optional exact or prefix structural key constraint.
  final MutationKey? key;

  /// Whether [key] must match exactly rather than by prefix.
  final bool exact;

  /// An optional submitted-execution status constraint.
  final MutationStatus? status;

  /// An optional pause-state constraint.
  final bool? isPaused;

  /// An optional same-client scope-ID constraint.
  final MutationScope? scope;

  /// An optional final read-only predicate.
  final bool Function(MutationSnapshot snapshot)? predicate;

  /// Whether [snapshot] satisfies every configured constraint.
  bool matches(MutationSnapshot snapshot) {
    final filterKey = key;
    if (filterKey != null) {
      final snapshotKey = snapshot.key;
      if (snapshotKey == null) return false;
      final keyMatches =
          exact ? snapshotKey == filterKey : snapshotKey.startsWith(filterKey);
      if (!keyMatches) return false;
    }

    final requiredStatus = status;
    if (requiredStatus != null && snapshot.status != requiredStatus) {
      return false;
    }
    final requiredPause = isPaused;
    if (requiredPause != null && snapshot.isPaused != requiredPause) {
      return false;
    }
    final requiredScope = scope;
    if (requiredScope != null && snapshot.scope != requiredScope) {
      return false;
    }
    final finalPredicate = predicate;
    return finalPredicate == null || finalPredicate(snapshot);
  }
}

/// The observable reason for a committed mutation-cache event.
enum MutationCacheEventKind {
  /// A submitted execution was added.
  added,

  /// A submitted execution's committed state changed.
  updated,

  /// An execution snapshot was removed from the cache.
  removed,
}

/// An immutable event emitted after a mutation-cache commit.
final class MutationCacheEvent {
  /// Creates a mutation-cache event.
  const MutationCacheEvent({required this.kind, required this.snapshot});

  /// The reason this event was emitted.
  final MutationCacheEventKind kind;

  /// The complete post-commit snapshot, or final snapshot for removal.
  final MutationSnapshot snapshot;
}

/// Global lifecycle callback before a recipe's mutate stage.
typedef MutationCacheOnMutate = FutureOr<void> Function(
  Object? variables,
  MutationContext context,
);

/// Global lifecycle callback for a successful mutation candidate.
typedef MutationCacheOnSuccess = FutureOr<void> Function(
  Object? data,
  Object? variables,
  QueryValue<Object?> onMutateResult,
  MutationContext context,
);

/// Global lifecycle callback for a primary mutation failure.
typedef MutationCacheOnError = FutureOr<void> Function(
  QueryFailure failure,
  Object? variables,
  QueryValue<Object?> onMutateResult,
  MutationContext context,
);

/// Global lifecycle callback after either mutation lifecycle.
typedef MutationCacheOnSettled = FutureOr<void> Function(
  QueryValue<Object?> data,
  QueryFailure? failure,
  Object? variables,
  QueryValue<Object?> onMutateResult,
  MutationContext context,
);

/// Immutable global callbacks captured independently by each submission.
final class MutationCacheCallbacks {
  /// Creates a global mutation lifecycle configuration.
  const MutationCacheCallbacks({
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  /// Callback before recipe onMutate.
  final MutationCacheOnMutate? onMutate;

  /// Callback before recipe onSuccess.
  final MutationCacheOnSuccess? onSuccess;

  /// Callback before recipe onError.
  final MutationCacheOnError? onError;

  /// Callback before recipe onSettled.
  final MutationCacheOnSettled? onSettled;
}

/// Type-independent client defaults for matching mutation recipes.
///
/// Register broad defaults before later, more specific key prefixes.
final class MutationDefaults {
  /// Creates a partial mutation-default registration.
  const MutationDefaults({
    this.retry,
    this.retention,
    this.networkMode,
  });

  /// Inference-neutral retry marker used when a recipe has no retry policy.
  final RetryPolicy<Never>? retry;

  /// Default settled snapshot retention.
  final RetentionPolicy? retention;

  /// Default connectivity behavior.
  final NetworkMode? networkMode;

  /// Applies every non-null value in [later] over this registration.
  MutationDefaults merge(MutationDefaults later) {
    return MutationDefaults(
      retry: later.retry ?? retry,
      retention: later.retention ?? retention,
      networkMode: later.networkMode ?? networkMode,
    );
  }
}

void _validatePause({
  required MutationStatus status,
  required bool isPaused,
  required PauseReason? pauseReason,
  required MutationScope? scope,
}) {
  if (isPaused != (pauseReason != null)) {
    throw ArgumentError(
      'pauseReason must be present exactly while isPaused is true.',
    );
  }
  if (isPaused && status != MutationStatus.pending) {
    throw ArgumentError.value(
      status,
      'status',
      'Only pending mutations can be paused.',
    );
  }
  if (pauseReason == PauseReason.scope && scope == null) {
    throw ArgumentError.value(
      scope,
      'scope',
      'A scope-paused mutation must have a scope.',
    );
  }
}

void _validateTerminalState({
  required MutationStatus status,
  required QueryValue<Object?> data,
  required QueryFailure? failure,
  required int failureCount,
}) {
  final isSuccess = status == MutationStatus.success;
  if (data.isPresent != isSuccess) {
    throw ArgumentError.value(
      data,
      'data',
      'Data must be present exactly for successful mutations.',
    );
  }
  if (status == MutationStatus.error && failure == null) {
    throw ArgumentError.value(
      failure,
      'failure',
      'An error mutation must contain a failure.',
    );
  }
  if (isSuccess && failure != null) {
    throw ArgumentError.value(
      failure,
      'failure',
      'A successful mutation cannot retain a failure.',
    );
  }
  if (isSuccess && failureCount != 0) {
    throw ArgumentError.value(
      failureCount,
      'failureCount',
      'A successful mutation must reset its failure count.',
    );
  }
}

Map<String, Object?> _freezeMetadata(Map<String, Object?> metadata) =>
    metadata.isEmpty
        ? const <String, Object?>{}
        : Map<String, Object?>.unmodifiable(metadata);
