# Jolt

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![jolt](https://img.shields.io/pub/v/jolt?label=jolt)](https://pub.dev/packages/jolt)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Fine-grained reactive state for Dart and Flutter.

Jolt gives you three small building blocks: `Signal` for writable state,
`Computed` for values derived from state, and `Effect` for work that reacts to
changes. No code generation, no widget context, no manual subscription wiring.

## A Small Example

```dart
import 'package:jolt/jolt.dart';

final query = Signal('');
final documents = Signal([
  'Signals store state',
  'Computed values derive state',
  'Effects run after state changes',
]);

final results = Computed(() {
  final text = query.value.trim().toLowerCase();
  if (text.isEmpty) return documents.value;

  return documents.value
      .where((document) => document.toLowerCase().contains(text))
      .toList();
});

final resultCountEffect = Effect(() {
  print('${results.value.length} result(s) for "${query.value}"');
});

query.value = 'state';
query.value = 'effect';

resultCountEffect.dispose();
```

Change a signal, and the values that read it update automatically. Derived
values stay in sync without being stored twice. Effects are explicit objects,
so the code that starts an effect also decides when to dispose it.

## Why Jolt?

- Plain Dart first: keep state in normal classes, then connect it to Flutter
  when the UI needs it.
- Fine-grained updates: reactions track the exact values they read.
- Derived state without bookkeeping: compute `filteredItems`, `isValid`, or
  `summaryText` from current state instead of syncing extra fields.
- Clear lifecycle: dispose an `Effect` / `Watcher` directly, or group related
  reactions in an `EffectScope`.
- Practical tools included: batching, watchers, streams, async state, and
  persistence helpers.

## Packages

Use `jolt` for core reactive state. Add a sibling package only when you need a
specific integration:

- `jolt_flutter` for Flutter rebuilds from Jolt reads.
- `jolt_setup` for setup-style widget logic with cleanup.
- `jolt_hooks` for projects using `flutter_hooks`.
- `jolt_surge` for a container-style layer on top of Jolt.

## Learn More

Start with the [Quick Start](https://pub.dev/documentation/jolt/latest/topics/Quick%20Start-topic.html)
or jump to the [API reference](https://pub.dev/documentation/jolt/latest/jolt/).

## License

MIT
