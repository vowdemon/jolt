# Jolt Flutter

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_flutter](https://img.shields.io/pub/v/jolt_flutter?label=jolt_flutter)](https://pub.dev/packages/jolt_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Flutter integration for [Jolt](https://pub.dev/packages/jolt). Provides widgets like `JoltBuilder`, `JoltSelector`, and `JoltProvider` to use Jolt's reactive system in Flutter. Also includes bidirectional `ValueNotifier` conversion and a hooks-style Setup Widget API.

> **📦 Package Exports**
> 
> `jolt_flutter` re-exports all APIs from the `jolt` package, so you only need to import `jolt_flutter` to access all Jolt reactive primitives (Signal, Computed, Effect, etc.).

## Usage

```dart
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

JoltBuilder(
  builder: (context) => Text('Count: ${counter.value}'),
)
```

## Core Widgets

### JoltBuilder

Automatically rebuilds when any signal accessed in its builder changes:

```dart
final counter = Signal(0);
final name = Signal('Flutter');

JoltBuilder(
  builder: (context) => Column(
    children: [
      Text('Hello ${name.value}'),
      Text('Count: ${counter.value}'),
      ElevatedButton(
        onPressed: () => counter.value++,
        child: Text('Increment'),
      ),
    ],
  ),
)
```

### JoltSelector

Rebuilds only when a specific selector function's result changes:

```dart
final user = Signal(User(name: 'John', age: 30));

// Only rebuilds when the user's name changes, not age
JoltSelector(
  selector: (prev) => user.value.name,
  builder: (context, name) => Text('Hello $name'),
)
```

The `selector` function receives the previous selected value (or `null` on first run) and returns the new value to watch. Rebuilds occur only when the returned value changes.

### JoltProvider

A widget that provides resources with lifecycle management:

```dart
class CounterStore extends JoltState {
  final counter = Signal(0);
  Timer? _timer;

  @override
  void onMount(BuildContext context) {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      counter.value++;
    });
  }

  @override
  void onUnmount(BuildContext context) {
    _timer?.cancel();
  }
}

JoltProvider<CounterStore>(
  create: (context) => CounterStore(),
  builder: (context, store) => Text('Count: ${store.counter.value}'),
)
```

Access the resource from descendant widgets:

```dart
Builder(
  builder: (context) {
    final store = JoltProvider.of<CounterStore>(context);
    return Text('Count: ${store.counter.value}');
  },
)
```

## ValueNotifier Integration

### Converting Jolt Signals to ValueNotifier

Bridge Jolt signals with Flutter's ValueNotifier system using the extension:

```dart
final counter = Signal(0);
final notifier = counter.notifier; // Returns JoltValueNotifier

// Use with AnimatedBuilder
AnimatedBuilder(
  animation: notifier,
  builder: (context, child) => Text('Count: ${notifier.value}'),
)

// Use with ValueListenableBuilder
ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('Count: $value'),
)
```

### Converting ValueNotifier to Jolt Signal

Convert Flutter's ValueNotifier to Jolt signals for bidirectional sync:

```dart
final notifier = ValueNotifier(0);
final signal = notifier.toNotifierSignal();

// Changes sync bidirectionally
notifier.value = 1; // signal.value becomes 1
signal.value = 2;   // notifier.value becomes 2
```

### Automatic Synchronization

ValueNotifier automatically syncs with Jolt signal changes:

```dart
final signal = Signal(0);
final notifier = signal.notifier;

// Changes to signal automatically update notifier
signal.value = 42; // notifier.value is now 42
```

## Setup Widget

> **⚠️ Important Note**
>
> Setup Widget and its hooks are **not part** of the `flutter_hooks` ecosystem. If you need `flutter_hooks`-compatible APIs, use the [`jolt_hooks`](https://pub.dev/packages/jolt_hooks) package instead.
>
> **Key Execution Difference:**
> - **Setup Widget**: The `setup` function runs **once** when the widget is created (like Vue / SolidJS), then rebuilds are driven by the reactive system
> - **flutter_hooks**: Hook functions run **on every build** (like React Hooks)
>
> These are fundamentally different models. Avoid mixing them to prevent confusion.

Setup Widget provides a composition API similar to Vue's Composition API for building Flutter widgets. The key difference from React hooks: the `setup` function executes only once when the widget is created, not on every rebuild. This provides better performance and a more predictable execution model.

### SetupBuilder

The simplest way to use Setup Widget is with `SetupBuilder`:

```dart
import 'package:jolt_flutter/setup.dart';

SetupBuilder(
  setup: (context) {
    final count = useSignal(0);
    
    return () => Column(
      children: [
        Text('Count: ${count.value}'),
        ElevatedButton(
          onPressed: () => count.value++,
          child: Text('Click'),
        ),
      ],
    );
  },
)
```

### SetupWidget vs SetupMixin

Before diving into each API, understand their differences:

| Feature | SetupWidget | SetupMixin |
|---------|-------------|-----------------|
| Base class | Extends `Widget` | Mixin for `State<T>` |
| Mutability | Like `StatelessWidget`, immutable | Mutable State class |
| `this` reference | ❌ Not available | ✅ Full access |
| Instance methods/fields | ❌ Should not use | ✅ Can define freely |
| Setup signature | `setup(context, props)` | `setup(context)` |
| Reactive props access | `props().property` | `props.property` |
| Non-reactive props access | `props.peek.property` | `widget.property` |
| Lifecycle methods | Via hooks only | Both hooks + State methods |
| Use case | Simple immutable widgets | Need State capabilities |

### SetupWidget

Create custom widgets by extending `SetupWidget`:

```dart
class CounterWidget extends SetupWidget<CounterWidget> {
  final int initialValue;
  
  const CounterWidget({super.key, this.initialValue = 0});

  @override
  setup(context, props) {
    // Use props.peek for one-time initialization (non-reactive)
    final count = useSignal(props.peek.initialValue);
    
    // Use props() for reactive access
    final displayText = useComputed(() => 
      'Count: ${count.value}, Initial: ${props().initialValue}'
    );
    
    return () => Column(
      children: [
        Text(displayText.value),
        ElevatedButton(
          onPressed: () => count.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

**Important Notes:**

- `setup` receives two parameters:
  - `context`: Standard Flutter `BuildContext`
  - `props`: `PropsReadonlyNode<YourWidgetType>`, provides reactive access to widget instance

- **Props Access Methods:**
  - `props()` / `props.value` / `props.get()` - Reactive access, establishes dependencies
  - `props.peek` - Non-reactive access, for one-time initialization

- **Like `StatelessWidget`:** The widget class should be immutable and not hold mutable state or define instance methods

### SetupMixin

Add composition API support to existing `StatefulWidget`s:

```dart
class CounterWidget extends StatefulWidget {
  final int initialValue;
  
  const CounterWidget({super.key, this.initialValue = 0});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget>
    with SetupMixin<CounterWidget> {
  
  @override
  setup(context) {
    // Use widget.property for one-time initialization (non-reactive)
    final count = useSignal(widget.initialValue);
    
    // Use props.property for reactive access
    final displayText = useComputed(() => 
      'Count: ${count.value}, Initial: ${props.initialValue}'
    );
    
    return () => Column(
      children: [
        Text(displayText.value),
        ElevatedButton(
          onPressed: () => count.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

**Key Differences:**

- `setup` receives only one parameter: `context` (no `props` parameter)
- Provides a `props` getter for reactive widget property access
- Compatible with traditional `State` lifecycle methods (`initState`, `dispose`, etc.)

**Two Ways to Access Widget Properties:**

```dart
setup(context) {
  // 1. widget.property - Non-reactive (equivalent to props.peek in SetupWidget)
  //    For one-time initialization, won't trigger updates on changes
  final initial = widget.initialValue;
  
  // 2. props.property - Reactive (equivalent to props() in SetupWidget)
  //    Use inside computed/effects to react to property changes
  final reactive = useComputed(() => props.initialValue * 2);
  
  return () => Text('${reactive.value}');
}
```

**State Context and `this` Reference:**

Unlike `SetupWidget` (which is analogous to `StatelessWidget`), `SetupMixin` runs within a `State` class, giving you full access to `this` and mutable state:

```dart
class _CounterWidgetState extends State<CounterWidget>
    with SetupMixin<CounterWidget> {
  
  // ✅ Allowed: Define instance fields in State
  final _controller = TextEditingController();
  int _tapCount = 0;
  
  // ✅ Allowed: Define instance methods
  void _handleTap() {
    setState(() => _tapCount++);
  }
  
  @override
  void initState() {
    super.initState();
    // Traditional State initialization
  }
  
  @override
  setup(context) {
    final count = useSignal(0);
    
    // ✅ Access 'this' and instance members
    onMounted(() {
      _controller.text = 'Initial: ${widget.initialValue}';
    });
    
    return () => Column(
      children: [
        TextField(controller: _controller),
        Text('Taps: $_tapCount'),
        ElevatedButton(
          onPressed: _handleTap,
          child: Text('Count: ${count.value}'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

**Key Point:** `SetupWidget` is like `StatelessWidget` - the widget class itself should be immutable. `SetupMixin` works within a `State` class where you can freely use `this`, define methods, maintain fields, and leverage the full capabilities of stateful widgets.

### Choosing the Right Pattern

> **💡 No Right or Wrong Choice**
>
> There's no single "correct" way to build widgets in Jolt. SetupWidget, SetupMixin, and traditional Flutter patterns (StatelessWidget, StatefulWidget) are all first-class citizens. Each shines in different scenarios—what matters is knowing when to use which, keeping your code clear and maintainable.
>
> The Setup API itself is entirely optional. If your team is comfortable with standard Flutter patterns and they're working well, there's no need to change. You can also use Riverpod, flutter_hooks, or any other state management solution you prefer, even mixing them in the same project.
>
> When you need composition-based logic, reactive state, or Vue/Solid-style patterns, the Setup API is there to give you that extra power—without forcing you to rewrite existing code.

**When to Use SetupWidget:**
- Creating simple, immutable widgets (like `StatelessWidget`)
- Want a pure composition-based API
- No need for instance methods, mutable fields, or `this` reference
- Prefer cleaner, more concise code
- All logic can be expressed through reactive hooks

**When to Use SetupMixin:**
- Need instance methods, fields, or access to `this`
- Need to use existing State mixins, special State base classes, or State extensions
- Want to combine composition API with imperative logic
- Need full control over `State` lifecycle methods (`initState`, `dispose`, `didUpdateWidget`, etc.)
- Working with complex widget logic that benefits from both approaches

### Available Hooks

Setup Widget provides hooks for all Jolt reactive primitives:

> **💡 About Using Hooks**
>
> For reactive objects like `Signal` and `Computed`, you can create them directly without hooks if they'll be garbage collected when the widget unmounts (e.g., local variables in the setup function). The main purpose of hooks is to ensure proper cleanup and state preservation during widget unmount or hot reload.
>
> ```dart
> setup(context, props) {
>   // Using hooks - Recommended, automatic lifecycle management
>   final count = useSignal(0);
>   
>   // Without hooks - Also fine, gets GC'd after widget unmounts
>   final temp = Signal(0);
>   
>   return () => Text('Count: ${count.value}');
> }
> ```

#### Reactive State Hooks

| Hook | Description |
|------|-------------|
| `useSignal(initial)` | Create a reactive Signal |
| `useSignal.lazy<T>()` | Create a lazy-loaded Signal |
| `useSignal.list(initial)` | Create a reactive list |
| `useSignal.map(initial)` | Create a reactive Map |
| `useSignal.set(initial)` | Create a reactive Set |
| `useSignal.iterable(getter)` | Create a reactive Iterable |
| `useSignal.async(source)` | Create an async Signal |
| `useSignal.persist(...)` | Create a persisted Signal |

#### Computed Value Hooks

| Hook | Description |
|------|-------------|
| `useComputed(fn)` | Create a computed value |
| `useComputed.withPrevious(getter)` | Create a computed value with access to previous value |
| `useComputed.writable(getter, setter)` | Create a writable computed value |
| `useComputed.writableWithPrevious(getter, setter)` | Create a writable computed value with access to previous value |
| `useComputed.convert(source, decode, encode)` | Create a type-converting computed value |

#### Effect Hooks

| Hook | Description |
|------|-------------|
| `useEffect(fn)` | Create an effect |
| `useEffect.lazy(fn)` | Create an immediately-executing effect |
| `useWatcher(sourcesFn, fn)` | Create a watcher |
| `useWatcher.immediately(...)` | Create an immediately-executing watcher |
| `useWatcher.once(...)` | Create a one-time watcher |

#### Lifecycle Hooks

| Hook | Description |
|------|-------------|
| `onMounted(fn)` | Callback when widget mounts |
| `onUnmounted(fn)` | Callback when widget unmounts |
| `onDidUpdateWidget(fn)` | Callback when widget updates |
| `onDidChangeDependencies(fn)` | Callback when dependencies change |
| `onActivated(fn)` | Callback when widget activates |
| `onDeactivated(fn)` | Callback when widget deactivates |

#### Utility Hooks

| Hook | Description |
|------|-------------|
| `useContext()` | Get BuildContext |
| `useSetupContext()` | Get JoltSetupContext |
| `useEffectScope()` | Create an effect scope |
| `useJoltStream(value)` | Create a stream from reactive value |
| `useMemoized(creator, [disposer])` | Memoize value with optional cleanup |
| `useAutoDispose(creator)` | Auto-dispose resource |
| `useHook(hook)` | Use a custom hook |

**Usage Example:**

```dart
setup: (context) {
  // Signals
  final count = useSignal(0);
  final name = useSignal('Flutter');
  
  // Computed values
  final doubled = useComputed(() => count.value * 2);
  
  // Reactive collections
  final items = useSignal.list(['apple', 'banana']);
  final userMap = useSignal.map({'name': 'John', 'age': 30});
  
  // Effects
  useEffect(() {
    print('Count changed: ${count.value}');
  });
  
  // Lifecycle callbacks
  onMounted(() {
    print('Widget mounted');
  });
  
  onUnmounted(() {
    print('Widget unmounted');
  });
  
  return () => Text('Count: ${count.value}');
}
```

**Automatic Resource Cleanup:**

All hooks automatically clean up their resources when the widget unmounts, ensuring proper cleanup and preventing memory leaks:

```dart
setup: (context) {
  final timer = useSignal<Timer?>(null);
  
  onMounted(() {
    timer.value = Timer.periodic(Duration(seconds: 1), (_) {
      print('Tick');
    });
  });
  
  onUnmounted(() {
    timer.value?.cancel();
  });
  
  return () => Text('Timer running');
}
```

## Related Packages

Jolt Flutter is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_flutter_hooks](https://pub.dev/packages/jolt_flutter_hooks) | Declarative hooks for Flutter: useTextEditingController, useScrollController, useFocusNode, etc. |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |
| [jolt_lint](https://pub.dev/packages/jolt_lint) | Custom lint and code assists: Wrap widgets, convert to/from Signals, Hook conversions |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
