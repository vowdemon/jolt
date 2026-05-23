# Derive State

Search state quickly needs more views: whether the query is empty, how many
results matched, and what message the UI should show.

Those are not new sources of state. They are derived from `query`, `documents`,
and `results`.

Normalize the query once:

```dart
late final Computed<String> _normalizedQuery =
    Computed(() => _query.value.trim().toLowerCase());
```

Then let `_results` read the normalized value:

```dart
late final Computed<List<String>> _results = Computed(() {
  final text = _normalizedQuery.value;
  if (text.isEmpty) return _documents.value;

  return _documents.value
      .where((document) => document.toLowerCase().contains(text))
      .toList();
});
```

The UI message can be derived too:

```dart
late final Computed<bool> _hasQuery =
    Computed(() => _normalizedQuery.value.isNotEmpty);

late final Computed<String> _summary = _results.derived((results) {
  if (!_hasQuery.value) return 'Type to search';
  if (results.isEmpty) return 'No matches';
  return '${results.length} match${results.length == 1 ? '' : 'es'}';
});
```

Expose the values callers need:

```dart
late final Readable<String> query = _query;
late final Readable<List<String>> results = _results;
late final Readable<String> summary = _summary;
```

No effect is needed here. Nothing is being saved, printed, fetched, or
scheduled. The values are just being calculated from current reactive reads.

## Keep Computed Values Quiet

A computed getter should read reactive values and return a value:

```dart
late final Computed<int> _resultCount =
    Computed(() => _results.value.length);
```

Do not put timers, requests, logs, persistence, or signal writes in the getter.
If code does work, it belongs in an effect.

Use another `Signal` only when the value has its own write path. A value like
`summary` follows from the current query and results, so keeping it computed
avoids duplicate state.

## Next Step

Use the same query to start real work in
[React to State Changes](React%20To%20State%20Changes-topic.html).
