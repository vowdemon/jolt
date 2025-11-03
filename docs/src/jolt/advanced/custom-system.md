---
---

# Custom System

When Jolt's predefined reactive primitives like `Signal` and `Computed` cannot meet special requirements, you can implement custom behavior by **extending these base classes**.

In most cases, **combining existing primitives** can build the desired functionality. For example, `ConvertComputed` and `PersistSignal` extend functionality by inheriting from `WritableComputed` and `Signal` respectively.

For lower-level customization scenarios, Jolt also provides **open reactive primitive extension capabilities**, allowing developers to create **fully custom reactive nodes** to meet complex or specific reactive logic requirements.

## Debounced Signal

Extend `Signal` to implement a debounced signal that waits for a period after a value change before notifying subscribers. If a new value update occurs within this period, the timer resets:

```dart
import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:test/test.dart';

class DebouncedSignal<T> extends Signal<T> {
  final Duration delay;
  Timer? _timer;

  DebouncedSignal(
    super.value, {
    required this.delay,
    super.onDebug,
  });

  @override
  void set(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.set(value);
    });
  }

  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}

// Usage
void main(){
  test('debounce signal', () async {
    final searchQuery = DebouncedSignal('', delay: Duration(milliseconds: 300));

    final results = <String>[];
    final effect = Effect(() {
      final query = searchQuery.value;
      if (query.isNotEmpty) {
        results.add('Results for: $query');
      }
    });

    searchQuery.value = 'j';
    await Future.delayed(Duration(milliseconds: 10));
    searchQuery.value = 'jo';
    await Future.delayed(Duration(milliseconds: 10));
    searchQuery.value = 'jol';
    await Future.delayed(Duration(milliseconds: 10));
    searchQuery.value = 'jolt';

    expect(results, isEmpty);

    await Future.delayed(Duration(milliseconds: 350));

    expect(results, equals(['Results for: jolt']));
    expect(searchQuery.value, equals('jolt'));
  });
}
```

