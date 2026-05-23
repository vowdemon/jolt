---
name: use-jolt-flutter
description: Use when Flutter widgets need to track Jolt signals and rebuild automatically when those signals change — typically with JoltBuilder — or when converting between Flutter Listenable / ValueNotifier and Jolt signals.
---

# Use Jolt Flutter

`package:jolt_flutter/jolt_flutter.dart` covers two responsibilities:

1. Track Jolt signals from inside a Flutter widget and rebuild it automatically when those signals change.
2. Convert between Flutter `Listenable` / `ValueNotifier` and Jolt signals in either direction.

It re-exports `package:jolt/jolt.dart`, so importing only `jolt_flutter` brings `Signal`, `Computed`, `Effect`, `Watcher`, `batch`, and `Readable` along. Use `use-jolt` for pure Dart state with no widget or `Listenable` boundary.

## API Choice Table

| Need | Use |
| --- | --- |
| Rebuild a subtree from every reactive `.value` read in `build` | `JoltBuilder` |
| Rebuild only from explicitly declared dependencies | `JoltBuilder.manual(deps: [...])` |
| Rebuild from a single `Readable<T>` | `JoltWatcher<T>` / `JoltWatcher.value` |
| Inline shorthand for one `Readable<T>` | `readable.watch((v) => ...)` |
| Rebuild only when a derived value changes by `!=` | `JoltSelector<T>` |
| Reactive callback that runs at frame end | `PostFrameEffect` |
| Expose `Readable<T>` as `ValueListenable<T>` | `readable.listenable` / `JoltValueListenable<T>` |
| Expose `Writable<T>` as `ValueNotifier<T>` (two-way) | `writable.notifier` / `JoltValueNotifier<T>` |
| Treat `ValueListenable<T>` as a Jolt `Readable<T>` | `valueListenable.toListenableSignal()` |
| Treat `ValueNotifier<T>` as a Jolt `Signal<T>` | `valueNotifier.toNotifierSignal()` |

Scope precision, narrowest first: `JoltSelector` > `JoltWatcher` > `JoltBuilder` > `JoltBuilder.manual`.

## Widgets

### `JoltBuilder` — auto-tracked rebuilds

Every `.value` read inside `builder` subscribes the widget. Multiple changes in one frame coalesce into a single rebuild.

```dart
final count = Signal(0);
final doubled = Computed(() => count.value * 2);

JoltBuilder(
  builder: (context) => Column(children: [
    Text('count: ${count.value}'),
    Text('doubled: ${doubled.value}'),
  ]),
);
```

### `JoltBuilder.manual` — explicit deps

Reactive reads in `builder` display fresh values but do **not** subscribe; only entries in `deps` drive rebuilds.

```dart
JoltBuilder.manual(
  deps: [visibleCount],
  builder: (context) => Text('${label.value}: ${visibleCount.value}'),
);
```

### `JoltWatcher` — single readable

`JoltWatcher.value` omits `BuildContext`. `readable.watch(...)` is the shortest form.

```dart
JoltWatcher<int>(readable: count, builder: (context, v) => Text('$v'));
count.watch((v) => Text('$v'));
```

### `JoltSelector` — narrow by a derived value

`selector` runs in a reactive scope and receives the previous result (`null` on first run). The widget rebuilds only when the new result is unequal (`!=`) to the previous one.

```dart
final user = Signal(User(name: 'Ada', age: 30));

JoltSelector<String>(
  selector: (_) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
);
```

## Frame Effects

`PostFrameEffect` works like core `Effect`, but notifications coalesce through `SchedulerBinding.endOfFrame`. Use it for reactive work that touches layout, `BuildContext`, controllers, focus, or navigation.

```dart
late final PostFrameEffect effect;
final size = Signal(Size.zero);

effect = PostFrameEffect(() {
  debugPrint('size: ${size.value}');
});

effect.dispose();
```

Flags: `lazy: true` defers the first run until `run()`; `detach: true` keeps the effect from retaining its enclosing scope; pass `debug: JoltDebugOption.type('...')` for meaningful labels in debug tools.

## Listenable Bridges

### Jolt → Flutter

`readable.listenable` and `writable.notifier` return cached wrappers (`JoltValueListenable<T>` / `JoltValueNotifier<T>`) until disposed. `notifier` is two-way: writes from either side propagate.

```dart
ValueListenableBuilder<int>(
  valueListenable: count.listenable,
  builder: (context, v, _) => Text('$v'),
);

final controller = count.notifier;
controller.value = 1; // count.value == 1
count.value = 2;      // controller.value == 2
```

Dispose long-lived bridges when their owner ends; the extension getter creates a fresh wrapper on next access.

### Flutter → Jolt

`toListenableSignal()` returns a read-only `Readable<T>`; `toNotifierSignal()` returns a writable `Signal<T>`. If the source is already a `JoltValueListenable` / `JoltValueNotifier`, the original Jolt node is returned — no extra wrapper.

```dart
final tab = ValueNotifier(0);
final readableTab = tab.toListenableSignal();

JoltBuilder(builder: (context) => Text('tab: ${readableTab.value}'));

final textCtrl = ValueNotifier('');
final textSignal = textCtrl.toNotifierSignal();
textSignal.value = 'ready'; // textCtrl.value == 'ready'
```

`ValueListenableSignal<T>` and `ValueNotifierSignal<T>` are the concrete cached types. Prefer the extension methods unless a test or integration needs the concrete type. After disposal these bridges keep their last value; writes to a disposed writable bridge are ignored.

## Rules

- Create mutable Jolt state outside `build` (in a model, `State`, or owner) and dispose owners explicitly.
- Match the widget to the dependency surface: prefer the narrowest that still captures the truly UI-driving reads.
- Use `JoltBuilder.manual` when `.value` reads in `build` are incidental and should not subscribe.
- Reach for `PostFrameEffect` only when the callback needs frame timing or Flutter context; use core `Effect` for plain reactions.
- Dispose bridges, frame effects, and owned signals when the Flutter owner is disposed.

## Source Navigation

Read source before answering API-sensitive questions.

| Area | Path |
| --- | --- |
| Public exports | `packages/jolt_flutter/lib/jolt_flutter.dart` |
| Reactive widgets | `packages/jolt_flutter/lib/src/widgets/` |
| Frame effect | `packages/jolt_flutter/lib/src/effect/post_frame_effect.dart` |
| Listenable bridges | `packages/jolt_flutter/lib/src/listenable/` |
| Example | `packages/jolt_flutter/example/jolt_flutter_example.dart` |
| Tests | `packages/jolt_flutter/test/` |
