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

        final counter = useCounterHook(0);

        final doubleCount = useComputed(() => counter.get() * 2);

        final lastCounter = useSignal(0);

        useWatcher(() => doubleCount.value, (_, oldValue) {
          lastCounter.value = oldValue!;
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
                        Text('counter: ${counter.get()}'),
                        Text('doubleCount: ${doubleCount.value}'),
                        Text('lastDoubleCounter: ${lastCounter.value}'),
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
                      onPressed: counter.increment,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      onPressed: counter.decrement,
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            );
      },
    );
  }
}

@defineHook
CounterHook useCounterHook([int initialValue = 0]) =>
    CounterHook(initialValue: initialValue);

class CounterHook extends SetupHook<Signal<int>> {
  final int initialValue;

  CounterHook({required this.initialValue});

  void increment() => state.value++;
  void decrement() => state.value--;
  void reset() => state.value = initialValue;
  int get() => state.value;
  void set(int value) => state.value = value;

  @override
  Signal<int> build() => Signal(initialValue);

  @override
  void unmount() => state.dispose();
}

@defineHook
final useCounterHookWithoutClass = ([int initialValue = 0]) {
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
};
