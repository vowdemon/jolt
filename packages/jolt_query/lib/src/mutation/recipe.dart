import 'dart:async';

import 'package:meta/meta.dart' show internal, nonVirtual;
import 'package:retry_plus/retry_plus.dart' show RetryStrategy;

import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import '../query/client.dart';
import '../query/policies.dart';
import '../retry/retry_policy.dart';

/// A serial lane identifier for mutations submitted to one client.
final class MutationScope {
  /// Creates a scope identified by [id].
  const MutationScope(this.id);

  /// The application-owned lane identifier.
  final String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MutationScope && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MutationScope($id)';
}

/// Immutable capabilities and recipe identity for one submitted mutation.
final class MutationContext {
  /// Creates a context for one submitted mutation.
  factory MutationContext({
    required QueryClient client,
    MutationKey? key,
    MutationScope? scope,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return MutationContext._(
      client: client,
      key: key,
      scope: scope,
      metadata: _freezeMetadata(metadata),
    );
  }

  const MutationContext._({
    required this.client,
    required this.key,
    required this.scope,
    required this.metadata,
  });

  /// The client that owns this submission.
  final QueryClient client;

  /// The optional structural key of the submitted mutation.
  final MutationKey? key;

  /// The optional same-client FIFO execution scope.
  final MutationScope? scope;

  /// Immutable application metadata captured for this submission.
  final Map<String, Object?> metadata;
}

/// Optional work performed before the mutation function.
///
/// Its return value is carried to every later lifecycle callback as an
/// explicit [QueryValue], so absence remains distinct from present `null`.
typedef MutationOnMutate<V, R> = FutureOr<R> Function(
  V variables,
  MutationContext context,
);

/// A reusable class-first mutation definition.
///
/// [V] is the variables type, [D] is successful data, and [R] is the optional
/// [onMutate] result. Subclasses only need to implement [mutate].
abstract base class Mutation<V, D, R> {
  /// Creates a reusable mutation recipe.
  ///
  /// Omitted policies inherit matching client defaults. Supplying a value,
  /// including a built-in value such as [NetworkMode.online], makes it an
  /// explicit recipe override.
  const Mutation({
    RetryPolicy<D>? retry,
    NetworkMode? networkMode,
    RetentionPolicy? retention,
  })  : _configuredRetry = retry,
        _configuredNetworkMode = networkMode,
        _configuredRetention = retention;

  final RetryPolicy<D>? _configuredRetry;
  final NetworkMode? _configuredNetworkMode;
  final RetentionPolicy? _configuredRetention;

  /// Optional structural key used by defaults, filtering, and observation.
  MutationKey? get key => null;

  /// Optional same-client FIFO execution scope.
  MutationScope? get scope => null;

  /// Immutable application metadata captured at submission.
  Map<String, Object?> get metadata => const <String, Object?>{};

  /// Connectivity behavior for the first attempt and retries.
  @nonVirtual
  NetworkMode get networkMode => _configuredNetworkMode ?? NetworkMode.online;

  /// Retention applied after this execution settles.
  @nonVirtual
  RetentionPolicy get retentionPolicy =>
      _configuredRetention ?? RetentionPolicy.standard;

  /// Retry policy for the mutation result type.
  ///
  /// Mutation retry is disabled by default. Retried writes should be
  /// idempotent or carry an application-level idempotency key.
  @nonVirtual
  RetryPolicy<D> get retryPolicy => _configuredRetry ?? RetryPolicy.none;

  /// Explicit retry policy, or null when matching defaults may supply it.
  @internal
  @nonVirtual
  RetryPolicy<D>? get configuredRetryInternal => _configuredRetry;

  /// Explicit network mode, or null when matching defaults may supply it.
  @internal
  @nonVirtual
  NetworkMode? get configuredNetworkModeInternal => _configuredNetworkMode;

  /// Explicit retention, or null when matching defaults may supply it.
  @internal
  @nonVirtual
  RetentionPolicy? get configuredRetentionInternal => _configuredRetention;

  /// Optional pre-mutation lifecycle callback.
  MutationOnMutate<V, R>? get onMutate => null;

  /// Runs one mutation-function attempt.
  FutureOr<D> mutate(V variables, MutationContext context);

  /// Runs after the mutation function and earlier success stages succeed.
  FutureOr<void> onSuccess(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {}

  /// Runs for the primary mutation or lifecycle failure.
  FutureOr<void> onError(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {}

  /// Runs after either the success or error lifecycle.
  FutureOr<void> onSettled(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {}

  /// Returns the same definition with a typed custom retry strategy.
  Mutation<V, D, R> retry(
    RetryStrategy<D> Function(RetryBuilder<D> retry) create,
  ) {
    return _RetryMutation<V, D, R>(this, RetryPolicy<D>.custom(create));
  }
}

/// Creates an inference-friendly inline mutation definition.
Mutation<V, D, R> mutation<V, D, R>({
  required FutureOr<D> Function(V variables, MutationContext context) mutate,
  MutationKey? key,
  MutationScope? scope,
  Map<String, Object?> metadata = const <String, Object?>{},
  NetworkMode? networkMode,
  RetentionPolicy? retention,
  RetryPolicy<Never>? retry,
  MutationOnMutate<V, R>? onMutate,
  FutureOr<void> Function(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  )? onSuccess,
  FutureOr<void> Function(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  )? onError,
  FutureOr<void> Function(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  )? onSettled,
}) {
  return _InlineMutation<V, D, R>(
    mutate: mutate,
    key: key,
    scope: scope,
    metadata: _freezeMetadata(metadata),
    networkMode: networkMode,
    retention: retention,
    retry: _markerRetry<D>(retry),
    onMutate: onMutate,
    onSuccess: onSuccess,
    onError: onError,
    onSettled: onSettled,
  );
}

/// Sentinel used internally by the zero-variable action facade.
enum NoVariables {
  /// The only value passed through the mutation runtime.
  value,
}

/// Creates a zero-variable mutation definition.
Mutation<NoVariables, D, R> action<D, R>({
  required FutureOr<D> Function(MutationContext context) mutate,
  MutationKey? key,
  MutationScope? scope,
  Map<String, Object?> metadata = const <String, Object?>{},
  NetworkMode? networkMode,
  RetentionPolicy? retention,
  RetryPolicy<Never>? retry,
  FutureOr<R> Function(MutationContext context)? onMutate,
  FutureOr<void> Function(
    D data,
    QueryValue<R> onMutateResult,
    MutationContext context,
  )? onSuccess,
  FutureOr<void> Function(
    QueryFailure failure,
    QueryValue<R> onMutateResult,
    MutationContext context,
  )? onError,
  FutureOr<void> Function(
    QueryValue<D> data,
    QueryFailure? failure,
    QueryValue<R> onMutateResult,
    MutationContext context,
  )? onSettled,
}) {
  return mutation<NoVariables, D, R>(
    mutate: (_, context) => mutate(context),
    key: key,
    scope: scope,
    metadata: metadata,
    networkMode: networkMode,
    retention: retention,
    retry: retry,
    onMutate: onMutate == null ? null : (_, context) => onMutate(context),
    onSuccess: onSuccess == null
        ? null
        : (data, _, result, context) => onSuccess(data, result, context),
    onError: onError == null
        ? null
        : (failure, _, result, context) => onError(failure, result, context),
    onSettled: onSettled == null
        ? null
        : (data, failure, _, result, context) =>
            onSettled(data, failure, result, context),
  );
}

final class _InlineMutation<V, D, R> extends Mutation<V, D, R> {
  const _InlineMutation({
    required FutureOr<D> Function(V, MutationContext) mutate,
    required this.key,
    required this.scope,
    required this.metadata,
    required super.networkMode,
    required super.retention,
    required super.retry,
    required MutationOnMutate<V, R>? onMutate,
    required FutureOr<void> Function(D, V, QueryValue<R>, MutationContext)?
        onSuccess,
    required FutureOr<void> Function(
      QueryFailure,
      V,
      QueryValue<R>,
      MutationContext,
    )? onError,
    required FutureOr<void> Function(
      QueryValue<D>,
      QueryFailure?,
      V,
      QueryValue<R>,
      MutationContext,
    )? onSettled,
  })  : _mutate = mutate,
        _onMutate = onMutate,
        _onSuccess = onSuccess,
        _onError = onError,
        _onSettled = onSettled;

  final FutureOr<D> Function(V, MutationContext) _mutate;
  final MutationOnMutate<V, R>? _onMutate;
  final FutureOr<void> Function(D, V, QueryValue<R>, MutationContext)?
      _onSuccess;
  final FutureOr<void> Function(
    QueryFailure,
    V,
    QueryValue<R>,
    MutationContext,
  )? _onError;
  final FutureOr<void> Function(
    QueryValue<D>,
    QueryFailure?,
    V,
    QueryValue<R>,
    MutationContext,
  )? _onSettled;

  @override
  final MutationKey? key;

  @override
  final MutationScope? scope;

  @override
  final Map<String, Object?> metadata;

  @override
  MutationOnMutate<V, R>? get onMutate => _onMutate;

  @override
  FutureOr<D> mutate(V variables, MutationContext context) =>
      _mutate(variables, context);

  @override
  FutureOr<void> onSuccess(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) =>
      _onSuccess?.call(data, variables, onMutateResult, context);

  @override
  FutureOr<void> onError(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) =>
      _onError?.call(failure, variables, onMutateResult, context);

  @override
  FutureOr<void> onSettled(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) =>
      _onSettled?.call(data, failure, variables, onMutateResult, context);
}

final class _RetryMutation<V, D, R> extends Mutation<V, D, R> {
  _RetryMutation(
    this._source,
    RetryPolicy<D> retryPolicy,
  ) : super(
          retry: retryPolicy,
          networkMode: _source._configuredNetworkMode,
          retention: _source._configuredRetention,
        );

  final Mutation<V, D, R> _source;

  @override
  MutationKey? get key => _source.key;

  @override
  MutationScope? get scope => _source.scope;

  @override
  Map<String, Object?> get metadata => _source.metadata;

  @override
  MutationOnMutate<V, R>? get onMutate => _source.onMutate;

  @override
  FutureOr<D> mutate(V variables, MutationContext context) =>
      _source.mutate(variables, context);

  @override
  FutureOr<void> onSuccess(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) =>
      _source.onSuccess(data, variables, onMutateResult, context);

  @override
  FutureOr<void> onError(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) =>
      _source.onError(failure, variables, onMutateResult, context);

  @override
  FutureOr<void> onSettled(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) =>
      _source.onSettled(
        data,
        failure,
        variables,
        onMutateResult,
        context,
      );
}

/// Per-submission typed lifecycle retained by the runtime.
@internal
abstract interface class MutationLifecycleInternal<V, D, R> {
  QueryValue<R> get onMutateResult;
  QueryValue<Object?> get erasedOnMutateResult;

  FutureOr<void> runOnMutate(V variables, MutationContext context);
  FutureOr<D> mutate(V variables, MutationContext context);
  FutureOr<void> onSuccess(D data, V variables, MutationContext context);
  FutureOr<void> onError(
    QueryFailure failure,
    V variables,
    MutationContext context,
  );
  FutureOr<void> onSettled(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    MutationContext context,
  );
}

/// Creates a fresh lifecycle for one submission.
@internal
MutationLifecycleInternal<V, D, R> createMutationLifecycleInternal<V, D, R>(
  Mutation<V, D, R> mutation,
) =>
    _MutationLifecycle<V, D, R>(mutation);

final class _MutationLifecycle<V, D, R>
    implements MutationLifecycleInternal<V, D, R> {
  _MutationLifecycle(this.mutation);

  final Mutation<V, D, R> mutation;
  QueryValue<R> _onMutateResult = QueryValue<R>.absent();

  @override
  QueryValue<R> get onMutateResult => _onMutateResult;

  @override
  QueryValue<Object?> get erasedOnMutateResult => switch (_onMutateResult) {
        QueryAbsent<R>() => const QueryValue<Object?>.absent(),
        QueryPresent<R>(:final value) => QueryValue<Object?>.present(value),
      };

  @override
  Future<void> runOnMutate(V variables, MutationContext context) async {
    final callback = mutation.onMutate;
    if (callback == null) return;
    final result = await callback(variables, context);
    _onMutateResult = QueryValue<R>.present(result);
  }

  @override
  FutureOr<D> mutate(V variables, MutationContext context) =>
      mutation.mutate(variables, context);

  @override
  FutureOr<void> onSuccess(
    D data,
    V variables,
    MutationContext context,
  ) =>
      mutation.onSuccess(data, variables, _onMutateResult, context);

  @override
  FutureOr<void> onError(
    QueryFailure failure,
    V variables,
    MutationContext context,
  ) =>
      mutation.onError(failure, variables, _onMutateResult, context);

  @override
  FutureOr<void> onSettled(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    MutationContext context,
  ) =>
      mutation.onSettled(
        data,
        failure,
        variables,
        _onMutateResult,
        context,
      );
}

RetryPolicy<D>? _markerRetry<D>(RetryPolicy<Never>? retry) {
  if (retry == null) return null;
  final marker = retry;
  if (!identical(marker, RetryPolicy.none) &&
      !identical(marker, RetryPolicy.standard)) {
    throw ArgumentError.value(
      retry,
      'retry',
      'Marker retry slots accept only RetryPolicy.none or '
          'RetryPolicy.standard. Apply typed custom retry with retry().',
    );
  }
  return marker;
}

Map<String, Object?> _freezeMetadata(Map<String, Object?> metadata) =>
    metadata.isEmpty
        ? const <String, Object?>{}
        : Map<String, Object?>.unmodifiable(metadata);
