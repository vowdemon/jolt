# Defining Custom Hooks

Custom hooks let you extract reusable setup logic — owning state, controllers, listeners, lifecycle callbacks, and reactive wiring — behind a single `use*` call. There are three forms, in increasing order of capability:

1. [**Function-style**](#1-function-style-composition) — a plain function composed from existing hooks. Use for most cases.
2. [**Class-style**](#2-class-style-via-setuphookt) — a subclass of `SetupHook<T>`. Use when you need element lifecycle callbacks, custom state shape, or hot-reload state preservation.
3. [**Extension-style**](#3-extension-style-attaching-to-a-built-in-creator) — extend a built-in creator like `JoltSetupHookSignalCreator` to add a method under `useSignal.x`, `useComputed.x`, etc. Use to keep namespacing tight.

All custom hooks share the same rules as built-in ones:

- Must be called **inside** a `setup` function (directly, or transitively through another hook).
- Hook calls must be at the top level — no `if`, no loops, no early returns before later hooks.
- Names should start with `use*` (function or method).
- Annotate with `@defineHook` from `package:jolt_setup/jolt_setup.dart` so tooling can recognize the API.

---

## 1. Function-style (composition)

Write an ordinary Dart function that composes other hooks and returns whatever state your callers need. The function inherits the active `SetupContext` from the caller automatically.

### Minimal example

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt_setup/jolt_setup.dart';

@defineHook
Signal<int> useCounter([int initial = 0]) {
  return useSignal(initial);
}
```

### Returning multiple things

Use a record or a `typedef`-record so the call site stays terse.

```dart
typedef CounterHook = ({
  Signal<int> value,
  void Function() increment,
  void Function() decrement,
  void Function() reset,
});

@defineHook
CounterHook useCounter([int initial = 0]) {
  final value = useSignal(initial);
  return (
    value: value,
    increment: () => value.value++,
    decrement: () => value.value--,
    reset:     () => value.value = initial,
  );
}
```

Call site:

```dart
setup(context, props) {
  final counter = useCounter(10);
  useEffect(() => debugPrint('count: ${counter.value.value}'));
  return () => GestureDetector(
    onTap: counter.increment,
    child: Text('${counter.value.value}'),
  );
}
```

### Composing other hooks

A function hook can call any other `use*` — built-in or your own. Lifecycle, controllers, listeners all compose naturally.

```dart
@defineHook
ScrollController useAutoScrollToBottom(Readable<bool> shouldFollow) {
  final controller = useScrollController();
  usePostFrameEffect(() {
    if (shouldFollow.value && controller.hasClients) {
      controller.jumpTo(controller.position.maxScrollExtent);
    }
  });
  return controller;
}
```

### When to upgrade to class-style

- You need to react to `didUpdateWidget` / `didChangeDependencies` / `activate` / `deactivate` directly — `on*` callbacks work, but a class lets you encapsulate them.
- You need a stable identity (`hook.state`) that should survive hot reload and update from a new config object.
- The hook owns multiple internal fields and should not be flattened into one return value.

---

## 2. Class-style (via `SetupHook<T>`)

Subclass `SetupHook<T>` and override `build()`. Override any subset of lifecycle methods you need. Register the instance with `useHook(...)`; the returned value is whatever `build()` returns.

### Lifecycle surface

| Override | When it fires |
| --- | --- |
| `T build()` | Once per hook slot. Returns the state value exposed via `state`. Result is also what `useHook(...)` returns. |
| `void mount()` | After `build`, when the hook is mounted (also re-runs after a `resetSetup`). |
| `void unmount()` | When the setup scope unmounts, or when a hot reload trims this slot. Use for `dispose()`, `removeListener`, `cancel`, etc. |
| `void didUpdateWidget(oldW, newW)` | Parent rebuilt with a new widget instance. Typed via covariance if you pin a generic. |
| `void didChangeDependencies()` | Inherited dependencies changed. |
| `void activate()` / `void deactivate()` | Element activate/deactivate. |
| `void reassemble(SetupHook newHook)` | Hot reload reused this slot. Copy fields from `newHook` into `this` to apply new config without losing state. |

You also get:
- `BuildContext get context` — the build context of the owning setup runtime.
- `T get state` — cached result of the last `build()`.
- `T? rawState` — same as `state` without the `as T` cast; assignable when you must replace state from `reassemble`.

### Minimal example

```dart
class CounterHook extends SetupHook<CounterHook> {
  CounterHook({required this.initialValue});
  final int initialValue;

  late Signal<int> signal;

  void increment() => signal.value++;
  void decrement() => signal.value--;
  void reset()     => signal.value = initialValue;

  @override
  CounterHook build() {
    signal = Signal(initialValue);
    return this;
  }

  @override
  void unmount() => signal.dispose();
}

@defineHook
CounterHook useCounter([int initialValue = 0]) =>
    useHook(CounterHook(initialValue: initialValue));
```

### Hot-reload contract

Hooks are matched across hot reload by **(position, runtimeType)**. To preserve state, override `reassemble` and copy mutable config fields from `newHook` to `this`. Leave `state` / `rawState` alone unless the new config requires rebuilding the underlying resource.

```dart
class _TimerHook extends SetupHook<Timer> {
  _TimerHook(this.duration, this.callback);
  Duration duration;
  void Function() callback;
  Timer? _timer;

  @override
  Timer build() => _timer = Timer.periodic(duration, (_) => callback());

  @override
  void unmount() => _timer?.cancel();

  @override
  void reassemble(covariant _TimerHook newHook) {
    callback = newHook.callback;            // cheap: just swap the closure

    if (newHook.duration != duration) {     // expensive: rebuild the timer
      duration = newHook.duration;
      _timer?.cancel();
      rawState = build();
    }
  }
}
```

### Ready-made bases

| Base | Use for |
| --- | --- |
| `AutoDisposeHook<T extends Disposable>(creator)` | Wraps any Jolt `Disposable`. Calls `state.dispose()` on unmount. Backs `useSignal`, `useComputed`, `useEffectScope`, etc. |
| `DisposableHook<T>(creator, [disposer])` | Memoizes a value; runs the optional `disposer` on unmount. Backs `useMemoized`. |

If you only need "create once, dispose once", prefer `useMemoized` / `useAutoDispose` over a full subclass.

---

## 3. Extension-style (attaching to a built-in creator)

Built-in factories like `useSignal`, `useComputed`, `useEffect`, `useWatcher`, `useUntil`, `useFuture`, `useStream`, `useListen`, `useSync`, `useTimer`, `useTextEditingController`, etc. are each a `const` instance of a `final class` (`JoltSetupHookSignalCreator`, `JoltSetupHookComputedCreator`, …). Dart's `final class` modifier prevents `extends` / `implements`, **but allows extension methods** — which makes this the right tool for adding `useSignal.myThing(...)`-style namespaced hooks.

### When to use this style

- You want callers to discover your hook under an existing namespace (e.g. a domain-specific signal type under `useSignal.*`).
- You want IDE autocomplete from `useSignal.` to surface your hook alongside built-in variants.
- You don't want to claim another top-level identifier.

### Creator targets

| Built-in | Creator class to extend |
| --- | --- |
| `useSignal`               | `JoltSetupHookSignalCreator` |
| `useComputed`             | `JoltSetupHookComputedCreator` |
| `useEffect`               | `JoltSetupHookEffectCreator` |
| `usePostFrameEffect`      | `JoltSetupHookPostFrameEffectCreator` |
| `useWatcher`              | `JoltSetupHookWatcherCreator` |
| `useEffectScope`          | `JoltSetupHookEffectScopeCreator` |
| `useUntil`                | `JoltSetupHookUntilCreator` |
| `useFuture`               | `JoltSetupHookFutureCreator` |
| `useStream`               | `JoltSetupHookStreamCreator` |
| `useStreamController`     | `JoltSetupHookStreamControllerCreator` |
| `useListen`               | `JoltSetupHookListenCreator` (or its nested `.value` / `.listenable` / `.stream`) |
| `useSync`                 | `JoltSetupHookSyncCreator` |
| `useTimer`                | `JoltSetupHookTimerCreator` |
| `useTextEditingController` | `JoltSetupHookTextEditingControllerCreator` |
| `useRestorableTextEditingController` | `JoltSetupHookRestorableTextEditingControllerCreator` |
| `useAutomaticKeepAlive`   | `JoltSetupHookAutomaticKeepAliveCreator` |
| `useSetupReset`           | `JoltSetupHookResetCreator` |

(Generic top-level hooks like `useScrollController`, `useFocusNode`, `useMemoized`, `useAutoDispose`, `useChangeNotifier`, `useValueNotifier`, `useHook`, `useContext`, `useInherited`, and the `on*` lifecycle helpers are plain functions, not creator classes — extension-style does not apply; add your own top-level function instead.)

### Example: adding `useSignal.counter`

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt_setup/jolt_setup.dart';

extension MySignalHooks on JoltSetupHookSignalCreator {
  /// A signal pre-wired as a counter, with a log on first mount.
  @defineHook
  Signal<int> counter([int initial = 0]) {
    // Call other hooks freely; the active SetupContext is inherited.
    final value = useSignal(initial);
    onMounted(() => debugPrint('counter started at ${value.peek}'));
    return value;
  }
}
```

Call site — appears under the existing `useSignal.` namespace:

```dart
setup(context, props) {
  final count = useSignal.counter(10);
  return () => Text('${count.value}');
}
```

### Example: adding a domain hook to `useComputed`

```dart
extension MyComputedHooks on JoltSetupHookComputedCreator {
  /// A computed that lerps between two reactive doubles.
  @defineHook
  Computed<double> lerp(Readable<double> a, Readable<double> b, Readable<double> t) {
    return useComputed(() => a.value + (b.value - a.value) * t.value);
  }
}

// useComputed.lerp(low, high, progress);
```

### Example: extending a nested namespace

`useListen` exposes `.value`, `.listenable`, `.stream`. Each is its own creator class, so you can extend any of them independently.

```dart
extension MyListenValueHooks on JoltSetupHookListenValueCreator {
  /// Logs every value the listenable emits, with a prefix.
  @defineHook
  void logged<T>(ValueListenable<T> listenable, String prefix) {
    useListen.value(listenable, (v) => debugPrint('$prefix: $v'));
  }
}

// useListen.value.logged(textCtrl, 'text');
```

### Calling the creator itself from inside the extension

Inside an extension method, the receiver is the creator instance (e.g. `JoltSetupHookSignalCreator`). The built-in entry — `useSignal(value)` — is `call<T>(value)` on that class. Three equivalent ways to invoke it from within the extension:

```dart
extension on JoltSetupHookSignalCreator {
  @defineHook
  Signal<int> initiallyFrom(int Function() init) {
    final a = useSignal(init());   // goes through the const top-level instance
    final b = this(init());        // same — invokes `call<T>` on the receiver
    final c = call(init());        // same — explicit method call
    return a;
  }
}
```

Prefer `useSignal(...)` for readability; reach for `this(...)` / `call(...)` only when you must disambiguate (e.g. inside another method named `call`).

### Limitations

- Extension methods on a `final class` cannot override or shadow existing methods on that class.
- Extensions resolve statically. If the same creator is extended in two places with a conflicting method name, callers must use `MyExt(useSignal).counter(...)` to disambiguate.
- Extensions cannot add fields — keep custom hook state inside the method body via `useSignal` / `useMemoized` / a private `SetupHook<T>`.

---

## Best Practices

- Annotate every custom hook (function, method, extension method) with `@defineHook`.
- Name with a `use*` prefix so users understand the call-time contract.
- Internally hold long-lived resources through `useMemoized` / `useAutoDispose` / specialized hooks, not raw `new` — otherwise you must wire `onUnmounted` yourself.
- Keep the hook order deterministic — no `if (...)` around `use*` calls.
- For configuration that may change across rebuilds, class-style with `reassemble` is the safe path; function-style hooks read fresh arguments each rebuild but their own `useMemoized` / `useSignal` slots only capture the **first** call's values unless you watch `props` reactively.
- Test custom hooks by mounting them inside a `SetupBuilder` in a widget test — no extra harness needed.
