import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

class _TestDisposable implements Disposable {
  bool disposed = false;

  @override
  void dispose() => disposed = true;
}

void main() {
  group('useAutoDispose', () {
    testWidgets('creates, runs, and disposes', (tester) async {
      late _TestDisposable disposable;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          disposable = useAutoDispose(() => _TestDisposable());
          return () => const Text('Test');
        }),
      ));
      await tester.pumpAndSettle();

      expect(disposable.disposed, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(disposable.disposed, isTrue);
    });
  });
}
