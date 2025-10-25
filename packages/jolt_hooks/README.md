# Jolt Hooks

Flutter hooks integration for the Jolt reactive state management system.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt_hooks/jolt_hooks.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

class CounterWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useSignal(0);
    
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
