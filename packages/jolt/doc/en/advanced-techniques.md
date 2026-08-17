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

The `data`, state flags, error views, and `map` helpers belong to
`AsyncStateReadableX<T>`, so they work on every
`Readable<AsyncState<T>>`, not only `AsyncSignal<T>`:

```dart
final visibleResults = Computed<AsyncState<List<Result>>>(
  () => remoteResults.value,
);
final Readonly<AsyncState<List<Result>>> resultsView =
    remoteResults.readonly();

print(visibleResults.isLoading);
print(resultsView.data);
```

These are statically resolved extension members. A receiver typed as
`dynamic` does not expose them, and custom `AsyncSignal` implementations can no
longer override their behavior. Keep the receiver typed as `AsyncSignal<T>` or
`Readable<AsyncState<T>>`; when dynamic access is unavoidable, read
`receiver.value` and inspect or map that `AsyncState` directly.

The async signal can live wherever the surrounding search state lives. Dispose
the effect when the logging or UI reaction is no longer needed.

## Persist A Value

Implement `PersistSignalStorage` once for keyed persistence. Its
`read<T>(key, initial)` method decides whether the key exists and when to invoke
`initial`, so it can distinguish a missing key from a stored `null`.

When the storage instance is already in scope, use the `PersistSignalStorageX`
extension to create signals without passing that instance back as an argument.
The receiver fixes the key type `K`, while the method type argument selects the
value type `T`:

```dart
final theme = settingsStorage.sync<String>(
  key: 'theme',
  initial: () => 'light',
);

final lastRemoteQuery = settingsStorage.async<String>(
  key: 'lastQuery',
  initial: () => '',
);
```

`sync<T>` is equivalent to `PersistSignal.storage<K, T>`, and `async<T>` is
equivalent to `AsyncPersistSignal.storage<K, T>`. Both forward `key`, `initial`,
and `debug` unchanged.

The static factories remain available when the storage is not the natural
receiver. Use `PersistSignal.storage<K, T>` when storage reads synchronously:

```dart
final theme = PersistSignal.storage<String, String>(
  key: 'theme',
  initial: () => 'light',
  storage: settingsStorage,
);
```

Its value is immediately available as `T`. A storage implementation may still
write asynchronously:

```dart
theme.value = 'dark';
await theme.ensureWrite();
```

Use `AsyncPersistSignal.storage<K, T>` when storage may read asynchronously. It
accepts the same arguments and exposes loading, success, and failure as
`AsyncState<T>`:

```dart
final lastRemoteQuery = AsyncPersistSignal.storage<String, String>(
  key: 'lastQuery',
  initial: () => '',
  storage: settingsStorage,
);

final restoreLogger = Effect(() {
  print(lastRemoteQuery.map(
    loading: () => 'Restoring query...',
    success: (query) => 'Restored: $query',
    error: (error, _) => 'Restore failed: $error',
  ));
});

lastRemoteQuery.set(session.query.peek);
await lastRemoteQuery.ensureWrite();

restoreLogger.dispose();
```

`PersistSignalStorage` returns `FutureOr` from both operations.
`AsyncPersistSignal` normalizes synchronous and asynchronous reads, including
synchronous read errors, into `AsyncLoading`, `AsyncSuccess`, and `AsyncError`.
The initial read is never written back. `PersistSignal` requires the read
result to be synchronous and throws immediately with guidance to use
`AsyncPersistSignal` if storage returns a Future.

The key type `K` belongs to `PersistSignalStorage<K>` and is preserved by both
storage factories. The `initial` callback can be omitted; when it is absent,
the storage implementation decides how to handle a missing value.

To assign work that produces a value asynchronously, use `setFuture`. It
publishes `AsyncLoading` immediately. Only the latest successful explicit
assignment becomes `AsyncSuccess` and is persisted; a current failure becomes
`AsyncError` without writing:

```dart
lastRemoteQuery.setFuture(loadNextQuery());
await lastRemoteQuery.ensureWrite();
```

When migrating from `PersistSignal.async`, replace `ensure()` or `getEnsured()`
with reads of the signal's `AsyncState<T>`. The shared
`AsyncStateReadableX<T>` helpers (`data`, state flags, error views, and `map`)
work directly on `AsyncPersistSignal<T>`.

Use the unnamed constructors when direct callbacks are simpler than a keyed
storage adapter:

```dart
final lastQuery = PersistSignal(
  read: () => storage['lastQuery'] ?? '',
  write: (value) => storage['lastQuery'] = value,
);

final remoteQuery = AsyncPersistSignal<String>(
  read: () async => await storage.read('lastQuery') ?? '',
  write: (value) => storage.write('lastQuery', value),
);
```

Synchronous assignments and `AsyncPersistSignal.set(T)` invoke storage `write`
or the direct `write` callback immediately. Directly assigning
`AsyncSuccess<T>` also writes its value; assigning `AsyncLoading<T>` or
`AsyncError<T>` only changes reactive state. `setFuture` writes only after its
Future completes successfully while still current. The storage or callback
owns encoding, decoding, throttling, serialization, coalescing, retry, and
transactions. `ensureWrite()` ignores the initial read, waits for the current
explicit Future assignment to settle or be superseded, and then waits for the
most recent write Future; it does not drain older overlapping writes.

These tools are independent. Add them when the surrounding code asks for that
kind of connection: a batched command, a one-off snapshot, a stream bridge, an
async source, or storage-backed state.

## Next Step

When this model moves into Flutter, choose the package to add around the core
`jolt` code in [Ecosystem](Jolt%20Ecosystem-topic.html).
