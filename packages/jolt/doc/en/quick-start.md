# Quick Start

Start with a search box. The user types a query, the app filters a list, and an
effect logs the current result count.

Put values that change directly in `Signal`s:

```dart
final query = Signal('');
final documents = Signal([
  'Signals store state',
  'Computed values derive state',
  'Effects run after state changes',
]);
```

Derive the visible results from those signals:

```dart
final results = Computed(() {
  final text = query.value.trim().toLowerCase();
  if (text.isEmpty) return documents.value;

  return documents.value
      .where((document) => document.toLowerCase().contains(text))
      .toList();
});
```

Changing the query marks `results` as stale. The next read calculates it again
from the current values:

```dart
query.value = 'state';
print(results.value);
```

Use an `Effect` when code should run after reactive reads change:

```dart
final resultCountEffect = Effect(() {
  print('${results.value.length} result(s) for "${query.value}"');
});

query.value = 'effect';
resultCountEffect.dispose();
```

The effect runs once when it is created. While it runs, Jolt records the
reactive values it reads. Later, changing `query.value` re-runs the effect
because the effect read both `query` and `results`.

`Effect(...)` creates an effect object. Store that object where the surrounding
code manages lifecycle, then call `dispose()` when the effect should end. In a
larger program you can put related effects inside an `EffectScope` and dispose
the scope.

The rest of this guide keeps the same search example and moves it toward code
you would actually keep in an app.

## Next Step

Move the loose values into a small class in
[Manage State](Manage%20State-topic.html).
