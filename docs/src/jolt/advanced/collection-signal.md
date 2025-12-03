---
---

# Pre-built Collection Signals

Jolt provides pre-built reactive collection types, including `ListSignal`, `SetSignal`, `MapSignal`, and `IterableSignal`. These pre-built collection signals are implemented based on corresponding Mixins, and all modification operations automatically trigger reactive updates. Suitable for scenarios requiring reactive collection operations, such as dynamic lists, tag sets, configuration maps, etc.

```dart
import 'package:jolt/jolt.dart';

void main() {
  final items = ListSignal(['a', 'b', 'c']);
  
  Effect(() {
    print('List: ${items.value}');
  });
  
  items.add('d'); // Output: "List: [a, b, c, d]"
}
```

## Pre-built Collection Signals

### ListSignal

`ListSignal` provides reactive list operations:

```dart
final items = ListSignal(['a', 'b', 'c']);
```

Using extension methods:

```dart
final normalList = [1, 2, 3];
final reactiveList = normalList.toListSignal();
```

All list operations automatically trigger updates:

```dart
final items = ListSignal([1, 2, 3]);

Effect(() {
  print('List length: ${items.length}');
});

items.add(4); // Triggers update
items.insert(0, 0); // Triggers update
items.removeAt(2); // Triggers update
items.clear(); // Triggers update
```

Directly replace the entire list:

```dart
final items = ListSignal([1, 2, 3]);
items.value = [4, 5, 6]; // Replace entire list, triggers update
```

### SetSignal

`SetSignal` provides reactive set operations:

```dart
final tags = SetSignal({'dart', 'flutter'});
```

Using extension methods:

```dart
final normalSet = {'dart', 'flutter'};
final reactiveSet = normalSet.toSetSignal();
```

All set operations automatically trigger updates:

```dart
final tags = SetSignal({'a', 'b'});

Effect(() {
  print('Tag count: ${tags.length}');
});

tags.add('c'); // Triggers update
tags.remove('a'); // Triggers update
tags.addAll({'d', 'e'}); // Triggers update
tags.clear(); // Triggers update
```

### MapSignal

`MapSignal` provides reactive map operations:

```dart
final user = MapSignal({'name': 'Alice', 'age': 30});
```

Using extension methods:

```dart
final normalMap = {'key': 'value'};
final reactiveMap = normalMap.toMapSignal();
```

All map operations automatically trigger updates:

```dart
final user = MapSignal({'name': 'Alice'});

Effect(() {
  print('User info: ${user.value}');
});

user['age'] = 30; // Triggers update
user.addAll({'city': 'NYC', 'country': 'USA'}); // Triggers update
user.remove('city'); // Triggers update
user.clear(); // Triggers update
```

### IterableSignal

`IterableSignal` provides reactive iterable operations, implemented based on `Computed`:

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final evenNumbers = IterableSignal(() => 
  numbers.value.where((n) => n.isEven)
);
```

You can use all iterable operations:

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final doubled = IterableSignal(() => 
  numbers.value.map((n) => n * 2)
);

Effect(() {
  print('Doubled: ${doubled.toList()}');
});
```

## Collection Signal Mixins

Jolt provides corresponding Mixins for each collection type. These Mixins implement all collection operations and automatically trigger reactive updates when modified:

- **`ListSignalMixin<E>`**: Provides reactive list functionality
- **`SetSignalMixin<E>`**: Provides reactive set functionality
- **`MapSignalMixin<K, V>`**: Provides reactive map functionality
- **`IterableSignalMixin<E>`**: Provides reactive iterable functionality

These Mixins implement all interface methods of the corresponding collection types and call `notify()` after modification operations to notify subscribers.

### How Mixins Work

Taking `ListSignalMixin` as an example:

```dart
mixin ListSignalMixin<E>
    implements ListBase<E>, Readonly<List<E>>, IMutableCollection {
  // Implement all List interface methods
  @override
  int get length => value.length;
  
  @override
  void add(E element) {
    peek.add(element);
    notify(); // Notify subscribers after modification
  }
  
  @override
  void removeAt(int index) {
    peek.removeAt(index);
    notify(); // Notify subscribers after modification
  }
  
  // ... other methods
}
```

Mixins access the underlying collection value through `value`, perform modifications through `peek`, and call `notify()` after modifications to trigger reactive updates.

## Creating Custom Collection Signals

You can create custom collection signals based on these Mixins, adding additional functionality or constraints.

### Example: Validated ListSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/list_signal.dart';
import 'package:jolt/src/jolt/signal.dart';

/// Validated list signal: only allows adding elements that satisfy conditions
class ValidatedListSignal<E> extends SignalImpl<List<E>>
    with ListSignalMixin<E>
    implements ListSignal<E> {
  final bool Function(E element) validator;

  ValidatedListSignal(
    List<E>? value, {
    required this.validator,
    super.onDebug,
  }) : super(value ?? []);

  @override
  void add(E element) {
    if (!validator(element)) {
      throw ArgumentError('Element does not pass validation: $element');
    }
    super.add(element);
  }

  @override
  void insert(int index, E element) {
    if (!validator(element)) {
      throw ArgumentError('Element does not pass validation: $element');
    }
    super.insert(index, element);
  }
}

