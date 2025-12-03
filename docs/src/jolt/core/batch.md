---
---

# Batch

Batch is used in the reactive system to optimize update performance. It can combine multiple updates together and notify subscribers once, avoiding performance issues caused by consecutive multiple updates. When you need to update multiple signals simultaneously, using batch can reduce unnecessary intermediate updates and improve the overall performance of the reactive system.

## Basic Usage

Use the `batch` function to combine multiple updates:

```dart
import 'package:jolt/jolt.dart';

void main() {
  final signal1 = Signal(1);
  final signal2 = Signal(2);
  final List<int> values = [];
  
  Effect(() {
    values.add(signal1.value + signal2.value);
  });
  
  // Without batching: triggers multiple updates
  signal1.value = 10;
  signal2.value = 20;
  // values = [3, 12, 30] (3 updates)
  
  // With batching: triggers only one update
  batch(() {
    signal1.value = 10;
    signal2.value = 20;
  });
  // values = [3, 30] (2 updates)
}
```

## Nested Usage

Batch can be nested—inner batches notify together when the outer batch ends:

```dart
final signal = Signal(0);

Effect(() {
  print('Update: ${signal.value}');
});

batch(() {
  signal.value = 1;
  
  batch(() {
    signal.value = 2;
  });
  
  signal.value = 3;
});
// Only outputs: "Update: 3" (all updates batched together)
```
