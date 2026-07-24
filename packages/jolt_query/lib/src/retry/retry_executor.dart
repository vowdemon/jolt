part of 'retry_policy.dart';

/// Connectivity behavior understood by the package-internal retry executor.
///
/// Public query and mutation recipes map their network mode to this boundary.
enum RetryNetworkMode {
  /// Gate the first attempt and every retry while offline.
  online,

  /// Allow the first attempt offline, then gate every retry.
  offlineFirst,

  /// Ignore connectivity for every attempt.
  always,
}

/// The work performed by one retry attempt.
typedef RetryAttempt<T> = FutureOr<T> Function(
  QueryCancellationToken cancellationToken,
);

/// Synchronously rejects stale operation, incarnation, or client generations.
typedef RetryExecutionGuard = void Function();

/// Commits one thrown attempt to query or mutation transient failure state.
typedef RetryAttemptFailureCallback = void Function(
  QueryFailure failure,
  int failureCount,
);

/// Publishes entry into or exit from an online wait.
typedef RetryOnlinePauseCallback = void Function(bool isPaused);

/// Publishes entry into or exit from a focus wait.
typedef RetryFocusPauseCallback = void Function(bool isPaused);

/// Package-internal manual adapter for a single logical operation.
///
/// This adapter borrows all timing and randomness from [runtime], owns retry
/// waits through [timers], and uses [cancellation] without marking the token as
/// consumed. It treats a `RetryStrategy<T>` only as a policy description.
///
/// In each adapted `RetryAttemptContext<T>`, only the outcome, retry index,
/// attempt number, elapsed time, and attempt duration are authoritative. Its
/// detached `RetryPipelineContext<T>` exists solely for stable per-operation
/// identity and a resynchronized elapsed read. Detached `now`, `random`,
/// `sleep`, `cancelToken`, `isCancelled`, `throwIfCancelled`, `timeout`,
/// `telemetry`, `phase`, and `setPhase` expose upstream detached defaults or
/// throw; none controls Jolt execution. Writes to detached elapsed state are
/// overwritten before the next policy decision.
final class RetryExecutor<T> {
  RetryExecutor({
    required this.policy,
    required this.runtime,
    required this.timers,
    required this.cancellation,
    required this.onlineManager,
    required this.focusManager,
    this.networkMode = RetryNetworkMode.online,
    this.guard,
    this.canStartRetry,
    this.onAttemptFailure,
    this.onOnlinePauseChanged,
    this.onFocusPauseChanged,
  });

  final RetryPolicy<T> policy;
  final QueryRuntime runtime;
  final TimerOrchestrator timers;
  final QueryCancellationController cancellation;
  final OnlineManager onlineManager;
  final FocusManager focusManager;
  final RetryNetworkMode networkMode;
  final RetryExecutionGuard? guard;
  final bool Function()? canStartRetry;
  final RetryAttemptFailureCallback? onAttemptFailure;
  final RetryOnlinePauseCallback? onOnlinePauseChanged;
  final RetryFocusPauseCallback? onFocusPauseChanged;

  final QueryCancellationController _retryWaitCancellation =
      QueryCancellationController();
  bool _hasStarted = false;
  bool _retriesStopped = false;
  bool _retriesPaused = false;

  /// Temporarily prevents another attempt without cancelling the active one.
  void pauseRetries() {
    if (_retriesStopped) return;
    _retriesPaused = true;
  }

  /// Restores retry eligibility while this operation is still active.
  void resumeRetries() {
    if (_retriesStopped) return;
    _retriesPaused = false;
  }

  /// Prevents another attempt without cancelling work that is already running.
  ///
  /// An active retry delay or online gate is released immediately. The current
  /// attempt outcome remains the operation's final outcome and no give-up hook
  /// is synthesized for this external stop condition.
  void stopRetries() {
    if (_retriesStopped) return;
    _retriesStopped = true;
    _retriesPaused = false;
    _retryWaitCancellation.cancel(_RetryStopReason.instance);
  }

