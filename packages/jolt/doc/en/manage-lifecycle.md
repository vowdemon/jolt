# Manage Lifecycle

A screen often starts several pieces of reactive work together: remote search,
analytics, subscriptions, maybe a watcher for transitions.

When they share one lifecycle, put them in an `EffectScope`:

```dart
final EffectScope _scope = EffectScope();

void dispose() {
  _scope.dispose();
}
```

Create related reactions inside `run()`:

```dart
_scope.run(() {
  Effect(() {
    final text = session.query.value.trim();
    if (text.isEmpty) return;

    final timer = Timer(const Duration(milliseconds: 300), () {
      unawaited(remoteSearch(text));
    });

    onEffectCleanup(timer.cancel);
  });
});
```

The scope disposes the effect created inside `run()`. It also runs cleanup
registered by that effect, such as the debounce timer cancellation.

A watcher can join the same scope:

```dart
_scope.run(() {
  Watcher<int>(
    () => session.results.value.length,
    (next, previous) {
      print('result count: $previous -> $next');
    },
  );
});
```

Use a scope when the same screen, route, request, test, or temporary workflow
creates several reactions and later disposes them together.

## Add Plain Dart Cleanup

If code inside the scope opens a stream subscription, controller, or other Dart
resource, register cleanup explicitly:

```dart
_scope.run(() {
  final subscription = events.listen(print);
  onScopeDispose(subscription.cancel);
});
```

`EffectScope` groups Jolt reactions. `onScopeDispose()` lets ordinary resources
use the same cleanup point.

## Detached Work

`detach: true` keeps an effect out of the current scope:

```dart
final appStateLogger = Effect(
  () => print(appState.value),
  detach: true,
);
```

Use it only when code outside the current scope will dispose that effect:

```dart
appStateLogger.dispose();
```

Do not create reactions and leave their lifecycle implicit. If you store an
`Effect` or `Watcher` in a field, dispose that field. If you create reactions
inside `scope.run()`, dispose the scope.

## Next Step

Connect the same model to batches, streams, async state, persistence, and
narrower read surfaces in [Advanced Techniques](Advanced%20Techniques-topic.html).
