import 'dart:async';

import 'package:jolt/jolt.dart' show untracked;
import 'package:meta/meta.dart' show internal, nonVirtual;
import 'package:retry_plus/retry_plus.dart' show RetryStrategy;

import '../foundation/environment_manager.dart';
import '../foundation/query_cancellation.dart';
import '../foundation/query_runtime.dart';
import '../foundation/query_value.dart';
import '../foundation/timer_orchestrator.dart';
import '../keys/query_key.dart';
import '../retry/retry_policy.dart';
import 'client.dart';
import 'observer_result.dart';
import 'policies.dart';
import 'reconciliation.dart';

/// One raw query attempt.
typedef QueryFunction<TData> = FutureOr<TData> Function(QueryContext context);

/// Equality used by one observer's selected presentation.
typedef QueryDataEquality<T> = bool Function(T previous, T next);

/// Resolves observer-local placeholder presence from a previous presentation.
typedef QueryPlaceholderResolver<T> = QueryValue<T> Function(
  QueryValue<T> previous,
);

/// A raw typed cache carrier accepted by exact QueryClient data operations.
///
/// Ordinary [Query] and raw `InfiniteQuery` recipes implement this contract.
/// Selected views do not, because their view type is not the shared raw cache
/// type.
abstract interface class QueryDataTarget<TData> {
  /// Structural key of the shared raw cache entry.
  QueryKey get key;

  /// Structural sharing policy applied by exact writes through this carrier.
  DataReconciler<TData> get reconciler;
}

