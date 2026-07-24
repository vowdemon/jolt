library;

import 'dart:async';
import 'dart:collection';

import 'package:jolt/jolt.dart' show Readable, Signal;
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../foundation/query_failure.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import '../query/client.dart';
import '../query/policies.dart';
import '../query/state.dart';
import '../retry/retry_policy.dart';
import 'cache.dart';
import 'execution.dart';
import 'models.dart';
import 'observer_result.dart';
import 'recipe.dart';

part 'observer.dart';

final Expando<_MutationRuntimeState> _mutationStates =
    Expando<_MutationRuntimeState>('jolt_query.mutations');

/// Mutation execution, cache, and observer operations on [QueryClient].
extension QueryClientMutationMethods on QueryClient {
  /// The client-owned mutation cache, created lazily on first use.
  MutationCache get mutationCache => _mutationStateFor(this).cache.public;

  /// Reactive count of fully committed pending mutation snapshots.
  Readable<int> get mutatingCount =>
      _mutationStateFor(this).mutatingCountInternal;

  /// Submits one independent mutation execution and exposes only its Future.
  Future<D> execute<V, D, R>(Mutation<V, D, R> mutation, V variables) {
    return _mutationStateFor(this)
        .submitMutationInternal<V, D, R>(mutation, variables)
        .future;
  }

  /// Runs a zero-variable action through the mutation pipeline.
  Future<D> executeAction<D, R>(Mutation<NoVariables, D, R> action) {
    return execute<NoVariables, D, R>(action, NoVariables.value);
  }

  /// Creates a latest-execution observer for a mutation.
  MutationObserver<V, D, R> observeMutation<V, D, R>(
    Mutation<V, D, R> mutation,
  ) {
    final state = _mutationStateFor(this);
    final observer = MutationObserver<V, D, R>._(this, state, mutation);
    return ownDisposableInternal(observer);
  }

  /// Synchronously counts matching pending mutation executions.
  int countMutating({MutationFilter filter = const MutationFilter()}) {
    checkActiveInternal();
    return _mutationStateFor(this)
        .cache
        .snapshots
        .where((snapshot) => snapshot.isPending && filter.matches(snapshot))
        .length;
  }

  /// Registers global or structural-prefix mutation defaults.
  ///
  /// Registrations merge in call order. Register broad defaults before later
  /// specific prefixes. Passing no [key] registers global defaults.
  void registerMutationDefaults(
    MutationDefaults defaults, {
    MutationKey? key,
  }) {
    _mutationStateFor(this).registerDefaultsInternal(defaults, key: key);
  }

  /// Removes every mutation-default registration without changing cache state.
  void clearMutationDefaults() {
    _mutationStateFor(this).clearDefaultsInternal();
  }

  /// Resolves type-independent mutation defaults for [key].
  MutationDefaults getMutationDefaults(MutationKey key) {
    return _mutationStateFor(this).resolveDefaultsInternal(key);
  }
}

_MutationRuntimeState _mutationStateFor(QueryClient client) {
  client.checkActiveInternal();
  final existing = _mutationStates[client];
  if (existing != null) {
    if (!existing.isActiveInternal) {
      throw StateError('MutationCache is disposed.');
    }
    return existing;
  }
  final state = _MutationRuntimeState(client);
  _mutationStates[client] = state;
  client.ownDisposableInternal(state);
  return state;
}

