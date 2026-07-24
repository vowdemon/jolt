import 'package:meta/meta.dart' show internal;

import '../retry/retry_policy.dart';

/// Controls whether an observer-triggered refetch should run.
enum RefetchPolicy {
  /// Never refetch for this trigger.
  never,

  /// Refetch only while the observer considers the data stale.
  stale,

  /// Refetch whenever the trigger occurs.
  always,
}

/// Selects which matched entries should execute during a bulk lifecycle call.
enum QueryRefetchTarget {
  /// Change matching cache state without executing a query function.
  none,

  /// Execute only entries with at least one enabled observer.
  active,

  /// Execute only entries without an enabled observer.
  ///
  /// Entries observed exclusively by disabled observers are inactive.
  inactive,

  /// Execute every eligible matched entry.
  all,
}

/// Controls how an operation interacts with online state.
enum NetworkMode {
  /// Wait for online state before the first attempt and every retry.
  online,

  /// Ignore online state for every attempt.
  always,

  /// Allow the first attempt offline, then wait before subsequent retries.
  offlineFirst,
}

/// Type-independent client defaults applied by structural key prefix.
///
/// Registrations are merged in registration order. A later non-null field
/// replaces the earlier value, so broad prefixes should be registered before
/// more specific prefixes.
final class QueryDefaults {
  /// Creates a partial query-default registration.
  const QueryDefaults({
    this.retry,
    this.staleTime,
    this.retention,
    this.networkMode,
    this.enabled,
    this.refetchOnMount,
    this.refetchOnFocus,
    this.refetchOnReconnect,
    this.retryOnMount,
    this.pollingInterval,
    this.pollingEnabled,
    this.pollInBackground,
  });

  /// Inference-neutral retry marker used when a recipe has no typed policy.
  final RetryPolicy<Never>? retry;

  /// Default freshness for imperative and observer reads.
  final StalePolicy? staleTime;

  /// Default inactive cache retention.
  final RetentionPolicy? retention;

  /// Default connectivity behavior.
  final NetworkMode? networkMode;

  /// Whether observers activate automatically.
  final bool? enabled;

  /// Mount-triggered refetch behavior.
  final RefetchPolicy? refetchOnMount;

  /// Focus-triggered refetch behavior.
  final RefetchPolicy? refetchOnFocus;

  /// Reconnect-triggered refetch behavior.
  final RefetchPolicy? refetchOnReconnect;

  /// Whether a failed entry retries when an observer mounts.
  final bool? retryOnMount;

  /// Default observer polling interval.
  final Duration? pollingInterval;

  /// Whether polling is enabled when an interval is inherited.
  ///
  /// False explicitly disables a broader default interval.
  final bool? pollingEnabled;

  /// Whether polling continues while the client is unfocused.
  final bool? pollInBackground;

  /// Applies every non-null value in [later] over this registration.
  QueryDefaults merge(QueryDefaults later) {
    final retry = later.retry ?? this.retry;
    if (retry != null &&
        !identical(retry, RetryPolicy.none) &&
        !identical(retry, RetryPolicy.standard)) {
      throw ArgumentError.value(
        retry,
        'retry',
        'Query defaults accept only RetryPolicy.none or '
            'RetryPolicy.standard. Apply typed custom retry to the recipe.',
      );
    }
    final interval = later.pollingInterval ?? pollingInterval;
    final pollingEnabled = later.pollingEnabled ??
        (later.pollingInterval != null ? true : this.pollingEnabled);
    if (interval != null && interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'pollingInterval',
        'A polling interval must be positive.',
      );
    }
    return QueryDefaults(
      retry: retry,
      staleTime: later.staleTime ?? staleTime,
      retention: later.retention ?? retention,
      networkMode: later.networkMode ?? networkMode,
      enabled: later.enabled ?? enabled,
      refetchOnMount: later.refetchOnMount ?? refetchOnMount,
      refetchOnFocus: later.refetchOnFocus ?? refetchOnFocus,
      refetchOnReconnect: later.refetchOnReconnect ?? refetchOnReconnect,
      retryOnMount: later.retryOnMount ?? retryOnMount,
      pollingInterval: interval,
      pollingEnabled: pollingEnabled,
      pollInBackground: later.pollInBackground ?? pollInBackground,
    );
  }
}