/// Capabilities supplied to a query function for one attempt.
final class QueryContext {
  /// Creates a query context.
  QueryContext({
    required this.client,
    required this.key,
    required this.cancellationToken,
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : metadata = Map<String, Object?>.unmodifiable(metadata),
        streamDataInternal = null,
        _operationGuardInternal = null;

  QueryContext._resolved({
    required this.client,
    required this.key,
    required this.cancellationToken,
    required this.metadata,
    required this.streamDataInternal,
    required void Function()? operationGuardInternal,
  }) : _operationGuardInternal = operationGuardInternal;

  /// The client actually executing this attempt.
  ///
  /// This can differ from a target's configured client when an operation is
  /// invoked through another explicit [QueryClient] receiver.
  final QueryClient client;

  /// The structural key of the operation being attempted.
  final QueryKey key;

  /// Cooperative cancellation for this attempt.
  final QueryCancellationToken cancellationToken;

  /// Immutable recipe metadata captured by the logical operation.
  final Map<String, Object?> metadata;

  /// Package-owned incremental-data capabilities for streamed helpers.
  @internal
  final QueryStreamDataControllerInternal? streamDataInternal;

  final void Function()? _operationGuardInternal;

  /// Rejects continuation after the owning operation loses cache ownership.
  ///
  /// Package-owned multi-transport helpers call this between transports so a
  /// cancellation or replacement cannot start later external work.
  @internal
  void ensureOperationCurrentInternal() => _operationGuardInternal?.call();
}

/// Internal streamed-attempt visibility mode.
enum QueryStreamAttemptModeInternal { reset, append, replace }

/// Internal operation-guarded data writes available to streamed query helpers.
abstract interface class QueryStreamDataControllerInternal {
  /// Starts a fresh retry attempt and returns the logical-operation baseline.
  QueryValue<Object?> beginAttempt(QueryStreamAttemptModeInternal mode);

  /// Publishes one successfully reduced partial value.
  void commitPartial(Object? data);
}

/// Runtime-owned capabilities used to create one guarded query operation.
///
/// This type is intentionally not exported by the package barrel. It lets an
/// erased cache entry ask a typed plan to construct its own retry executor.
final class QueryPlanExecution {
  /// Creates an execution capability bundle.
  const QueryPlanExecution({
    required this.client,
    required this.runtime,
    required this.timers,
    required this.cancellation,
    required this.onlineManager,
    required this.focusManager,
    required this.defaultPolicy,
    this.networkModeOverride,
    this.guard,
    this.canStartRetry,
    this.onAttemptFailure,
    this.onOnlinePauseChanged,
    this.onFocusPauseChanged,
    this.streamData,
  });

  final QueryClient client;
  final QueryRuntime runtime;
  final TimerOrchestrator timers;
  final QueryCancellationController cancellation;
  final OnlineManager onlineManager;
  final FocusManager focusManager;
  final RetryPolicy<Never> defaultPolicy;
  final NetworkMode? networkModeOverride;
  final RetryExecutionGuard? guard;
  final bool Function()? canStartRetry;
  final RetryAttemptFailureCallback? onAttemptFailure;
  final RetryOnlinePauseCallback? onOnlinePauseChanged;
  final RetryFocusPauseCallback? onFocusPauseChanged;
  final QueryStreamDataControllerInternal? streamData;
}

/// An erased operation whose typed retry executor remains hidden in its plan.
abstract interface class ResolvedQueryOperation {
  /// The guarded operation result.
  Future<Object?> get result;

  /// Prevents another retry without cancelling an attempt already in flight.
  void stopRetries();

  /// Temporarily prevents later retry attempts.
  void pauseRetries();

  /// Restores retry eligibility after [pauseRetries].
  void resumeRetries();
}

/// Immutable erased fetch-plan boundary retained by cache entries.
abstract base class ResolvedQueryPlanBase {
  /// Creates an erased resolved-plan boundary.
  const ResolvedQueryPlanBase();

  QueryKey get key;
  RetryPolicyBase? get configuredRetry;
  NetworkMode get networkMode;
  bool get hasExplicitNetworkMode;
  StalePolicy get stalePolicy;
  bool get hasExplicitStalePolicy;
  RetentionPolicy get retentionPolicy;
  bool get hasExplicitRetentionPolicy;
  Map<String, Object?> get metadata;
  DataReconcilerBase get reconciler;

  /// Invokes one raw attempt without applying retry.
  FutureOr<Object?> fetch(QueryContext context);

  /// Creates an operation while retaining the plan's original result type.
  ResolvedQueryOperation createOperation(QueryPlanExecution execution);

  /// Reconciles erased values inside the plan's original result type.
  Object? reconcileData(Object? previous, Object? next);
}

/// An immutable fetch plan captured from a typed [Query].
final class ResolvedQueryPlan<TData> extends ResolvedQueryPlanBase {
  /// Creates a typed immutable fetch plan.
  ResolvedQueryPlan({
    required this.key,
    required QueryFunction<TData> fetch,
    required this.configuredRetry,
    required this.networkMode,
    this.hasExplicitNetworkMode = true,
    required this.stalePolicy,
    this.hasExplicitStalePolicy = true,
    required this.retentionPolicy,
    this.hasExplicitRetentionPolicy = true,
    required Map<String, Object?> metadata,
    required this.reconciler,
  })  : _fetch = fetch,
        metadata = Map<String, Object?>.unmodifiable(metadata);

  @override
  final QueryKey key;

  final QueryFunction<TData> _fetch;

  @override
  final RetryPolicy<TData>? configuredRetry;

  @override
  final NetworkMode networkMode;

  @override
  final bool hasExplicitNetworkMode;

  @override
  final StalePolicy stalePolicy;

  @override
  final bool hasExplicitStalePolicy;

  @override
  final RetentionPolicy retentionPolicy;

  @override
  final bool hasExplicitRetentionPolicy;

  @override
  final Map<String, Object?> metadata;

  @override
  final DataReconciler<TData> reconciler;

  @override
  FutureOr<TData> fetch(QueryContext context) => _fetch(context);

  @override
  ResolvedQueryOperation createOperation(QueryPlanExecution execution) {
    final executor = RetryExecutor<TData>(
      policy: configuredRetry ?? execution.defaultPolicy,
      runtime: execution.runtime,
      timers: execution.timers,
      cancellation: execution.cancellation,
      onlineManager: execution.onlineManager,
      focusManager: execution.focusManager,
      networkMode: switch (hasExplicitNetworkMode
          ? networkMode
          : execution.networkModeOverride ?? networkMode) {
        NetworkMode.online => RetryNetworkMode.online,
        NetworkMode.always => RetryNetworkMode.always,
        NetworkMode.offlineFirst => RetryNetworkMode.offlineFirst,
      },
      guard: execution.guard,
      canStartRetry: execution.canStartRetry,
      onAttemptFailure: execution.onAttemptFailure,
      onOnlinePauseChanged: execution.onOnlinePauseChanged,
      onFocusPauseChanged: execution.onFocusPauseChanged,
    );
    final result = executor.execute(
      (cancellationToken) => untracked(
        () => _fetch(
          QueryContext._resolved(
            client: execution.client,
            key: key,
            cancellationToken: cancellationToken,
            metadata: metadata,
            streamDataInternal: execution.streamData,
            operationGuardInternal: execution.guard,
          ),
        ),
      ),
    );
    return _ResolvedQueryOperation<TData>(executor, result);
  }

  @override
  Object? reconcileData(Object? previous, Object? next) {
    return reconciler.reconcile(previous as TData, next as TData);
  }

  /// Copies this plan with a new typed retry policy.
  ResolvedQueryPlan<TData> withRetryPolicy(RetryPolicy<TData> value) {
    return ResolvedQueryPlan<TData>(
      key: key,
      fetch: _fetch,
      configuredRetry: value,
      networkMode: networkMode,
      hasExplicitNetworkMode: hasExplicitNetworkMode,
      stalePolicy: stalePolicy,
      hasExplicitStalePolicy: hasExplicitStalePolicy,
      retentionPolicy: retentionPolicy,
      hasExplicitRetentionPolicy: hasExplicitRetentionPolicy,
      metadata: metadata,
      reconciler: reconciler,
    );
  }
}

final class _ResolvedQueryOperation<TData> implements ResolvedQueryOperation {
  const _ResolvedQueryOperation(this.executor, this.typedResult);

  final RetryExecutor<TData> executor;
  final Future<TData> typedResult;

  @override
  Future<Object?> get result => typedResult;

  @override
  void stopRetries() => executor.stopRetries();

  @override
  void pauseRetries() => executor.pauseRetries();

  @override
  void resumeRetries() => executor.resumeRetries();
}

/// Erased initial data retained by a staged target.
final class ResolvedInitialData {
  /// Creates resolved raw initial data.
  const ResolvedInitialData(this.data, {this.updatedAt});

  /// The present raw value, including an explicit `null`.
  final Object? data;

  /// The optional caller-supplied commit time.
  final DateTime? updatedAt;
}

/// Non-generic observer-settings boundary used by heterogeneous observation.
abstract base class ResolvedObserverSettingsBase {
  const ResolvedObserverSettingsBase();

  bool? get enabled;
  StalePolicy? get staleTime;
  RefetchPolicy? get refetchOnMount;
  RefetchPolicy? get refetchOnFocus;
  RefetchPolicy? get refetchOnReconnect;
  bool? get retryOnMount;
  Duration? get pollingInterval;
  bool? get pollingEnabled;
  bool? get pollInBackground;
  bool get hasCustomEquality;

  /// Compares selected values inside the settings' original view type.
  bool areEqualObject(Object? previous, Object? next);
}

/// Observer-local settings captured by a target.
final class ResolvedObserverSettings<TView>
    extends ResolvedObserverSettingsBase {
  /// Creates observer settings. Null fields inherit runtime defaults.
  const ResolvedObserverSettings({
    this.enabled,
    this.staleTime,
    this.refetchOnMount,
    this.refetchOnFocus,
    this.refetchOnReconnect,
    this.retryOnMount,
    this.pollingInterval,
    this.pollingIntervalResolver,
    this.pollingEnabled,
    this.pollInBackground,
    this.equality,
  });

  @override
  final bool? enabled;
  @override
  final StalePolicy? staleTime;
  @override
  final RefetchPolicy? refetchOnMount;
  @override
  final RefetchPolicy? refetchOnFocus;
  @override
  final RefetchPolicy? refetchOnReconnect;
  @override
  final bool? retryOnMount;
  @override
  final Duration? pollingInterval;
  final QueryPollingIntervalResolver<TView>? pollingIntervalResolver;
  @override
  final bool? pollingEnabled;
  @override
  final bool? pollInBackground;
  final QueryDataEquality<TView>? equality;

  @override
  bool get hasCustomEquality => equality != null;

  /// Compares selected values using custom equality or Dart equality.
  bool areEqual(TView previous, TView next) {
    final compare = equality;
    return compare == null
        ? previous == next
        : untracked(() => compare(previous, next));
  }

  @override
  bool areEqualObject(Object? previous, Object? next) {
    return areEqual(previous as TView, next as TView);
  }

  /// Returns settings with every non-null [other] value applied.
  ResolvedObserverSettings<TView> merge(
    ResolvedObserverSettings<TView> other,
  ) {
    if (other.pollingInterval != null &&
        other.pollingIntervalResolver != null) {
      throw ArgumentError(
        'pollingInterval and pollingIntervalResolver are mutually exclusive.',
      );
    }
    final replacesWithInterval = other.pollingInterval != null;
    final replacesWithResolver = other.pollingIntervalResolver != null;
    final interval =
        replacesWithResolver ? null : other.pollingInterval ?? pollingInterval;
    final intervalResolver = replacesWithInterval
        ? null
        : other.pollingIntervalResolver ?? pollingIntervalResolver;
    final pollingEnabled = other.pollingEnabled ??
        (replacesWithInterval || replacesWithResolver
            ? true
            : this.pollingEnabled);
    if (interval != null && interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'pollingInterval',
        'A polling interval must be positive.',
      );
    }
    return ResolvedObserverSettings<TView>(
      enabled: other.enabled ?? enabled,
      staleTime: other.staleTime ?? staleTime,
      refetchOnMount: other.refetchOnMount ?? refetchOnMount,
      refetchOnFocus: other.refetchOnFocus ?? refetchOnFocus,
      refetchOnReconnect: other.refetchOnReconnect ?? refetchOnReconnect,
      retryOnMount: other.retryOnMount ?? retryOnMount,
      pollingInterval: interval,
      pollingIntervalResolver: intervalResolver,
      pollingEnabled: pollingEnabled,
      pollInBackground: other.pollInBackground ?? pollInBackground,
      equality: other.equality ?? equality,
    );
  }
}

/// Typed projection that safely owns the raw-to-view conversion.
abstract base class ResolvedQueryProjection<TView> {
  const ResolvedQueryProjection();

  /// Applies the projection to erased raw cache data.
  TView apply(Object? rawData);
}

final class _TypedQueryProjection<TData, TView>
    extends ResolvedQueryProjection<TView> {
  const _TypedQueryProjection(this.select);

  final TView Function(TData data) select;

  @override
  TView apply(Object? rawData) => select(rawData as TData);
}

final class _ComposedQueryProjection<TPrevious, TView>
    extends ResolvedQueryProjection<TView> {
  const _ComposedQueryProjection(this.previous, this.select);

  final ResolvedQueryProjection<TPrevious> previous;
  final TView Function(TPrevious data) select;

  @override
  TView apply(Object? rawData) => select(previous.apply(rawData));
}

/// Non-generic resolved target boundary used by heterogeneous observation.
abstract base class ResolvedQueryTargetBase {
  const ResolvedQueryTargetBase();

  ResolvedQueryPlanBase get plan;
  ResolvedInitialData? get initialData;
  ResolvedObserverSettingsBase get observer;
  bool get hasPlaceholder;

  /// Applies the target's typed projection without a client-side cast.
  Object? selectObject(Object? rawData);

  /// Resolves placeholder presence inside the target's original view type.
  QueryValue<Object?> resolvePlaceholderObject(QueryValue<Object?> previous);

  /// Visits this target while restoring its original selected-view type.
  R accept<R>(ResolvedQueryTargetVisitor<R> visitor);
}

/// A type-safe bridge from erased targets back to their selected-view type.
abstract interface class ResolvedQueryTargetVisitor<R> {
  /// Visits one target without a raw generic or `dynamic` cast.
  R visit<TView>(ResolvedQueryTarget<TView> target);
}

/// Immutable observer presentation captured from one staged target.
final class ResolvedQueryTarget<TView> extends ResolvedQueryTargetBase {
  /// Creates a resolved target.
  ResolvedQueryTarget({
    required this.plan,
    required this.projection,
    this.initialData,
    ResolvedObserverSettings<TView>? observer,
    this.placeholder,
  }) : observer = observer ?? ResolvedObserverSettings<TView>();

