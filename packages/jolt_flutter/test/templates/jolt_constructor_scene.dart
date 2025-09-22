import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class JoltConstructorScene extends StatefulWidget {
  const JoltConstructorScene({
    super.key,
    required this.rebuildCallback,
    required this.counter,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter;

  @override
  State<JoltConstructorScene> createState() => _JoltConstructorSceneState();
}

class _JoltConstructorSceneState extends State<JoltConstructorScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increment'),
              onPressed: () {
                widget.counter.value++;
              },
              child: Text('Increment'),
            ),
            JoltResource(
              builder: (context, _) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Count: ${widget.counter.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class JoltBuilderScene extends StatefulWidget {
  const JoltBuilderScene({
    super.key,
    required this.rebuildCallback,
    required this.counter,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter;

  @override
  State<JoltBuilderScene> createState() => _JoltBuilderSceneState();
}

class _JoltBuilderSceneState extends State<JoltBuilderScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increment'),
              onPressed: () {
                widget.counter.value++;
              },
              child: Text('Increment'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Builder Count: ${widget.counter.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class JoltWithStoreScene extends StatefulWidget {
  const JoltWithStoreScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<JoltWithStoreScene> createState() => _JoltWithStoreSceneState();
}

class _JoltWithStoreSceneState extends State<JoltWithStoreScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: JoltResource(
          create: (context) {
            final counter = Signal(0);
            return (
              counter: counter,
              increment: () => counter.value++,
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
                Text('Store Count: ${store.counter.value}'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NestedJoltScene extends StatefulWidget {
  const NestedJoltScene({
    super.key,
    required this.rebuildCallback,
    required this.counter1,
    required this.counter2,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter1;
  final Signal<int> counter2;

  @override
  State<NestedJoltScene> createState() => _NestedJoltSceneState();
}

class _NestedJoltSceneState extends State<NestedJoltScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increment1'),
              onPressed: () {
                widget.counter1.value++;
              },
              child: Text('Increment Counter1'),
            ),
            ElevatedButton(
              key: Key('increment2'),
              onPressed: () {
                widget.counter2.value++;
              },
              child: Text('Increment Counter2'),
            ),
            JoltResource(
              builder: (context, _) {
                widget.rebuildCallback(++rebuildCount);
                return Column(
                  children: [
                    Text('Counter1: ${widget.counter1.value}'),
                    JoltResource.builder(
                      builder: (context) {
                        widget.rebuildCallback(++rebuildCount);
                        return Text('Counter2: ${widget.counter2.value}');
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