final class _MutationRuntimeState
    implements
        Disposable,
        MutationExecutionOwnerInternal,
        MutationSubmitterInternal {
  _MutationRuntimeState(this.clientInternal) {
    _mutatingCount = Signal<int>(0);
    cache = MutationCacheControllerInternal(
      notifications: clientInternal.notificationsInternal,
      callbacks: clientInternal.mutationCallbacksInternal,
      onCommittedEvent: _refreshMutatingCount,
    );
    _clearOwnedCache = cache.clearEntries;
    clientInternal.registerCacheClearerInternal(_clearOwnedCache);
  }

  @override
  final QueryClient clientInternal;

  late final MutationCacheControllerInternal cache;
  late final Signal<int> _mutatingCount;
  late final void Function() _clearOwnedCache;
  final Set<MutationExecutionBaseInternal> _executions =
      <MutationExecutionBaseInternal>{};
  final Map<MutationScope, Queue<MutationExecutionBaseInternal>> _scopes =
      <MutationScope, Queue<MutationExecutionBaseInternal>>{};
  final List<_MutationDefaultsRegistration> _defaults =
      <_MutationDefaultsRegistration>[];
  int _nextId = 0;
  bool _isActive = true;

  @override
  bool get isActiveInternal => _isActive && !clientInternal.isDisposed;

  Readable<int> get mutatingCountInternal => _mutatingCount;

  void registerDefaultsInternal(
    MutationDefaults defaults, {
    MutationKey? key,
  }) {
    _checkActive();
    const MutationDefaults().merge(defaults);
    final retry = defaults.retry;
    if (retry != null &&
        !identical(retry, RetryPolicy.none) &&
        !identical(retry, RetryPolicy.standard)) {
      throw ArgumentError.value(
        retry,
        'defaults.retry',
        'Mutation defaults accept only RetryPolicy.none or '
            'RetryPolicy.standard.',
      );
    }
    _defaults.add(_MutationDefaultsRegistration(key, defaults));
  }

  void clearDefaultsInternal() {
    _checkActive();
    _defaults.clear();
  }

  MutationDefaults resolveDefaultsInternal(MutationKey? key) {
    var resolved = const MutationDefaults();
    for (final registration in _defaults) {
      final prefix = registration.key;
      if (prefix == null || (key != null && key.startsWith(prefix))) {
        resolved = resolved.merge(registration.defaults);
      }
    }
    return resolved;
  }

  @override
  MutationExecutionInternal<V, D, R> submitMutationInternal<V, D, R>(
    Mutation<V, D, R> mutation,
    V variables, {
    MutationExecutionListenerInternal<V, D, R>? listener,
  }) {
    _checkActive();

    final key = mutation.key;
    final scope = mutation.scope;
    final metadata = mutation.metadata;
    final defaults = resolveDefaultsInternal(key);
    final networkMode = mutation.configuredNetworkModeInternal ??
        defaults.networkMode ??
        NetworkMode.online;
    final configuredRetry = mutation.configuredRetryInternal;
    final RetryPolicy<D> retryPolicy = configuredRetry ??
        (defaults.retry == null
            ? RetryPolicy.none
            : _typedMutationRetry<D>(defaults.retry!));
    final retentionPolicy = mutation.configuredRetentionInternal ??
        defaults.retention ??
        RetentionPolicy.standard;

    Queue<MutationExecutionBaseInternal>? queue;
    var isScopeHead = true;
    if (scope != null) {
      queue = _scopes.putIfAbsent(
        scope,
        () => Queue<MutationExecutionBaseInternal>(),
      );
      isScopeHead = queue.isEmpty;
    }

    final initialPauseReason = !isScopeHead
        ? PauseReason.scope
        : networkMode == NetworkMode.online &&
                !clientInternal.onlineManager.isOnline
            ? PauseReason.offline
            : null;
    final cancellation = clientInternal.ownCancellationInternal();
    final execution = MutationExecutionInternal<V, D, R>(
      owner: this,
      id: ++_nextId,
      variables: variables,
      context: MutationContext(
        client: clientInternal,
        key: key,
        scope: scope,
        metadata: metadata,
      ),
      lifecycle: createMutationLifecycleInternal(mutation),
      cacheCallbacks: cache.callbacks,
      retryPolicyInternal: retryPolicy,
      networkModeInternal: networkMode,
      retentionPolicy: retentionPolicy,
      cancellation: cancellation,
      submittedAt: clientInternal.runtime.clock.wallNow(),
      submissionZone: Zone.current,
      initialPauseReason: initialPauseReason,
      listener: listener,
    );

    _executions.add(execution);
    queue?.add(execution);
    try {
      cache.add(execution);
    } catch (_) {
      _executions.remove(execution);
      queue?.remove(execution);
      if (queue != null && queue.isEmpty) _scopes.remove(scope);
      clientInternal.releaseCancellationInternal(cancellation);
      rethrow;
    }

    if (isScopeHead) execution.startInternal();
    return execution;
  }

  @override
  bool containsExecutionInternal(MutationExecutionBaseInternal execution) =>
      _executions.contains(execution);

  @override
  void publishExecutionInternal(
    MutationExecutionBaseInternal execution,
    MutationCacheEventKind kind,
  ) {
    if (!isActiveInternal || !_executions.contains(execution)) return;
    cache.publish(execution, kind);
  }

  @override
  void releaseScopeInternal(MutationExecutionBaseInternal execution) {
    final scope = execution.scope;
    if (scope == null) return;
    final queue = _scopes[scope];
    if (queue == null || queue.isEmpty) return;
    if (identical(queue.first, execution)) {
      queue.removeFirst();
    } else {
      queue.remove(execution);
    }
    if (queue.isEmpty) _scopes.remove(scope);
  }

  @override
  void continueScopeInternal(MutationScope? scope) {
    if (scope == null || !isActiveInternal) return;
    final queue = _scopes[scope];
    if (queue == null || queue.isEmpty) return;
    final next = queue.first;
    next.markScopeEligibleInternal();
    next.startInternal();
  }

  @override
  void scheduleExecutionGcInternal(MutationExecutionBaseInternal execution) {
    execution.gcGenerationInternal += 1;
    final generation = execution.gcGenerationInternal;
    execution.gcHandleInternal?.cancel();
    execution.gcHandleInternal = null;
    if (!execution.isSettledInternal || execution.observerCountInternal != 0) {
      return;
    }
    if (!cache.containsExecution(execution)) {
      forgetExecutionInternal(execution);
      return;
    }
    final delay = execution.retentionPolicy.duration;
    if (delay == null) return;
    execution.gcHandleInternal = clientInternal.timersInternal.schedule(
      delay,
      () {
        if (!isActiveInternal ||
            generation != execution.gcGenerationInternal ||
            !execution.isSettledInternal ||
            execution.observerCountInternal != 0 ||
            !cache.containsExecution(execution)) {
          return;
        }
        cache.remove(execution.id);
        forgetExecutionInternal(execution);
      },
    );
  }

  @override
  void forgetExecutionInternal(MutationExecutionBaseInternal execution) {
    if (!execution.isSettledInternal) return;
    _executions.remove(execution);
  }

  void _checkActive() {
    clientInternal.checkActiveInternal();
    if (!_isActive || cache.isDisposed) {
      throw StateError('MutationCache is disposed.');
    }
  }

  void _refreshMutatingCount() {
    if (!isActiveInternal || cache.isDisposed) return;
    _mutatingCount.value = cache.executions
        .where((execution) => !execution.isSettledInternal)
        .length;
  }

  @override
  void dispose() {
    if (!_isActive) return;
    _isActive = false;
    clientInternal.releaseDisposableInternal(this);
    clientInternal.releaseCacheClearerInternal(_clearOwnedCache);
    final executions = List<MutationExecutionBaseInternal>.of(_executions);
    _scopes.clear();
    for (final execution in executions) {
      execution.abortDisposedInternal();
    }
    _executions.clear();
    _defaults.clear();
    cache.dispose();
    _mutatingCount.dispose();
  }
}

final class _MutationDefaultsRegistration {
  const _MutationDefaultsRegistration(this.key, this.defaults);

  final MutationKey? key;
  final MutationDefaults defaults;
}

RetryPolicy<T> _typedMutationRetry<T>(RetryPolicy<Never> marker) => marker;
