import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/setup.dart';

void main() {
  group('useMemoized', () {
    testWidgets('creates, runs, and disposes', (tester) async {
      int createCount = 0;
      bool disposed = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final value = useMemoized(
            () {
              createCount++;
              return 'test';
            },
            (value) => disposed = true,
          );
          return () => Text(value);
        }),
      ));
      await tester.pumpAndSettle();

      expect(createCount, 1);
      expect(disposed, isFalse);
      expect(find.text('test'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(disposed, isTrue);
    });
  });
}
