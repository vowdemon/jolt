import 'dart:async';

import 'query_cancellation.dart';
import 'query_runtime.dart';

/// Internal ownership and late-callback guards for runtime timer handles.
final class TimerOrchestrator {
  TimerOrchestrator(this._scheduler);

  final QueryTimerScheduler _scheduler;
  final Set<ManagedScheduledHandle> _handles = <ManagedScheduledHandle>{};
  int _generation = 0;
  bool _isDisposed = false;

  QueryScheduledHandle schedule(
    Duration delay,
    void Function() callback,
  ) {
    _checkActive();
    final generation = _generation;
    late final ManagedScheduledHandle managed;
    managed = ManagedScheduledHandle._(this, periodic: false);
    _handles.add(managed);
    managed._attach(
      _scheduler.schedule(delay, () {
        if (!managed._canRun(generation)) return;
        managed._finish();
        callback();
      }),
    );
    return managed;
  }

  QueryScheduledHandle schedulePeriodic(
    Duration interval,
    void Function() callback,
  ) {
    _checkActive();
    final generation = _generation;
    late final ManagedScheduledHandle managed;
    managed = ManagedScheduledHandle._(this, periodic: true);
    _handles.add(managed);
    managed._attach(
      _scheduler.schedulePeriodic(interval, () {
        if (managed._canRun(generation)) callback();
      }),
    );
    return managed;
  }

  Future<void> wait(
    Duration delay, {
    required QueryCancellationController cancellation,
  }) {
    if (_isDisposed) {
      return Future<void>.error(
        StateError('Timer orchestrator is disposed.'),
        StackTrace.current,
      );
    }
    if (cancellation.isCancelled) {
      return Future<void>.error(
        QueryCancelledException(cancellation.reason),
        StackTrace.current,
      );
    }

    final completer = Completer<void>();
    QueryScheduledHandle? handle;
    void Function()? removeCancellationListener;

    void finish() {
      removeCancellationListener?.call();
      removeCancellationListener = null;
      if (!completer.isCompleted) completer.complete();
    }

    void cancel(Object? reason) {
      handle?.cancel();
      removeCancellationListener?.call();
      removeCancellationListener = null;
      if (!completer.isCompleted) {
        completer.completeError(
          QueryCancelledException(reason),
          StackTrace.current,
        );
      }
    }

    removeCancellationListener = cancellation.addListener(cancel);
    if (delay <= Duration.zero) {
      finish();
    } else {
      handle = schedule(delay, finish);
    }
    return completer.future;
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('Timer orchestrator is disposed.');
  }

  void _remove(ManagedScheduledHandle handle) => _handles.remove(handle);

  bool _isGenerationCurrent(int generation) =>
      !_isDisposed && generation == _generation;

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation += 1;
    final handles = List<ManagedScheduledHandle>.of(_handles);
    _handles.clear();
    for (final handle in handles) {
      handle.cancel();
    }
  }
}

final class ManagedScheduledHandle implements QueryScheduledHandle {
  ManagedScheduledHandle._(this._owner, {required this.periodic});

  final TimerOrchestrator _owner;
  final bool periodic;
  QueryScheduledHandle? _inner;
  bool _isCancelled = false;
  bool _isFinished = false;

  void _attach(QueryScheduledHandle inner) {
    if (_isCancelled || _isFinished) {
      inner.cancel();
    } else {
      _inner = inner;
    }
  }

  bool _canRun(int generation) =>
      !_isCancelled && !_isFinished && _owner._isGenerationCurrent(generation);

  void _finish() {
    if (_isFinished) return;
    _isFinished = true;
    _inner = null;
    _owner._remove(this);
  }

  @override
  bool get isCancelled => _isCancelled;

  @override
  void cancel() {
    if (_isCancelled || _isFinished) return;
    _isCancelled = true;
    _inner?.cancel();
    _inner = null;
    _owner._remove(this);
  }
}
