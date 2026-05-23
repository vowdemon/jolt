# EffectScope Reference

Use this reference when multiple signals, effects, watchers, waits, or ordinary
resources share one lifecycle.

## Core Idea

`EffectScope` is a disposal boundary. Reactions created inside `run()` belong
to that scope unless they are detached.

```dart
import 'package:jolt/jolt.dart';

final scope = EffectScope();
final query = Signal('');

scope.run(() {
  Effect(() => print(query.value));
});

scope.dispose();
```

Use scopes for screens, routes, requests, tests, sessions, or temporary
workflows that create several related reactions.

## Plain Dart Cleanup

Use `onScopeDispose` for non-Jolt resources owned by the scope.

```dart
final scope = EffectScope();

scope.run(() {
  final subscription = events.listen(print);
  onScopeDispose(subscription.cancel);
});

scope.dispose();
```

This keeps Jolt reactions and ordinary resources under the same lifecycle.

## Scope Ownership Pattern

Store the scope in the object that owns the lifecycle.

```dart
class SearchSession {
  final EffectScope _scope = EffectScope();
  final Signal<String> _query = Signal('');

  SearchSession() {
    _scope.run(() {
      Effect(() {
        print('query = ${_query.value}');
      });
    });
  }

  void dispose() {
    _scope.dispose();
  }
}
```

Do not create a scope if nothing owns its disposal.

## Nested Scopes

Nested scopes are useful when a subtask should be disposed before the parent.

```dart
final parent = EffectScope();

late EffectScope child;

parent.run(() {
  child = EffectScope();
  child.run(() {
    Effect(() => print(activeItem.value));
  });
});

child.dispose();
parent.dispose();
```

Use `detach: true` for a child scope only when parent disposal should not
dispose it and another owner is responsible.

```dart
final detached = EffectScope(detach: true);
```

## Detached Reactions

`Effect` and `Watcher` also accept `detach`. A detached reaction is not owned by
the active scope.

```dart
scope.run(() {
  final globalLogger = Effect(
    () => print(appState.value),
    detach: true,
  );

  onScopeDispose(() {
    // This cleanup is optional ownership wiring chosen by this scope.
    globalLogger.dispose();
  });
});
```

Prefer normal scoped ownership unless there is a concrete reason to detach.

## Tests

Scopes are useful in tests because they centralize cleanup.

```dart
final scope = EffectScope();
addTearDown(scope.dispose);

scope.run(() {
  Effect(() => values.add(signal.value));
});
```

## Avoid

- Creating effects and watchers in a scope but never disposing the scope.
- Using `detach: true` to silence lifecycle questions.
- Registering cleanup far away from the resource it owns.
- Treating `EffectScope` as a dependency injection container; it is a lifecycle
  boundary, not an app architecture by itself.
