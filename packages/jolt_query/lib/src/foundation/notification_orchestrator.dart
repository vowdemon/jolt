import 'dart:async';

import 'package:jolt/jolt.dart' show batch, untracked;

import 'query_runtime.dart';

/// Internal batching and reentrancy control for outward notifications.
final class NotificationOrchestrator {
  NotificationOrchestrator(this._scheduler);

  final QueryNotificationScheduler _scheduler;
  final List<_QueuedNotification> _queue = <_QueuedNotification>[];
  QueryScheduledHandle? _scheduled;
  int _generation = 0;
  bool _isFlushing = false;
  bool _isDisposed = false;

  void enqueue(void Function() callback) {
    if (_isDisposed) return;
    _queue.add(_QueuedNotification(Zone.current, callback));
    if (_scheduled == null && !_isFlushing) _scheduleFlush();
  }

  void _scheduleFlush() {
    final generation = _generation;
    _scheduled = _scheduler.schedule(() {
      _scheduled = null;
      if (_isDisposed || generation != _generation) return;
      _flush();
    });
  }

  void _flush() {
    if (_isFlushing || _isDisposed) return;
    _isFlushing = true;
    try {
      untracked<void>(() {
        batch<void>(() {
          var index = 0;
          while (index < _queue.length && !_isDisposed) {
            final notification = _queue[index];
            index += 1;
            notification.zone.runGuarded(notification.callback);
          }
          if (index > 0) _queue.removeRange(0, index);
        });
      });
    } finally {
      _isFlushing = false;
      if (_queue.isNotEmpty && !_isDisposed && _scheduled == null) {
        _scheduleFlush();
      }
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation += 1;
    _scheduled?.cancel();
    _scheduled = null;
    _queue.clear();
  }
}

final class _QueuedNotification {
  const _QueuedNotification(this.zone, this.callback);

  final Zone zone;
  final void Function() callback;
}
