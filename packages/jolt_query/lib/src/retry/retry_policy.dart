import 'dart:async';

import 'package:jolt/jolt.dart' show Effect;
import 'package:retry_plus/retry_plus.dart'
    show
        AttemptOutcome,
        AttemptOutcomeError,
        AttemptOutcomeResult,
        DelayPolicy,
        RetryAttemptContext,
        RetryIf,
        RetryPipelineContext,
        RetryStrategy;

import '../foundation/environment_manager.dart';
import '../foundation/query_cancellation.dart';
import '../foundation/query_failure.dart';
import '../foundation/query_runtime.dart';
import '../foundation/timer_orchestrator.dart';

part 'retry_executor.dart';

/// The non-generic package boundary shared by erased query plans.
///
/// This type deliberately contains no `retry_plus` vocabulary. Applications
/// configure retry through the typed [RetryPolicy] facade instead.
abstract base class RetryPolicyBase {
  const RetryPolicyBase();
}

/// A typed description of retry behavior for one raw operation result.
///
/// [none] and [standard] are inference-neutral markers. A custom policy keeps
/// [T] visible to predicates and hooks, while the strategy itself is created
/// once for each logical operation.
sealed class RetryPolicy<T> extends RetryPolicyBase {
  const RetryPolicy._();

  /// Never retries.
  static const RetryPolicy<Never> none = _NoRetryPolicy();

  /// Retries exceptions three times with non-jittered exponential backoff.
  ///
  /// Delays begin at one second and are capped at thirty seconds.
  static const RetryPolicy<Never> standard = _StandardRetryPolicy();

  /// Creates a typed custom policy from a `retry_plus` strategy description.
  ///
  /// Users of this factory declare `retry_plus` as a direct dependency and
  /// import it themselves. Jolt Query does not invoke an upstream retry
  /// executor and does not re-export any `retry_plus` symbol.
  factory RetryPolicy.custom(
    RetryStrategy<T> Function(RetryBuilder<T> retry) create,
  ) = _CustomRetryPolicy<T>;
}

final class _NoRetryPolicy extends RetryPolicy<Never> {
  const _NoRetryPolicy() : super._();
}

final class _StandardRetryPolicy extends RetryPolicy<Never> {
  const _StandardRetryPolicy() : super._();
}

final class _CustomRetryPolicy<T> extends RetryPolicy<T> {
  const _CustomRetryPolicy(this.create) : super._();

  final RetryStrategy<T> Function(RetryBuilder<T> retry) create;
}

/// A narrow type witness for constructing a `RetryStrategy<T>`.
///
/// These helpers keep exception-only expressions typed to [T]. Every returned
/// predicate and strategy is still the corresponding `retry_plus` 0.1.1 type,
/// so callers can compose it with that package's complete policy vocabulary.
final class RetryBuilder<T> {
  const RetryBuilder._();

  /// Matches every exception outcome.
  RetryIf<T> get exceptions => RetryIf<T>.exception();

  /// Matches exception outcomes accepted by [test].
  RetryIf<T> exceptionWhere(
    FutureOr<bool> Function(Object error, StackTrace stackTrace) test,
  ) {
    return RetryIf<T>.exceptionWhere(test);
  }

  /// Matches exception outcomes whose error is an [E].
  RetryIf<T> exceptionType<E extends Object>() {
    return RetryIf.exceptionType<E, T>();
  }

  /// Matches successful results accepted by [test].
  RetryIf<T> result(FutureOr<bool> Function(T result) test) {
    return RetryIf<T>.result(test);
  }

  /// Matches attempts accepted by [test].
  RetryIf<T> where(
    FutureOr<bool> Function(RetryAttemptContext<T> attempt) test,
  ) {
    return RetryIf<T>.where(test);
  }

  /// Matches every result or exception outcome.
  RetryIf<T> get any => RetryIf<T>.any();

  /// Matches no outcomes.
  RetryIf<T> get never => RetryIf<T>.never();

  /// Allows another retry while its zero-based index is below [retries].
  RetryIf<T> maxRetries(int retries) => RetryIf<T>.maxRetries(retries);

  /// Creates a strategy while preserving [T] across all callbacks.
  RetryStrategy<T> strategy({
    String? name,
    DelayPolicy? delay,
    RetryIf<T>? retryIf,
    FutureOr<void> Function(RetryAttemptContext<T> attempt)? onRetry,
    FutureOr<void> Function(RetryAttemptContext<T> attempt)? onGiveUp,
  }) {
    return RetryStrategy<T>(
      name: name,
      delay: delay,
      retryIf: retryIf,
      onRetry: onRetry,
      onGiveUp: onGiveUp,
    );
  }
}
