## jolt_surge

A lightweight, signal-driven state container and Flutter widget set built on top of Jolt Signals. It provides predictable rebuilds, composable listeners, and selector-based rendering with fine-grained tracking control.


### Key Concepts
- Surge<State>: a small state container with `state`, `emit(next)`, `dispose()`, and `SurgeObserver` hooks.
- Widgets:
  - SurgeProvider: provide a `Surge` instance via `create` or `.value`.
  - SurgeConsumer: unified consume point with `builder`, `listener`, `buildWhen`, `listenWhen`.
  - SurgeBuilder: `builder`-only convenience.
  - SurgeListener: `listener`-only convenience.
  - SurgeSelector: rebuilds only when selected value changes (by `==`).

Tracking semantics:
- builder and listener are strictly non-tracked (untracked).
- buildWhen, listenWhen, selector are tracked by default (they can depend on external signals). To opt-out, wrap your reads with `untracked(() => ...)` or use `peek`.

## Quick Start

### Define a Surge
```dart
import 'package:jolt_surge/jolt_surge.dart';

class CounterSurge extends Surge<int> {
  CounterSurge() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);

  @override
  void onChange(Change<int> change) {
    // optional: observe transitions
  }
}
```

### Provide and consume
```dart
SurgeProvider<CounterSurge>(
  create: (_) => CounterSurge(), // auto-disposed on unmount
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, surge) => Text('count: $state'),
  ),
);
```

Using `.value` (you manage lifecycle):
```dart
final surge = CounterSurge();

SurgeProvider<CounterSurge>.value(
  value: surge, // not auto-disposed
  child: SurgeBuilder<CounterSurge, int>(
    builder: (context, state, s) => Text('count: $state'),
  ),
);
```

### Actions (emit state)
```dart
ElevatedButton(
  onPressed: () => context.read<CounterSurge>().increment(),
  child: const Text('Increment'),
);
```

## Widgets

### SurgeConsumer
- builder: non-tracked UI build.
- listener: non-tracked side effect (runs when effect recomputes).
- buildWhen(prev, next, surge): tracked condition for rebuilding.
- listenWhen(prev, next, surge): tracked condition for listener.

```dart
SurgeConsumer<CounterSurge, int>(
  buildWhen: (prev, next, s) => next.isEven, // tracked
  listenWhen: (prev, next, s) => next > prev, // tracked
  builder: (context, state, s) => Text('count: $state'),
  listener: (context, state, s) {
    // e.g., SnackBar or analytics
  },
);
```

Disable tracking for a condition:
```dart
buildWhen: (prev, next, s) => untracked(() => shouldRebuildSignal.value),
```

### SurgeBuilder
```dart
SurgeBuilder<CounterSurge, int>(
  builder: (context, state, s) => Text('count: $state'),
);
```

### SurgeListener
```dart
SurgeListener<CounterSurge, int>(
  listener: (context, state, s) {
    // side-effect only
  },
  child: const SizedBox.shrink(),
);
```

### SurgeSelector
Rebuild only when the selected value changes by equality.
```dart
SurgeSelector<CounterSurge, int, String>(
  selector: (state, s) => state.isEven ? 'even' : 'odd', // tracked by default
  builder: (context, selected, s) => Text(selected),
);
```

Disable selector tracking:
```dart
selector: (state, s) => untracked(() => externalSignal.valueAsLabel(state)),
```

## Direct surge param (bypass Provider)
You can pass a `surge` directly to any widget; it will ignore outer providers and follow instance changes:
```dart
final s1 = CounterSurge();
final s2 = CounterSurge();

Widget view(CounterSurge surge) => SurgeBuilder<CounterSurge, int>(
  surge: surge,
  builder: (context, state, s) => Text('count: $state'),
);

// swap instances to follow a new surge
```