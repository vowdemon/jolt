# Manage State

The first example used local variables. A real feature usually wants a small
class that keeps writes in one place.

Start with the writable state:

```dart
class SearchSession {
  final Signal<String> _query = Signal('');
  final Signal<List<String>> _documents = Signal(const []);
}
```

The filtered result list still belongs in the same class, but it is not another
source of state:

```dart
late final Computed<List<String>> _results = Computed(() {
  final text = _query.value.trim().toLowerCase();
  if (text.isEmpty) return _documents.value;

  return _documents.value
      .where((document) => document.toLowerCase().contains(text))
      .toList();
});
```

Expose read surfaces as `Readable<T>`:

```dart
late final Readable<String> query = _query;
late final Readable<List<String>> documents = _documents;
late final Readable<List<String>> results = _results;
```

Callers can read those fields inside effects, computed values, widgets, and
tests. They cannot assign through them.

Writes go through named methods:

```dart
void setQuery(String value) {
  _query.value = value;
}

void replaceDocuments(List<String> value) {
  _documents.value = List.unmodifiable(value);
}
```

The class can now be used without exposing writable signals:

```dart
final session = SearchSession();

session.replaceDocuments([
  'Signals store state',
  'Computed values derive state',
  'Effects run after state changes',
]);

session.setQuery('state');
print(session.results.value);
```

## Why Not Expose Signal?

This is easy to write:

```dart
final Signal<String> query = Signal('');
```

but every caller can now write `query.value`. If the class later needs to trim,
validate, copy, debounce, reset, or log changes, the write path is already
spread around the program.

For shared state, keep the signal private and publish a read surface:

```dart
final Signal<String> _query = Signal('');
late final Readable<String> query = _query;

void setQuery(String value) {
  _query.value = value;
}
```

That keeps future changes local. If `setQuery()` later needs normalization or
validation, callers do not need to change.

The session now has source state and a filtered result list.

## Next Step

Add more views to the same class in [Derive State](Derive%20State-topic.html),
without adding more writable fields.
