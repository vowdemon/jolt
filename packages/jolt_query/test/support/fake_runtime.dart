import 'dart:collection';

import 'package:jolt_query/jolt_query.dart';

final class FakeQueryClock implements QueryClock {
  FakeQueryClock({
    DateTime? wall,
    Duration monotonic = Duration.zero,
  })  : _wall = wall ?? DateTime.utc(2025),
        _monotonic = monotonic;

  DateTime _wall;
  Duration _monotonic;

  @override
  Duration monotonicNow() => _monotonic;

  @override
  DateTime wallNow() => _wall;

  void advance(Duration duration) {
    _wall = _wall.add(duration);
    _monotonic += duration;
  }
}

final class FakeQueryRandomSource implements QueryRandomSource {
  FakeQueryRandomSource([Iterable<double> values = const <double>[0.5]])
      : _values = Queue<double>.of(values);

  final Queue<double> _values;

  @override
  double nextDouble() {
    if (_values.isEmpty) throw StateError('No fake random value remains.');
    final value = _values.removeFirst();
    if (value < 0 || value >= 1) {
      throw StateError('Fake random values must be in [0, 1).');
    }
    return value;
  }
}

final class FakeQueryTimerScheduler implements QueryTimerScheduler {
  Duration now = Duration.zero;
  final List<FakeScheduledHandle> handles = <FakeScheduledHandle>[];

  @override
  QueryScheduledHandle schedule(Duration delay, void Function() callback) {
    final handle = FakeScheduledHandle(
      due: now + (delay.isNegative ? Duration.zero : delay),
      callback: callback,
    );
    handles.add(handle);
    return handle;
  }

  @override
  QueryScheduledHandle schedulePeriodic(
    Duration interval,
    void Function() callback,
  ) {
    if (interval <= Duration.zero) throw ArgumentError.value(interval);
    final handle = FakeScheduledHandle(
      due: now + interval,
      interval: interval,
      callback: callback,
    );
    handles.add(handle);
    return handle;
  }

  void elapse(Duration duration) {
    final target = now + duration;
    while (true) {
      FakeScheduledHandle? next;
      for (final handle in handles) {
        if (handle.isCancelled || handle.due > target) continue;
        if (next == null || handle.due < next.due) next = handle;
      }
      if (next == null) break;
      now = next.due;
      next.fire();
    }
    now = target;
  }
}

final class FakeQueryNotificationScheduler
    implements QueryNotificationScheduler {
  final List<FakeScheduledHandle> handles = <FakeScheduledHandle>[];

  @override
  QueryScheduledHandle schedule(void Function() flush) {
    final handle = FakeScheduledHandle(
      due: Duration.zero,
      callback: flush,
    );
    handles.add(handle);
    return handle;
  }

  void flushAll() {
    for (final handle in List<FakeScheduledHandle>.of(handles)) {
      handle.fire();
    }
  }
}

final class FakeScheduledHandle implements QueryScheduledHandle {
  FakeScheduledHandle({
    required this.due,
    required this.callback,
    this.interval,
  });

  Duration due;
  final Duration? interval;
  final void Function() callback;
  bool _isCancelled = false;

  @override
  bool get isCancelled => _isCancelled;

  @override
  void cancel() => _isCancelled = true;

  void fire({bool evenIfCancelled = false}) {
    if (_isCancelled && !evenIfCancelled) return;
    callback();
    if (interval case final interval?) {
      due += interval;
    } else {
      _isCancelled = true;
    }
  }
}
