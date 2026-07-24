import 'dart:async';
import 'dart:math';

/// A cancellable handle returned by a query runtime scheduler.
abstract interface class QueryScheduledHandle {
  /// Whether cancellation has been requested.
  bool get isCancelled;

  /// Cancels this handle. Repeated calls have no additional effect.
  void cancel();
}

/// Supplies wall-clock and monotonic time to a query client.
abstract interface class QueryClock {
  /// Returns current wall-clock time.
  DateTime wallNow();

  /// Returns monotonic elapsed time from an implementation-defined origin.
  Duration monotonicNow();
}

/// Schedules one-shot and periodic query work.
abstract interface class QueryTimerScheduler {
  /// Schedules [callback] once after [delay].
  QueryScheduledHandle schedule(Duration delay, void Function() callback);

  /// Schedules [callback] repeatedly at [interval].
  QueryScheduledHandle schedulePeriodic(
    Duration interval,
    void Function() callback,
  );
}

/// Supplies random values used by retry jitter.
abstract interface class QueryRandomSource {
  /// Returns a value greater than or equal to zero and less than one.
  double nextDouble();
}

/// Schedules an outward notification flush.
abstract interface class QueryNotificationScheduler {
  /// Schedules [flush] and returns its cancellable handle.
  QueryScheduledHandle schedule(void Function() flush);
}

/// Borrowed deterministic capabilities used by a [QueryClient].
///
/// A client owns handles created through these providers, but it does not own
/// or dispose the providers themselves.
final class QueryRuntime {
  /// Creates a complete runtime capability bundle.
  const QueryRuntime({
    required this.clock,
    required this.timers,
    required this.random,
    required this.notifications,
  });

  /// Creates a runtime backed by Dart's system clock, timers, and microtasks.
  factory QueryRuntime.system() {
    final clock = _SystemQueryClock();
    return QueryRuntime(
      clock: clock,
      timers: const _SystemQueryTimerScheduler(),
      random: _SystemQueryRandomSource(),
      notifications: const _SystemQueryNotificationScheduler(),
    );
  }

  /// Borrowed time provider.
  final QueryClock clock;

  /// Borrowed timer provider.
  final QueryTimerScheduler timers;

  /// Borrowed random provider.
  final QueryRandomSource random;

  /// Borrowed notification provider.
  final QueryNotificationScheduler notifications;
}

final class _SystemQueryClock implements QueryClock {
  _SystemQueryClock() {
    _stopwatch.start();
  }

  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration monotonicNow() => _stopwatch.elapsed;

  @override
  DateTime wallNow() => DateTime.now();
}

final class _SystemQueryRandomSource implements QueryRandomSource {
  final Random _random = Random();

  @override
  double nextDouble() => _random.nextDouble();
}

final class _SystemQueryTimerScheduler implements QueryTimerScheduler {
  const _SystemQueryTimerScheduler();

  @override
  QueryScheduledHandle schedule(Duration delay, void Function() callback) {
    final handle = _SystemTimerHandle();
    handle._attach(
      Timer(delay.isNegative ? Duration.zero : delay, () {
        if (!handle.isCancelled) callback();
      }),
    );
    return handle;
  }

  @override
  QueryScheduledHandle schedulePeriodic(
    Duration interval,
    void Function() callback,
  ) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Periodic intervals must be positive.',
      );
    }
    final handle = _SystemTimerHandle();
    handle._attach(
      Timer.periodic(interval, (_) {
        if (!handle.isCancelled) callback();
      }),
    );
    return handle;
  }
}

final class _SystemQueryNotificationScheduler
    implements QueryNotificationScheduler {
  const _SystemQueryNotificationScheduler();

  @override
  QueryScheduledHandle schedule(void Function() flush) {
    final handle = _MicrotaskHandle();
    scheduleMicrotask(() {
      if (!handle.isCancelled) flush();
    });
    return handle;
  }
}

final class _SystemTimerHandle implements QueryScheduledHandle {
  Timer? _timer;
  bool _isCancelled = false;

  void _attach(Timer timer) {
    if (_isCancelled) {
      timer.cancel();
    } else {
      _timer = timer;
    }
  }

  @override
  bool get isCancelled => _isCancelled;

  @override
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _timer?.cancel();
    _timer = null;
  }
}

final class _MicrotaskHandle implements QueryScheduledHandle {
  bool _isCancelled = false;

  @override
  bool get isCancelled => _isCancelled;

  @override
  void cancel() => _isCancelled = true;
}
