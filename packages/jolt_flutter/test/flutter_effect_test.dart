import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  group('FlutterEffect', () {
    testWidgets('runs immediately when not lazy', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      expect(values, [1]);

      signal.dispose();
    });

    testWidgets('lazy effect runs only when invoked', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      final effect = FlutterEffect(() {
        values.add(signal.value);
      }, lazy: true);

      expect(values, isEmpty);

      signal.value = 2;
      await tester.pumpAndSettle();
      expect(values, isEmpty);

      effect.run();
      expect(values, [2]);

      signal.dispose();
      effect.dispose();
    });

    testWidgets('schedules at frame end', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      signal.value = 2;
      expect(values, [1]);

      await tester.pumpAndSettle();
      expect(values, [1, 2]);

      signal.dispose();
    });

    testWidgets('coalesces multiple triggers in one frame', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      FlutterEffect(() {
        values.add(signal.value);
      });

      signal.value = 2;
      signal.value = 3;
      signal.value = 4;
      expect(values, [1]);

      await tester.pumpAndSettle();
      expect(values, [1, 4]);

      signal.dispose();
    });

    testWidgets('run executes immediately on lazy effect', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      final effect = FlutterEffect(() {
        values.add(signal.value);
      }, lazy: true);

      effect.run();
      expect(values, [1]);

      signal.value = 2;
      effect.run();
      expect(values, [1, 2]);

      signal.dispose();
      effect.dispose();
    });

    testWidgets('dispose cancels pending frame execution', (tester) async {
      final signal = Signal(1);
      final values = <int>[];

      final effect = FlutterEffect(() {
        values.add(signal.value);
      });

      signal.value = 2;
      effect.dispose();

      await tester.pumpAndSettle();
      expect(values, [1]);

      signal.dispose();
    });

    testWidgets('runs once after batch within a frame', (tester) async {
      final a = Signal(1);
      final b = Signal(2);
      final values = <int>[];

      FlutterEffect(() {
        values.add(a.value + b.value);
      });

      batch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(values, [3]);

      await tester.pumpAndSettle();
      expect(values, [3, 30]);

      a.dispose();
      b.dispose();
    });
  });
}