// Usage
final positiveNumbers = ValidatedListSignal<int>(
  [],
  validator: (n) => n > 0,
);

positiveNumbers.add(5); // OK
positiveNumbers.add(-1); // Throws exception
```

### Example: SetSignal with Maximum Length

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/set_signal.dart';
import 'package:jolt/src/jolt/signal.dart';

/// Set signal with maximum length limit
class BoundedSetSignal<E> extends SignalImpl<Set<E>>
    with SetSignalMixin<E>
    implements SetSignal<E> {
  final int maxLength;

  BoundedSetSignal(
    Set<E>? value, {
    required this.maxLength,
    super.onDebug,
  }) : super(value ?? {});

  @override
  bool add(E element) {
    if (value.length >= maxLength && !value.contains(element)) {
      throw StateError('Set has reached maximum length: $maxLength');
    }
    return super.add(element);
  }

  @override
  void addAll(Iterable<E> other) {
    final toAdd = other.where((e) => !value.contains(e));
    if (value.length + toAdd.length > maxLength) {
      throw StateError('Adding these elements would exceed maximum length');
    }
    super.addAll(other);
  }
}

// Usage
final tags = BoundedSetSignal<String>(
  {},
  maxLength: 5,
);

tags.add('dart'); // OK
tags.addAll({'flutter', 'web', 'mobile', 'desktop'}); // OK (5 total)
tags.add('server'); // Throws exception
```

### Example: Read-only View MapSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/map_signal.dart';
import 'package:jolt/src/jolt/signal.dart';

/// Read-only view map signal: cannot be modified, only read
class ReadonlyMapSignal<K, V> extends SignalImpl<Map<K, V>>
    with MapSignalMixin<K, V>
    implements MapSignal<K, V> {
  ReadonlyMapSignal(Map<K, V>? value, {super.onDebug}) : super(value ?? {});

  @override
  void operator []=(K key, V value) {
    throw UnsupportedError('Cannot modify readonly map');
  }

  @override
  V? remove(Object? key) {
    throw UnsupportedError('Cannot modify readonly map');
  }

  @override
  void clear() {
    throw UnsupportedError('Cannot modify readonly map');
  }

  @override
  void addAll(Map<K, V> other) {
    throw UnsupportedError('Cannot modify readonly map');
  }
}

// Usage
final config = ReadonlyMapSignal<String, dynamic>({
  'appName': 'MyApp',
  'version': '1.0.0',
});

print(config['appName']); // OK
config['newKey'] = 'value'; // Throws exception
```

### Example: Custom IterableSignal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/collection/iterable_signal.dart';
import 'package:jolt/src/jolt/computed.dart';

/// Cached iterable signal: caches transformation results for better performance
class CachedIterableSignal<E, R> extends ComputedImpl<Iterable<R>>
    with IterableMixin<R>, IterableSignalMixin<R>
    implements IterableSignal<R> {
  final Iterable<E> Function() sourceGetter;
  final R Function(E element) transform;
  List<R>? _cachedResult;
  Iterable<E>? _lastSource;

  CachedIterableSignal(
    this.sourceGetter,
    this.transform, {
    super.onDebug,
  }) : super(() => sourceGetter().map(transform));

  @override
  Iterable<R> get value {
    final source = sourceGetter();
    if (_cachedResult == null || _lastSource != source) {
      _cachedResult = source.map(transform).toList();
      _lastSource = source;
    }
    return _cachedResult!;
  }
}

// Usage
final numbers = Signal([1, 2, 3, 4, 5]);

final squared = CachedIterableSignal<int, int>(
  () => numbers.value,
  (n) => n * n,
);

print(squared.toList()); // [1, 4, 9, 16, 25]
```

## Best Practices

1. **Prefer Pre-built Signals**: For most scenarios, the pre-built `ListSignal`, `SetSignal`, `MapSignal`, and `IterableSignal` are sufficient.

2. **Use Mixins to Extend Functionality**: If you need to add validation, constraints, or special behavior, extend `SignalImpl<CollectionType>` and use the corresponding Mixin.

3. **Maintain Reactive Semantics**: Custom collection signals should maintain reactive semantics, calling `notify()` after modification operations (Mixins handle this automatically).

4. **Implement Required Interfaces**: Ensure custom signals implement the corresponding collection interfaces (such as `ListBase`, `SetBase`, `MapBase`) for compatibility with Dart's standard library.

5. **Handle Edge Cases**: When implementing custom validation or constraint logic, consider edge cases such as empty collections, maximum length, etc.

## Related APIs

- [Extending Jolt](./extending-jolt.md) - Learn how to extend Jolt's core functionality
- [Signal](../core/signal.md) - Learn about basic signal usage
- [Computed](../core/computed.md) - Learn about computed property usage
