import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('deterministic runtime capabilities control time and scheduling', () {
    final clock = FakeQueryClock();
    final timers = FakeQueryTimerScheduler();
    final random = FakeQueryRandomSource(<double>[0.25]);
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: clock,
      timers: timers,
      random: random,
      notifications: notifications,
    );
    var timerCalls = 0;
    var notificationsCalls = 0;

    runtime.timers.schedule(
      const Duration(seconds: 2),
      () => timerCalls += 1,
    );
    runtime.notifications.schedule(() => notificationsCalls += 1);

    clock.advance(const Duration(seconds: 2));
    timers.elapse(const Duration(seconds: 1));
    expect(timerCalls, 0);
    timers.elapse(const Duration(seconds: 1));
    notifications.flushAll();

    expect(clock.wallNow(), DateTime.utc(2025, 1, 1, 0, 0, 2));
    expect(clock.monotonicNow(), const Duration(seconds: 2));
    expect(runtime.random.nextDouble(), 0.25);
    expect(timerCalls, 1);
    expect(notificationsCalls, 1);
  });

  test('scheduled handle cancellation is idempotent', () {
    final timers = FakeQueryTimerScheduler();
    var calls = 0;
    final handle = timers.schedule(Duration.zero, () => calls += 1);

    handle
      ..cancel()
      ..cancel();
    timers.elapse(Duration.zero);

    expect(handle.isCancelled, isTrue);
    expect(calls, 0);
  });
}
