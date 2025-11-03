---
---

# Convert Signal

Convert signals are used in the reactive system for bidirectional conversion between signals of different types. Essentially, it is a WritableComputed used for bidirectional value conversion or type conversion. It provides a writable computed value that can encode and decode data transformations, suitable for scenarios like form inputs, API data conversion, etc., where conversions between different data representations are needed.

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';

void main() {
  final count = Signal(0);
  
  // Create a signal that converts int to String
  final textCount = ConvertComputed(
    count,
    decode: (int value) => value.toString(),
    encode: (String value) => int.parse(value),
  );
  
  // Setting value through textCount automatically updates count
  textCount.value = "42";
  print(count.value); // Output: 42
  
  // Setting value through count automatically updates textCount
  count.value = 100;
  print(textCount.value); // Output: "100"
}
```

## Creation

Use the `ConvertComputed` constructor to create a converted computed value:

```dart
final source = Signal(0);

final converted = ConvertComputed(
  source,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);
```

Parameter description:
- `source`: The source signal
- `decode`: Function that converts from source type to target type
- `encode`: Function that converts from target type to source type

## Basic Usage

### Form Input Conversion

```dart
final age = Signal(18);

final ageText = ConvertComputed(
  age,
  decode: (int value) => value.toString(),
  encode: (String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      throw FormatException('Invalid age');
    }
    return parsed;
  },
);
```

### Price Formatting

```dart
final price = Signal(100);

final priceText = ConvertComputed(
  price,
  decode: (int value) => '\$${value.toStringAsFixed(2)}',
  encode: (String value) {
    final cleaned = value.replaceAll('\$', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      throw FormatException('Invalid price');
    }
    return parsed.toInt();
  },
);
```

### Bidirectional Synchronization

The converted signal can be read and written, automatically synchronizing to the source signal:

```dart
final count = Signal(0);
final textCount = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

// Write through converted signal
textCount.value = "42"; // count automatically becomes 42

// Write through source signal
count.value = 100; // textCount automatically becomes "100"
```

