// ignore_for_file: deprecated_export_use

import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  final Brightness brightness = Brightness.light;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return JoltProvider(
      create: (context) {
        final brightness = Signal(Brightness.light);
        final counter = Signal(0);
        final doubleCount = Computed(() => counter.value * 2);

        int increment() => counter.value++;
        int decrement() => counter.value--;

        return (
          brightness: brightness,
          counter: counter,
          doubleCount: doubleCount,
          increment: increment,
          decrement: decrement,
        );
      },
      builder: (context, store) {
        return MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: store.brightness.value == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: Scaffold(
            body: DefaultTextStyle(
              style: textTheme.displayMedium!.copyWith(
                color: store.brightness.value == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              child: Center(
                child: JoltProvider(
                  create: (context) {
                    final lastCounter = Signal(0);

                    Watcher(() => store.doubleCount.value, (_, oldValue) {
                      lastCounter.value = oldValue!;
                    });
                    return lastCounter;
                  },
                  builder: (context, lastCounter) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Text('counter: ${store.counter.value}'),
                        Text('doubleCount: ${store.doubleCount.value}'),
                        Text('lastDoubleCounter: ${lastCounter.value}'),
                      ],
                    );
                  },
                ),
              ),
            ),
            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                FloatingActionButton(
                  onPressed: () {
                    store.brightness.value =
                        store.brightness.value == Brightness.light
                            ? Brightness.dark
                            : Brightness.light;
                  },
                  child: store.brightness.value == Brightness.light
                      ? Icon(Icons.brightness_2)
                      : Icon(Icons.brightness_7),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: store.increment,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: store.decrement,
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
