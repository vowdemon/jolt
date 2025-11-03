---
---

# Collection Signal

Collection signals provide reactive collection types in the reactive system, including `ListSignal`, `SetSignal`, `MapSignal`, and `IterableSignal`. All mutation operations automatically trigger reactive updates, suitable for scenarios requiring reactive collection operations, such as dynamic lists, tag collections, configuration maps, etc.

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

## Creation

### ListSignal

```dart
final items = ListSignal(['a', 'b', 'c']);
```

Using extension methods:

```dart
final normalList = [1, 2, 3];
final reactiveList = normalList.toListSignal();
```

### SetSignal

```dart
final tags = SetSignal({'dart', 'flutter'});
```

Using extension methods:

```dart
final normalSet = {'dart', 'flutter'};
final reactiveSet = normalSet.toSetSignal();
```

### MapSignal

```dart
final user = MapSignal({'name': 'Alice', 'age': 30});
```

Using extension methods:

```dart
final normalMap = {'key': 'value'};
final reactiveMap = normalMap.toMapSignal();
```

### IterableSignal

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final evenNumbers = IterableSignal(() => 
  numbers.value.where((n) => n.isEven)
);
```

## Basic Usage

### ListSignal

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

Replace the entire list directly:

```dart
final items = ListSignal([1, 2, 3]);

items.value = [4, 5, 6]; // Replace entire list, triggers update
```

### SetSignal

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

You can use all iterator operations:

```dart
final numbers = Signal([1, 2, 3, 4, 5]);

final doubled = IterableSignal(() => 
  numbers.value.map((n) => n * 2)
);

Effect(() {
  print('Doubled: ${doubled.toList()}');
});
```

