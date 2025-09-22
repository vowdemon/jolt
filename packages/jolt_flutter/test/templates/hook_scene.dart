import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class BasicHookScene extends StatefulWidget {
  const BasicHookScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<BasicHookScene> createState() => _BasicHookSceneState();
}

class _BasicHookSceneState extends State<BasicHookScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final count = Signal(0);
            return (
              count: count,
              increment: () => count.value++,
            );
          },
          builder: (context, store) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('increment'),
                  onPressed: store.increment,
                  child: Text('Increment'),
                ),
                Text('Count: ${store.count.value}'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MultiSignalHookScene extends StatefulWidget {
  const MultiSignalHookScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<MultiSignalHookScene> createState() => _MultiSignalHookSceneState();
}

class _MultiSignalHookSceneState extends State<MultiSignalHookScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final signalA = Signal(0);
            final signalB = Signal(0);
            return (
              signalA: signalA,
              signalB: signalB,
              incrementA: () => signalA.value++,
              incrementB: () => signalB.value++,
            );
          },
          builder: (context, store) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('incrementA'),
                  onPressed: store.incrementA,
                  child: Text('Increment A'),
                ),
                ElevatedButton(
                  key: Key('incrementB'),
                  onPressed: store.incrementB,
                  child: Text('Increment B'),
                ),
                Text('A: ${store.signalA.value}, B: ${store.signalB.value}'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SignalComputedHookScene extends StatefulWidget {
  const SignalComputedHookScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<SignalComputedHookScene> createState() =>
      _SignalComputedHookSceneState();
}

class _SignalComputedHookSceneState extends State<SignalComputedHookScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final count = Signal(0);
            final doubleCount = Computed(() => count.value * 2);
            return (
              count: count,
              doubleCount: doubleCount,
              increment: () => count.value++,
            );
          },
          builder: (context, store) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('increment'),
                  onPressed: store.increment,
                  child: Text('Increment'),
                ),
                JoltResource.builder(builder: (context) {
                  widget.rebuildCallback(++rebuildCount);
                  return Text(
                      'Count: ${store.count.value}, Double: ${store.doubleCount.value}');
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ComplexHookScene extends StatefulWidget {
  const ComplexHookScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<ComplexHookScene> createState() => _ComplexHookSceneState();
}

class _ComplexHookSceneState extends State<ComplexHookScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final valueA = Signal(0);
            final valueB = Signal(0);
            final sum = Computed(() => valueA.value + valueB.value);
            final product = Computed(() => valueA.value * valueB.value);
            final average = Computed(() {
              final total = valueA.value + valueB.value;
              return total > 0 ? total / 2.0 : 0.0;
            });

            return (
              valueA: valueA,
              valueB: valueB,
              sum: sum,
              product: product,
              average: average,
              setA: () => valueA.value = 5,
              setB: () => valueB.value = 3,
            );
          },
          builder: (context, store) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('setA'),
                  onPressed: store.setA,
                  child: Text('Set A to 5'),
                ),
                ElevatedButton(
                  key: Key('setB'),
                  onPressed: store.setB,
                  child: Text('Set B to 3'),
                ),
                JoltResource.builder(builder: (context) {
                  widget.rebuildCallback(++rebuildCount);
                  return Text(
                      'Sum: ${store.sum.value}, Product: ${store.product.value}, Average: ${store.average.value}');
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NestedHookScene extends StatefulWidget {
  const NestedHookScene({
    super.key,
    required this.rebuildCallback,
    required this.runHookCallback,
  });

  final ValueChanged<int> rebuildCallback;
  final ValueChanged<int> runHookCallback;

  @override
  State<NestedHookScene> createState() => _NestedHookSceneState();
}

class _NestedHookSceneState extends State<NestedHookScene> {
  int rebuildCount = 0;
  int runHookCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            widget.runHookCallback(++runHookCount);
            final outerCount = Signal(0);
            return (
              outerCount: outerCount,
              incrementOuter: () => outerCount.value++,
            );
          },
          builder: (context, outerStore) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('incrementOuter'),
                  onPressed: outerStore.incrementOuter,
                  child: Text('Increment Outer'),
                ),
                Text('Outer: ${outerStore.outerCount.value}'),
                JoltResource(
                  create: (context) {
                    widget.runHookCallback(++runHookCount);
                    final innerCount = Signal(0);
                    return (
                      innerCount: innerCount,
                      incrementInner: () => innerCount.value++,
                    );
                  },
                  builder: (context, innerStore) {
                    widget.rebuildCallback(++rebuildCount);
                    return Column(
                      children: [
                        ElevatedButton(
                          key: Key('incrementInner'),
                          onPressed: innerStore.incrementInner,
                          child: Text('Increment Inner'),
                        ),
                        Text('Inner: ${innerStore.innerCount.value}'),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ConditionalHookScene extends StatefulWidget {
  const ConditionalHookScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<ConditionalHookScene> createState() => _ConditionalHookSceneState();
}

class _ConditionalHookSceneState extends State<ConditionalHookScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final show = Signal(false);
            return (
              show: show,
              toggle: () => show.value = !show.value,
            );
          },
          builder: (context, store) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('toggle'),
                  onPressed: store.toggle,
                  child: Text('Toggle'),
                ),
                Text('Show: ${store.show.value}'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AsyncHookScene extends StatefulWidget {
  const AsyncHookScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<AsyncHookScene> createState() => _AsyncHookSceneState();
}

class _AsyncHookSceneState extends State<AsyncHookScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    widget.rebuildCallback(++rebuildCount);

    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final loading = Signal(false);
            final data = Signal<String?>(null);

            Future<void> loadData() async {
              loading.value = true;
              await Future.delayed(Duration(milliseconds: 100));
              data.value = 'Hello World';
              loading.value = false;
            }

            return (
              loading: loading,
              data: data,
              load: loadData,
            );
          },
          builder: (context, store) {
            widget.rebuildCallback(++rebuildCount);
            return Column(
              children: [
                ElevatedButton(
                  key: Key('load'),
                  onPressed: store.load,
                  child: Text('Load Data'),
                ),
                Text(
                    'Loading: ${store.loading.value}, Data: ${store.data.value}'),
              ],
            );
          },
        ),
      ),
    );
  }
}