/// The inputs available to a resolver-based [StalePolicy].
final class StaleState {
  /// Creates a staleness snapshot.
  const StaleState({
    required this.now,
    required this.updatedAt,
    required this.isInvalidated,
  });

  /// The current wall-clock time.
  final DateTime now;

  /// The time at which data was last committed.
  final DateTime updatedAt;

  /// Whether invalidation occurred after the last successful commit.
  final bool isInvalidated;

  /// The non-negative age of the committed data.
  Duration get age {
    final elapsed = now.difference(updatedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
}

/// Computes whether data is stale for one observer.
typedef StaleResolver = bool Function(StaleState state);

/// Observer- or recipe-level data freshness policy.
sealed class StalePolicy {
  const StalePolicy._();

  /// Data is stale as soon as it has been committed.
  static const StalePolicy immediate = _ImmediateStalePolicy();

  /// Data stays fresh until explicitly invalidated.
  static const StalePolicy untilInvalidated = _UntilInvalidatedStalePolicy();

  /// Data never refetches automatically, including after invalidation.
  static const StalePolicy immutable = _ImmutableStalePolicy();

  /// Data becomes stale after [duration].
  factory StalePolicy.duration(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(
        duration,
        'duration',
        'A stale duration cannot be negative.',
      );
    }
    return _DurationStalePolicy(duration);
  }

  /// Delegates staleness to [resolve].
  ///
  /// Because an arbitrary resolver has no predictable time boundary, observers
  /// recalculate it when query, target, or environment state changes.
  factory StalePolicy.resolve(StaleResolver resolve) = _ResolvedStalePolicy;

  /// Whether [state] is stale under this policy.
  bool isStale(StaleState state);

  /// Whether automatic and bulk refetch execution is disabled.
  bool get isImmutable => false;

  /// Package seam used to publish a predictable fresh-to-stale edge.
  @internal
  Duration? timeUntilStaleInternal(StaleState state) => null;
}

final class _ImmediateStalePolicy extends StalePolicy {
  const _ImmediateStalePolicy() : super._();

  @override
  bool isStale(StaleState state) => true;

  @override
  Duration timeUntilStaleInternal(StaleState state) => Duration.zero;
}

final class _UntilInvalidatedStalePolicy extends StalePolicy {
  const _UntilInvalidatedStalePolicy() : super._();

  @override
  bool isStale(StaleState state) => state.isInvalidated;
}

final class _ImmutableStalePolicy extends StalePolicy {
  const _ImmutableStalePolicy() : super._();

  @override
  bool isStale(StaleState state) => false;

  @override
  bool get isImmutable => true;
}

final class _DurationStalePolicy extends StalePolicy {
  const _DurationStalePolicy(this.duration) : super._();

  final Duration duration;

  @override
  bool isStale(StaleState state) =>
      state.isInvalidated || state.age >= duration;

  @override
  Duration timeUntilStaleInternal(StaleState state) {
    final remaining = state.updatedAt.add(duration).difference(state.now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

final class _ResolvedStalePolicy extends StalePolicy {
  const _ResolvedStalePolicy(this.resolve) : super._();

  final StaleResolver resolve;

  @override
  bool isStale(StaleState state) => resolve(state);
}

/// Cache retention after an entry loses its final observer.
sealed class RetentionPolicy {
  const RetentionPolicy._();

  /// The standard five-minute retention used by queries.
  static const RetentionPolicy standard =
      _DurationRetentionPolicy(Duration(minutes: 5));

  /// Retains an entry until it is explicitly removed or its client is disposed.
  static const RetentionPolicy forever = _ForeverRetentionPolicy();

  /// Retains an entry for [duration].
  factory RetentionPolicy.duration(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(
        duration,
        'duration',
        'A retention duration cannot be negative.',
      );
    }
    return _DurationRetentionPolicy(duration);
  }

  /// The finite duration, or `null` for [forever].
  Duration? get duration;

  /// Whether this policy disables time-based garbage collection.
  bool get isForever => duration == null;
}

final class _DurationRetentionPolicy extends RetentionPolicy {
  const _DurationRetentionPolicy(this.value) : super._();

  final Duration value;

  @override
  Duration get duration => value;
}

final class _ForeverRetentionPolicy extends RetentionPolicy {
  const _ForeverRetentionPolicy() : super._();

  @override
  Duration? get duration => null;
}
