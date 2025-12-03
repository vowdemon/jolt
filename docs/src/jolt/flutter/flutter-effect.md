---
---

# FlutterEffect

`FlutterEffect` is a side effect implementation specifically designed for Flutter, scheduled to execute at the end of the current Flutter frame. This merges multiple triggers within the same frame into a single execution, avoiding unnecessary repeated executions during frame rendering, which is very useful for UI-related side effects that should not interfere with frame rendering.

## Basic Usage

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

final count = Signal(0);

// Effect executes at the end of the current frame, even if count changes multiple times in the same frame
final effect = FlutterEffect(() {
  print('Count is: ${count.value}');
});

count.value = 1;
count.value = 2;
count.value = 3;
// Effect executes once at the end of the current frame, outputs: "Count is: 3"
```

## Creating FlutterEffect

### Immediate Execution (Default)

By default, `FlutterEffect` executes immediately upon creation and immediately collects dependencies, then executes at the end of the current frame when dependencies change:

```dart
final signal = Signal(0);

// Effect executes immediately and collects dependencies
final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}); // Immediately outputs: "Signal value: 0"

signal.value = 1; // Effect executes at the end of the current frame
signal.value = 2; // Effect executes at the end of the current frame (merged into one)
```

### Lazy Dependency Collection

Using `lazy: true` delays dependency collection. `FlutterEffect` does not execute immediately and does not collect dependencies—you must manually call `run()` to start collecting dependencies. This is suitable for "define first, use later" scenarios:

```dart
final signal = Signal(0);

// Define FlutterEffect first, but don't collect dependencies
final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}, lazy: true); // Does not execute immediately, does not collect dependencies

// Manually start collecting dependencies later
effect.run(); // Now starts collecting dependencies and executes, outputs: "Signal value: 0"

signal.value = 1; // Effect executes at the end of the current frame
```

You can also use the `FlutterEffect.lazy` factory method:

```dart
final effect = FlutterEffect.lazy(() {
  print('Signal value: ${signal.value}');
});
```

**Use Cases**: Lazy dependency collection is mainly used when you need to define a FlutterEffect first and activate it later, such as defining it during component initialization and activating it at a specific time.

## Manual Execution

You can use the `run()` method to manually trigger FlutterEffect execution. For FlutterEffects with `lazy: true`, `run()` starts collecting dependencies and executes:

```dart
final signal = Signal(0);

final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}, lazy: true);

effect.run(); // Starts collecting dependencies and executes, outputs: "Signal value: 0"

signal.value = 1; // Effect executes at the end of the current frame
```

For non-lazy FlutterEffects, `run()` re-executes and updates dependencies:

```dart
final signal = Signal(0);

final effect = FlutterEffect(() {
  print('Signal value: ${signal.value}');
}); // Already executed and collected dependencies

effect.run(); // Re-executes, outputs: "Signal value: 0"
```

## Cleanup Functions

`FlutterEffect` supports registering cleanup functions that execute before Effect re-runs or when it's disposed:

```dart
final count = Signal(0);

FlutterEffect(() {
  print('Count changed: ${count.value}');

  final timer = Timer.periodic(Duration(seconds: 1), (_) {
    count.value++;
  });

  onEffectCleanup(() => timer.cancel());
});
```

### Using in Async

If you need to use cleanup functions in async operations, you should directly use the `effect.onCleanUp()` method:

```dart
final effect = FlutterEffect(() async {
  final subscription = await someAsyncOperation();

  // In async context, directly use effect.onCleanUp()
  effect.onCleanUp(() => subscription.cancel());
});
```

## Differences from Effect

The main difference between `FlutterEffect` and `Effect` is execution timing:

- **Effect**: Executes immediately when dependencies change (within reactive update cycle)
- **FlutterEffect**: Executes at the end of the current Flutter frame when dependencies change (batched)

### Use Cases

**Use FlutterEffect when:**
- You need to execute UI-related side effects (such as updating UI state, showing dialogs, etc.)
- You want to merge multiple updates within the same frame into one execution
- You don't want to execute side effects during frame rendering

**Use Effect when:**
- You need to immediately respond to dependency changes
- You're executing non-UI-related side effects (such as logging, data synchronization, etc.)
- You don't need frame-level batching

## Complete Examples

### Batch Update Handling

```dart
final items = ListSignal([1, 2, 3]);

FlutterEffect(() {
  // Even if items are modified multiple times in the same frame, this only executes once
  print('Items updated: ${items.value}');
});

// Multiple modifications within the same frame
items.add(4);
items.add(5);
items.removeAt(0);
// Effect executes once at the end of the current frame
```

### UI State Updates

```dart
final isLoading = Signal(false);
final error = Signal<String?>(null);

FlutterEffect(() {
  if (isLoading.value) {
    // Show loading indicator
    showLoadingDialog();
  } else if (error.value != null) {
    // Show error message
    showErrorSnackBar(error.value!);
  } else {
    // Hide dialog
    hideLoadingDialog();
  }
});
```

### Combined with Cleanup Functions

```dart
final count = Signal(0);
Timer? _timer;

FlutterEffect(() {
  _timer?.cancel();
  _timer = Timer.periodic(Duration(seconds: 1), (_) {
    count.value++;
  });

  onEffectCleanup(() {
    _timer?.cancel();
    _timer = null;
  });
});
```

## Important Notes

1. **Frame Scheduling**: `FlutterEffect` uses `SchedulerBinding.instance.endOfFrame` to schedule execution, ensuring execution after frame rendering completes.

2. **Batching**: Multiple triggers within the same frame are automatically merged into one execution, improving performance.

3. **Lifecycle**: `FlutterEffect` requires manual lifecycle management. Remember to call `dispose()` when done.

4. **Dependency Tracking**: `FlutterEffect` automatically tracks dependencies and schedules execution when dependencies change.

5. **Performance Optimization**: For frequently updating scenarios, using `FlutterEffect` can significantly reduce execution count and improve performance.

