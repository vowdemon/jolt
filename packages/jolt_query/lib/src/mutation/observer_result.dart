import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../query/state.dart';
import 'models.dart';

/// One complete immutable mutation-observer presentation.
final class MutationObserverResult<V, D, R> {
  /// Creates and validates a mutation observer result.
  factory MutationObserverResult({
    required MutationStatus status,
    required QueryValue<V> variables,
    required QueryValue<D> data,
    required QueryValue<R> onMutateResult,
    bool isPaused = false,
    PauseReason? pauseReason,
    QueryFailure? failure,
    int failureCount = 0,
    DateTime? submittedAt,
  }) {
    _validateObserverState(
      status: status,
      variables: variables,
      data: data,
      onMutateResult: onMutateResult,
      isPaused: isPaused,
      pauseReason: pauseReason,
      failure: failure,
      failureCount: failureCount,
      submittedAt: submittedAt,
    );
    return MutationObserverResult<V, D, R>._(
      status: status,
      variables: variables,
      data: data,
      onMutateResult: onMutateResult,
      isPaused: isPaused,
      pauseReason: pauseReason,
      failure: failure,
      failureCount: failureCount,
      submittedAt: submittedAt,
    );
  }

  /// Creates the initial or reset idle presentation.
  factory MutationObserverResult.idle() {
    return MutationObserverResult<V, D, R>(
      status: MutationStatus.idle,
      variables: QueryValue<V>.absent(),
      data: QueryValue<D>.absent(),
      onMutateResult: QueryValue<R>.absent(),
    );
  }

  const MutationObserverResult._({
    required this.status,
    required this.variables,
    required this.data,
    required this.onMutateResult,
    required this.isPaused,
    required this.pauseReason,
    required this.failure,
    required this.failureCount,
    required this.submittedAt,
  });

  /// The observer presentation status.
  final MutationStatus status;

  /// Submitted variables, absent only while idle.
  final QueryValue<V> variables;

  /// Successful result data, including present-null.
  final QueryValue<D> data;

  /// Result of onMutate, including absent and present-null states.
  final QueryValue<R> onMutateResult;

  /// Whether pending work is waiting for an eligibility gate.
  final bool isPaused;

  /// The current gate reason, present exactly while [isPaused].
  final PauseReason? pauseReason;

  /// The current retryable or terminal failure, if any.
  final QueryFailure? failure;

  /// The number of thrown mutation-function attempts.
  final int failureCount;

  /// The latest presented execution's submission time, or null while idle.
  final DateTime? submittedAt;

  /// Whether no execution is currently presented.
  bool get isIdle => status == MutationStatus.idle;

  /// Whether the presented execution is still active.
  bool get isPending => status == MutationStatus.pending;

  /// Whether the presented execution succeeded.
  bool get isSuccess => status == MutationStatus.success;

  /// Whether the presented execution failed.
  bool get isError => status == MutationStatus.error;
}

void _validateObserverState({
  required MutationStatus status,
  required QueryValue<Object?> variables,
  required QueryValue<Object?> data,
  required QueryValue<Object?> onMutateResult,
  required bool isPaused,
  required PauseReason? pauseReason,
  required QueryFailure? failure,
  required int failureCount,
  required DateTime? submittedAt,
}) {
  if (failureCount < 0) {
    throw ArgumentError.value(
      failureCount,
      'failureCount',
      'Must not be negative.',
    );
  }

  final isIdle = status == MutationStatus.idle;
  final isSuccess = status == MutationStatus.success;
  if (variables.isAbsent != isIdle) {
    throw ArgumentError.value(
      variables,
      'variables',
      'Variables must be absent exactly while idle.',
    );
  }
  if (data.isPresent != isSuccess) {
    throw ArgumentError.value(
      data,
      'data',
      'Data must be present exactly while successful.',
    );
  }
  if (isIdle && onMutateResult.isPresent) {
    throw ArgumentError.value(
      onMutateResult,
      'onMutateResult',
      'Idle presentation cannot contain an onMutate result.',
    );
  }
  if ((submittedAt == null) != isIdle) {
    throw ArgumentError.value(
      submittedAt,
      'submittedAt',
      'Submission time must be null exactly while idle.',
    );
  }
  if (isPaused != (pauseReason != null)) {
    throw ArgumentError(
      'pauseReason must be present exactly while isPaused is true.',
    );
  }
  if (isPaused && status != MutationStatus.pending) {
    throw ArgumentError.value(
      status,
      'status',
      'Only pending observer results can be paused.',
    );
  }
  if (status == MutationStatus.error && failure == null) {
    throw ArgumentError.value(
      failure,
      'failure',
      'An error result must contain a failure.',
    );
  }
  if (isSuccess && failure != null) {
    throw ArgumentError.value(
      failure,
      'failure',
      'A successful result cannot contain a failure.',
    );
  }
  if (isSuccess && failureCount != 0) {
    throw ArgumentError.value(
      failureCount,
      'failureCount',
      'A successful result must reset its failure count.',
    );
  }
}
