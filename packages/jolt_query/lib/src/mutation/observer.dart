part of 'client_extension.dart';

/// Reactive latest-execution presentation for a mutation.
final class MutationObserver<V, D, R>
    implements Readable<MutationObserverResult<V, D, R>>, Disposable {
  MutationObserver._(this._client, this._submitter, this._mutation)
      : _result = Signal<MutationObserverResult<V, D, R>>(
          MutationObserverResult<V, D, R>.idle(),
        );

  final QueryClient _client;
  final MutationSubmitterInternal _submitter;

  Mutation<V, D, R> _mutation;

  /// The reusable mutation definition executed by this observer.
  Mutation<V, D, R> get mutation => _mutation;

  final Signal<MutationObserverResult<V, D, R>> _result;
  _MutationBinding<V, D, R>? _binding;
  int _generation = 0;
  bool _isDisposed = false;

  /// Whether this observer has detached and released its reactive state.
  bool get isDisposed => _isDisposed;

  /// The current complete presentation without reactive tracking.
  MutationObserverResult<V, D, R> get snapshot => _result.peek;

  @override
  MutationObserverResult<V, D, R> get peek => _result.peek;

  @override
  MutationObserverResult<V, D, R> get value => _result.value;

  /// Current observer status.
  MutationStatus get status => value.status;

  /// Whether no execution is currently presented.
  bool get isIdle => value.isIdle;

  /// Whether the presented execution is still active.
  bool get isPending => value.isPending;

  /// Whether the presented execution succeeded.
  bool get isSuccess => value.isSuccess;

  /// Whether the presented execution failed.
  bool get isError => value.isError;

  /// Submitted variables, absent while idle.
  QueryValue<V> get variables => value.variables;

  /// Successful data, including present-null.
  QueryValue<D> get data => value.data;

  /// Result of onMutate, including absent and present-null states.
  QueryValue<R> get onMutateResult => value.onMutateResult;

  /// Current terminal or retryable failure.
  QueryFailure? get failure => value.failure;

  /// Number of thrown mutation-function attempts.
  int get failureCount => value.failureCount;

  /// Whether the latest execution is waiting on an eligibility gate.
  bool get isPaused => value.isPaused;

  /// The latest execution's pause reason.
  PauseReason? get pauseReason => value.pauseReason;

  /// The latest execution's submission time.
  DateTime? get submittedAt => value.submittedAt;

  /// Submits an independent execution and presents it as the latest call.
  Future<D> execute(
    V variables, {
    void Function(
      D data,
      V variables,
      QueryValue<R> onMutateResult,
      MutationContext context,
    )? onSuccess,
    void Function(
      QueryFailure failure,
      V variables,
      QueryValue<R> onMutateResult,
      MutationContext context,
    )? onError,
    void Function(
      QueryValue<D> data,
      QueryFailure? failure,
      V variables,
      QueryValue<R> onMutateResult,
      MutationContext context,
    )? onSettled,
  }) {
    _checkActive();
    _detachCurrent();
    final generation = ++_generation;
    final binding = _MutationBinding<V, D, R>(
      observer: this,
      generation: generation,
      onSuccess: onSuccess,
      onError: onError,
      onSettled: onSettled,
    );
    _binding = binding;
    try {
      final execution = _submitter.submitMutationInternal<V, D, R>(
        _mutation,
        variables,
        listener: binding,
      );
      binding.attach(execution);
      if (binding.isEligibleInternal) _present(execution);
      return execution.future;
    } catch (_) {
      if (identical(_binding, binding)) {
        _binding = null;
        _setResult(MutationObserverResult<V, D, R>.idle());
      }
      rethrow;
    }
  }

  /// Replaces the recipe captured by future submissions.
  ///
  /// An equal nullable structural key preserves the current presentation and
  /// active binding. Changing the key resets presentation to idle without
  /// cancelling an already submitted execution.
  void updateMutation(Mutation<V, D, R> mutation) {
    _checkActive();
    final keyChanged = _mutation.key != mutation.key;
    _mutation = mutation;
    if (!keyChanged) return;

    _generation += 1;
    _detachCurrent();
    _setResult(MutationObserverResult<V, D, R>.idle());
  }

  /// Detaches presentation and returns to idle without stopping execution.
  void reset() {
    _checkActive();
    _generation += 1;
    _detachCurrent();
    _setResult(MutationObserverResult<V, D, R>.idle());
  }

  void _present(MutationExecutionInternal<V, D, R> execution) {
    if (_isDisposed) return;
    _setResult(
      MutationObserverResult<V, D, R>(
        status: execution.status,
        variables: QueryValue<V>.present(execution.variables),
        data: execution.dataInternal,
        onMutateResult: execution.onMutateResultInternal,
        isPaused: execution.isPaused,
        pauseReason: execution.pauseReasonInternal,
        failure: execution.failureInternal,
        failureCount: execution.failureCountInternal,
        submittedAt: execution.submittedAtInternal,
      ),
    );
  }

  void _setResult(MutationObserverResult<V, D, R> next) {
    final previous = _result.peek;
    if (previous.status == next.status &&
        previous.variables == next.variables &&
        previous.data == next.data &&
        previous.onMutateResult == next.onMutateResult &&
        previous.isPaused == next.isPaused &&
        previous.pauseReason == next.pauseReason &&
        previous.failure == next.failure &&
        previous.failureCount == next.failureCount &&
        previous.submittedAt == next.submittedAt) {
      return;
    }
    _result.value = next;
  }

  void _detachCurrent() {
    final binding = _binding;
    _binding = null;
    binding?.detach();
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('MutationObserver is disposed.');
    _client.checkActiveInternal();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation += 1;
    _detachCurrent();
    _result.dispose();
    _client.releaseDisposableInternal(this);
  }
}