  @override
  final ResolvedQueryPlanBase plan;

  final ResolvedQueryProjection<TView> projection;

  @override
  final ResolvedInitialData? initialData;

  @override
  final ResolvedObserverSettings<TView> observer;

  final QueryPlaceholderResolver<TView>? placeholder;

  @override
  bool get hasPlaceholder => placeholder != null;

  /// Applies the complete selected-view pipeline.
  TView select(Object? rawData) => untracked(() => projection.apply(rawData));

  @override
  Object? selectObject(Object? rawData) => select(rawData);

  /// Resolves placeholder presence, returning absent when unconfigured.
  QueryValue<TView> resolvePlaceholder(QueryValue<TView> previous) {
    final resolve = placeholder;
    return resolve == null
        ? QueryValue<TView>.absent()
        : untracked(() => resolve(previous));
  }

  @override
  QueryValue<Object?> resolvePlaceholderObject(QueryValue<Object?> previous) {
    final typedPrevious = switch (previous) {
      QueryAbsent<Object?>() => QueryValue<TView>.absent(),
      QueryPresent<Object?>(:final value) =>
        QueryValue<TView>.present(value as TView),
    };
    final resolved = resolvePlaceholder(typedPrevious);
    return switch (resolved) {
      QueryAbsent<TView>() => const QueryValue<Object?>.absent(),
      QueryPresent<TView>(:final value) => QueryValue<Object?>.present(value),
    };
  }

