# Tricks Reference

Use this reference for higher-level core helpers that shape signal APIs:
`PersistSignal`, `ConvertComputed`, readonly views, and practical wrapper
patterns.

## PersistSignal

`PersistSignal<T>` keeps an in-memory signal and writes assignments to external
storage.

Use synchronous factories when storage reads are immediate:

```dart
final theme = PersistSignal.sync(
  read: () => prefs.getString('theme') ?? 'light',
  write: (value) => prefs.setString('theme', value),
);

theme.value = 'dark';
await theme.ensureWrite();
```

Use asynchronous factories when loading needs a `Future`:

```dart
final profileName = PersistSignal.async(
  read: () => api.loadName(),
  write: (value) => api.saveName(value),
  initialValue: () => 'Loading',
);

await profileName.ensure();
print(profileName.value);
```

Use `throttle` to collapse fast writes:

```dart
final draft = PersistSignal.sync(
  read: () => storage['draft'] ?? '',
  write: (value) => storage['draft'] = value,
  throttle: const Duration(milliseconds: 300),
);
```

Call `ensureWrite()` before shutdown, navigation, or tests that need persisted
writes to finish.

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

- Using `PersistSignal` for every value just because storage exists. Persist
  only state that owns storage semantics.
- Using `ConvertComputed` when conversion is not reversible enough to support
  assignment.
- Exposing `Readonly` when `Readable` is sufficient for the API.
- Putting validation only inside `encode` if callers need user-facing errors.
