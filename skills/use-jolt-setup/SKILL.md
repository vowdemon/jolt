---
name: use-jolt-setup
description: Use when building Flutter widgets in a setup-once / hooks-driven composition style — declaring signals, controllers, listenables, effects, timers, and lifecycle callbacks through `use*` hooks inside a `setup` function that runs once, owns and disposes those resources, and returns a builder for reactive rebuilds. Provides SetupWidget, SetupMixin (on existing StatefulWidget), and SetupBuilder.
---

# Use Jolt Setup

`package:jolt_setup/jolt_setup.dart` brings a Vue/React-style composition model to Flutter on top of Jolt. A widget has two phases:

1. **Setup phase** — a `setup` function runs **once** per widget identity. Inside it, `use*` hooks declare every long-lived resource: signals, controllers, listenables, effects, timers, lifecycle callbacks. The setup function returns a `WidgetFunction` (`() => Widget`) that closes over those resources.
2. **Build phase** — the returned builder is invoked on every rebuild. Reactive reads (`signal.value`, `controller.value`, etc.) inside the builder are tracked through a `PostFrameEffect`, so changes coalesce to one rebuild at frame end.

The package re-exports `package:jolt_flutter/jolt_flutter.dart`, so `Signal`, `Computed`, `Effect`, `JoltBuilder`, `PostFrameEffect`, `.listenable` / `.notifier`, etc. come along.

All hooks live in [`references/hooks.md`](references/hooks.md). This file focuses on the three entry surfaces that own a setup runtime: `SetupWidget`, `SetupMixin`, and `SetupBuilder`.

## Choosing an Entry Surface

| Situation | Use |
| --- | --- |
| New widget; want a dedicated immutable widget type and reactive `props` | `SetupWidget<T>` |
| Existing `StatefulWidget` whose `State<T>` you must keep (custom methods, mixins, external API) | `SetupMixin<T>` |
| Local composition, prototypes, leaf widgets — no need for a named widget class | `SetupBuilder` |

All three share the same setup model below; they only differ in how they bind a `setup` callback to the Flutter element tree.

## The Setup Runtime (shared by all three)

Every entry surface creates a `SetupContext` that:

- Holds an `EffectScope` so signals/effects created during setup are automatically disposed when the widget unmounts.
- Records the **ordered list of hooks** registered through `useHook` / `use*`. Hot reload reuses hooks by sequence position and runtime type; a mismatch unmounts the tail and re-mounts new hooks.
- Owns a `PostFrameEffect` "renderer" that wraps the returned builder. Reactive reads inside the builder track this effect, so dependency changes schedule `markNeedsBuild` at frame end.
- Forwards Flutter element lifecycle (`didUpdateWidget`, `didChangeDependencies`, `activate`, `deactivate`, `unmount`, `reassemble`) to each hook, in registration order on activate, reverse order on deactivate/unmount.
- Exposes `resetSetup()` — schedules a full setup rerun at frame end (tears down hooks + renderer, runs `setup` again). Use only when the initialization boundary itself must rebuild; ordinary state changes belong in signals/effects.

Implication: **don't put conditional `use*` calls behind `if` / loops** that can change between rebuilds, and **don't call `use*` outside `setup`** — the hook index must be stable. (Bare reactive reads through `.value` happen in the **builder**, not in `setup` itself, unless you want them as setup-time dependencies of an effect/computed.)

## `SetupWidget<T>`

A new widget base class. Override `setup(BuildContext context, Props<T> props)`; the returned `WidgetFunction<T>` is the builder. `Props<T>` is a reactive view of the current widget instance — read `props()` or `props.value` to subscribe to widget-field changes from the parent.

```dart
class CounterCard extends SetupWidget<CounterCard> {
  const CounterCard({
    super.key,
    required this.title,
    required this.initialValue,
  });

  final String title;
  final int initialValue;

  @override
  setup(context, props) {
    final count = useSignal(props().initialValue);
    final label = useComputed(() => '${props().title}: ${count.value}');

    onMounted(() => debugPrint('mounted: ${props().title}'));

    return () => GestureDetector(
      onTap: () => count.value++,
      child: Text(label.value),
    );
  }
}
```

Use `SetupWidget` when the component has a clear identity (constructor fields, public API) and parent updates to those fields should flow into setup-owned state through `props`.

## `SetupMixin<T>` (on `State<T>`)

Mixes into an existing `State<T>` subclass. Override `WidgetFunction<T> setup(BuildContext context)`; access widget fields via the mixin getter `props` (reactive) or `widget` (plain Flutter). All `State` lifecycle and instance methods remain available — the mixin only adds the setup runtime on top.

```dart
class _WelcomePanelState extends State<WelcomePanel>
    with SetupMixin<WelcomePanel> {
  late AnimationController controller;

  void show() => controller.forward();
  void hide() => controller.reverse();

  @override
  setup(context) {
    controller = useAnimationController(
      duration: const Duration(milliseconds: 250),
    );

    return () => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(opacity: controller, child: const FlutterLogo(size: 72)),
        Row(children: [
          FilledButton(onPressed: show, child: const Text('Show')),
          OutlinedButton(onPressed: hide, child: const Text('Hide')),
        ]),
      ],
    );
  }
}
```