  @override
  R accept<R>(ResolvedQueryTargetVisitor<R> visitor) {
    return visitor.visit<TView>(this);
  }
}

/// Non-generic base implemented by every observable query target.
abstract interface class AnyQueryTarget {
  /// Client used by host integrations when no client is supplied separately.
  QueryClient get client;

  QueryKey get key;

  @internal
  ResolvedQueryTargetBase get resolved;
}

/// Observable terminal stage for a selected query view.
sealed class QueryTarget<TView> implements AnyQueryTarget {
  const QueryTarget({QueryClient? client}) : _configuredClient = client;

  final QueryClient? _configuredClient;

  @override
  QueryClient get client => _configuredClient ?? QueryClient.defaultClient;

  @override
  @internal
  ResolvedQueryTarget<TView> get resolved;

  @override
  QueryKey get key => resolved.plan.key;

  /// Applies observer-local behavior and returns a terminal target.
  QueryTarget<TView> observer({
    bool? enabled,
    StalePolicy? staleTime,
    RefetchPolicy? refetchOnMount,
    RefetchPolicy? refetchOnFocus,
    RefetchPolicy? refetchOnReconnect,
    bool? retryOnMount,
    Duration? pollingInterval,
    QueryPollingIntervalResolver<TView>? pollingIntervalResolver,
    bool? pollingEnabled,
    bool? pollInBackground,
    QueryDataEquality<TView>? equality,
  }) {
    final current = resolved;
    final observer = current.observer.merge(
      ResolvedObserverSettings<TView>(
        enabled: enabled,
        staleTime: staleTime,
        refetchOnMount: refetchOnMount,
        refetchOnFocus: refetchOnFocus,
        refetchOnReconnect: refetchOnReconnect,
        retryOnMount: retryOnMount,
        pollingInterval: pollingInterval,
        pollingIntervalResolver: pollingIntervalResolver,
        pollingEnabled: pollingEnabled,
        pollInBackground: pollInBackground,
        equality: equality,
      ),
    );
    return _TerminalQueryTarget<TView>(
      ResolvedQueryTarget<TView>(
        plan: current.plan,
        projection: current.projection,
        initialData: current.initialData,
        observer: observer,
        placeholder: current.placeholder,
      ),
      client: _configuredClient,
    );
  }

