---
---

# ValueNotifier Integration

Jolt provides seamless integration with Flutter's `ValueNotifier` system, allowing bidirectional conversion between Jolt signals and Flutter's `ValueNotifier`.

## JoltValueNotifier

`JoltValueNotifier` is a `ValueNotifier` implementation that wraps Jolt reactive values, providing Flutter's `ValueNotifier` interface. This allows you to seamlessly integrate Jolt signals with Flutter Widgets and state management systems.

### Basic Usage

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

final signal = Signal(42);
final notifier = JoltValueNotifier(signal);

// Use with AnimatedBuilder
AnimatedBuilder(
  animation: notifier,
  builder: (context, child) => Text('${notifier.value}'),
)
```

### Extension Methods

Jolt provides extension methods that let you directly get `ValueNotifier` from reactive values:

```dart
final counter = Signal(0);
final notifier = counter.notifier;

// Use with Flutter widgets
ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('$value'),
)
```

### Caching Mechanism

The `notifier` extension method returns a cached instance. Multiple calls return the same instance, ensuring performance optimization:

```dart
final counter = Signal(0);
final notifier1 = counter.notifier;
final notifier2 = counter.notifier;

print(identical(notifier1, notifier2)); // true
```

## Bidirectional Synchronization

### From ValueNotifier to Signal

Jolt provides extension methods to convert `ValueNotifier` to reactive signals with bidirectional synchronization:

```dart
final notifier = ValueNotifier(0);
final signal = notifier.toNotifierSignal();

// Bidirectional synchronization
notifier.value = 1; // signal.value becomes 1
signal.value = 2;   // notifier.value becomes 2
```

### Use Cases

This feature is particularly useful in the following scenarios:

1. **Integrating Existing Code**: If you have existing code using `ValueNotifier`, you can easily convert it to Jolt signals.

2. **Third-Party Library Integration**: Some third-party libraries may use `ValueNotifier`, which you can convert to Jolt signals to leverage the reactive system's advantages.

3. **Progressive Migration**: When migrating from `ValueNotifier` to Jolt, you can gradually convert while maintaining compatibility.

## Complete Examples

### Using JoltValueNotifier

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notifier = counter.notifier;

    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Count: $value'),
            ElevatedButton(
              onPressed: () => counter.value++,
              child: Text('Increment'),
            ),
          ],
        );
      },
    );
  }
}
```

### Using AnimatedBuilder

```dart
final opacity = Signal(1.0);
final notifier = opacity.notifier;

AnimatedBuilder(
  animation: notifier,
  builder: (context, child) {
    return Opacity(
      opacity: notifier.value,
      child: child,
    );
  },
  child: Text('Fade in/out'),
);
```

### Bidirectional Conversion

```dart
// Create Signal from ValueNotifier
final notifier = ValueNotifier<String>('Hello');
final signal = notifier.toNotifierSignal();

// Now can use in Jolt reactive system
Effect(() {
  print('Signal value: ${signal.value}');
});

// Modifying either direction synchronizes
notifier.value = 'World'; // Signal also updates
signal.value = 'Jolt';    // ValueNotifier also updates
```

## Important Notes

1. **Lifecycle Management**: `JoltValueNotifier` automatically manages synchronization with Jolt signals. When `ValueNotifier` is disposed, synchronization automatically stops.

2. **Performance Considerations**: The `notifier` extension method uses a caching mechanism. Multiple calls return the same instance, avoiding multiple listeners.

3. **Collection Signals**: For mutable collection signals (such as `ListSignal`, `MapSignal`, etc.), `JoltValueNotifier` listens to all changes, including internal modifications.

4. **Type Safety**: All conversions maintain complete type safety with compile-time type checking.

5. **Automatic Cleanup**: When Jolt signals are disposed, `JoltValueNotifier` automatically cleans up resources without manual management.