Use `SetupMixin` when you must keep a custom `State<T>` — e.g. to expose instance methods to a `GlobalKey`, mix in other `State` mixins, satisfy a base class, or migrate an existing widget incrementally.

Important: setup runs on **first build**, not in `initState`, because hooks may read inherited widgets (`Theme.of(context)` via `useInherited`). Override `initState` only for work that does not depend on setup-owned state.

## `SetupBuilder`

A `SetupWidget<SetupBuilder>` constructed from an inline callback. No widget class needed; the `setup` callback receives `BuildContext` (no typed `props`, since the widget identity is `SetupBuilder` itself).

```dart
SetupBuilder(
  setup: (context) {
    final count = useSignal(0);
    useEffect(() => debugPrint('count = ${count.value}'));

    return () => FilledButton(
      onPressed: () => count.value++,
      child: Text('Count: ${count.value}'),
    );
  },
)
```

Use `SetupBuilder` for local composition, reactive leaf widgets in larger build methods, prototypes, or anywhere the cost of declaring a `SetupWidget` subclass outweighs its benefit. Each `SetupBuilder` in a parent build is a separate widget identity and gets its own setup runtime.

## Hooks at a Glance

Hooks are top-level `use*` functions (or `use*.variant(...)` factories) that must be called inside a setup function. They fall into a few buckets:

- **Reactive primitives** — `useSignal` (+ `.lazy/.list/.map/.set/.iterable/.async`), `useComputed` (+ `.withPrevious/.writable/...`), `useEffect`, `usePostFrameEffect`, `useWatcher` (+ `.immediately/.once`), `useEffectScope`, `useUntil` (+ `.when/.changed`).
- **Lifecycle callbacks** — `onMounted`, `onUnmounted`, `onDidUpdateWidget`, `onDidChangeDependencies`, `onActivated`, `onDeactivated`.
- **Context & memo** — `useContext`, `useSetupContext`, `useInherited`, `useMemoized`, `useAutoDispose`, `useHook` (+ `SetupHook<T>` for custom hooks).
- **Flutter controllers** — text/scroll/page/tab/animation/focus/etc. (auto-disposed).
- **Listenable & sync bridges** — `useValueNotifier`, `useChangeNotifier`, `useListen.{value,listenable,stream}` (+ `.watch`), `useSync.{from,bidi}`.
- **Async** — `useFuture` (+ `.watch`), `useStream` (+ `.watch`), `useStreamController` (+ `.broadcast`).
- **Misc** — `useTimer` (+ `.periodic`), `useAppLifecycleState`, `useAutomaticKeepAlive` (+ `.value`), experimental `useSetupReset` family.

Full signatures, variants, lifecycle behavior, and examples are in [`references/hooks.md`](references/hooks.md). To write your own hook — function-style, class-style (`SetupHook<T>`), or extension-style attached to a built-in creator like `useSignal.myThing` — see [`references/custom-hooks.md`](references/custom-hooks.md).

## Rules

- Call `use*` only at the top level of `setup` — never inside conditionals, loops, callbacks, or after early returns. The hook index must be stable across rebuilds.
- Return only the `() => Widget` from `setup`. Don't return computed widgets directly; let the builder close over reactive state so rebuilds work.
- Long-lived resources belong in hooks (`useSignal`, `useMemoized`, controller hooks); they auto-dispose. Don't `new` them in `setup` without a hook unless you also handle disposal via `onUnmounted` or an `EffectScope`.
- Use `props()` (`SetupWidget`) or the `props` getter (`SetupMixin`) when setup-owned state must react to parent updates; raw `widget.foo` reads in `setup` are captured only at the first run.
- `resetSetup()` is a heavy escape hatch (rebuilds the whole hook sequence). Prefer ordinary signal updates.
- Reading inherited widgets inside `setup`: use `useInherited((c) => Theme.of(c))` so dependency changes invalidate the cached value reactively. Plain `Theme.of(context)` works too but isn't reactive past the initial setup.

## Source Navigation

Read source before answering API-sensitive questions.

| Area | Path |
| --- | --- |
| Public exports | `packages/jolt_setup/lib/jolt_setup.dart` |
| `SetupContext`, `SetupHook`, lifecycle plumbing | `packages/jolt_setup/lib/src/setup/framework.dart` |
| `SetupWidget`, `SetupBuilder`, `SetupWidgetElement` | `packages/jolt_setup/lib/src/setup/widget.dart` |
| `SetupMixin` | `packages/jolt_setup/lib/src/setup/stateful_mixin.dart` |
| Built-in hooks | `packages/jolt_setup/lib/src/hooks/` |
| Example | `packages/jolt_setup/example/jolt_setup_example.dart` |
| Tests | `packages/jolt_setup/test/` |
