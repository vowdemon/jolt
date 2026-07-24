import 'dart:async';

import 'package:jolt/jolt.dart' show untracked;

import '../foundation/query_cancellation.dart';
import '../foundation/query_failure.dart';
import '../foundation/query_runtime.dart';
import '../foundation/query_value.dart';
import '../query/client.dart';
import '../query/policies.dart';
import '../query/state.dart';
import '../retry/retry_policy.dart';
import 'models.dart';
import 'recipe.dart';

/// Client-owned services needed by one mutation execution.
abstract interface class MutationExecutionOwnerInternal {
  QueryClient get clientInternal;
  bool get isActiveInternal;

  bool containsExecutionInternal(MutationExecutionBaseInternal execution);

  void publishExecutionInternal(
    MutationExecutionBaseInternal execution,
    MutationCacheEventKind kind,
  );

  void releaseScopeInternal(MutationExecutionBaseInternal execution);
  void continueScopeInternal(MutationScope? scope);
  void scheduleExecutionGcInternal(MutationExecutionBaseInternal execution);
  void forgetExecutionInternal(MutationExecutionBaseInternal execution);
}

/// Type-preserving submission boundary shared by client and observers.
abstract interface class MutationSubmitterInternal {
  MutationExecutionInternal<V, D, R> submitMutationInternal<V, D, R>(
    Mutation<V, D, R> mutation,
    V variables, {
    MutationExecutionListenerInternal<V, D, R>? listener,
  });
}

/// Observer-owned presentation and per-call callbacks for one execution.
abstract interface class MutationExecutionListenerInternal<V, D, R> {
  bool get isEligibleInternal;

  void onMutationExecutionChangedInternal(
    MutationExecutionInternal<V, D, R> execution,
  );

  void onMutationSuccessInternal(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  );

  void onMutationErrorInternal(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  );

  void onMutationSettledInternal(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  );
}

/// Erased mutable execution boundary retained by MutationCache.
abstract base class MutationExecutionBaseInternal {
  int get id;
  MutationScope? get scope;
  MutationStatus get status;
  bool get isPaused;
  bool get isSettledInternal;
  int get observerCountInternal;
  RetentionPolicy get retentionPolicy;
  MutationSnapshot get snapshotInternal;
  QueryScheduledHandle? get gcHandleInternal;
  set gcHandleInternal(QueryScheduledHandle? value);
  int get gcGenerationInternal;
  set gcGenerationInternal(int value);

  void startInternal();
  void markScopeEligibleInternal();
  void notifyListenerInternal();
  void abortDisposedInternal();
  void onCacheRemovedInternal();
}

