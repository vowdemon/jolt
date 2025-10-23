import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class BasicComputedScene extends StatefulWidget {
  const BasicComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.counter,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter;
  final Computed<int> computed;

  @override
  State<BasicComputedScene> createState() => _BasicComputedSceneState();
}

class _BasicComputedSceneState extends State<BasicComputedScene> {
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
                return Text(
                    'Counter: ${widget.counter.value}, Double: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class StringComputedScene extends StatefulWidget {
  const StringComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.name,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<String> name;
  final Computed<String> computed;

  @override
  State<StringComputedScene> createState() => _StringComputedSceneState();
}

class _StringComputedSceneState extends State<StringComputedScene> {
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
                widget.name.value = 'Bob';
              },
              child: Text('Update Name'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Name: ${widget.name.value}, Greeting: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BoolComputedScene extends StatefulWidget {
  const BoolComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.isLoggedIn,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<bool> isLoggedIn;
  final Computed<bool> computed;

  @override
  State<BoolComputedScene> createState() => _BoolComputedSceneState();
}

class _BoolComputedSceneState extends State<BoolComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('login'),
              onPressed: () {
                widget.isLoggedIn.value = true;
              },
              child: Text('Login'),
            ),
            ElevatedButton(
              key: Key('logout'),
              onPressed: () {
                widget.isLoggedIn.value = false;
              },
              child: Text('Logout'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Logged In: ${widget.isLoggedIn.value}, Can Access: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ListComputedScene extends StatefulWidget {
  const ListComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.numbers,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<List<int>> numbers;
  final Computed<int> computed;

  @override
  State<ListComputedScene> createState() => _ListComputedSceneState();
}

class _ListComputedSceneState extends State<ListComputedScene> {
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
                final newList = List<int>.from(widget.numbers.value);
                newList.add(6);
                widget.numbers.value = newList;
              },
              child: Text('Add Number'),
            ),
            ElevatedButton(
              key: Key('remove'),
              onPressed: () {
                final newList = List<int>.from(widget.numbers.value);
                if (newList.isNotEmpty) {
                  newList.removeLast();
                }
                widget.numbers.value = newList;
              },
              child: Text('Remove Number'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Numbers: ${widget.numbers.value}, Sum: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectComputedScene extends StatefulWidget {
  const ObjectComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.user,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<User> user;
  final Computed<String> computed;

  @override
  State<ObjectComputedScene> createState() => _ObjectComputedSceneState();
}

class _ObjectComputedSceneState extends State<ObjectComputedScene> {
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
                widget.user.value = User(name: 'Bob', age: 30);
              },
              child: Text('Update User'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'User: ${widget.user.value}, Info: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConditionalComputedScene extends StatefulWidget {
  const ConditionalComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.score,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> score;
  final Computed<String> computed;

  @override
  State<ConditionalComputedScene> createState() =>
      _ConditionalComputedSceneState();
}

class _ConditionalComputedSceneState extends State<ConditionalComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increase'),
              onPressed: () {
                widget.score.value += 10;
              },
              child: Text('Increase Score'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Score: ${widget.score.value}, Grade: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CachedComputedScene extends StatefulWidget {
  const CachedComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.counter,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> counter;
  final Computed<int> computed;

  @override
  State<CachedComputedScene> createState() => _CachedComputedSceneState();
}

class _CachedComputedSceneState extends State<CachedComputedScene> {
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
                return Text(
                    'Counter: ${widget.counter.value}, Square: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AsyncComputedScene extends StatefulWidget {
  const AsyncComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.input,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<String> input;
  final Computed<String> computed;

  @override
  State<AsyncComputedScene> createState() => _AsyncComputedSceneState();
}

class _AsyncComputedSceneState extends State<AsyncComputedScene> {
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
                widget.input.value = 'world';
              },
              child: Text('Update Input'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Input: ${widget.input.value}, Processed: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WritableComputedScene extends StatefulWidget {
  const WritableComputedScene({
    super.key,
    required this.rebuildCallback,
    required this.firstName,
    required this.lastName,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<String> firstName;
  final Signal<String> lastName;
  final WritableComputed<String> computed;

  @override
  State<WritableComputedScene> createState() => _WritableComputedSceneState();
}

class _WritableComputedSceneState extends State<WritableComputedScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('setFull'),
              onPressed: () {
                widget.computed.value = 'Jane Smith';
              },
              child: Text('Set Full Name'),
            ),
            JoltBuilder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'First: ${widget.firstName.value}, Last: ${widget.lastName.value}, Full: ${widget.computed.value}');
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
