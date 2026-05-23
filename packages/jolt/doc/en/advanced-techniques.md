# Advanced Techniques

By now the search model has private writable state, public reads, derived
values, reactions, and a scope for grouped lifecycle.

The rest of the package is a set of small tools you add when the model needs to
touch another part of the program.

## Batch Related Writes

Use `batch()` when one action updates several sources:

```dart
void reset(List<String> documents) {
  batch(() {
    _query.value = '';
    _documents.value = List.unmodifiable(documents);
  });
}
```

Effects and watchers observe the final state after the outermost batch ends.

## Read Without Tracking

Use `peek` or `untracked()` when a read is only a snapshot:

```dart
final searchId = Signal('local');

final searchTraceEffect = Effect(() {
  final text = session.query.value.trim();
  if (text.isEmpty) return;

  final id = untracked(() => searchId.value);
  print('search $id: $text');
});

searchTraceEffect.dispose();
```

Changing `searchId` alone will not re-run the effect.

## Wait For A Condition

Use `until()` when imperative code needs to wait for reactive state:

```dart
final documentsLoaded =
    session.documents.until((documents) => documents.isNotEmpty);
```

The returned `Until` can be awaited like a future:

```dart
session.replaceDocuments([
  'Signals store state',
  'Computed values derive state',
  'Effects run after state changes',
]);

final documents = await documentsLoaded;
```

By default this wait is independent of any current scope. Pass `detach: false`
when scope disposal should cancel the wait.

## Bridge To Streams

Use `listen()` when another API expects stream-like updates:

```dart
final subscription = session.summary.listen(
  analytics.recordSearchSummary,
  immediately: true,
);
```

Cancel the subscription when that bridge is no longer needed:

```dart
await subscription.cancel();
```

## Use Readonly For A Narrower Wrapper

The usual public read surface is a `Readable<T>` typed reference:

```dart
late final Readable<String> query = _query;
```

Use `readonly()` when an API specifically wants a Jolt read-only view object:

```dart
late final Readonly<String> queryView = _query.readonly();
```

Both forms prevent assignment through the public type. `Readable<T>` is the
smaller surface; `Readonly<T>` is a wrapper.

## Model Async State

Use `AsyncSignal` when loading, success, and error should be visible as state:

```dart
final remoteResults = AsyncSignal.fromFuture(api.search('signal'));
```

Read the async state from effects, computed values, or UI code:

```dart
final remoteResultLogger = Effect(() {
  final message = remoteResults.map(
    loading: () => 'Searching...',
    success: (results) => '${results.length} remote results',
    error: (error, _) => 'Search failed: $error',
  );

  print(message);
});

remoteResultLogger.dispose();
```

The async signal can live wherever the surrounding search state lives. Dispose
the effect when the logging or UI reaction is no longer needed.

## Persist A Value

Use `PersistSignal` when storage is part of the state model:

```dart
final lastQuery = PersistSignal.sync(
  read: () => storage['lastQuery'] ?? '',
  write: (value) => storage['lastQuery'] = value,
);
```

After writing, wait until the pending storage write has finished:

```dart
lastQuery.value = session.query.peek;
await lastQuery.ensureWrite();
```

Async persistent signals should be initialized with `ensure()` or
`getEnsured()` before assignment.

These tools are independent. Add them when the surrounding code asks for that
kind of connection: a batched command, a one-off snapshot, a stream bridge, an
async source, or storage-backed state.

## Next Step

When this model moves into Flutter, choose the package to add around the core
`jolt` code in [Ecosystem](Jolt%20Ecosystem-topic.html).
