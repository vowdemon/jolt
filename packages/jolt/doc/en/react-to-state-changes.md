# React To State Changes

Filtering local documents is derived state. Fetching remote results is work.

Use an effect for work that follows reactive reads. This effect debounces the
query before calling a remote search function:

```dart
_remoteSearchEffect = Effect(() {
  final text = query.value.trim();
  if (text.isEmpty) return;

  final timer = Timer(const Duration(milliseconds: 300), () {
    unawaited(search(text));
  });

  onEffectCleanup(timer.cancel);
});
```

`onEffectCleanup()` runs before the effect runs again and when the effect is
disposed. In this example it cancels the previous debounce timer before a new
timer is scheduled.

Keep the effect in the class that started it:

```dart
class RemoteSearch {
  late final Effect _remoteSearchEffect;

  RemoteSearch({
    required Readable<String> query,
    required Future<void> Function(String query) search,
  }) {
    _remoteSearchEffect = Effect(() {
      // debounce and call search
    });
  }

  void dispose() {
    _remoteSearchEffect.dispose();
  }
}
```

The effect is the long-running part here, not the `Timer`; the timer is created
by one run of the effect and cleaned up before the next run.

## Watch A Transition

Use `Watcher` when the change itself matters:

```dart
final queryWatcher = Watcher<String>(
  () => session.query.value,
  (next, previous) {
    print('query changed from "$previous" to "$next"');
  },
);

queryWatcher.dispose();
```

Most work only needs current values, so `Effect` is the default. Use `Watcher`
when the callback needs both previous and next values, or when you need watcher
controls such as pause, resume, or once.

At this point the search feature has state, derived values, and reactive work.

## Next Step

Move related reactions into one scope in
[Manage Lifecycle](Manage%20Lifecycle-topic.html).