  /// Executes [attempt] with the configured policy exactly once.
  Future<T> execute(RetryAttempt<T> attempt) async {
    if (_hasStarted) {
      throw StateError(
          'A RetryExecutor can execute only one logical operation.');
    }
    _hasStarted = true;

    final removeCancellationListener = cancellation.addListener(
      _retryWaitCancellation.cancel,
    );
    try {
      _checkCanRun();
      if (networkMode == RetryNetworkMode.online) {
        await _waitUntilOnline(cancellation);
        _checkCanRun();
      }

      final strategy = _createStrategy(policy);
      final pipelineContext = RetryPipelineContext<T>();
      final operationStartedAt = runtime.clock.monotonicNow();
      var attemptNumber = 0;
      var failureCount = 0;
      var hasRetried = false;

      while (true) {
        _checkCanRun();
        attemptNumber += 1;
        final attemptStartedAt = runtime.clock.monotonicNow();

        late final AttemptOutcome<T> outcome;
        try {
          outcome = AttemptOutcome<T>.result(
            await attempt(cancellation.token),
          );
        } catch (error, stackTrace) {
          _throwIfCancelled();
          outcome = AttemptOutcome<T>.error(error, stackTrace);
        }

        final attemptCompletedAt = runtime.clock.monotonicNow();
        _checkCanRun();
        final elapsed = _elapsed(operationStartedAt, attemptCompletedAt);
        pipelineContext.elapsed = elapsed;
        final retryAttempt = RetryAttemptContext<T>(
          outcome: outcome,
          pipelineContext: pipelineContext,
          retryIndex: attemptNumber - 1,
          attemptNumber: attemptNumber,
          elapsed: elapsed,
          attemptDuration: _elapsed(attemptStartedAt, attemptCompletedAt),
        );

        if (outcome
            case AttemptOutcomeError<T>(
              :final error,
              :final stackTrace,
            )) {
          failureCount += 1;
          onAttemptFailure?.call(
            QueryFailure(error, stackTrace),
            failureCount,
          );
        }

        final shouldRetry = await strategy.retryIf.shouldHandle(retryAttempt);
        _checkCanRun();
        if (!shouldRetry) {
          if (hasRetried) {
            await strategy.onGiveUp?.call(retryAttempt);
            _checkCanRun();
          }
          return _complete(outcome);
        }

        if (!_mayStartRetry()) return _complete(outcome);
        await strategy.onRetry?.call(retryAttempt);
        _checkCanRun();
        if (!_mayStartRetry()) return _complete(outcome);

        final delay = await strategy.delay.compute<T>(
              retryAttempt,
              runtime.random.nextDouble,
            ) ??
            Duration.zero;
        _checkCanRun();
        if (!_mayStartRetry()) return _complete(outcome);
        hasRetried = true;

        final mayContinue = await _waitBeforeRetry(delay);
        _checkCanRun();
        if (!mayContinue || !_mayStartRetry()) return _complete(outcome);
      }
    } finally {
      removeCancellationListener();
    }
  }

  RetryStrategy<T> _createStrategy(RetryPolicy<T> value) {
    if (identical(value, RetryPolicy.none)) {
      return RetryStrategy<T>(
        delay: DelayPolicy.none(),
        retryIf: RetryIf<T>.never(),
      );
    }
    if (identical(value, RetryPolicy.standard)) {
      return RetryStrategy<T>(
        delay: DelayPolicy.exponential(
          initial: const Duration(seconds: 1),
          max: const Duration(seconds: 30),
        ),
        retryIf: RetryIf<T>.exception() & RetryIf<T>.maxRetries(3),
      );
    }
    final custom = value as _CustomRetryPolicy<T>;
    return custom.create(RetryBuilder<T>._());
  }

