# Jolt Setup Hooks Reference

All hooks must be called inside a `setup` function (or a custom hook that is itself called inside `setup`). They register against the active `SetupContext`, are matched by position across hot reloads, and clean up when the setup scope unmounts.

Quick navigation:

- [Reactive primitives](#reactive-primitives) — `useSignal`, `useComputed`, `useEffect`, `usePostFrameEffect`, `useWatcher`, `useEffectScope`, `useUntil`
- [Lifecycle callbacks](#lifecycle-callbacks) — `onMounted`, `onUnmounted`, `onDidUpdateWidget`, `onDidChangeDependencies`, `onActivated`, `onDeactivated`
- [Context, memo, custom hooks](#context-memo-custom-hooks) — `useContext`, `useSetupContext`, `useInherited`, `useMemoized`, `useAutoDispose`, `useHook`, `SetupHook<T>`
- [Flutter controllers](#flutter-controllers) — text, scroll, page, tab, animation, focus, transformation, menu, magnifier, etc.
- [Listenable & sync bridges](#listenable--sync-bridges) — `useValueNotifier`, `useChangeNotifier`, `useListen`, `useSync`
- [Async](#async) — `useFuture`, `useStream`, `useStreamController`
- [Misc](#misc) — `useTimer`, `useAppLifecycleState`, `useAutomaticKeepAlive`, `useSetupReset`

---

## Reactive primitives

### `useSignal`

Creates a `Signal<T>` owned by the setup scope. Variants are namespaced on the same object.

```dart
final count   = useSignal(0);                  // Signal<int>
final lazy    = useSignal.lazy<int>();         // Signal<int> without initial
final items   = useSignal.list<String>([]);    // ListSignal
final byId    = useSignal.map<String, User>({});
final tags    = useSignal.set<String>({});
final visible = useSignal.iterable(() => items.where((i) => i.active));
final user    = useSignal.async(() => FutureSource(loadUser));
```

All signals are auto-disposed on unmount.

### `useComputed`

Creates a `Computed<T>`. Variants:

```dart
final doubled    = useComputed(() => count.value * 2);
final ranking    = useComputed.withPrevious<int>((prev) => count.value + (prev ?? 0));
final mirror     = useComputed.writable(() => count.value, (v) => count.value = v);
final mirrorPrev = useComputed.writableWithPrevious((prev) => ..., setter);
```

### `useEffect`

Reactive effect that runs immediately and on every dependency change.

```dart
useEffect(() {
  debugPrint('count: ${count.value}');
});

useEffect.lazy(() {/* first run deferred */});
```

The returned `Effect` is disposed automatically. Use `onEffectCleanup` (from `jolt`) inside the body for per-run cleanup.

### `usePostFrameEffect`

Same as `useEffect`, but the body coalesces to `SchedulerBinding.endOfFrame`. Use when the effect touches layout, controllers, focus, scroll, or `BuildContext`.

```dart
final scroll = useScrollController();
final atBottom = useSignal(false);

usePostFrameEffect(() {
  if (atBottom.value && scroll.hasClients) {
    scroll.jumpTo(scroll.position.maxScrollExtent);
  }
});
```

`usePostFrameEffect.lazy(...)` defers the first run.

### `useWatcher`

`Watcher` over a `sourcesFn`. Receives previous and new source values.

```dart
useWatcher(
  () => count.value,
  (current, previous) => debugPrint('$previous -> $current'),
);

useWatcher.immediately(() => count.value, fn);
useWatcher.once(() => count.value, fn);          // self-disposes after first call
```

Pass `when: (prev, next) => ...` to gate the callback.

### `useEffectScope`

Creates an `EffectScope` owned by the setup scope. Useful when several reactions should live and die together inside the setup boundary.

```dart
final scope = useEffectScope();

onMounted(() {
  scope.run(() {
    Effect(() => debugPrint(count.value.toString()));
  });
});
```

Pass `detach: true` to keep the scope from being attached to the current effect context.

### `useUntil`

Reactive wait helpers. The returned `Until<T>` implements `Future<T>`.

```dart
final ready  = useUntil(count, (v) => v >= 5);   // predicate
final isFive = useUntil.when(count, 5);          // equality
final any    = useUntil.changed(count);          // first change

onMounted(() async {
  await ready;
  debugPrint('threshold hit');
});
```

`Until` is cancelled automatically on unmount.

---

## Lifecycle callbacks

These mirror Flutter element lifecycle, registered against the setup runtime.

| Hook | Fires when |
| --- | --- |
| `onMounted(fn)` | After the current setup pass is mounted (all hooks created). |
| `onUnmounted(fn)` | When the setup scope unmounts. |
| `onDidUpdateWidget<T>((oldW, newW) => ...)` | Parent rebuilt with a new widget instance. Generic top-level form. |
| `onDidUpdateWidgetAt((oldW, newW) => ...)` | Same as above, on `SetupWidget` / `SetupMixin` where `T` is inferred. |
| `onDidChangeDependencies(fn)` | Inherited widget dependencies changed. |
| `onActivated(fn)` | Widget was reactivated after `deactivate`. |
| `onDeactivated(fn)` | Widget was temporarily removed from the tree. |

```dart
setup(context, props) {
  final socket = useMemoized(() => connect(), (s) => s.close());

  onMounted(socket.start);
  onDeactivated(socket.pause);
  onActivated(socket.resume);
  onUnmounted(socket.flush);

  return () => const SizedBox.shrink();
}
```

Inside a `SetupWidget<T>` or `SetupMixin<T>`, use `onDidUpdateWidgetAt((T oldW, T newW) {...})` for inferred widget typing.

---

## Context, memo, custom hooks

### `useContext()`

Returns the current `BuildContext` of the setup runtime. Useful inside reusable hooks that don't take `context` as a parameter.

```dart
final loc = MaterialLocalizations.of(useContext());
```

### `useSetupContext()`

Returns the active `SetupContext`. Used by advanced hook implementations or to access the underlying `EffectScope`.

### `useInherited<T>(getter, {debug})`

Reactive read of an inherited widget. Returns a `Computed<T>` that is invalidated when inherited dependencies change.

```dart
final theme = useInherited((c) => Theme.of(c));
return () => Text('Hi', style: theme.value.textTheme.bodyLarge);
```

Prefer this over plain `Theme.of(context)` in `setup` when the derived value must follow inherited updates.

### `useMemoized<T>(creator, [disposer])`

Memoizes a value for the lifetime of the hook slot. Optional `disposer` runs on unmount. The low-level building block for non-`ChangeNotifier` resources.

```dart
final controller = useMemoized(
  () => TextEditingController(text: props().title),
  (c) => c.dispose(),
);
```

### `useAutoDispose<T extends Disposable>(creator)`

Specialized `useMemoized` for Jolt `Disposable` types. Calls `state.dispose()` on unmount. Used internally by `useSignal`, `useComputed`, `useEffectScope`, etc.

### `useHook<T>(SetupHook<T>)` and `SetupHook<T>`

Register a custom hook. Subclass `SetupHook<T>` to implement `build()` plus any lifecycle methods you need (`mount`, `unmount`, `didUpdateWidget`, `didChangeDependencies`, `activate`, `deactivate`, `reassemble`).

```dart
class CounterHook extends SetupHook<int> {
  @override
  int build() => 0;
}

setup(context, props) {
  final count = useHook(CounterHook());
  return () => Text('$count');
}
```

Two ready-made bases are provided:

- `AutoDisposeHook<T extends Disposable>(creator)` — auto-disposes the state on unmount.
- `DisposableHook<T>(creator, [disposer])` — backs `useMemoized`.

---

## Flutter controllers

All controller hooks dispose the controller on unmount. They are built on `useChangeNotifier` or `useMemoized`.

### Text editing

| Hook | Returns |
| --- | --- |
| `useTextEditingController({text})` | `TextEditingController` |
| `useTextEditingController.fromValue(value)` | `TextEditingController` from a `TextEditingValue` |
| `useRestorableTextEditingController({text})` | `RestorableTextEditingController` |
| `useRestorableTextEditingController.fromValue(value)` | restorable from value |
| `useSearchController()` | `SearchController` |
| `useUndoHistoryController({value})` | `UndoHistoryController` |

### Scroll / paging

| Hook | Returns |
| --- | --- |
| `useScrollController({...})` | `ScrollController` |
| `useTrackingScrollController({...})` | `TrackingScrollController` |
| `useFixedExtentScrollController({...})` | `FixedExtentScrollController` |
| `usePageController({...})` | `PageController` |
| `useDraggableScrollableController()` | `DraggableScrollableController` |
| `useCarouselController({initialItem})` | `CarouselController` |

### Tabs / animation / ticker

| Hook | Returns |
| --- | --- |
| `useTabController({required length, ...})` | `TabController` (auto-vsync if omitted) |
| `useAnimationController({...})` | `AnimationController` (auto-vsync if omitted) |
| `useSingleTickerProvider()` | `TickerProvider` for one ticker |
| `useTickerProvider()` | `TickerProvider` for multiple tickers |
| `useCupertinoTabController({initialIndex})` | `CupertinoTabController` |

### Focus

| Hook | Returns |
| --- | --- |
| `useFocusNode({debugLabel, ...})` | `FocusNode` |
| `useFocusScopeNode({...})` | `FocusScopeNode` |

### Misc Material / Cupertino

| Hook | Returns |
| --- | --- |
| `useTransformationController([value])` | `TransformationController` |
| `useWidgetStatesController([value])` | `WidgetStatesController` |
| `useExpansibleController()` | `ExpansibleController` |
| `useTreeSliverController()` | `TreeSliverController` |
| `useOverlayPortalController({debugLabel})` | `OverlayPortalController` |
| `useSnapshotController({allowSnapshotting})` | `SnapshotController` |
| `useContextMenuController({onRemove})` | `ContextMenuController` |
| `useMenuController()` | `MenuController` |
| `useMagnifierController({animationController})` | `MagnifierController` |

Example:

```dart
setup(context, props) {
  final vsync   = useSingleTickerProvider();
  final tabs    = useTabController(length: 3, vsync: vsync);
  final scroll  = useScrollController();
  final focus   = useFocusNode();

  return () => Column(children: [
    TabBar(controller: tabs, tabs: const [Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C')]),
    Expanded(child: TabBarView(
      controller: tabs,
      children: [
        ListView(controller: scroll, children: const []),
        TextField(focusNode: focus),
        const Placeholder(),
      ],
    )),
  ]);
}
```

---

## Listenable & sync bridges

### `useValueNotifier<T>(initial)`

Creates a `ValueNotifier<T>` auto-disposed on unmount.

### `useChangeNotifier<T extends ChangeNotifier>(creator)`

Low-level: memoize any `ChangeNotifier` and call `.dispose()` on unmount. Backs most controller hooks. Use when no specialized hook exists for the notifier type you need.

### `useListen`

Subscribe to external listenables — pure side effect, no value returned for the listener (the underlying object is the result for variants that need one). Hot reload updates the callback / re-attaches if the source changed.

| Variant | Subscribes to |
| --- | --- |
| `useListen.value(listenable, (v) => ...)` | stable `ValueListenable<T>` |
| `useListen.value.watch(readableOfValueListenable, (v) => ...)` | a `Readable<ValueListenable<T>>` that may swap |
| `useListen.listenable(listenable, () => ...)` | stable `Listenable` |
| `useListen.listenable.watch(readableOfListenable, () => ...)` | swappable `Listenable` |
| `useListen.stream(stream, (e) => ..., {onError, onDone, cancelOnError})` | `Stream<T>` |
| `useListen.stream.watch(readableOfStream, ...)` | swappable stream |

```dart
useListen.value(textCtrl, (text) => debugPrint(text));
useListen.stream(events, (e) => handle(e));
```

### `useSync`

Synchronize a `Writable<T>` with an external `Listenable`.

```dart
useSync.from(text, controller, getter: (c) => c.text);

useSync.bidi(
  text,
  controller,
  getter: (c) => c.text,
  setter: (v) => controller.text = v,
);
```

`.from` is one-way (source → target). `.bidi` is two-way; the implementation guards against re-entrant loops on the initial value.

---

## Async

### `useFuture`

Tracks a `FutureOr<T>?` as an `AsyncSnapshot`-shaped signal (`AsyncSnapshotFutureSignal<T>`). Supports `setFuture(...)` to re-point at a new future.

```dart
final snap = useFuture(loadUser(), initialData: User.empty());

return () => switch (snap.connectionState) {
  ConnectionState.done    => Text('${snap.data}'),
  ConnectionState.waiting => const CircularProgressIndicator(),
  _                       => const SizedBox.shrink(),
};
```

`useFuture.watch(readableFuture)` re-subscribes whenever the readable's value changes.

### `useStream`

Same as `useFuture`, but for streams: returns `AsyncSnapshotStreamSignal<T>`. Subscription is cancelled on unmount.

```dart
final snap = useStream(messages);
useStream.watch(activeChannel);
```

### `useStreamController`

Owns a `StreamController<T>` for the setup scope, closed on unmount.

```dart
final ctrl = useStreamController<int>();
final snap = useStream(ctrl.stream);
```

`useStreamController.broadcast<T>(...)` creates a broadcast controller.

---

## Misc

### `useTimer`

A setup-owned timer that auto-cancels on unmount. Returns a `TimerHook` (implements `Timer`) with `pause()`, `resume()`, `reset()`.

```dart
final visible = useSignal(false);

useTimer(const Duration(milliseconds: 300), () {
  visible.value = true;
});

useTimer.periodic(const Duration(seconds: 1), (t) {
  debugPrint('tick ${t.tick}');
});
```

By default, the timer starts after the setup scope mounts. Pass `start: TimerStart.immediate` to start during hook creation.

### `useAppLifecycleState`

Tracks `AppLifecycleState`. Returns a `Readonly<AppLifecycleState?>`.

```dart
final lifecycle = useAppLifecycleState(onChange: (s) => log('$s'));
return () => Text('${lifecycle.value}');
```

### `useAutomaticKeepAlive`

Keeps the surrounding subtree alive when off-screen (e.g. inside a `PageView`, `TabBarView`, lazy list).

```dart
useAutomaticKeepAlive(true);          // fixed policy
useAutomaticKeepAlive.value(active);  // Readable<bool> policy
```

### `useSetupReset` (experimental)

Schedules a full setup rerun at frame end. Use only when the initialization boundary itself must rebuild.

```dart
final reset = useSetupReset();              // returns void Function()

useSetupReset.listen(() => [valueListenable]); // reset when any listenable fires
useSetupReset.watch(() => [signalA, signalB]); // reset when any readable changes
useSetupReset.select(() => locale.value);      // reset when the selected value changes
```

`useSetupReset` is intentionally a heavy escape hatch. Prefer ordinary reactive updates wherever possible.

---

## Defining a Custom Hook

Three forms — function-style composition, class-style `SetupHook<T>`, and extension-style on a built-in creator (`useSignal.myThing`, `useComputed.myThing`, …). See [`custom-hooks.md`](custom-hooks.md) for signatures, lifecycle contract, hot-reload behavior, and worked examples.
