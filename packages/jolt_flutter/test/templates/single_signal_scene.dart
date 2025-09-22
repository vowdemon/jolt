import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class BasicSignalScene extends StatefulWidget {
  const BasicSignalScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<BasicSignalScene> createState() => _BasicSignalSceneState();
}

class _BasicSignalSceneState extends State<BasicSignalScene> {
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
                widget.signal.value++;
              },
              child: Text('Increment'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Value: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ListSignalScene extends StatefulWidget {
  const ListSignalScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<List<int>> signal;

  @override
  State<ListSignalScene> createState() => _ListSignalSceneState();
}

class _ListSignalSceneState extends State<ListSignalScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('add'),
              onPressed: () {
                final newList = List<int>.from(widget.signal.value);
                newList.add(4);
                widget.signal.value = newList;
              },
              child: Text('Add'),
            ),
            ElevatedButton(
              key: Key('remove'),
              onPressed: () {
                final newList = List<int>.from(widget.signal.value);
                if (newList.isNotEmpty) {
                  newList.removeLast();
                }
                widget.signal.value = newList;
              },
              child: Text('Remove'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('List: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectSignalScene extends StatefulWidget {
  const ObjectSignalScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<User> signal;

  @override
  State<ObjectSignalScene> createState() => _ObjectSignalSceneState();
}

class _ObjectSignalSceneState extends State<ObjectSignalScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('update'),
              onPressed: () {
                widget.signal.value = User(name: 'Bob', age: 30);
              },
              child: Text('Update'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('User: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NullableSignalScene extends StatefulWidget {
  const NullableSignalScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<String?> signal;

  @override
  State<NullableSignalScene> createState() => _NullableSignalSceneState();
}

class _NullableSignalSceneState extends State<NullableSignalScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('set'),
              onPressed: () {
                widget.signal.value = 'Hello';
              },
              child: Text('Set'),
            ),
            ElevatedButton(
              key: Key('clear'),
              onPressed: () {
                widget.signal.value = null;
              },
              child: Text('Clear'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Value: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DirectAssignmentScene extends StatefulWidget {
  const DirectAssignmentScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<DirectAssignmentScene> createState() => _DirectAssignmentSceneState();
}

class _DirectAssignmentSceneState extends State<DirectAssignmentScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('set5'),
              onPressed: () {
                widget.signal.value = 5;
              },
              child: Text('Set to 5'),
            ),
            ElevatedButton(
              key: Key('set10'),
              onPressed: () {
                widget.signal.value = 10;
              },
              child: Text('Set to 10'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Value: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SameValueScene extends StatefulWidget {
  const SameValueScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<SameValueScene> createState() => _SameValueSceneState();
}

class _SameValueSceneState extends State<SameValueScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('setSame'),
              onPressed: () {
                widget.signal.value = 5; // 相同值
              },
              child: Text('Set Same'),
            ),
            ElevatedButton(
              key: Key('setDifferent'),
              onPressed: () {
                widget.signal.value = 10; // 不同值
              },
              child: Text('Set Different'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Value: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MultiListenerScene extends StatefulWidget {
  const MultiListenerScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<MultiListenerScene> createState() => _MultiListenerSceneState();
}

class _MultiListenerSceneState extends State<MultiListenerScene> {
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
                widget.signal.value++;
              },
              child: Text('Increment'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Listener1: ${widget.signal.value}');
              },
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Listener2: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class User {
  final String name;
  final int age;

  User({required this.name, required this.age});

  @override
  String toString() => '$name, $age';
}
