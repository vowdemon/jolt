import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_query/jolt_query.dart';

void main() {
  testWidgets('binding mirrors Flutter focus without changing online state',
      (tester) async {
    final client = QueryClient();
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      client.dispose();
    });
    client.onlineManager.isOnline = false;
    final lifecycle = client.bindFlutterLifecycle(binding: tester.binding);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(client.focusManager.isFocused, isFalse);
    expect(client.onlineManager.isOnline, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(client.focusManager.isFocused, isTrue);
    expect(client.onlineManager.isOnline, isFalse);

    lifecycle.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(client.focusManager.isFocused, isTrue);
  });

  testWidgets('client owns and disposes its lifecycle binding', (tester) async {
    final client = QueryClient();
    final lifecycle = client.bindFlutterLifecycle(binding: tester.binding);

    expect(lifecycle.isDisposed, isFalse);

    client.dispose();

    expect(lifecycle.isDisposed, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
