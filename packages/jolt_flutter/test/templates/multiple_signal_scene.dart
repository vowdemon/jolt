import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class IndependentSignalsScene extends StatefulWidget {
  const IndependentSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.signalA,
    required this.signalB,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signalA;
  final Signal<int> signalB;

  @override
  State<IndependentSignalsScene> createState() =>
      _IndependentSignalsSceneState();
}

class _IndependentSignalsSceneState extends State<IndependentSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementA'),
              onPressed: () {
                widget.signalA.value++;
              },
              child: Text('Increment A'),
            ),
            ElevatedButton(
              key: Key('incrementB'),
              onPressed: () {
                widget.signalB.value++;
              },
              child: Text('Increment B'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'A: ${widget.signalA.value}, B: ${widget.signalB.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SimultaneousSignalsScene extends StatefulWidget {
  const SimultaneousSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.signalA,
    required this.signalB,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signalA;
  final Signal<int> signalB;

  @override
  State<SimultaneousSignalsScene> createState() =>
      _SimultaneousSignalsSceneState();
}

class _SimultaneousSignalsSceneState extends State<SimultaneousSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementBoth'),
              onPressed: () {
                widget.signalA.value++;
                widget.signalB.value++;
              },
              child: Text('Increment Both'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'A: ${widget.signalA.value}, B: ${widget.signalB.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChainedSignalsScene extends StatefulWidget {
  const ChainedSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.signalA,
    required this.signalB,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signalA;
  final Signal<int> signalB;

  @override
  State<ChainedSignalsScene> createState() => _ChainedSignalsSceneState();
}

class _ChainedSignalsSceneState extends State<ChainedSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementA'),
              onPressed: () {
                widget.signalA.value++;
                widget.signalB.value = widget.signalA.value;
              },
              child: Text('Increment A (Chain)'),
            ),
            JoltResource.builder(
              builder: (context) {
                final signalC = widget.signalA.value + widget.signalB.value;
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'A: ${widget.signalA.value}, B: ${widget.signalB.value}, C: $signalC');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConditionalSignalsScene extends StatefulWidget {
  const ConditionalSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.condition,
    required this.valueA,
    required this.valueB,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<bool> condition;
  final Signal<int> valueA;
  final Signal<int> valueB;

  @override
  State<ConditionalSignalsScene> createState() =>
      _ConditionalSignalsSceneState();
}

class _ConditionalSignalsSceneState extends State<ConditionalSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('toggle'),
              onPressed: () {
                widget.condition.value = !widget.condition.value;
              },
              child: Text('Toggle Condition'),
            ),
            ElevatedButton(
              key: Key('incrementA'),
              onPressed: () {
                widget.valueA.value++;
              },
              child: Text('Increment A'),
            ),
            ElevatedButton(
              key: Key('incrementB'),
              onPressed: () {
                widget.valueB.value++;
              },
              child: Text('Increment B'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                final value = widget.condition.value
                    ? widget.valueB.value
                    : widget.valueA.value;
                return Text(
                    'Condition: ${widget.condition.value}, Value: $value');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ArraySignalsScene extends StatefulWidget {
  const ArraySignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.listA,
    required this.listB,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<List<int>> listA;
  final Signal<List<int>> listB;

  @override
  State<ArraySignalsScene> createState() => _ArraySignalsSceneState();
}

class _ArraySignalsSceneState extends State<ArraySignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('updateA'),
              onPressed: () {
                final newList = List<int>.from(widget.listA.value);
                newList.add(4);
                widget.listA.value = newList;
              },
              child: Text('Update List A'),
            ),
            ElevatedButton(
              key: Key('updateB'),
              onPressed: () {
                final newList = List<int>.from(widget.listB.value);
                newList.add(7);
                widget.listB.value = newList;
              },
              child: Text('Update List B'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'ListA: ${widget.listA.value}, ListB: ${widget.listB.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectSignalsScene extends StatefulWidget {
  const ObjectSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.user,
    required this.settings,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<User> user;
  final Signal<Settings> settings;

  @override
  State<ObjectSignalsScene> createState() => _ObjectSignalsSceneState();
}

class _ObjectSignalsSceneState extends State<ObjectSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('updateUser'),
              onPressed: () {
                widget.user.value = User(name: 'Bob', age: 30);
              },
              child: Text('Update User'),
            ),
            ElevatedButton(
              key: Key('updateSettings'),
              onPressed: () {
                widget.settings.value = Settings(theme: 'dark', language: 'zh');
              },
              child: Text('Update Settings'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Column(
                  children: [
                    Text('User: ${widget.user.value}'),
                    Text('Settings: ${widget.settings.value}'),
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

class PerformanceSignalsScene extends StatefulWidget {
  const PerformanceSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.signals,
  });

  final ValueChanged<int> rebuildCallback;
  final List<Signal<int>> signals;

  @override
  State<PerformanceSignalsScene> createState() =>
      _PerformanceSignalsSceneState();
}

class _PerformanceSignalsSceneState extends State<PerformanceSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('updateMultiple'),
              onPressed: () {
                for (int i = 0; i < widget.signals.length; i++) {
                  widget.signals[i].value = i + 1;
                }
              },
              child: Text('Update Multiple'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                final sum = widget.signals
                    .fold<int>(0, (sum, signal) => sum + signal.value);
                return Text('Sum: $sum');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorHandlingSignalsScene extends StatefulWidget {
  const ErrorHandlingSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.signalA,
    required this.signalB,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signalA;
  final Signal<int> signalB;

  @override
  State<ErrorHandlingSignalsScene> createState() =>
      _ErrorHandlingSignalsSceneState();
}

class _ErrorHandlingSignalsSceneState extends State<ErrorHandlingSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementA'),
              onPressed: () {
                widget.signalA.value++;
              },
              child: Text('Increment A'),
            ),
            ElevatedButton(
              key: Key('setBToZero'),
              onPressed: () {
                widget.signalB.value = 0;
              },
              child: Text('Set B to 0'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                String result;
                try {
                  result =
                      (widget.signalA.value / widget.signalB.value).toString();
                } catch (e) {
                  result = 'Error';
                }
                return Text(
                    'A: ${widget.signalA.value}, B: ${widget.signalB.value}, Result: $result');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AsyncSignalsScene extends StatefulWidget {
  const AsyncSignalsScene({
    super.key,
    required this.rebuildCallback,
    required this.loading,
    required this.data,
    required this.error,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<bool> loading;
  final Signal<String?> data;
  final Signal<String?> error;

  @override
  State<AsyncSignalsScene> createState() => _AsyncSignalsSceneState();
}

class _AsyncSignalsSceneState extends State<AsyncSignalsScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('load'),
              onPressed: () async {
                widget.loading.value = true;
                widget.error.value = null;

                try {
                  await Future.delayed(Duration(milliseconds: 100));
                  widget.data.value = 'Success';
                } catch (e) {
                  widget.error.value = e.toString();
                } finally {
                  widget.loading.value = false;
                }
              },
              child: Text('Load Data'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Loading: ${widget.loading.value}, Data: ${widget.data.value}, Error: ${widget.error.value}');
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

class Settings {
  final String theme;
  final String language;

  Settings({required this.theme, required this.language});

  @override
  String toString() => '$theme, $language';
}