/// One independent, typed, client-owned mutation submission.
final class MutationExecutionInternal<V, D, R>
    extends MutationExecutionBaseInternal {
  MutationExecutionInternal({
    required this.owner,
    required this.id,
    required this.variables,
    required this.context,
    required this.lifecycle,
    required this.cacheCallbacks,
    required this.retryPolicyInternal,
    required this.networkModeInternal,
    required this.retentionPolicy,
    required this.cancellation,
    required this.submittedAt,
    required this.submissionZone,
    required PauseReason? initialPauseReason,
    MutationExecutionListenerInternal<V, D, R>? listener,
  })  : _pauseReason = initialPauseReason,
        _listener = listener;

  final MutationExecutionOwnerInternal owner;

  @override
  final int id;

  final V variables;
  final MutationContext context;
  final MutationLifecycleInternal<V, D, R> lifecycle;
  final MutationCacheCallbacks cacheCallbacks;
  final RetryPolicy<D> retryPolicyInternal;
  final NetworkMode networkModeInternal;
  final QueryCancellationController cancellation;
  final DateTime submittedAt;
  final Zone submissionZone;
  final Completer<D> _completer = Completer<D>();

  MutationExecutionListenerInternal<V, D, R>? _listener;
  MutationStatus _status = MutationStatus.pending;
  QueryValue<D> _data = QueryValue<D>.absent();
  PauseReason? _pauseReason;
  QueryFailure? _failure;
  int _failureCount = 0;
  RetryExecutor<D>? _retryExecutor;
  bool _started = false;
  bool _isSettled = false;
  bool _isAborted = false;
  bool _cancellationReleased = false;

  @override
  QueryScheduledHandle? gcHandleInternal;

  @override
  int gcGenerationInternal = 0;

  Future<D> get future => _completer.future;
  QueryValue<D> get dataInternal => _data;
  QueryFailure? get failureInternal => _failure;
  int get failureCountInternal => _failureCount;
  DateTime get submittedAtInternal => submittedAt;
  PauseReason? get pauseReasonInternal => _pauseReason;
  QueryValue<R> get onMutateResultInternal => lifecycle.onMutateResult;

  @override
  MutationScope? get scope => context.scope;

  @override
  MutationStatus get status => _status;

  @override
  bool get isPaused => _pauseReason != null;

  @override
  bool get isSettledInternal => _isSettled;

  @override
  int get observerCountInternal => _listener == null ? 0 : 1;

  @override
  final RetentionPolicy retentionPolicy;

  @override
  MutationSnapshot get snapshotInternal => MutationSnapshot(
        id: id,
        key: context.key,
        status: _status,
        isPaused: isPaused,
        pauseReason: _pauseReason,
        variables: variables,
        data: _eraseValue(_data),
        failure: _failure,
        failureCount: _failureCount,
        submittedAt: submittedAt,
        onMutateResult: lifecycle.erasedOnMutateResult,
        scope: context.scope,
        metadata: context.metadata,
      );

  void detachListenerInternal(
    MutationExecutionListenerInternal<V, D, R> listener,
  ) {
    if (!identical(_listener, listener)) return;
    _listener = null;
    owner.scheduleExecutionGcInternal(this);
  }

  @override
  void startInternal() {
    if (_started || _isSettled || _isAborted || !owner.isActiveInternal) {
      return;
    }
    _started = true;
    unawaited(_run());
  }

  @override
  void markScopeEligibleInternal() {
    if (_isSettled || _isAborted) return;
    final shouldPauseOffline = networkModeInternal == NetworkMode.online &&
        !owner.clientInternal.onlineManager.isOnline;
    _setPauseReason(
      shouldPauseOffline ? PauseReason.offline : null,
      publish: true,
    );
  }

  Future<void> _run() async {
    var cacheSettledInvoked = false;
    var recipeSettledInvoked = false;
    try {
      await _invokePrimary<void>(
        () => cacheCallbacks.onMutate?.call(variables, context),
      );
      final resultBeforeOnMutate = lifecycle.onMutateResult;
      await _invokePrimary<void>(
        () => lifecycle.runOnMutate(variables, context),
      );
      if (lifecycle.onMutateResult != resultBeforeOnMutate) {
        owner.publishExecutionInternal(this, MutationCacheEventKind.updated);
      }

      final candidate = await _executeWithRetry();
      await _invokePrimary<void>(
        () => cacheCallbacks.onSuccess?.call(
          candidate,
          variables,
          lifecycle.erasedOnMutateResult,
          context,
        ),
      );
      await _invokePrimary<void>(
        () => lifecycle.onSuccess(candidate, variables, context),
      );

      if (cacheCallbacks.onSettled != null) {
        cacheSettledInvoked = true;
        await _invokePrimary<void>(
          () => cacheCallbacks.onSettled?.call(
            QueryValue<Object?>.present(candidate),
            null,
            variables,
            lifecycle.erasedOnMutateResult,
            context,
          ),
        );
      }
      recipeSettledInvoked = true;
      await _invokePrimary<void>(
        () => lifecycle.onSettled(
          QueryValue<D>.present(candidate),
          null,
          variables,
          context,
        ),
      );
      _checkActive();
      _commitSuccess(candidate);
    } catch (error, stackTrace) {
      if (!_canContinue) return;
      if (_pauseReason == PauseReason.offline) {
        _setPauseReason(null, publish: true);
      }
      final failure = QueryFailure(error, stackTrace);
      await _runErrorLifecycle(
        failure,
        cacheSettledInvoked: cacheSettledInvoked,
        recipeSettledInvoked: recipeSettledInvoked,
      );
      if (!_canContinue) return;
      _commitError(failure);
    }
  }

  Future<D> _executeWithRetry() {
    _checkActive();
    if (_pauseReason == PauseReason.offline &&
        owner.clientInternal.onlineManager.isOnline) {
      _setPauseReason(null, publish: true);
    }
    final executor = RetryExecutor<D>(
      policy: retryPolicyInternal,
      runtime: owner.clientInternal.runtime,
      timers: owner.clientInternal.timersInternal,
      cancellation: cancellation,
      onlineManager: owner.clientInternal.onlineManager,
      focusManager: owner.clientInternal.focusManager,
      networkMode: switch (networkModeInternal) {
        NetworkMode.online => RetryNetworkMode.online,
        NetworkMode.always => RetryNetworkMode.always,
        NetworkMode.offlineFirst => RetryNetworkMode.offlineFirst,
      },
      guard: _checkActive,
      onAttemptFailure: (failure, failureCount) {
        if (!_canContinue) return;
        _failure = failure;
        _failureCount = failureCount;
        owner.publishExecutionInternal(this, MutationCacheEventKind.updated);
      },
      onOnlinePauseChanged: (isPaused) {
        if (!_canContinue) return;
        _setPauseReason(
          isPaused ? PauseReason.offline : null,
          publish: true,
        );
      },
      onFocusPauseChanged: (isPaused) {
        if (!_canContinue) return;
        _setPauseReason(
          isPaused ? PauseReason.focus : null,
          publish: true,
        );
      },
    );
    _retryExecutor = executor;
    return executor.execute(
      (cancellationToken) => _invokePrimary<D>(
        () => lifecycle.mutate(variables, context),
      ),
    );
  }

  Future<void> _runErrorLifecycle(
    QueryFailure failure, {
    required bool cacheSettledInvoked,
    required bool recipeSettledInvoked,
  }) async {
    await _invokeCleanup(
      () => cacheCallbacks.onError?.call(
        failure,
        variables,
        lifecycle.erasedOnMutateResult,
        context,
      ),
    );
    await _invokeCleanup(
      () => lifecycle.onError(failure, variables, context),
    );
    if (!cacheSettledInvoked) {
      await _invokeCleanup(
        () => cacheCallbacks.onSettled?.call(
          const QueryValue<Object?>.absent(),
          failure,
          variables,
          lifecycle.erasedOnMutateResult,
          context,
        ),
      );
    }
    if (!recipeSettledInvoked) {
      await _invokeCleanup(
        () => lifecycle.onSettled(
          QueryValue<D>.absent(),
          failure,
          variables,
          context,
        ),
      );
    }
  }

  Future<T> _invokePrimary<T>(FutureOr<T> Function() invoke) async {
    _checkActive();
    final value = await untracked<FutureOr<T>>(
      () => submissionZone.run<FutureOr<T>>(invoke),
    );
    _checkActive();
    return value;
  }

  Future<void> _invokeCleanup(FutureOr<void> Function() invoke) async {
    if (!_canContinue) return;
    try {
      await untracked<FutureOr<void>>(
        () => submissionZone.run<FutureOr<void>>(invoke),
      );
    } catch (error, stackTrace) {
      submissionZone.handleUncaughtError(error, stackTrace);
    }
  }

  bool get _canContinue => !_isAborted && !_isSettled && owner.isActiveInternal;

  void _checkActive() {
    if (!_canContinue || !owner.containsExecutionInternal(this)) {
      throw const _MutationAbortedInternal();
    }
  }

  void _commitSuccess(D candidate) {
    if (!_canContinue) return;
    _status = MutationStatus.success;
    _data = QueryValue<D>.present(candidate);
    _failure = null;
    _failureCount = 0;
    _pauseReason = null;
    _finishScopeAndCancellation();
    notifyListenerInternal();
    _invokePerCallSuccess(candidate);
    if (owner.isActiveInternal) {
      owner.publishExecutionInternal(this, MutationCacheEventKind.updated);
      owner.continueScopeInternal(scope);
      owner.scheduleExecutionGcInternal(this);
    }
    _completeSuccess(candidate);
  }

  void _commitError(QueryFailure failure) {
    if (!_canContinue) return;
    _status = MutationStatus.error;
    _data = QueryValue<D>.absent();
    _failure = failure;
    _pauseReason = null;
    _finishScopeAndCancellation();
    notifyListenerInternal();
    _invokePerCallError(failure);
    if (owner.isActiveInternal) {
      owner.publishExecutionInternal(this, MutationCacheEventKind.updated);
      owner.continueScopeInternal(scope);
      owner.scheduleExecutionGcInternal(this);
    }
    _completeError(failure);
  }

  void _finishScopeAndCancellation() {
    _isSettled = true;
    _retryExecutor = null;
    _releaseCancellation();
    owner.releaseScopeInternal(this);
  }

  void _completeSuccess(D data) {
    if (!_completer.isCompleted) _completer.complete(data);
  }

  void _completeError(QueryFailure failure) {
    if (!_completer.isCompleted) {
      _completer.completeError(failure.error, failure.stackTrace);
    }
  }

  void _invokePerCallSuccess(D candidate) {
    final listener = _listener;
    if (listener == null || !listener.isEligibleInternal) return;
    submissionZone.runGuarded(
      () => listener.onMutationSuccessInternal(
        candidate,
        variables,
        lifecycle.onMutateResult,
        context,
      ),
    );
    if (!listener.isEligibleInternal) return;
    submissionZone.runGuarded(
      () => listener.onMutationSettledInternal(
        QueryValue<D>.present(candidate),
        null,
        variables,
        lifecycle.onMutateResult,
        context,
      ),
    );
  }

  void _invokePerCallError(QueryFailure failure) {
    final listener = _listener;
    if (listener == null || !listener.isEligibleInternal) return;
    submissionZone.runGuarded(
      () => listener.onMutationErrorInternal(
        failure,
        variables,
        lifecycle.onMutateResult,
        context,
      ),
    );
    if (!listener.isEligibleInternal) return;
    submissionZone.runGuarded(
      () => listener.onMutationSettledInternal(
        QueryValue<D>.absent(),
        failure,
        variables,
        lifecycle.onMutateResult,
        context,
      ),
    );
  }

  void _setPauseReason(PauseReason? value, {required bool publish}) {
    if (_pauseReason == value) return;
    _pauseReason = value;
    if (publish && owner.isActiveInternal) {
      owner.publishExecutionInternal(this, MutationCacheEventKind.updated);
    }
  }

  @override
  void notifyListenerInternal() {
    final listener = _listener;
    if (listener != null && listener.isEligibleInternal) {
      listener.onMutationExecutionChangedInternal(this);
    }
  }

  @override
  void abortDisposedInternal() {
    if (_isSettled || _isAborted) return;
    _isAborted = true;
    _retryExecutor?.stopRetries();
    _retryExecutor = null;
    cancellation.cancel(const QueryClientDisposedException());
    _releaseCancellation();
    if (!_completer.isCompleted) {
      _completer.completeError(
        const QueryClientDisposedException(),
        StackTrace.current,
      );
    }
    _listener = null;
  }

  void _releaseCancellation() {
    if (_cancellationReleased) return;
    _cancellationReleased = true;
    owner.clientInternal.releaseCancellationInternal(cancellation);
  }

  @override
  void onCacheRemovedInternal() {
    gcGenerationInternal += 1;
    gcHandleInternal?.cancel();
    gcHandleInternal = null;
    if (_isSettled && observerCountInternal == 0) {
      owner.forgetExecutionInternal(this);
    }
  }
}

QueryValue<Object?> _eraseValue<T>(QueryValue<T> value) {
  return switch (value) {
    QueryAbsent<T>() => const QueryValue<Object?>.absent(),
    QueryPresent<T>(:final value) => QueryValue<Object?>.present(value),
  };
}

final class _MutationAbortedInternal implements Exception {
  const _MutationAbortedInternal();
}
