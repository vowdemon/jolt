import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SetupBuilder(
      setup: (context) {
        final brightness = useSignal(Brightness.light);
        final composedCounter = useCounterHookWithoutClass(0);
        final extractedComposedCounter = useCounterHookWithoutClass2(10);
        final classCounter = useCounterHookClass(20);
        final extractedClassCounter = useCounterHookClass2(30);
        final doubledCount = useComputed(() => classCounter.get() * 2);
        final previousDoubledCount = useSignal(0);

        useWatcher(() => doubledCount.value, (_, oldValue) {
          previousDoubledCount.value = oldValue ?? 0;
        });

        return () => MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: brightness.value == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: Scaffold(
                body: DefaultTextStyle(
                  style: textTheme.displayMedium!.copyWith(
                    color: brightness.value == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Text('Composition hook: ${composedCounter.get()}'),
                        Text(
                          'Composition hook from extracted logic: '
                          '${extractedComposedCounter.get()}',
                        ),
                        Text('Class hook: ${classCounter.get()}'),
                        Text(
                          'Class hook from extracted class: '
                          '${extractedClassCounter.get()}',
                        ),
                        Text('Doubled class hook count: ${doubledCount.value}'),
                        Text(
                            'Previous doubled count: ${previousDoubledCount.value}'),
                      ],
                    ),
                  ),
                ),
                floatingActionButton: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    FloatingActionButton(
                      onPressed: () {
                        brightness.value = brightness.value == Brightness.light
                            ? Brightness.dark
                            : Brightness.light;
                      },
                      child: brightness.value == Brightness.light
                          ? Icon(Icons.brightness_2)
                          : Icon(Icons.brightness_7),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: composedCounter.increment,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: composedCounter.decrement,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: extractedComposedCounter.increment,
                      child: const Icon(Icons.exposure_plus_1),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: extractedComposedCounter.decrement,
                      child: const Icon(Icons.exposure_neg_1),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: classCounter.increment,
                      child: const Icon(Icons.filter_1),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: extractedClassCounter.increment,
                      child: const Icon(Icons.filter_2),
                    ),
                  ],
                ),
              ),
            );
      },
    );
  }
}

class Counter {
  Counter({required this.initialValue}) : raw = Signal(initialValue);
  final int initialValue;
  final Signal<int> raw;
  void increment() => raw.value++;
  void decrement() => raw.value--;
  void reset() => raw.value = initialValue;
  int get() => raw.value;
  void set(int value) => raw.value = value;
  void dispose() => raw.dispose();
}

typedef CounterCompositionHook = ({
  Signal<int> counter,
  void Function() increment,
  void Function() decrement,
  void Function() reset,
  int Function() get,
  void Function(int value) set,
});

/// 1. Composition hook.
@defineHook
CounterCompositionHook useCounterHookWithoutClass([int initialValue = 0]) {
  final counter = useSignal(0);
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
}

/// 2. Composition hook generated from existing logic.
@defineHook
Counter useCounterHookWithoutClass2([int initialValue = 0]) {
  final counter = useMemoized(
    () => Counter(initialValue: initialValue),
    (counter) => counter.dispose(),
  );

  return counter;
}

/// 3. Class-based hook.
@defineHook
CounterHook useCounterHookClass([int initialValue = 0]) =>
    useHook(CounterHook(initialValue: initialValue));

class CounterHook extends SetupHook<CounterHook> {
  final int initialValue;

  CounterHook({required this.initialValue});

  late Signal<int> signal;
  void increment() => signal.value++;
  void decrement() => signal.value--;
  void reset() => signal.value = initialValue;
  int get() => signal.value;
  void set(int value) => signal.value = value;

  @override
  CounterHook build() {
    signal = Signal(initialValue);
    return this;
  }

  @override
  void unmount() => signal.dispose();
}

/// 4. Class-based hook generated from an existing class.
@defineHook
Counter useCounterHookClass2([int initialValue = 0]) =>
    useHook(CounterHook2(initialValue: initialValue));

class CounterHook2 extends SetupHook<Counter> {
  final int initialValue;
  CounterHook2({required this.initialValue});
  @override
  Counter build() => Counter(initialValue: initialValue);

  @override
  void unmount() => state.dispose();
}
