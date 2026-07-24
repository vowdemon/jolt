import 'dart:async';

import 'package:jolt_query/jolt_query.dart';
import 'package:test/test.dart';

void main() {
  test('FocusManager keeps identity and last state across source completion',
      () async {
    final manager = FocusManager();
    final source = StreamController<bool>();

    manager.setEventSource(source.stream);
    source.add(false);
    await pumpEventQueue();
    expect(manager.isFocused, isFalse);

    await source.close();
    expect(manager.isFocused, isFalse);

    manager.isFocused = true;
    expect(manager.value, isTrue);
    manager
      ..dispose()
      ..dispose();
  });

  test(
      'FocusManager replacement cancels the prior source and keeps client identity',
      () async {
    var firstCancellations = 0;
    var secondCancellations = 0;
    final first = StreamController<bool>(
      sync: true,
      onCancel: () => firstCancellations += 1,
    );
    final second = StreamController<bool>(
      sync: true,
      onCancel: () => secondCancellations += 1,
    );
    final client = QueryClient();
    final manager = client.focusManager;

    manager.setEventSource(first.stream);
    first.add(false);
    expect(manager.isFocused, isFalse);

    manager.setEventSource(second.stream);
    await pumpEventQueue();
    expect(firstCancellations, 1);
    expect(client.focusManager, same(manager));

    first.add(true);
    expect(manager.isFocused, isFalse);
    second.add(true);
    expect(manager.isFocused, isTrue);

    client
      ..dispose()
      ..dispose();
    await pumpEventQueue();
    expect(secondCancellations, 1);
    expect(first.isClosed, isFalse);
    expect(second.isClosed, isFalse);

    await first.close();
    await second.close();
  });

  test('OnlineManager replacement cancels the prior subscription', () async {
    final manager = OnlineManager();
    final first = StreamController<bool>();
    final second = StreamController<bool>();

    manager.setEventSource(first.stream);
    manager.setEventSource(second.stream);
    first.add(false);
    second.add(false);
    await pumpEventQueue();
    expect(manager.isOnline, isFalse);

    second.add(true);
    await pumpEventQueue();
    expect(manager.isOnline, isTrue);

    manager.dispose();
    await first.close();
    await second.close();
  });

  test('source errors reach the Zone captured at registration', () async {
    final errors = <Object>[];
    final manager = OnlineManager();
    final source = StreamController<bool>();

    await runZonedGuarded(
      () async {
        manager.setEventSource(source.stream);
        source.addError(StateError('source failed'), StackTrace.current);
        await pumpEventQueue();
      },
      (error, _) => errors.add(error),
    );

    expect(errors.single, isA<StateError>());
    expect(manager.isOnline, isTrue);
    manager.dispose();
    await source.close();
  });
}