final class _MutationBinding<V, D, R>
    implements MutationExecutionListenerInternal<V, D, R> {
  _MutationBinding({
    required this.observer,
    required this.generation,
    required this.onSuccess,
    required this.onError,
    required this.onSettled,
  });

  final MutationObserver<V, D, R> observer;
  final int generation;
  final void Function(D, V, QueryValue<R>, MutationContext)? onSuccess;
  final void Function(QueryFailure, V, QueryValue<R>, MutationContext)? onError;
  final void Function(
    QueryValue<D>,
    QueryFailure?,
    V,
    QueryValue<R>,
    MutationContext,
  )? onSettled;
  MutationExecutionInternal<V, D, R>? _execution;

  void attach(MutationExecutionInternal<V, D, R> execution) {
    _execution = execution;
    if (!isEligibleInternal) detach();
  }

  void detach() {
    final execution = _execution;
    _execution = null;
    execution?.detachListenerInternal(this);
  }

  @override
  bool get isEligibleInternal =>
      !observer._isDisposed &&
      observer._generation == generation &&
      identical(observer._binding, this);

  @override
  void onMutationExecutionChangedInternal(
    MutationExecutionInternal<V, D, R> execution,
  ) {
    if (isEligibleInternal && identical(_execution, execution)) {
      observer._present(execution);
    }
  }

  @override
  void onMutationSuccessInternal(
    D data,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {
    onSuccess?.call(data, variables, onMutateResult, context);
  }

  @override
  void onMutationErrorInternal(
    QueryFailure failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {
    onError?.call(failure, variables, onMutateResult, context);
  }

  @override
  void onMutationSettledInternal(
    QueryValue<D> data,
    QueryFailure? failure,
    V variables,
    QueryValue<R> onMutateResult,
    MutationContext context,
  ) {
    onSettled?.call(data, failure, variables, onMutateResult, context);
  }
}

/// Zero-variable facade for mutation observers.
extension MutationActionObserverMethods<D, R>
    on MutationObserver<NoVariables, D, R> {
  /// Executes with [NoVariables.value] while omitting the sentinel callbacks.
  Future<D> run({
    void Function(
      D data,
      QueryValue<R> onMutateResult,
      MutationContext context,
    )? onSuccess,
    void Function(
      QueryFailure failure,
      QueryValue<R> onMutateResult,
      MutationContext context,
    )? onError,
    void Function(
      QueryValue<D> data,
      QueryFailure? failure,
      QueryValue<R> onMutateResult,
      MutationContext context,
    )? onSettled,
  }) {
    return execute(
      NoVariables.value,
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
}