  /// Uses an explicit observer-local placeholder value.
  QueryTarget<TView> placeholderData(TView data) {
    return placeholder((previous) => QueryValue<TView>.present(data));
  }

  /// Uses [resolve] to derive observer-local placeholder presence.
  QueryTarget<TView> placeholder(QueryPlaceholderResolver<TView> resolve) {
    final current = resolved;
    return _TerminalQueryTarget<TView>(
      ResolvedQueryTarget<TView>(
        plan: current.plan,
        projection: current.projection,
        initialData: current.initialData,
        observer: current.observer,
        placeholder: resolve,
      ),
      client: _configuredClient,
    );
  }
}

/// Select-capable stage for a query view.
sealed class QueryView<TView> extends QueryTarget<TView> {
  const QueryView({super.client});

  /// Selects this view into [TNext] while preserving its raw fetch plan.
  QueryView<TNext> select<TNext>(TNext Function(TView value) selector) {
    final current = resolved;
    return _SelectedQueryView<TView, TNext>(
      ResolvedQueryTarget<TNext>(
        plan: current.plan,
        projection: _ComposedQueryProjection<TView, TNext>(
          current.projection,
          selector,
        ),
        initialData: current.initialData,
        observer: ResolvedObserverSettings<TNext>(),
      ),
      client: _configuredClient,
    );
  }
}

/// Reusable externally subclassable raw query recipe.
///
/// External subclasses implement only [key] and [fetch]. Recipe policy belongs
/// in the super-constructor so omitted values can inherit client defaults.
abstract base class Query<TData> extends QueryView<TData>
    implements QueryDataTarget<TData> {
  const Query({
    super.client,
    RetryPolicy<TData>? retry,
    StalePolicy? staleTime,
    RetentionPolicy? retention,
    NetworkMode? networkMode,
    Map<String, Object?> metadata = const <String, Object?>{},
    DataReconciler<TData>? reconciler,
  })  : _configuredRetry = retry,
        _configuredStaleTime = staleTime,
        _configuredRetention = retention,
        _configuredNetworkMode = networkMode,
        _metadata = metadata,
        _configuredReconciler = reconciler;

  final RetryPolicy<TData>? _configuredRetry;
  final StalePolicy? _configuredStaleTime;
  final RetentionPolicy? _configuredRetention;
  final NetworkMode? _configuredNetworkMode;
  final Map<String, Object?> _metadata;
  final DataReconciler<TData>? _configuredReconciler;

  @override
  QueryKey get key;

  /// Performs one raw attempt.
  FutureOr<TData> fetch(QueryContext context);

  /// Typed retry behavior for the raw data result.
  @nonVirtual
  RetryPolicy<TData>? get retryPolicy => _configuredRetry;

  /// Default freshness used when an observer does not override it.
  @nonVirtual
  StalePolicy get stalePolicy => _configuredStaleTime ?? StalePolicy.immediate;

  /// Default cache retention.
  @nonVirtual
  RetentionPolicy get retentionPolicy =>
      _configuredRetention ?? RetentionPolicy.standard;

  /// Default connectivity behavior.
  @nonVirtual
  NetworkMode get networkMode => _configuredNetworkMode ?? NetworkMode.online;

  /// Immutable recipe metadata.
  Map<String, Object?> get metadata => _metadata;

  /// Raw-data structural sharing policy.
  @override
  DataReconciler<TData> get reconciler =>
      _configuredReconciler ?? DataReconciler<TData>.standard();

  @override
  @internal
  ResolvedQueryTarget<TData> get resolved {
    final plan = ResolvedQueryPlan<TData>(
      key: key,
      fetch: fetch,
      configuredRetry: _configuredRetry,
      networkMode: _configuredNetworkMode ?? NetworkMode.online,
      hasExplicitNetworkMode: _configuredNetworkMode != null,
      stalePolicy: _configuredStaleTime ?? StalePolicy.immediate,
      hasExplicitStalePolicy: _configuredStaleTime != null,
      retentionPolicy: _configuredRetention ?? RetentionPolicy.standard,
      hasExplicitRetentionPolicy: _configuredRetention != null,
      metadata: metadata,
      reconciler: reconciler,
    );
    return ResolvedQueryTarget<TData>(
      plan: plan,
      projection: _TypedQueryProjection<TData, TData>((data) => data),
    );
  }

  /// Replaces retry behavior while [TData] remains available for inference.
  Query<TData> retry(
    RetryStrategy<TData> Function(RetryBuilder<TData> retry) create,
  ) {
    return _RetryQuery<TData>(this, RetryPolicy<TData>.custom(create));
  }

  /// Seeds raw cache data before any selection is applied.
  QueryView<TData> initialData(
    TData data, {
    DateTime? updatedAt,
  }) {
    final current = resolved;
    return _InitialQueryView<TData>(
      ResolvedQueryTarget<TData>(
        plan: current.plan,
        projection: current.projection,
        initialData: ResolvedInitialData(data, updatedAt: updatedAt),
        observer: current.observer,
        placeholder: current.placeholder,
      ),
      client: _configuredClient,
    );
  }
}

/// Creates an inference-friendly inline [Query].
Query<TData> query<TData>({
  required QueryKey key,
  required QueryFunction<TData> fetch,
  QueryClient? client,
  RetryPolicy<Never>? retry,
  StalePolicy? staleTime,
  RetentionPolicy? retention,
  NetworkMode? networkMode,
  Map<String, Object?> metadata = const <String, Object?>{},
  DataReconciler<TData>? reconciler,
}) {
  return _InlineQuery<TData>(
    client: client,
    key: key,
    fetch: fetch,
    retry: _queryMarkerRetry<TData>(retry),
    staleTime: staleTime,
    retention: retention,
    networkMode: networkMode,
    metadata: metadata,
    reconciler: reconciler,
  );
}

RetryPolicy<T>? _queryMarkerRetry<T>(RetryPolicy<Never>? marker) {
  if (marker == null) return null;
  if (!identical(marker, RetryPolicy.none) &&
      !identical(marker, RetryPolicy.standard)) {
    throw ArgumentError.value(
      marker,
      'retry',
      'Marker retry slots accept only RetryPolicy.none or '
          'RetryPolicy.standard. Apply typed custom retry with retry().',
    );
  }
  return marker;
}

final class _InlineQuery<TData> extends Query<TData> {
  _InlineQuery({
    required super.client,
    required this.key,
    required QueryFunction<TData> fetch,
    required super.retry,
    required super.staleTime,
    required super.retention,
    required super.networkMode,
    required super.metadata,
    required super.reconciler,
  }) : _fetch = fetch;

