# Jolt Hooks

Flutter hooks integration for the Jolt reactive state management system.

## Usage

### Using JoltBuilder (Widget-based)

`JoltBuilder` is a `StatelessWidget` that creates a reactive scope. It's ideal for use in regular `Widget` build methods:

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt/jolt.dart';

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = Signal(0);
    
    return Scaffold(
      body: JoltBuilder(
        builder: (context) => Text('Count: ${count.value}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### Using useJoltWidget (Hook-based)

`useJoltWidget` is a Flutter hook that wraps a widget builder in a reactive effect. It must be used within a `HookBuilder` and is perfect for integrating with other hooks:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_hooks/jolt_hooks.dart';
import 'package:jolt/jolt.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
    return Scaffold(
      body: HookBuilder(
        builder: (context) => useJoltWidget(() {
          return Text('Count: ${count.value}');
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## API Reference

| Hook | Description |
|------|-------------|
| `useSignal` | Creates a reactive signal |
| `useComputed` | Creates a computed signal |
| `useWritableComputed` | Creates a writable computed signal |
| `useConvertComputed` | Creates a type-converting signal |
| `useListSignal` | Creates a reactive list |
| `useMapSignal` | Creates a reactive map |
| `useSetSignal` | Creates a reactive set |
| `useIterableSignal` | Creates a reactive iterable |
| `useJoltEffect` | Creates a reactive effect |
| `useJoltWatcher` | Creates a watcher |
| `useJoltEffectScope` | Creates an effect scope |
| `useAsyncSignal` | Creates an async signal |
| `usePersistSignal` | Creates a persistent signal |
| `useJoltStream` | Creates a stream from a reactive value |
| `useJoltWidget` | Creates a reactive widget that rebuilds when dependencies change |
