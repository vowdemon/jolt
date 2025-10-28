import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class ToNotifierSignalScene extends StatefulWidget {
  const ToNotifierSignalScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<ToNotifierSignalScene> createState() => _ToNotifierSignalSceneState();
}

class _ToNotifierSignalSceneState extends State<ToNotifierSignalScene> {
  int rebuildCount = 0;
  late ValueNotifier<int> valueNotifier;
  late Signal<int> signal;

  @override
  void initState() {
    super.initState();
    valueNotifier = ValueNotifier(0);
    signal = valueNotifier.toNotifierSignal();
  }

  @override
  void dispose() {
    valueNotifier.dispose();
    signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementNotifier'),
              onPressed: () {
                valueNotifier.value++;
              },
              child: Text('Increment Notifier'),
            ),
            ElevatedButton(
              key: Key('incrementSignal'),
              onPressed: () {
                signal.value++;
              },
              child: Text('Increment Signal'),
            ),
            JoltBuilder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Notifier: ${valueNotifier.value}, Signal: ${signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Test scene for ValueListenable.toListenableSignal() unidirectional sync
class ToListenableSignalScene extends StatefulWidget {
  const ToListenableSignalScene({
    super.key,
    required this.rebuildCallback,
  });

  final ValueChanged<int> rebuildCallback;

  @override
  State<ToListenableSignalScene> createState() =>
      _ToListenableSignalSceneState();
}

class _ToListenableSignalSceneState extends State<ToListenableSignalScene> {
  int rebuildCount = 0;
  late ValueNotifier<int> valueNotifier;
  late ReadonlySignal<int> signal;

  @override
  void initState() {
    super.initState();
    valueNotifier = ValueNotifier(0);
    signal = valueNotifier.toListenableSignal();
  }

  @override
  void dispose() {
    valueNotifier.dispose();
    signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementNotifier'),
              onPressed: () {
                valueNotifier.value++;
              },
              child: Text('Increment Notifier'),
            ),
            ElevatedButton(
              key: Key('tryIncrementSignal'),
              onPressed: () {
                // 尝试修改只读信号，应该失败
                try {
                  // ReadonlySignal 没有 value setter，所以这里会编译失败
                  // 这是预期的行为，证明它是只读的
                } catch (e) {
                  // 预期会失败
                }
              },
              child: Text('Try Increment Signal (Should Fail)'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Notifier: ${valueNotifier.value}, Signal: ${signal.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Test scene for Signal.notifier conversion
class SignalNotifierScene extends StatefulWidget {
  const SignalNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<SignalNotifierScene> createState() => _SignalNotifierSceneState();
}

class _SignalNotifierSceneState extends State<SignalNotifierScene> {
  int rebuildCount = 0;
  late ValueNotifier<int> notifier;

  @override
  void initState() {
    super.initState();
    notifier = widget.signal.notifier;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementSignal'),
              onPressed: () {
                widget.signal.value++;
              },
              child: Text('Increment Signal'),
            ),
            ElevatedButton(
              key: Key('incrementNotifier'),
              onPressed: () {
                notifier.value++;
              },
              child: Text('Increment Notifier'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Signal: ${widget.signal.value}, Notifier: ${notifier.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Test scene for Computed.notifier conversion
class ComputedNotifierScene extends StatefulWidget {
  const ComputedNotifierScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
    required this.computed,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;
  final Computed<int> computed;

  @override
  State<ComputedNotifierScene> createState() => _ComputedNotifierSceneState();
}

class _ComputedNotifierSceneState extends State<ComputedNotifierScene> {
  int rebuildCount = 0;
  late ValueNotifier<int> notifier;

  @override
  void initState() {
    super.initState();
    notifier = widget.computed.notifier;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: Key('incrementSignal'),
              onPressed: () {
                widget.signal.value++;
              },
              child: Text('Increment Signal'),
            ),
            ElevatedButton(
              key: Key('tryIncrementNotifier'),
              onPressed: () {
                try {
                  notifier.value++;
                } catch (_) {}
              },
              child: Text('Try Increment Notifier (Should Fail)'),
            ),
            JoltResource.builder(
              builder: (context) {
                widget.rebuildCallback(++rebuildCount);
                return Text(
                    'Signal: ${widget.signal.value}, Computed: ${widget.computed.value}, Notifier: ${notifier.value}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Test scene for .notifier caching mechanism
class NotifierCachingScene extends StatefulWidget {
  const NotifierCachingScene({
    super.key,
    required this.rebuildCallback,
    required this.signal,
  });

  final ValueChanged<int> rebuildCallback;
  final Signal<int> signal;

  @override
  State<NotifierCachingScene> createState() => _NotifierCachingSceneState();
}

class _NotifierCachingSceneState extends State<NotifierCachingScene> {
  int rebuildCount = 0;
  late ValueNotifier<int> notifier1;
  late ValueNotifier<int> notifier2;

  @override
  void initState() {
    super.initState();

    notifier1 = widget.signal.notifier;
    notifier2 = widget.signal.notifier;
  }

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
                final isSameInstance = identical(notifier1, notifier2);
                return Text(
                    'Value: ${widget.signal.value}, Same Instance: $isSameInstance');
              },
            ),
          ],
        ),
      ),
    );
  }
}