  @override
  final QueryKey key;

  final QueryFunction<TData> _fetch;

  @override
  FutureOr<TData> fetch(QueryContext context) => _fetch(context);
}

final class _RetryQuery<TData> extends Query<TData> {
  _RetryQuery(this.source, RetryPolicy<TData> retryPolicy)
      : super(
          client: source._configuredClient,
          retry: retryPolicy,
          staleTime: source._configuredStaleTime,
          retention: source._configuredRetention,
          networkMode: source._configuredNetworkMode,
          metadata: source.metadata,
          reconciler: source.reconciler,
        );

  final Query<TData> source;

  @override
  QueryKey get key => source.key;

  @override
  FutureOr<TData> fetch(QueryContext context) => source.fetch(context);
}

final class _InitialQueryView<TView> extends QueryView<TView> {
  const _InitialQueryView(this.resolved, {required super.client});

  @override
  final ResolvedQueryTarget<TView> resolved;
}

final class _SelectedQueryView<TPrevious, TView> extends QueryView<TView> {
  const _SelectedQueryView(this.resolved, {required super.client});

  @override
  final ResolvedQueryTarget<TView> resolved;
}

final class _TerminalQueryTarget<TView> extends QueryTarget<TView> {
  const _TerminalQueryTarget(this.resolved, {required super.client});

  @override
  final ResolvedQueryTarget<TView> resolved;
}
