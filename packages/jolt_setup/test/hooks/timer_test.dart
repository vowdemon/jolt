import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useTimer (one-shot)', () {
    testWidgets('creates timer and returns TimerHook', (tester) async {
      TimerHook? hook;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          hook = useTimer(const Duration(seconds: 1), () {});
          return () => const SizedBox();
        }),
      ));

      expect(hook, isNotNull);
      expect(hook!.isActive, isTrue);
    });

    testWidgets('callback is invoked after duration when immediately is true',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final invoked = useSignal(false);
          useTimer(const Duration(milliseconds: 50), () {
            invoked.value = true;
          }, immediately: true);
          return () => Text(invoked.value ? 'done' : 'waiting');
        }),
      ));

      expect(find.text('waiting'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('callback is invoked after duration when immediately is false',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final invoked = useSignal(false);
          useTimer(const Duration(milliseconds: 50), () {
            invoked.value = true;
          }, immediately: false);
          return () => Text(invoked.value ? 'done' : 'waiting');
        }),
      ));

      expect(find.text('waiting'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('cancel on unmount', (tester) async {
      var invoked = false;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useTimer(const Duration(seconds: 10), () {
            invoked = true;
          });
          return () => const SizedBox();
        }),
      ));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 11));
      expect(invoked, isFalse,
          reason: 'Timer should be cancelled on unmount, callback not run');
    });

    testWidgets('maintains same hook instance across rebuilds', (tester) async {
      TimerHook? fromSetup;
      TimerHook? fromBuild;
      var setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {},
          child: SetupBuilder(setup: (context) {
            setupCount++;
            fromSetup = useTimer(const Duration(seconds: 1), () {});
            return () {
              fromBuild = fromSetup;
              return SizedBox(key: ValueKey(fromSetup.hashCode));
            };
          }),
        ),
      ));

      expect(setupCount, 1);
      expect(identical(fromSetup, fromBuild), isTrue);

      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1);
      expect(identical(fromSetup, fromBuild), isTrue);
    });
  });

  group('useTimer.periodic', () {
    testWidgets('creates periodic timer and returns TimerHook', (tester) async {
      TimerHook? hook;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          hook = useTimer.periodic(const Duration(seconds: 1), (_) {});
          return () => const SizedBox();
        }),
      ));

      expect(hook, isNotNull);
      expect(hook!.isActive, isTrue);
    });

    testWidgets('callback is invoked repeatedly', (tester) async {
      const tickKey = Key('tick');
      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final tickCount = useSignal(0);
          useTimer.periodic(const Duration(milliseconds: 50), (_) {
            tickCount.value++;
          }, immediately: true);
          return () => Text('${tickCount.value}', key: tickKey);
        }),
      ));

      expect(find.byKey(tickKey), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 150));
      final text = (tester.widget<Text>(find.byKey(tickKey))).data;
      final count = int.tryParse(text ?? '') ?? 0;
      expect(count, greaterThanOrEqualTo(2),
          reason: 'Periodic timer should have fired at least twice in 150ms');
    });

    testWidgets('cancel on unmount', (tester) async {
      final ticksFromOutside = ValueNotifier<int>(0);

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          useTimer.periodic(const Duration(milliseconds: 50), (_) {
            ticksFromOutside.value++;
          });
          return () => Text('${ticksFromOutside.value}');
        }),
      ));

      await tester.pump(const Duration(milliseconds: 20));
      final countBeforeUnmount = ticksFromOutside.value;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 200));
      expect(ticksFromOutside.value, countBeforeUnmount,
          reason: 'Periodic timer should be cancelled on unmount');
    });

    testWidgets('tick increments', (tester) async {
      TimerHook? hook;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          hook = useTimer.periodic(
            const Duration(milliseconds: 40),
            (_) {},
            immediately: true,
          );
          return () => Text('tick:${hook?.tick ?? 0}');
        }),
      ));

      expect(find.textContaining('tick:'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(hook!.tick, greaterThanOrEqualTo(2));
    });
  });
}

class _RebuildTestWidget extends StatefulWidget {
  const _RebuildTestWidget({
    required this.child,
    required this.onRebuild,
  });

  final Widget child;
  final VoidCallback onRebuild;

  @override
  State<_RebuildTestWidget> createState() => _RebuildTestWidgetState();
}

class _RebuildTestWidgetState extends State<_RebuildTestWidget> {
  void triggerRebuild() {
    setState(() {
      widget.onRebuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
