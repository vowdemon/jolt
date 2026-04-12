import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

@defineHook
CounterHook useCounterHook([int initialValue = 0]) =>
    useHook(CounterHook(initialValue: initialValue));

class CounterHook extends SetupHook<CounterHook> {
  CounterHook({required this.initialValue});

  final int initialValue;
  late final Signal<int> _counter;

  void increment() => _counter.value++;
  void decrement() => _counter.value--;
  void reset() => _counter.value = initialValue;
  int get() => _counter.value;
  void set(int value) => _counter.value = value;
  bool get isDisposed => _counter.isDisposed;

  @override
  CounterHook build() {
    _counter = Signal(initialValue);
    return this;
  }

  @override
  void unmount() => _counter.dispose();
}

@defineHook
// ignore: prefer_function_declarations_over_variables
final useCounterHookWithoutClass = ([int initialValue = 0]) {
  final counter = useSignal(initialValue);

  void increment() => counter.value++;
  void decrement() => counter.value--;
  void reset() => counter.value = initialValue;
  int get() => counter.value;
  void set(int value) => counter.value = value;

  return (
    counter: counter,
    increment: increment,
    decrement: decrement,
    reset: reset,
    get: get,
    set: set,
  );
};

void main() {
  group('jolt_setup example hooks', () {
    testWidgets(
        'useCounterHook preserves state methods and disposes on unmount',
        (tester) async {
      late CounterHook counter;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          counter = useCounterHook(3);
          return () => Text('count: ${counter.get()}');
        }),
      ));

      expect(find.text('count: 3'), findsOneWidget);

      counter.increment();
      await tester.pumpAndSettle();
      expect(find.text('count: 4'), findsOneWidget);

      counter.set(8);
      await tester.pumpAndSettle();
      expect(find.text('count: 8'), findsOneWidget);

      counter.reset();
      await tester.pumpAndSettle();
      expect(find.text('count: 3'), findsOneWidget);

      expect(counter.isDisposed, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(counter.isDisposed, isTrue);
    });

    testWidgets(
        'useCounterHookWithoutClass respects initial value, methods, and disposal',
        (tester) async {
      late ({
        Signal<int> counter,
        void Function() increment,
        void Function() decrement,
        void Function() reset,
        int Function() get,
        void Function(int value) set,
      }) counter;

      await tester.pumpWidget(MaterialApp(
        home: SetupBuilder(setup: (context) {
          counter = useCounterHookWithoutClass(5);
          return () => Text('count: ${counter.get()}');
        }),
      ));

      expect(find.text('count: 5'), findsOneWidget);

      counter.increment();
      await tester.pumpAndSettle();
      expect(find.text('count: 6'), findsOneWidget);

      counter.decrement();
      await tester.pumpAndSettle();
      expect(find.text('count: 5'), findsOneWidget);

      counter.set(9);
      await tester.pumpAndSettle();
      expect(find.text('count: 9'), findsOneWidget);

      counter.reset();
      await tester.pumpAndSettle();
      expect(find.text('count: 5'), findsOneWidget);

      expect(counter.counter.isDisposed, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(counter.counter.isDisposed, isTrue);
    });
  });
}
