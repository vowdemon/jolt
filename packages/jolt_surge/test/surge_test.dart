import 'package:jolt/jolt.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt_surge/jolt_surge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surges/counter_surge.dart';

void main() {
  group('Surge', () {
    group('observer', () {
      late TestSurgeObserver observer;
      late List<Change> changes;

      setUp(() {
        changes = [];
        observer = TestSurgeObserver(changes);
        SurgeObserver.observer = observer;
      });

      test('onCreate', () {
        final surge = CounterSurge();
        expect(observer.created, contains(surge));
      });

      test('onChange', () {
        final surge = CounterSurge();
        surge.emit(1);
        expect(changes.length, 1);
        final change = changes.first;
        expect(change.currentState, 0);
        expect(change.nextState, 1);
      });

      test('onDispose', () {
        final surge = CounterSurge();
        surge.dispose();
        expect(observer.disposed, contains(surge));
      });
    });

    group('state', () {
      test('initial state', () {
        final surge = CounterSurge();
        expect(surge.state, 0);
      });

      group('emit', () {
        test('should emit the new state', () {
          final surge = CounterSurge();
          surge.emit(1);
          expect(surge.state, 1);
        });

        test('should not emit the same state', () {
          final surge = CounterSurge();
          final states = <int>[];
          Effect(() {
            states.add(surge.state);
          });
          expect(states, equals([0]));
          surge.emit(1);
          expect(states, equals([0, 1]));
          surge.emit(1);
          expect(states, equals([0, 1]));
        });
      });

      group('stream', () {
        test('should emit the new state', () async {
          final surge = CounterSurge();
          final states = <int>[];
          surge.stream.listen((state) {
            states.add(state);
          });

          surge.emit(1);
          surge.emit(1);
          await Future.delayed(const Duration(milliseconds: 1));
          expect(states, equals([1]));
        });
      });

      group('create parameter', () {
        test('should use Signal by default', () {
          final surge = TestSurgeWithCreate(0);
          expect(surge.state, 0);
          expect(surge.raw, isA<Signal<int>>());

          surge.emit(1);
          expect(surge.state, 1);

          // Verify it's reactive
          final states = <int>[];
          Effect(() {
            states.add(surge.state);
          });
          expect(states, equals([1]));

          surge.emit(2);
          expect(states, equals([1, 2]));
        });

        test('should use custom create function when provided', () {
          Signal<int>? customSignal;
          final surge = TestSurgeWithCreate(10, creator: (state) {
            customSignal = Signal(state);
            return customSignal!;
          });

          expect(surge.state, 10);
          expect(surge.raw, equals(customSignal));
          expect(customSignal, isNotNull);

          surge.emit(20);
          expect(surge.state, 20);
          expect(customSignal!.value, 20);

          // Verify it's reactive
          final states = <int>[];
          Effect(() {
            states.add(surge.state);
          });
          expect(states, equals([20]));

          surge.emit(30);
          expect(states, equals([20, 30]));
        });

        test('should work with WritableComputed as create function', () {
          final baseSignal = Signal<int>(0);
          final surge = TestSurgeWithCreate(100, creator: (state) {
            // Initialize baseSignal with the initial state
            baseSignal.value = state;
            return WritableComputed(
              () => baseSignal.value,
              (value) => baseSignal.value = value,
            );
          });

          expect(surge.state, 100);
          expect(baseSignal.value, 100);

          surge.emit(200);
          expect(surge.state, 200);
          expect(baseSignal.value, 200);

          // Verify it's reactive
          final states = <int>[];
          Effect(() {
            states.add(surge.state);
          });
          expect(states, equals([200]));

          surge.emit(300);
          expect(states, equals([200, 300]));

          // Verify changes to base signal reflect in surge
          baseSignal.value = 400;
          expect(surge.state, 400);
          expect(states, equals([200, 300, 400]));
        });

        test('should handle multiple surges with different create functions',
            () {
          final surge1 = TestSurgeWithCreate(1);
          final surge2 =
              TestSurgeWithCreate(2, creator: (state) => Signal(state * 2));

          expect(surge1.state, 1);
          expect(surge2.state, 4); // 2 * 2

          surge1.emit(10);
          surge2.emit(20);

          expect(surge1.state, 10);
          expect(surge2.state, 20);
        });
      });
    });
  });

  group('Widgets', () {
    group('SurgeProvider', () {
      testWidgets('normal constructor provides and disposes on unmount',
          (tester) async {
        CounterSurge? created;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>(
              create: (_) {
                created = CounterSurge();
                return created!;
              },
              child: SurgeBuilder<CounterSurge, int>.full(
                builder: (context, state, surge) => Text('$state'),
              ),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);
        expect(created, isNotNull);
        expect(created!.isDisposed, isFalse);

        // Unmount tree -> should trigger dispose via SurgeProvider(create)
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(created!.isDisposed, isTrue);
      });

      testWidgets('value constructor provides and does not dispose value',
          (tester) async {
        final surge = CounterSurge();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeBuilder<CounterSurge, int>.full(
                builder: (context, state, s) => Text('$state'),
              ),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);
        expect(surge.isDisposed, isFalse);

        // Update and verify builder rebuilds
        surge.emit(1);
        await tester.pump();
        expect(find.text('1'), findsOneWidget);

        // Unmount tree -> value constructor should NOT dispose provided instance
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(surge.isDisposed, isFalse);

        // Explicitly dispose to avoid leaks
        surge.dispose();
      });
    });

    group('SurgeBuilder', () {
      testWidgets('rebuilds when state changes', (tester) async {
        final surge = CounterSurge();
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeBuilder<CounterSurge, int>.full(
                builder: (context, state, s) {
                  buildCount++;
                  return Text('state=$state');
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        surge.emit(1);
        await tester.pump();

        expect(find.text('state=1'), findsOneWidget);
        expect(buildCount, 2);
      });

      testWidgets('buildWhen controls rebuilds', (tester) async {
        final surge = CounterSurge();
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeBuilder<CounterSurge, int>.full(
                buildWhen: (prev, next, s) => next.isEven,
                builder: (context, state, s) {
                  buildCount++;
                  return Text('state=$state');
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        // next=1 -> odd -> no rebuild expected
        surge.emit(1);
        await tester.pump();
        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        // next=2 -> even -> rebuild expected
        surge.emit(2);
        await tester.pump();
        expect(find.text('state=2'), findsOneWidget);
        expect(buildCount, 2);

        // next=3 -> odd -> no rebuild
        surge.emit(3);
        await tester.pump();
        expect(find.text('state=2'), findsOneWidget);
        expect(buildCount, 2);
      });

      testWidgets('follows provider when provided Surge instance changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: s,
              child: SurgeBuilder<CounterSurge, int>.full(
                builder: (context, state, surge) =>
                    Text('id=${surge.hashCode};state=$state'),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        expect(find.text('id=${surge1.hashCode};state=0'), findsOneWidget);

        // Switch provider to new instance; builder should pick up new surge
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=0'), findsOneWidget);

        // Emit on surge2 and verify UI updates accordingly
        surge2.emit(5);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=5'), findsOneWidget);

        // Ensure surge1 changes do not affect UI after switch
        surge1.emit(7);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=5'), findsOneWidget);

        // Cleanup
        surge1.dispose();
        surge2.dispose();
      });
    });

    group('SurgeListener', () {
      testWidgets('invokes listener when state changes', (tester) async {
        final surge = CounterSurge();
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeListener<CounterSurge, int>.full(
                listener: (context, state, s) => received.add(state),
                child: const SizedBox(),
              ),
            ),
          ),
        );

        expect(received, isEmpty);
        surge.emit(1);
        await tester.pump();
        expect(received, [1]);

        surge.emit(2);
        await tester.pump();
        expect(received, [1, 2]);

        surge.dispose();
      });

      testWidgets('listenWhen controls listener invocation', (tester) async {
        final surge = CounterSurge();
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeListener<CounterSurge, int>.full(
                listenWhen: (prev, next, s) => next.isEven,
                listener: (context, state, s) => received.add(state),
                child: const SizedBox(),
              ),
            ),
          ),
        );

        surge.emit(1); // odd -> should not call
        await tester.pump();
        expect(received, isEmpty);

        surge.emit(2); // even -> should call
        await tester.pump();
        expect(received, [2]);

        surge.emit(3); // odd -> no call
        await tester.pump();
        expect(received, [2]);

        surge.emit(4); // even -> call
        await tester.pump();
        expect(received, [2, 4]);

        surge.dispose();
      });

      testWidgets('follows provider when provided Surge changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();
        final received = <String>[];

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: s,
              child: SurgeListener<CounterSurge, int>.full(
                listener: (context, state, surge) =>
                    received.add('id=${surge.hashCode};$state'),
                child: const SizedBox(),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));

        // Emit on surge1 -> listener should receive
        surge1.emit(1);
        await tester.pump();
        expect(received, ['id=${surge1.hashCode};1']);

        // Switch to surge2 provider
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();

        // Emit on surge2 -> listener should receive with surge2 id
        surge2.emit(2);
        await tester.pump();
        expect(
            received, ['id=${surge1.hashCode};1', 'id=${surge2.hashCode};2']);

        // Emit on surge1 after switch -> should NOT be received
        surge1.emit(3);
        await tester.pump();
        expect(
            received, ['id=${surge1.hashCode};1', 'id=${surge2.hashCode};2']);

        surge1.dispose();
        surge2.dispose();
      });
    });

    group('SurgeConsumer', () {
      testWidgets('rebuilds when state changes and calls builder',
          (tester) async {
        final surge = CounterSurge();
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                builder: (context, state, s) {
                  buildCount++;
                  return Text('state=$state');
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        surge.emit(1);
        await tester.pump();
        expect(find.text('state=1'), findsOneWidget);
        expect(buildCount, 2);
      });

      testWidgets('buildWhen controls rebuilds', (tester) async {
        final surge = CounterSurge();
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                buildWhen: (prev, next, s) => next.isEven,
                builder: (context, state, s) {
                  buildCount++;
                  return Text('state=$state');
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        // odd -> no rebuild
        surge.emit(1);
        await tester.pump();
        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        // even -> rebuild
        surge.emit(2);
        await tester.pump();
        expect(find.text('state=2'), findsOneWidget);
        expect(buildCount, 2);
      });

      testWidgets('listener is invoked on state changes', (tester) async {
        final surge = CounterSurge();
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                listener: (context, state, s) => received.add(state),
                builder: (context, state, s) => Text('state=$state'),
              ),
            ),
          ),
        );

        expect(received, isEmpty);
        surge.emit(1);
        await tester.pump();
        expect(received, [1]);

        surge.emit(3);
        await tester.pump();
        expect(received, [1, 3]);
      });

      testWidgets('listenWhen controls listener invocation', (tester) async {
        final surge = CounterSurge();
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                listenWhen: (prev, next, s) => next.isEven,
                listener: (context, state, s) => received.add(state),
                builder: (context, state, s) => Text('state=$state'),
              ),
            ),
          ),
        );

        surge.emit(1); // odd -> no call
        await tester.pump();
        expect(received, isEmpty);

        surge.emit(2); // even -> call
        await tester.pump();
        expect(received, [2]);

        surge.emit(3); // odd -> no call
        await tester.pump();
        expect(received, [2]);

        surge.emit(4); // even -> call
        await tester.pump();
        expect(received, [2, 4]);
      });

      testWidgets('follows provider when provided Surge changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: s,
              child: SurgeConsumer<CounterSurge, int>.full(
                builder: (context, state, surge) =>
                    Text('id=${surge.hashCode};state=$state'),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        expect(find.text('id=${surge1.hashCode};state=0'), findsOneWidget);

        // Switch provider instance
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=0'), findsOneWidget);

        // Emit on surge2 -> should reflect in UI
        surge2.emit(9);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=9'), findsOneWidget);

        // Changes on surge1 should not affect UI after switch
        surge1.emit(7);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=9'), findsOneWidget);

        // Cleanup
        surge1.dispose();
        surge2.dispose();
      });
    });

    group('Direct surge parameter', () {
      testWidgets('SurgeBuilder uses provided surge and ignores outer provider',
          (tester) async {
        final surgeOuter = CounterSurge();
        final surgeInner = CounterSurge();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surgeOuter,
              child: SurgeBuilder<CounterSurge, int>.full(
                surge: surgeInner,
                builder: (context, state, surge) =>
                    Text('id=${surge.hashCode};state=$state'),
              ),
            ),
          ),
        );

        // Should bind to surgeInner
        expect(find.text('id=${surgeInner.hashCode};state=0'), findsOneWidget);

        // Changing inner updates UI
        surgeInner.emit(10);
        await tester.pump();
        expect(find.text('id=${surgeInner.hashCode};state=10'), findsOneWidget);

        // Changing outer has no effect
        surgeOuter.emit(20);
        await tester.pump();
        expect(find.text('id=${surgeInner.hashCode};state=10'), findsOneWidget);

        surgeOuter.dispose();
        surgeInner.dispose();
      });

      testWidgets('SurgeBuilder works with only direct surge (no provider)',
          (tester) async {
        final surge = CounterSurge();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeBuilder<CounterSurge, int>.full(
              surge: surge,
              builder: (context, state, s) => Text('state=$state'),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        surge.emit(1);
        await tester.pump();
        expect(find.text('state=1'), findsOneWidget);

        surge.dispose();
      });

      testWidgets(
          'SurgeListener uses provided surge and ignores outer provider',
          (tester) async {
        final surgeOuter = CounterSurge();
        final surgeInner = CounterSurge();
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surgeOuter,
              child: SurgeListener<CounterSurge, int>.full(
                surge: surgeInner,
                listener: (context, state, s) => received.add(state),
                child: const SizedBox(),
              ),
            ),
          ),
        );

        surgeInner.emit(2); // should trigger
        await tester.pump();
        expect(received, [2]);

        surgeOuter.emit(3); // should not trigger
        await tester.pump();
        expect(received, [2]);

        surgeOuter.dispose();
        surgeInner.dispose();
      });

      testWidgets('SurgeListener works with only direct surge (no provider)',
          (tester) async {
        final surge = CounterSurge();
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeListener<CounterSurge, int>.full(
              surge: surge,
              listener: (context, state, s) => received.add(state),
              child: const SizedBox(),
            ),
          ),
        );

        surge.emit(5);
        await tester.pump();
        expect(received, [5]);

        surge.dispose();
      });

      testWidgets('SurgeConsumer uses provided surge (builder + listener)',
          (tester) async {
        final surgeOuter = CounterSurge();
        final surgeInner = CounterSurge();
        final received = <int>[];
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surgeOuter,
              child: SurgeConsumer<CounterSurge, int>.full(
                surge: surgeInner,
                listener: (context, state, s) => received.add(state),
                builder: (context, state, s) {
                  buildCount++;
                  return Text('id=${s.hashCode};state=$state');
                },
              ),
            ),
          ),
        );

        expect(find.text('id=${surgeInner.hashCode};state=0'), findsOneWidget);
        expect(buildCount, 1);

        surgeInner.emit(6);
        await tester.pump();
        expect(find.text('id=${surgeInner.hashCode};state=6'), findsOneWidget);
        expect(received, [6]);
        expect(buildCount, 2);

        // Changing outer should not affect
        surgeOuter.emit(8);
        await tester.pump();
        expect(find.text('id=${surgeInner.hashCode};state=6'), findsOneWidget);
        expect(received, [6]);
        expect(buildCount, 2);

        surgeOuter.dispose();
        surgeInner.dispose();
      });

      testWidgets('SurgeConsumer works with only direct surge (no provider)',
          (tester) async {
        final surge = CounterSurge();
        final received = <int>[];
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeConsumer<CounterSurge, int>.full(
              surge: surge,
              listener: (context, state, s) => received.add(state),
              builder: (context, state, s) {
                buildCount++;
                return Text('state=$state');
              },
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        expect(received, isEmpty);
        expect(buildCount, 1);

        surge.emit(11);
        await tester.pump();
        expect(find.text('state=11'), findsOneWidget);
        expect(received, [11]);
        expect(buildCount, 2);

        surge.dispose();
      });

      testWidgets('SurgeBuilder follows when provided surge instance changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeBuilder<CounterSurge, int>.full(
              surge: s,
              builder: (context, state, surge) =>
                  Text('id=${surge.hashCode};state=$state'),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        expect(find.text('id=${surge1.hashCode};state=0'), findsOneWidget);

        // Switch surge param to surge2
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=0'), findsOneWidget);

        surge2.emit(3);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=3'), findsOneWidget);

        // Old surge1 should not affect
        surge1.emit(5);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=3'), findsOneWidget);

        surge1.dispose();
        surge2.dispose();
      });

      testWidgets('SurgeListener follows when provided surge instance changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();
        final received = <String>[];

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeListener<CounterSurge, int>.full(
              surge: s,
              listener: (context, state, surge) =>
                  received.add('id=${surge.hashCode};$state'),
              child: const SizedBox(),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        surge1.emit(1);
        await tester.pump();
        expect(received, ['id=${surge1.hashCode};1']);

        // Switch surge param to surge2
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        surge2.emit(2);
        await tester.pump();
        expect(
            received, ['id=${surge1.hashCode};1', 'id=${surge2.hashCode};2']);

        // Emitting on surge1 after switch should not be recorded
        surge1.emit(3);
        await tester.pump();
        expect(
            received, ['id=${surge1.hashCode};1', 'id=${surge2.hashCode};2']);

        surge1.dispose();
        surge2.dispose();
      });

      testWidgets('SurgeConsumer follows when provided surge instance changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();
        final received = <String>[];

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeConsumer<CounterSurge, int>.full(
              surge: s,
              listener: (context, state, surge) =>
                  received.add('id=${surge.hashCode};$state'),
              builder: (context, state, surge) =>
                  Text('id=${surge.hashCode};state=$state'),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        expect(find.text('id=${surge1.hashCode};state=0'), findsOneWidget);
        surge1.emit(4);
        await tester.pump();
        expect(received, ['id=${surge1.hashCode};4']);

        // Switch surge param to surge2
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=0'), findsOneWidget);
        surge2.emit(7);
        await tester.pump();
        expect(
            received, ['id=${surge1.hashCode};4', 'id=${surge2.hashCode};7']);

        // Emitting on surge1 should not change UI or listener now
        surge1.emit(9);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};state=7'), findsOneWidget);
        expect(
            received, ['id=${surge1.hashCode};4', 'id=${surge2.hashCode};7']);

        surge1.dispose();
        surge2.dispose();
      });
    });

    group('SurgeSelector', () {
      testWidgets(
          'builds with selected value and rebuilds when selection changes',
          (tester) async {
        final surge = CounterSurge();
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeSelector<CounterSurge, int, String>.full(
                selector: (state, _) => state.isEven ? 'even' : 'odd',
                builder: (context, selected, s) {
                  buildCount++;
                  return Text('sel=$selected');
                },
              ),
            ),
          ),
        );

        expect(find.text('sel=even'), findsOneWidget);
        expect(buildCount, 1);

        surge.emit(1); // odd -> selection changes
        await tester.pump();
        expect(find.text('sel=odd'), findsOneWidget);
        expect(buildCount, 2);

        surge.dispose();
      });

      testWidgets('does not rebuild when selector returns same value',
          (tester) async {
        final surge = CounterSurge();
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeSelector<CounterSurge, int, bool>.full(
                selector: (state, _) => state.isEven,
                builder: (context, isEven, s) {
                  buildCount++;
                  return Text('even=$isEven');
                },
              ),
            ),
          ),
        );

        expect(find.text('even=true'), findsOneWidget);
        expect(buildCount, 1);

        // state 2 is also even -> selector result stays true -> expect no rebuild
        surge.emit(2);
        await tester.pump();
        expect(find.text('even=true'), findsOneWidget);
        expect(buildCount, 1);

        // change parity -> selector result changes -> expect rebuild
        surge.emit(3);
        await tester.pump();
        expect(find.text('even=false'), findsOneWidget);
        expect(buildCount, 2);

        surge.dispose();
      });

      testWidgets('follows provider when provided Surge instance changes',
          (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: s,
              child: SurgeSelector<CounterSurge, int, String>.full(
                selector: (state, _) => 'id=${s.hashCode};$state',
                builder: (context, selected, surge) => Text(selected),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        expect(find.text('id=${surge1.hashCode};0'), findsOneWidget);

        // Switch provider instance
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};0'), findsOneWidget);

        // Emit on surge2 -> selection should reflect new state
        surge2.emit(4);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};4'), findsOneWidget);

        // Emit on surge1 should not affect after switch
        surge1.emit(5);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};4'), findsOneWidget);

        surge1.dispose();
        surge2.dispose();
      });

      testWidgets('works with Provider.value supplying surge', (tester) async {
        final surge = CounterSurge();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeSelector<CounterSurge, int, int>.full(
                selector: (state, _) => state,
                builder: (context, selected, s) => Text('state=$selected'),
              ),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        surge.emit(2);
        await tester.pump();
        expect(find.text('state=2'), findsOneWidget);

        surge.dispose();
      });

      testWidgets('direct surge provided ignores outer provider',
          (tester) async {
        final surgeOuter = CounterSurge();
        final surgeInner = CounterSurge();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surgeOuter,
              child: SurgeSelector<CounterSurge, int, String>.full(
                surge: surgeInner,
                selector: (state, surge) => 'id=${surge.hashCode};$state',
                builder: (context, selected, s) => Text(selected),
              ),
            ),
          ),
        );

        // Should bind to surgeInner
        expect(find.text('id=${surgeInner.hashCode};0'), findsOneWidget);

        surgeInner.emit(1);
        await tester.pump();
        expect(find.text('id=${surgeInner.hashCode};1'), findsOneWidget);

        // Outer changes should not affect
        surgeOuter.emit(3);
        await tester.pump();
        expect(find.text('id=${surgeInner.hashCode};1'), findsOneWidget);

        surgeOuter.dispose();
        surgeInner.dispose();
      });

      testWidgets('works with only direct surge (no provider)', (tester) async {
        final surge = CounterSurge();

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeSelector<CounterSurge, int, String>.full(
              surge: surge,
              selector: (state, s) => 'state=$state',
              builder: (context, selected, s) => Text(selected),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        surge.emit(2);
        await tester.pump();
        expect(find.text('state=2'), findsOneWidget);

        surge.dispose();
      });

      testWidgets('follows when provided surge param changes', (tester) async {
        final surge1 = CounterSurge();
        final surge2 = CounterSurge();

        Widget buildWithSurge(CounterSurge s) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeSelector<CounterSurge, int, String>.full(
              surge: s,
              selector: (state, surge) => 'id=${surge.hashCode};$state',
              builder: (context, selected, s) => Text(selected),
            ),
          );
        }

        await tester.pumpWidget(buildWithSurge(surge1));
        expect(find.text('id=${surge1.hashCode};0'), findsOneWidget);

        // switch param to surge2
        await tester.pumpWidget(buildWithSurge(surge2));
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};0'), findsOneWidget);

        surge2.emit(6);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};6'), findsOneWidget);

        // surge1 should not affect now
        surge1.emit(7);
        await tester.pump();
        expect(find.text('id=${surge2.hashCode};6'), findsOneWidget);

        surge1.dispose();
        surge2.dispose();
      });
    });

    group('Side effects', () {
      testWidgets('SurgeBuilder does not track external signals',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeBuilder<CounterSurge, int>.full(
                builder: (context, state, s) {
                  final ov = other.value;
                  buildCount++;
                  return Text('state=$state;ov=$ov');
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0;ov=0'), findsOneWidget);
        expect(buildCount, 1);

        // Changing external signal should NOT rebuild
        other.set(1);
        await tester.pump();
        expect(find.text('state=0;ov=0'), findsOneWidget);
        expect(buildCount, 1);

        // Changing surge should rebuild
        surge.emit(1);
        await tester.pump();
        expect(find.text('state=1;ov=1'), findsOneWidget);
        expect(buildCount, 2);

        surge.dispose();
      });

      testWidgets('buildWhen is tracked by external signals when provided',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeBuilder<CounterSurge, int>.full(
                buildWhen: (prev, next, s) {
                  final _ = other.value;
                  return true;
                },
                builder: (context, state, s) {
                  buildCount++;
                  return Text('state=$state');
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 1);

        // Changing external signal should rebuild because buildWhen is evaluated in tracked context
        other.set(1);
        await tester.pump();
        expect(find.text('state=0'), findsOneWidget);
        expect(buildCount, 2);

        // State change also rebuilds
        surge.emit(1);
        await tester.pump();
        expect(find.text('state=1'), findsOneWidget);
        expect(buildCount, 3);

        surge.dispose();
      });

      testWidgets('listener is not tracked by external signals',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                listener: (context, state, s) {
                  final _ = other.value;
                  received.add(state);
                },
                builder: (context, state, s) => Text('state=$state'),
              ),
            ),
          ),
        );

        // Changing external signal should NOT trigger listener
        other.set(1);
        await tester.pump();
        expect(received, isEmpty);

        // State change triggers listener
        surge.emit(1);
        await tester.pump();
        expect(received, [1]);

        surge.dispose();
      });

      testWidgets('listenWhen is tracked by external signals when provided',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        final received = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                listenWhen: (prev, next, s) {
                  final _ = other.value;
                  return true;
                },
                listener: (context, state, s) => received.add(state),
                builder: (context, state, s) => Text('state=$state'),
              ),
            ),
          ),
        );

        // Changing external signal should trigger listener because listenWhen is evaluated in tracked context
        other.set(1);
        await tester.pump();
        expect(received, [0]);

        // State change also triggers listener
        surge.emit(1);
        await tester.pump();
        expect(received, [0, 1]);

        surge.dispose();
      });

      testWidgets('SurgeSelector tracks external signals by default',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeSelector<CounterSurge, int, String>.full(
                selector: (state, s) {
                  // Read external signal; because of untracked, should NOT cause tracking
                  final ov = other.value;
                  return 'state=$state;ov=$ov';
                },
                builder: (context, selected, s) {
                  buildCount++;
                  return Text(selected);
                },
              ),
            ),
          ),
        );

        expect(find.text('state=0;ov=0'), findsOneWidget);
        expect(buildCount, 1);

        // Changing external signal should rebuild (tracked by default)
        other.set(1);
        await tester.pump();
        expect(find.text('state=0;ov=1'), findsOneWidget);
        expect(buildCount, 2);

        // State change should also rebuild
        surge.emit(2);
        await tester.pump();
        expect(find.text('state=2;ov=1'), findsOneWidget);
        expect(buildCount, 3);

        surge.dispose();
      });

      group('Explicit untracked in conditions', () {
        testWidgets('buildWhen with untracked does not track external signals',
            (tester) async {
          final surge = CounterSurge();
          final other = Signal<int>(0);
          var buildCount = 0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeBuilder<CounterSurge, int>.full(
                  buildWhen: (prev, next, s) {
                    final _ = untracked(() => other.value);
                    return true;
                  },
                  builder: (context, state, s) {
                    buildCount++;
                    return Text('state=$state');
                  },
                ),
              ),
            ),
          );

          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);

          // Changing external signal should NOT rebuild due to untracked
          other.set(1);
          await tester.pump();
          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);

          // State change triggers rebuild
          surge.emit(1);
          await tester.pump();
          expect(find.text('state=1'), findsOneWidget);
          expect(buildCount, 2);

          surge.dispose();
        });

        testWidgets('listenWhen with untracked does not track external signals',
            (tester) async {
          final surge = CounterSurge();
          final other = Signal<int>(0);
          final received = <int>[];

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeConsumer<CounterSurge, int>.full(
                  listenWhen: (prev, next, s) {
                    final _ = untracked(() => other.value);
                    return true;
                  },
                  listener: (context, state, s) => received.add(state),
                  builder: (context, state, s) => Text('state=$state'),
                ),
              ),
            ),
          );

          // Changing external signal should NOT trigger listener due to untracked
          other.set(1);
          await tester.pump();
          expect(received, isEmpty);

          // State change triggers listener
          surge.emit(1);
          await tester.pump();
          expect(received, [1]);

          surge.dispose();
        });

        testWidgets('selector with untracked does not track external signals',
            (tester) async {
          final surge = CounterSurge();
          final other = Signal<int>(0);
          var buildCount = 0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeSelector<CounterSurge, int, String>.full(
                  selector: (state, s) {
                    final ov = untracked(() => other.value);
                    return 'state=$state;ov=$ov';
                  },
                  builder: (context, selected, s) {
                    buildCount++;
                    return Text(selected);
                  },
                ),
              ),
            ),
          );

          expect(find.text('state=0;ov=0'), findsOneWidget);
          expect(buildCount, 1);

          // Changing external signal should NOT rebuild due to untracked
          other.set(2);
          await tester.pump();
          expect(find.text('state=0;ov=0'), findsOneWidget);
          expect(buildCount, 1);

          // State change triggers rebuild; selector reads current external value then
          surge.emit(3);
          await tester.pump();
          expect(find.text('state=3;ov=2'), findsOneWidget);
          expect(buildCount, 2);

          surge.dispose();
        });
      });

      testWidgets(
          'Effect disposed on unmount: Consumer does not rebuild or listen',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        final received = <int>[];
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeConsumer<CounterSurge, int>.full(
                listenWhen: (prev, next, s) {
                  other.value; // tracked if alive
                  return true;
                },
                listener: (context, state, s) => received.add(state),
                builder: (context, state, s) {
                  buildCount++;
                  return Text('state=$state');
                },
              ),
            ),
          ),
        );

        expect(buildCount, 1);
        expect(received, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        other.set(1);
        surge.emit(1);
        await tester.pump();

        expect(buildCount, 1);
        expect(received, isEmpty);
      });

      testWidgets('Effect disposed on unmount: Selector does not rebuild',
          (tester) async {
        final surge = CounterSurge();
        final other = Signal<int>(0);
        var buildCount = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SurgeProvider<CounterSurge>.value(
              value: surge,
              child: SurgeSelector<CounterSurge, int, String>.full(
                selector: (state, s) => 'state=$state;ov=${other.value}',
                builder: (context, selected, s) {
                  buildCount++;
                  return Text(selected);
                },
              ),
            ),
          ),
        );

        expect(buildCount, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        other.set(1);
        surge.emit(1);
        await tester.pump();

        expect(buildCount, 1);
      });
    });

    group('Cubit-compatible factory constructors', () {
      group('SurgeBuilder', () {
        testWidgets('factory constructor works without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          var buildCount = 0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeBuilder<CounterSurge, int>(
                  builder: (context, state) {
                    buildCount++;
                    return Text('state=$state');
                  },
                ),
              ),
            ),
          );

          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);

          surge.emit(1);
          await tester.pump();
          expect(find.text('state=1'), findsOneWidget);
          expect(buildCount, 2);

          surge.dispose();
        });

        testWidgets(
            'factory constructor buildWhen works without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          var buildCount = 0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeBuilder<CounterSurge, int>(
                  buildWhen: (prev, next) => next.isEven,
                  builder: (context, state) {
                    buildCount++;
                    return Text('state=$state');
                  },
                ),
              ),
            ),
          );

          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);

          // next=1 -> odd -> no rebuild expected
          surge.emit(1);
          await tester.pump();
          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);

          // next=2 -> even -> rebuild expected
          surge.emit(2);
          await tester.pump();
          expect(find.text('state=2'), findsOneWidget);
          expect(buildCount, 2);

          surge.dispose();
        });
      });

      group('SurgeConsumer', () {
        testWidgets('factory constructor works without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          var buildCount = 0;
          final received = <int>[];

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeConsumer<CounterSurge, int>(
                  builder: (context, state) {
                    buildCount++;
                    return Text('state=$state');
                  },
                  listener: (context, state) => received.add(state),
                ),
              ),
            ),
          );

          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);
          expect(received, isEmpty);

          surge.emit(1);
          await tester.pump();
          expect(find.text('state=1'), findsOneWidget);
          expect(buildCount, 2);
          expect(received, [1]);

          surge.dispose();
        });

        testWidgets(
            'factory constructor buildWhen and listenWhen work without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          var buildCount = 0;
          final received = <int>[];

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeConsumer<CounterSurge, int>(
                  buildWhen: (prev, next) => next.isEven,
                  listenWhen: (prev, next) => next > prev,
                  builder: (context, state) {
                    buildCount++;
                    return Text('state=$state');
                  },
                  listener: (context, state) => received.add(state),
                ),
              ),
            ),
          );

          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);
          expect(received, isEmpty);

          // next=1 -> odd -> no rebuild, but next > prev -> listen
          surge.emit(1);
          await tester.pump();
          expect(find.text('state=0'), findsOneWidget);
          expect(buildCount, 1);
          expect(received, [1]);

          // next=2 -> even -> rebuild, and next > prev -> listen
          surge.emit(2);
          await tester.pump();
          expect(find.text('state=2'), findsOneWidget);
          expect(buildCount, 2);
          expect(received, [1, 2]);

          // next=2 -> same state, no update triggered, no rebuild, no listen
          surge.emit(2);
          await tester.pump();
          expect(find.text('state=2'), findsOneWidget);
          expect(buildCount, 2); // No rebuild because state didn't change
          expect(received, [1, 2]); // No listen because state didn't change

          surge.dispose();
        });
      });

      group('SurgeListener', () {
        testWidgets('factory constructor works without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          final received = <int>[];

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeListener<CounterSurge, int>(
                  listener: (context, state) => received.add(state),
                  child: const SizedBox(),
                ),
              ),
            ),
          );

          expect(received, isEmpty);
          surge.emit(1);
          await tester.pump();
          expect(received, [1]);

          surge.emit(2);
          await tester.pump();
          expect(received, [1, 2]);

          surge.dispose();
        });

        testWidgets(
            'factory constructor listenWhen works without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          final received = <int>[];

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeListener<CounterSurge, int>(
                  listenWhen: (prev, next) => next.isEven,
                  listener: (context, state) => received.add(state),
                  child: const SizedBox(),
                ),
              ),
            ),
          );

          surge.emit(1); // odd -> should not call
          await tester.pump();
          expect(received, isEmpty);

          surge.emit(2); // even -> should call
          await tester.pump();
          expect(received, [2]);

          surge.emit(3); // odd -> no call
          await tester.pump();
          expect(received, [2]);

          surge.emit(4); // even -> call
          await tester.pump();
          expect(received, [2, 4]);

          surge.dispose();
        });
      });

      group('SurgeSelector', () {
        testWidgets('factory constructor works without surge parameter',
            (tester) async {
          final surge = CounterSurge();
          var buildCount = 0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeSelector<CounterSurge, int, String>(
                  selector: (state) => state.isEven ? 'even' : 'odd',
                  builder: (context, selected) {
                    buildCount++;
                    return Text('sel=$selected');
                  },
                ),
              ),
            ),
          );

          expect(find.text('sel=even'), findsOneWidget);
          expect(buildCount, 1);

          surge.emit(1); // odd -> selection changes
          await tester.pump();
          expect(find.text('sel=odd'), findsOneWidget);
          expect(buildCount, 2);

          surge.dispose();
        });

        testWidgets(
            'factory constructor does not rebuild when selector returns same value',
            (tester) async {
          final surge = CounterSurge();
          var buildCount = 0;

          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SurgeProvider<CounterSurge>.value(
                value: surge,
                child: SurgeSelector<CounterSurge, int, bool>(
                  selector: (state) => state.isEven,
                  builder: (context, isEven) {
                    buildCount++;
                    return Text('even=$isEven');
                  },
                ),
              ),
            ),
          );

          expect(find.text('even=true'), findsOneWidget);
          expect(buildCount, 1);

          // state 2 is also even -> selector result stays true -> expect no rebuild
          surge.emit(2);
          await tester.pump();
          expect(find.text('even=true'), findsOneWidget);
          expect(buildCount, 1);

          // change parity -> selector result changes -> expect rebuild
          surge.emit(3);
          await tester.pump();
          expect(find.text('even=false'), findsOneWidget);
          expect(buildCount, 2);

          surge.dispose();
        });
      });
    });
  });
}

class TestSurgeObserver extends SurgeObserver {
  final List<Change> changes;
  final List<dynamic> created = [];
  final List<dynamic> disposed = [];

  TestSurgeObserver(this.changes);

  @override
  void onCreate(surge) {
    super.onCreate(surge);
    created.add(surge);
  }

  @override
  void onChange(surge, Change change) {
    super.onChange(surge, change);
    changes.add(change);
  }

  @override
  void onDispose(surge) {
    super.onDispose(surge);
    disposed.add(surge);
  }
}

class TestSurgeWithCreate extends Surge<int> {
  TestSurgeWithCreate(super.initialState, {super.creator});
}
