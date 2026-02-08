import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/extension.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  group('useUntil', () {
    testWidgets('returns Until that completes when predicate is met',
        (tester) async {
      late Until<int> until;
      late Signal<int> count;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          count = useSignal(0);
          until = useUntil(count, (v) => v >= 5);
          return () => Text('Count: ${count.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(until.isCompleted, isFalse);
      expect(until.isCancelled, isFalse);

      count.value = 5;
      await tester.pumpAndSettle();

      expect(await until, 5);
      expect(until.isCompleted, isTrue);
    });

    testWidgets('completes immediately when condition already met',
        (tester) async {
      late Until<int> until;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final count = useSignal(10);
          until = useUntil(count, (v) => v >= 5);
          return () => Text('Count: ${count.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(await until, 10);
      expect(until.isCompleted, isTrue);
    });

    testWidgets('cancel on unmount', (tester) async {
      late Until<int> until;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final count = useSignal(0);
          until = useUntil(count, (v) => v >= 100);
          return () => Text('Count: ${count.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(until.isCancelled, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(until.isCancelled, isTrue);
      expect(until.isCompleted, isFalse);
    });

    testWidgets('returns same Until instance across rebuilds', (tester) async {
      Until<int>? fromSetup;
      Until<int>? fromBuild;
      var setupCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _RebuildTestWidget(
          onRebuild: () {},
          child: SetupBuilder(setup: (context) {
            setupCount++;
            final count = useSignal(0);
            fromSetup = useUntil(count, (v) => v >= 5);
            return () {
              fromBuild = fromSetup;
              return Text('${count.value}');
            };
          }),
        ),
      ));
      await tester.pumpAndSettle();

      expect(setupCount, 1);
      expect(identical(fromSetup, fromBuild), isTrue);

      final state = tester
          .state<_RebuildTestWidgetState>(find.byType(_RebuildTestWidget));
      state.triggerRebuild();
      await tester.pump();

      expect(setupCount, 1);
      expect(identical(fromSetup, fromBuild), isTrue);
    });

    testWidgets('cancels old Until and creates new one on hot reload',
        (tester) async {
      late Until<int> oldUntil;
      late Signal<int> count;
      final oldThenFired = <bool>[false];

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          count = useSignal(0);
          final until = useUntil(count, (v) => v >= 5);
          oldUntil = until;
          onMounted(() {
            oldUntil.then((_) => oldThenFired[0] = true);
          });
          return () => Text('${count.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(oldUntil.isCancelled, isFalse);

      final rootElement = tester.binding.rootElement;
      assert(rootElement != null, 'Root element must exist');
      rootElement!.owner!.reassemble(rootElement);
      await tester.pump();

      expect(oldUntil.isCancelled, isTrue);

      count.value = 5;
      await tester.pumpAndSettle();

      expect(oldThenFired[0], isFalse,
          reason: 'Old Until .then must not fire after reassemble');
    });
  });

  group('useUntil.when', () {
    testWidgets('completes when source equals value', (tester) async {
      late Until<String> until;
      late Signal<String> status;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          status = useSignal('loading');
          until = useUntil.when(status, 'ready');
          return () => Text(status.value);
        }),
      ));
      await tester.pumpAndSettle();

      expect(until.isCompleted, isFalse);
      status.value = 'ready';
      await tester.pumpAndSettle();

      expect(await until, 'ready');
      expect(until.isCompleted, isTrue);
    });

    testWidgets('completes immediately when already equal', (tester) async {
      late Until<int> until;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final signal = useSignal(42);
          until = useUntil.when(signal, 42);
          return () => Text('${signal.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(await until, 42);
      expect(until.isCompleted, isTrue);
    });

    testWidgets('cancel on unmount', (tester) async {
      late Until<String> until;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final status = useSignal('loading');
          until = useUntil.when(status, 'ready');
          return () => Text(status.value);
        }),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(until.isCancelled, isTrue);
    });
  });

  group('useUntil.changed', () {
    testWidgets('completes when source value changes', (tester) async {
      late Until<int> until;
      late Signal<int> count;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          count = useSignal(1);
          until = useUntil.changed(count);
          return () => Text('${count.value}');
        }),
      ));
      await tester.pumpAndSettle();

      expect(until.isCompleted, isFalse);
      count.value = 2;
      await tester.pumpAndSettle();

      expect(await until, 2);
      expect(until.isCompleted, isTrue);
    });

    testWidgets('cancel on unmount', (tester) async {
      late Until<int> until;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          final count = useSignal(0);
          until = useUntil.changed(count);
          return () => Text('${count.value}');
        }),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(until.isCancelled, isTrue);
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