  Future<bool> _waitBeforeRetry(Duration delay) async {
    try {
      await timers.wait(
        delay,
        cancellation: _retryWaitCancellation,
      );
      while (_mayStartRetry()) {
        if (networkMode != RetryNetworkMode.always) {
          await _waitUntilOnline(_retryWaitCancellation);
        }
        if (!_mayStartRetry()) return false;
        await _waitUntilFocused(_retryWaitCancellation);
        if (!_mayStartRetry()) return false;
        if (focusManager.isFocused &&
            (networkMode == RetryNetworkMode.always ||
                onlineManager.isOnline)) {
          return true;
        }
      }
      return false;
    } on QueryCancelledException {
      _throwIfCancelled();
      if (_retriesStopped) return false;
      rethrow;
    }
  }

  Future<void> _waitUntilOnline(
    QueryCancellationController waitCancellation,
  ) async {
    if (onlineManager.isOnline) return;
    if (waitCancellation.isCancelled) {
      throw QueryCancelledException(waitCancellation.reason);
    }

    onOnlinePauseChanged?.call(true);
    final completer = Completer<void>();
    late final Effect onlineEffect;
    void Function()? removeCancellationListener;

    void completeOnlineWait() {
      if (!completer.isCompleted) completer.complete();
    }

    void cancelOnlineWait(Object? reason) {
      if (!completer.isCompleted) {
        completer.completeError(
          QueryCancelledException(reason),
          StackTrace.current,
        );
      }
    }

    onlineEffect = Effect.lazy(
      () {
        if (onlineManager.value) completeOnlineWait();
      },
      detach: true,
    );
    removeCancellationListener = waitCancellation.addListener(cancelOnlineWait);
    if (!completer.isCompleted) onlineEffect.run();

    try {
      await completer.future;
    } finally {
      removeCancellationListener();
      onlineEffect.dispose();
      onOnlinePauseChanged?.call(false);
    }
  }

  Future<void> _waitUntilFocused(
    QueryCancellationController waitCancellation,
  ) async {
    if (focusManager.isFocused) return;
    if (waitCancellation.isCancelled) {
      throw QueryCancelledException(waitCancellation.reason);
    }

    onFocusPauseChanged?.call(true);
    final completer = Completer<void>();
    late final Effect focusEffect;
    void Function()? removeCancellationListener;

    void completeFocusWait() {
      if (!completer.isCompleted) completer.complete();
    }

    void cancelFocusWait(Object? reason) {
      if (!completer.isCompleted) {
        completer.completeError(
          QueryCancelledException(reason),
          StackTrace.current,
        );
      }
    }

    focusEffect = Effect.lazy(
      () {
        if (focusManager.value) completeFocusWait();
      },
      detach: true,
    );
    removeCancellationListener = waitCancellation.addListener(cancelFocusWait);
    if (!completer.isCompleted) focusEffect.run();

    try {
      await completer.future;
    } finally {
      removeCancellationListener();
      focusEffect.dispose();
      onFocusPauseChanged?.call(false);
    }
  }

  bool _mayStartRetry() {
    return !_retriesStopped &&
        !_retriesPaused &&
        (canStartRetry?.call() ?? true);
  }

  void _checkCanRun() {
    _throwIfCancelled();
    guard?.call();
    _throwIfCancelled();
  }

  void _throwIfCancelled() {
    if (cancellation.isCancelled) {
      throw QueryCancelledException(cancellation.reason);
    }
  }

  static Duration _elapsed(Duration startedAt, Duration endedAt) {
    final elapsed = endedAt - startedAt;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  static TReturn _complete<TReturn>(AttemptOutcome<TReturn> outcome) {
    switch (outcome) {
      case AttemptOutcomeResult<TReturn>(:final result):
        return result;
      case AttemptOutcomeError<TReturn>(:final error, :final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final class _RetryStopReason {
  const _RetryStopReason._();

  static const instance = _RetryStopReason._();
}
