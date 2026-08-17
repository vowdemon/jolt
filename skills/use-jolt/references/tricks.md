# Tricks Reference

Use this reference for higher-level core helpers that shape signal APIs:
`PersistSignal`, `ConvertComputed`, readonly views, and practical wrapper
patterns.

## Persistent Signals

Use `PersistSignal<T>` when the initial read completes synchronously. Pass
direct callbacks to the unnamed constructor when key lookup, fallback, or
encoding is local to one value:

```dart
final theme = PersistSignal(
  read: () => prefs.getString('theme') ?? 'light',
  write: (value) => prefs.setString('theme', value),
);

theme.value = 'dark';
await theme.ensureWrite();
```

Use `AsyncPersistSignal<T>` when the initial read returns a `Future<T>`. Its
value is `AsyncState<T>`: construction starts in loading, then the read becomes
success or error without being written back. The shared async-state readable
helpers work directly on it:

```dart
final profileName = AsyncPersistSignal<String>(
  read: api.loadName,
  write: api.saveName,
);

final label = Computed(() => profileName.map(
  loading: () => 'Loading',
  success: (name) => name,
  error: (error, _) => 'Failed: $error',
));

profileName.set('Ada');
await profileName.ensureWrite();
```

Use `setFuture` when the new value is asynchronous. It publishes loading
immediately. Only its successful result is written, and only if that Future is
still current; a current failure becomes `AsyncError` without writing:

```dart
profileName.setFuture(api.loadSuggestedName());
await profileName.ensureWrite();
```

Direct `value` assignment follows the state: `AsyncSuccess<T>` persists its
value, while `AsyncLoading<T>` and `AsyncError<T>` only replace reactive state.
Every explicit assignment supersedes a pending read or older `setFuture`.

Implement `PersistSignalStorage<K>` when several signals share typed keyed
storage:

```dart
abstract interface class PersistSignalStorage<K> {
  FutureOr<T> read<T>(K key, [T Function()? initial]);
  FutureOr<void> write<T>(K key, T value);
}

final theme = settingsStorage.sync<String>(
  key: 'theme',
  initial: () => 'light',
);

final profile = settingsStorage.async<Profile>(
  key: 'profile',
);
```

Use the static factories when the storage is not the natural receiver:

```dart

final theme = PersistSignal.storage<String, String>(
  key: 'theme',
  initial: () => 'light',
  storage: settingsStorage,
);

final profile = AsyncPersistSignal.storage<String, Profile>(
  key: 'profile',
  storage: settingsStorage,
);
```

The `PersistSignalStorageX<K>` methods infer `K` from the receiver and are
otherwise equivalent to their static factories. They forward `key`, optional
`initial`, and optional `debug` unchanged.

Let storage decide whether a key is missing, whether to invoke the optional
`initial` callback, and what to do when no initial callback is supplied. Use
`PersistSignal.storage<K, T>` only when `read` returns `T` synchronously; use
`AsyncPersistSignal.storage<K, T>` for either synchronous or asynchronous
reads.

Keep throttling, debouncing, serialization, coalescing, retry, transactions,
and codecs inside the direct callbacks or storage adapter. Jolt invokes
synchronous success writes immediately; `setFuture` writes after it successfully
resolves while still current. `ensureWrite()` ignores the initial read, waits
for the current explicit Future assignment, and then waits for the most recent
write Future, but does not drain older overlapping writes.

## ConvertComputed

`ConvertComputed<T, U>` exposes a writable converted view over a writable
source.

```dart
final cents = Signal(1250);

final dollars = ConvertComputed<String, int>(
  cents,
  decode: (value) => (value / 100).toStringAsFixed(2),
  encode: (value) => (double.parse(value) * 100).round(),
);

dollars.value = '20.00';
print(cents.value);
```

Use it for format/parse pairs, unit conversion, enum/string views, and form
field adapters.

Keep `decode` and `encode` deterministic. Surface validation errors at the
write boundary or wrap them in command methods if user input may be invalid.

## Readonly Views

The smallest public read surface is usually `Readable<T>`:

```dart
final Signal<int> _count = Signal(0);
late final Readable<int> count = _count;
```

Use `readonly()` when an API specifically wants a `Readonly<T>` object:

```dart
late final Readonly<int> countView = _count.readonly();
```

Both prevent assignment through the public type.

## Wrapper Pattern

Wrap a signal when you need domain-specific names and invariants.

```dart
class PageIndex {
  final Signal<int> _value = Signal(0);

  late final Readable<int> value = _value;

  void goTo(int index) {
    if (index < 0) return;
    _value.value = index;
  }

  void reset() {
    _value.value = 0;
  }
}
```

Prefer a small wrapper over exposing a raw writable signal when business rules
are expected to grow.

## Update Helpers

Use `Writable.update` for read-modify-write without tracking the current read.

```dart
count.update((value) => value + 1);
```

Use `Writable.set` for method-style assignment:

```dart
count.set(0);
```

## Avoid

- Using a persistent signal for every value just because storage exists.
  Persist only state that owns storage semantics.
- Using `ConvertComputed` when conversion is not reversible enough to support
  assignment.
- Exposing `Readonly` when `Readable` is sufficient for the API.
- Putting validation only inside `encode` if callers need user-facing errors.
