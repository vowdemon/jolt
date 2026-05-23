# AsyncSignal Reference

Use this reference when a signal must represent loading, success, and error
state from a `Future`, `Stream`, or replaceable async source.

## Core Idea

`AsyncSignal<T>` is a `Signal<AsyncState<T>>`. It publishes `AsyncLoading`,
`AsyncSuccess<T>`, or `AsyncError`.

```dart
import 'package:jolt/jolt.dart';

final user = AsyncSignal.fromFuture(loadUser());

final label = Computed(() {
  return user.map(
    loading: () => 'Loading',
    success: (value) => value.name,
    error: (error, _) => 'Failed: $error',
  );
});
```

Read it like any other signal from computed values, effects, or UI integration
layers.

## Creating Async Signals

Use a future source for one result:

```dart
final profile = AsyncSignal.fromFuture(api.loadProfile());
```

Use a stream source for repeated results:

```dart
final messages = AsyncSignal.fromStream(messageStream);
```

Use the general constructor when the source may be supplied or replaced later:

```dart
final searchResults = AsyncSignal<List<Result>>();

await searchResults.fetch(
  FutureSource(api.search('jolt')),
);
```

## Reading State

Use convenience getters for simple branches:

```dart
if (profile.isLoading) {
  print('loading');
}

if (profile.isSuccess) {
  print(profile.data);
}

if (profile.isError) {
  print(profile.error);
}
```

Use `map` for computed presentation state:

```dart
final message = Computed(() {
  return profile.map(
    loading: () => 'Loading profile',
    success: (value) => 'Hello ${value.name}',
    error: (error, _) => 'Could not load profile: $error',
  );
});
```

## Source Replacement

`fetch` replaces the current source. Late emissions from older sources are
ignored.

```dart
final results = AsyncSignal<List<Result>>();

Future<void> runSearch(String query) {
  return results.fetch(FutureSource(api.search(query)));
}
```

This is useful for search, route changes, and user-driven reloads.

## Initial State

The default initial state is loading. Supply `initialValue` when another state
is more useful before the first source emits.

```dart
final cache = AsyncSignal<List<Item>>(
  initialValue: AsyncSuccess(const []),
);
```

## AsyncSignal Or Effect

Use `AsyncSignal` when async progress is itself state that other code should
read.

Use `Effect` when async work is only a side effect and the state is modeled
elsewhere.

```dart
final query = Signal('');
final results = AsyncSignal<List<Result>>();

final searchEffect = Effect(() {
  final text = query.value.trim();
  if (text.isEmpty) return;

  results.fetch(FutureSource(api.search(text)));
});
```

Guard against request storms with debounce, `Watcher`, or explicit command
methods when needed.

## Stream Notes

`AsyncSignal.fromStream` updates as the stream emits. Dispose or replace the
source through the owning model's lifecycle when the stream should end.

For converting a readable into a stream of its changes, use
`readable.stream` or `readable.listen(...)`; see `advanced.dart`.

## Avoid

- Hiding loading and error in nullable data.
- Writing separate `isLoading`, `error`, and `data` signals when one
  `AsyncSignal` should represent the state.
- Starting async work inside `Computed`.
- Ignoring source replacement and letting stale async results overwrite newer
  state.
