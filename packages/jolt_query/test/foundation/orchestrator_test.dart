import 'package:jolt_query/src/foundation/notification_orchestrator.dart';
import 'package:jolt_query/src/foundation/timer_orchestrator.dart';
import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('timer cancellation wins over providers delivering late callbacks', () {
    final scheduler = FakeQueryTimerScheduler();
    final timers = TimerOrchestrator(scheduler);
    var calls = 0;

    final handle = timers.schedule(
      const Duration(seconds: 1),
      () => calls += 1,
    );
    handle.cancel();
    scheduler.handles.single.fire(evenIfCancelled: true);

    expect(calls, 0);
    timers.dispose();
  });

  test('owned delay is immediately cancellable', () async {
    final scheduler = FakeQueryTimerScheduler();
    final timers = TimerOrchestrator(scheduler);
    final cancellation = QueryCancellationController();

    final wait = timers.wait(
      const Duration(seconds: 5),
      cancellation: cancellation,
    );
    cancellation.cancel('disposed');

    await expectLater(wait, throwsA(isA<QueryCancelledException>()));
    expect(scheduler.handles.single.isCancelled, isTrue);
    timers.dispose();
  });

  test('notifications are queued, reentrant, and scheduled once', () {
    final scheduler = FakeQueryNotificationScheduler();
    final notifications = NotificationOrchestrator(scheduler);
    final calls = <int>[];

    notifications.enqueue(() {
      calls.add(1);
      notifications.enqueue(() => calls.add(3));
    });
    notifications.enqueue(() => calls.add(2));

    expect(scheduler.handles, hasLength(1));
    scheduler.flushAll();
    expect(calls, <int>[1, 2, 3]);

    notifications.dispose();
  });
}
