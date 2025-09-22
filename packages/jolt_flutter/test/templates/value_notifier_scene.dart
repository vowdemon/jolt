import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class BasicValueNotifierScene extends StatefulWidget {
  const BasicValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<BasicValueNotifierScene> createState() =>
      _BasicValueNotifierSceneState();
}

class _BasicValueNotifierSceneState extends State<BasicValueNotifierScene> {
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

class MultiListenerValueNotifierScene extends StatefulWidget {
  const MultiListenerValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<MultiListenerValueNotifierScene> createState() =>
      _MultiListenerValueNotifierSceneState();
}

class _MultiListenerValueNotifierSceneState
    extends State<MultiListenerValueNotifierScene> {
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

class ListenerManagementScene extends StatefulWidget {
  const ListenerManagementScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<ListenerManagementScene> createState() =>
      _ListenerManagementSceneState();
}

class _ListenerManagementSceneState extends State<ListenerManagementScene> {
  int rebuildCount = 0;
  bool isListening = true;

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
            ElevatedButton(
              key: Key('removeListener'),
              onPressed: () {
                isListening = false;
                setState(() {});
              },
              child: Text('Remove Listener'),
            ),
            if (isListening)
              JoltResource.builder(
                builder: (context) {
                  widget.rebuildCallback(++rebuildCount);
                  return Text('Value: ${widget.signal.value}');
                },
              )
            else
              Text('Value: ${widget.signal.value}'),
          ],
        ),
      ),
    );
  }
}

class ComputedValueNotifierScene extends StatefulWidget {
  const ComputedValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;
  final Computed<int> computed;

  @override
  State<ComputedValueNotifierScene> createState() =>
      _ComputedValueNotifierSceneState();
}

class _ComputedValueNotifierSceneState
    extends State<ComputedValueNotifierScene> {
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
                return Text(
                    'Counter: ${widget.signal.value}, Double: ${widget.computed.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedBuilderScene extends StatefulWidget {
  const AnimatedBuilderScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<AnimatedBuilderScene> createState() => _AnimatedBuilderSceneState();
}

class _AnimatedBuilderSceneState extends State<AnimatedBuilderScene> {
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
            AnimatedBuilder(
              animation: widget.signal,
              builder: (context, child) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Animated Value: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ValueListenableBuilderScene extends StatefulWidget {
  const ValueListenableBuilderScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<ValueListenableBuilderScene> createState() =>
      _ValueListenableBuilderSceneState();
}

class _ValueListenableBuilderSceneState
    extends State<ValueListenableBuilderScene> {
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
            ValueListenableBuilder<int>(
              valueListenable: widget.signal,
              builder: (context, value, child) {
                widget.rebuildCallback(++rebuildCount);
                return Text('Listenable Value: $value');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LifecycleValueNotifierScene extends StatefulWidget {
  const LifecycleValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<LifecycleValueNotifierScene> createState() =>
      _LifecycleValueNotifierSceneState();
}

class _LifecycleValueNotifierSceneState
    extends State<LifecycleValueNotifierScene> {
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

class ErrorHandlingValueNotifierScene extends StatefulWidget {
  const ErrorHandlingValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<ErrorHandlingValueNotifierScene> createState() =>
      _ErrorHandlingValueNotifierSceneState();
}

class _ErrorHandlingValueNotifierSceneState
    extends State<ErrorHandlingValueNotifierScene> {
  int rebuildCount = 0;
  bool hasError = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('increment'),
              onPressed: () {
                if (!hasError) {
                  widget.signal.value++;
                }
              },
              child: Text('Increment'),
            ),
            ElevatedButton(
              key: Key('triggerError'),
              onPressed: () {
                hasError = true;
                setState(() {});
              },
              child: Text('Trigger Error'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                if (hasError) {
                  return Text('Value: Error');
                }
                return Text('Value: ${widget.signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceValueNotifierScene extends StatefulWidget {
  const PerformanceValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<PerformanceValueNotifierScene> createState() =>
      _PerformanceValueNotifierSceneState();
}

class _PerformanceValueNotifierSceneState
    extends State<PerformanceValueNotifierScene> {
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

class NestedValueNotifierScene extends StatefulWidget {
  const NestedValueNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.outerSignal,
    required this.innerSignal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> outerSignal;
  final Signal<int> innerSignal;

  @override
  State<NestedValueNotifierScene> createState() =>
      _NestedValueNotifierSceneState();
}

class _NestedValueNotifierSceneState extends State<NestedValueNotifierScene> {
  int rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementOuter'),
              onPressed: () {
                widget.outerSignal.value++;
              },
              child: Text('Increment Outer'),
            ),
            ElevatedButton(
              key: Key('incrementInner'),
              onPressed: () {
                widget.innerSignal.value++;
              },
              child: Text('Increment Inner'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Outer: ${widget.outerSignal.value}, Inner: ${widget.innerSignal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConditionalListeningScene extends StatefulWidget {
  const ConditionalListeningScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
    required this.isListening,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;
  final Signal<bool> isListening;

  @override
  State<ConditionalListeningScene> createState() =>
      _ConditionalListeningSceneState();
}

class _ConditionalListeningSceneState extends State<ConditionalListeningScene> {
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
            ElevatedButton(
              key: Key('toggleListening'),
              onPressed: () {
                widget.isListening.value = !widget.isListening.value;
              },
              child: Text('Toggle Listening'),
            ),
            ValueListenableBuilder(
                valueListenable: widget.isListening,
                builder: (context, value, child) {
                  widget.rebuildCallback(++rebuildCount);
                  return value
                      ? ValueListenableBuilder(
                          valueListenable: widget.signal,
                          builder: (context, value2, child) {
                            widget.rebuildCallback(++rebuildCount);
                            return Text('Value: $value2, Listening: $value');
                          })
                      : Text(
                          'Value: ${widget.signal.value}, Listening: $value');
                }),
          ],
        ),
      ),
    );
  }
}
