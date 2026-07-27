import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:test/test.dart';

import '../support/fake_runtime.dart';

void main() {
  test('client owns stable managers handles operations and observers',
      () async {
    final timers = FakeQueryTimerScheduler();
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: FakeQueryClock(),
      timers: timers,
      random: FakeQueryRandomSource(),
      notifications: notifications,
    );
    final client = QueryClient(runtime: runtime);
    final focus = client.focusManager;
    final online = client.onlineManager;
    final observer = _TestDisposable();
    final cancellation = client.ownCancellationInternal();
    var sourceSubscriptionCancelled = false;
    final eventSource = StreamController<bool>(
      onCancel: () => sourceSubscriptionCancelled = true,
    );
    client.onlineManager.setEventSource(eventSource.stream);
    client.ownDisposableInternal(observer);
    client.timersInternal.schedule(const Duration(days: 1), () {});
    client.notificationsInternal.enqueue(() {});

    client
      ..dispose()
      ..dispose();

    expect(identical(client.focusManager, focus), isTrue);
    expect(identical(client.onlineManager, online), isTrue);
    expect(observer.disposeCount, 1);
    expect(cancellation.isCancelled, isTrue);
    expect(timers.handles.single.isCancelled, isTrue);
    expect(notifications.handles.single.isCancelled, isTrue);
    expect(sourceSubscriptionCancelled, isTrue);
    expect(eventSource.isClosed, isFalse);
    await eventSource.close();
  });

  test('disposing one client does not dispose borrowed runtime providers', () {
    final timers = FakeQueryTimerScheduler();
    final notifications = FakeQueryNotificationScheduler();
    final runtime = QueryRuntime(
      clock: FakeQueryClock(),
      timers: timers,
      random: FakeQueryRandomSource(<double>[0.1, 0.2]),
      notifications: notifications,
    );
    final first = QueryClient(runtime: runtime);
    final second = QueryClient(runtime: runtime);

    first.dispose();
    var called = false;
    second.timersInternal.schedule(Duration.zero, () => called = true);
    timers.elapse(Duration.zero);

    expect(called, isTrue);
    expect(runtime.random.nextDouble(), 0.1);
    second.dispose();
  });

  test('disposed clients reject public reads fetches and observers', () async {
    final client = QueryClient()..dispose();
    final source = query<int>(
      key: QueryKey(<Object?>['disposed-public-operation']),
      fetch: (_) => 1,
    );

    expect(
      () => client.getQueryData(source),
      throwsA(isA<QueryClientDisposedException>()),
    );
    await expectLater(
      client.fetchQuery(source),
      throwsA(isA<QueryClientDisposedException>()),
    );
    expect(
      () => client.observeQuery(source),
      throwsA(isA<QueryClientDisposedException>()),
    );
  });
}

final class _TestDisposable implements Disposable {
  int disposeCount = 0;

  @override
  void dispose() => disposeCount += 1;
}
