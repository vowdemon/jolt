# Ecosystem

Stay in `jolt` while the problem is reactive state: source values, derived
values, effects, watchers, scopes, streams, async state, and persistence.

Move to another package only when the surrounding app needs a specific
integration.

## Stay In `jolt`

`SearchSession`, derived results, remote-search effects, and scopes all belong
in the core package. None of that requires Flutter.

## Add `jolt_flutter` For Rendering

Use `jolt_flutter` when Flutter should rebuild from reactive reads:

```dart
JoltBuilder(
  builder: (context) => Text(model.session.summary.value),
);
```

The builder tracks the Jolt values read inside it and rebuilds when they change.

## Add `jolt_setup` For Setup-Style Widgets

Use `jolt_setup` when widget code has setup-time resources: controllers, focus
nodes, subscriptions, local signals, effects, and cleanup that should live with
one widget instance.

## Add `jolt_hooks` For HookWidget Code

Use `jolt_hooks` when the surrounding Flutter code already uses
`flutter_hooks`:

```dart
final query = useSignal('');
final hasQuery = useComputed(() => query.value.trim().isNotEmpty);
```

That keeps Jolt resources in the hook lifecycle.

## Add `jolt_surge` For Container-Style Features

Use `jolt_surge` when a feature should expose a state value and named actions in
a Cubit-like class:

```dart
class SearchSurge extends Surge<SearchState> {
  SearchSurge() : super(const SearchState.empty());

  void setQuery(String query) {
    emit(state.copyWith(query: query));
  }
}
```

This is an architecture choice, not a requirement for using Jolt.

## Add `jolt_lint` During Development

Use `jolt_lint` for analyzer checks, assists, and migrations around Jolt and
setup-style code.
