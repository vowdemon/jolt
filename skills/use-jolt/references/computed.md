# Computed Reference

Use this reference when the task is about deriving state from signals,
automatic dependency tracking, equality, writable computed values, or previous
computed results.

## Core Idea

`Computed<T>` is a cached read-only value. Its getter tracks the reactive values
it reads and recomputes when those dependencies change.

```dart
import 'package:jolt/jolt.dart';

final firstName = Signal('Ada');
final lastName = Signal('Lovelace');

final fullName = Computed(
  () => '${firstName.value} ${lastName.value}',
);

print(fullName.value);
```

## Derived State Belongs In Computed

Use `Computed` for values such as:

- filtered or sorted lists
- validation state
- labels and summaries
- totals and counters
- normalized forms
- permission and visibility booleans

```dart
class SearchModel {
  final _query = Signal('');
  final _documents = Signal(const <String>[]);

  late final _normalizedQuery =
      Computed(() => _query.value.trim().toLowerCase());

  late final _results = Computed(() {
    final text = _normalizedQuery.value;
    if (text.isEmpty) return _documents.value;
    return _documents.value
        .where((doc) => doc.toLowerCase().contains(text))
        .toList(growable: false);
  });

  late final Readable<List<String>> results = _results;
}
```

## One-Source Projection

Use `readable.derived(...)` when one readable is the only source.

```dart
final count = Signal(0);
final label = count.derived((value) => 'Count: $value');
```

This is shorthand for a `Computed` that reads the source.

## Writable Computed

Use `WritableComputed<T>` when the derived value also has a meaningful
assignment path.

```dart
final firstName = Signal('Ada');
final lastName = Signal('Lovelace');

final fullName = WritableComputed(
  () => '${firstName.value} ${lastName.value}',
  (String value) {
    final parts = value.split(' ');
    firstName.value = parts.first;
    lastName.value = parts.skip(1).join(' ');
  },
);

fullName.value = 'Grace Hopper';
```

Use `Computed<T>` when assignment would be unclear or lossy.

The setter does not directly refresh the computed cache and does not notify
subscribers by itself. Assignment is meaningful when the setter writes the
signal state that the getter tracks.

```dart
final cents = Signal(1250);

final dollars = WritableComputed(
  () => (cents.value / 100).toStringAsFixed(2),
  (String value) {
    cents.value = (double.parse(value) * 100).round();
  },
);

dollars.value = '20.00';
print(dollars.value); // recomputed from cents.value
```

If the setter only writes unrelated state, the computed value can remain cached
until a tracked dependency changes or the computed is notified explicitly.

## Equality

Use `equals` to define when a recomputed value is treated as unchanged. The
callback receives the new value first and the previous cached value second.
Return `true` when subscribers should not be notified for that recomputation.

```dart
final rounded = Computed(
  () => rawNumber.value.round(),
  equals: (current, previous) => current == previous,
);
```

Use custom equality for stable projections, tolerances, or identity rules:

```dart
final temperature = Signal(20.01);

final displayTemperature = Computed(
  () => temperature.value,
  equals: (current, previous) =>
      previous != null && (current - previous).abs() < 0.1,
);
```

Keep equality cheap and deterministic. Equality decides propagation, not
whether the getter runs.

## Previous Value

Use `Computed.withPrevious` when deriving the next value needs the previous
computed result.

```dart
final raw = Signal(0);

final nonDecreasing = Computed.withPrevious((int? previous) {
  final next = raw.value;
  if (previous == null) return next;
  return next < previous ? previous : next;
});
```

Prefer ordinary `Computed` unless the previous value is part of the model.

## Purity Rule

A computed getter should read reactive values and return a value.

Do not put these in `Computed`:

- signal writes
- timers
- requests
- stream subscriptions
- logging that must happen once per change
- persistence
- controller mutations

Use `Effect` for work and keep `Computed` for values.

## Refreshing Manually

Use manual notification when a computed depends on external state that Jolt
cannot track automatically.

`notify()` recomputes and forces subscribers to update even if the computed
result is equal to the previous value.

`notifySoft()` recomputes and notifies subscribers only when the computed result
changes according to `equals` or `!=`.

```dart
final locale = Signal('en');
final clockText = Computed(() => formatClock(DateTime.now(), locale.value));

clockText.notify(); // force subscribers to update
clockText.notifySoft();
```

Prefer modeling external inputs as signals when possible. Manual notification is
for values Jolt cannot observe directly, such as clocks, caches, or external
mutable objects.
