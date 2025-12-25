import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final brightness = Signal(Brightness.light);

  final counter = Signal(0);

  late final doubleCount = Computed(() => counter.value * 2);

  final lastCounter = Signal(0);

  int increment() => counter.value++;

  int decrement() => counter.value--;

  late final Watcher watcher;

  @override
  void initState() {
    super.initState();
    watcher = Watcher(() => doubleCount.value, (_, oldValue) {
      lastCounter.value = oldValue!;
    });
  }

  @override
  void dispose() {
    watcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
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
                Text('counter: ${counter.value}'),
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
              onPressed: increment,
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              onPressed: decrement,
              child: const Icon(Icons.remove),
            ),
          ],
        ),
      ),
    );
  }
}
