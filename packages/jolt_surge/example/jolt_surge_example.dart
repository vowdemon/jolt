import 'package:flutter/material.dart';
import 'package:jolt_surge/jolt_surge.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MainApp());
}

/// Counter Surge - Manages counter state
class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  void reset() => emit(0);
}

/// Brightness Surge - Manages theme brightness
class BrightnessSurge extends Surge<Brightness> {
  BrightnessSurge() : super(Brightness.light);

  void toggle() =>
      emit(state == Brightness.light ? Brightness.dark : Brightness.light);
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SurgeProvider<BrightnessSurge>(
      create: (_) => BrightnessSurge(),
      child: SurgeBuilder<BrightnessSurge, Brightness>(
        builder: (context, brightness, _) {
          return SurgeProvider<CounterSurge>(
            create: (_) => CounterSurge(),
            child: MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: const HomePage(),
            ),
          );
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final counterSurge = context.read<CounterSurge>();
    final brightnessSurge = context.read<BrightnessSurge>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jolt Surge Example'),
        actions: [
          IconButton(
            icon: Icon(
              brightnessSurge.state == Brightness.light
                  ? Icons.brightness_2
                  : Icons.brightness_7,
            ),
            onPressed: brightnessSurge.toggle,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Counter display using SurgeBuilder
            SurgeBuilder<CounterSurge, int>(
              builder: (context, count, surge) {
                return Column(
                  children: [
                    Text(
                      'Counter: $count',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 16),
                    SurgeSelector<CounterSurge, int, int>(
                      selector: (state, surge) => state * 2,
                      builder: (context, doubleValue, surge) => Text(
                        'Double: $doubleValue',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: counterSurge.decrement,
                  heroTag: 'decrement',
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: counterSurge.reset,
                  heroTag: 'reset',
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: counterSurge.increment,
                  heroTag: 'increment',
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Example with SurgeConsumer for side effects
            SurgeConsumer<CounterSurge, int>(
              listener: (context, state, surge) {
                // Side effect: Show snackbar when counter reaches 10
                if (state == 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Counter reached 10!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              listenWhen: (prev, next, _) => next == 10,
              builder: (context, state, surge) {
                return Text(
                  'Last action: ${state >= 10 ? "Reached 10!" : "Counting..."}',
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
