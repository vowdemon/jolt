# Jolt Setup

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_setup](https://img.shields.io/pub/v/jolt_setup?label=jolt_setup)](https://pub.dev/packages/jolt_setup)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Setup Widget API and Flutter hooks for [Jolt](https://pub.dev/packages/jolt). Provides a composition API similar to Vue's Composition API for building Flutter widgets, along with declarative hooks for managing common Flutter resources such as controllers, focus nodes, and lifecycle states with automatic cleanup.

## Why Setup Widget?

Setup Widget brings the simplicity and power of Vue's Composition API to Flutter, dramatically reducing boilerplate while making your code more maintainable and easier to understand.

### Key Features

✨ **Composition-Based Logic** - Organize code by feature, not lifecycle  
🎯 **Automatic Resource Cleanup** - No more manual dispose(), everything cleans up automatically  
⚡ **Better Performance** - `setup` runs once, not on every rebuild (unlike React hooks)  
🔄 **Reactive by Default** - Built on Jolt's Signal system for fine-grained reactivity  
🪝 **Rich Hook Library** - Declarative APIs for controllers, focus nodes, animations, and more  
🔧 **Flexible** - Use with SetupWidget, SetupMixin, or SetupBuilder based on your needs  

### Quick Comparison

See the difference yourself. Here's the same widget implemented both ways:

**With Setup Widget:**

```dart
class HookExample extends SetupWidget<HookExample> {
  HookExample({super.key});

  @override
  setup(context, props) {
    useAutomaticKeepAlive(true);

    final scrollController = useScrollController();
    useListenable(scrollController, () {
      print('scrollController.offset: ${scrollController.offset}');
    });

    final loadingFuture =
        useFuture(Future.delayed(Duration(seconds: 3), () => true));

    useAppLifecycleState(
      onChange: (state) {
        if (state == AppLifecycleState.resumed) {
          print('app resumed');
        } else if (state == AppLifecycleState.paused) {
          print('app paused');
        }
      },
    );

    return () => SingleChildScrollView(
        controller: scrollController,
        child: switch (loadingFuture.hasData) {
          false => Center(child: CircularProgressIndicator()),
          true => Column(
              children: [
                for (var i = 0; i < 100; i++) Text('Item $i'),
              ],
            ),
        });
  }
}
```

**Traditional StatefulWidget:**

```dart
class NormalExample extends StatefulWidget {
  const NormalExample({super.key});

  @override
  State<NormalExample> createState() => _NormalExampleState();
}

class _NormalExampleState extends State<NormalExample>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  late final ScrollController scrollController;
  late final Future<bool> loadingFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    loadingFuture = Future.delayed(Duration(seconds: 3), () => true);
    scrollController.addListener(_listener);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('app resumed');
    } else if (state == AppLifecycleState.paused) {
      print('app paused');
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_listener);
    scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _listener() {
    print('scrollController.offset: ${scrollController.offset}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
        controller: scrollController,
        child: FutureBuilder(
            future: loadingFuture,
            builder: (context, snapshot) {
              return switch (snapshot.hasData) {
                false => Center(child: CircularProgressIndicator()),
                true => Column(
                    children: [
                      for (var i = 0; i < 100; i++) Text('Item $i'),
                    ],
                  ),
              };
            }));
  }
}
```

**The Difference:**
- ✅ **Less code** - 36 lines vs 64 lines
- ✅ **No manual cleanup** - Automatic resource disposal
- ✅ **No mixins needed** - Everything through simple hooks
- ✅ **Better organization** - Logic grouped by feature, not scattered across lifecycle methods
- ✅ **Easier to test** - Composition makes unit testing straightforward

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:jolt_setup/jolt_setup.dart';

class MyWidget extends SetupWidget {
  @override
  setup(context) {
    final textController = useTextEditingController('Hello');
    final focusNode = useFocusNode();
    final count = useSignal(0);
    
    return () => Scaffold(
      body: Column(
        children: [
          TextField(
            controller: textController,
            focusNode: focusNode,
          ),
          Text('Count: ${count.value}'),
          ElevatedButton(
            onPressed: () => count.value++,
            child: Text('Increment'),
          ),
        ],
      ),
    );
  }
}
```

## Recommended: Use with jolt_lint

For the best development experience, it's **highly recommended** to use `jolt_setup` with [`jolt_lint`](https://pub.dev/packages/jolt_lint):

```yaml
# analysis_options.yaml

plugins:
  jolt_lint: ^3.0.0
```

**What jolt_lint provides:**
- 🔍 **Hook Rules Enforcement** - Ensures hooks are only called in setup or other hooks
- 🚫 **Prevents Common Mistakes** - Catches async/callback hook usage at compile time
- 💡 **Code Assists** - Quick fixes for converting between patterns
- 🎯 **Better DX** - Get immediate feedback on hook usage violations

Without `jolt_lint`, hook rule violations will only be caught at runtime. With it, you get compile-time safety and helpful IDE warnings.

**Learn more:** See [jolt_lint documentation](https://pub.dev/packages/jolt_lint) for setup and configuration.

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
import 'package:jolt_setup/setup.dart';

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

## Available Hooks

### Reactive State Hooks

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

| Hook | Description |
|------|-------------|
| `useSignal(initial)` | Create a reactive Signal |
| `useSignal.lazy<T>()` | Create a lazy-loaded Signal |
| `useSignal.list(initial)` | Create a reactive list |
| `useSignal.map(initial)` | Create a reactive Map |
| `useSignal.set(initial)` | Create a reactive Set |
| `useSignal.iterable(getter)` | Create a reactive Iterable |
| `useSignal.async(source)` | Create an async Signal |

### Computed Value Hooks

| Hook | Description |
|------|-------------|
| `useComputed(fn)` | Create a computed value |
| `useComputed.withPrevious(getter)` | Create a computed value with access to previous value |
| `useComputed.writable(getter, setter)` | Create a writable computed value |
| `useComputed.writableWithPrevious(getter, setter)` | Create a writable computed value with access to previous value |

### Effect Hooks

| Hook | Description |
|------|-------------|
| `useEffect(fn)` | Create an effect |
| `useEffect.lazy(fn)` | Create an immediately-executing effect |
| `useWatcher(sourcesFn, fn)` | Create a watcher |
| `useWatcher.immediately(...)` | Create an immediately-executing watcher |
| `useWatcher.once(...)` | Create a one-time watcher |

### Lifecycle Hooks

| Hook | Description |
|------|-------------|
| `onMounted(fn)` | Callback when widget mounts |
| `onUnmounted(fn)` | Callback when widget unmounts |
| `onDidUpdateWidget(fn)` | Callback when widget updates |
| `onDidChangeDependencies(fn)` | Callback when dependencies change |
| `onActivated(fn)` | Callback when widget activates |
| `onDeactivated(fn)` | Callback when widget deactivates |

### Utility Hooks

| Hook | Description |
|------|-------------|
| `useContext()` | Get BuildContext |
| `useSetupContext()` | Get JoltSetupContext |
| `useEffectScope()` | Create an effect scope |
| `useJoltStream(value)` | Create a stream from reactive value |
| `useMemoized(creator, [disposer])` | Memoize value with optional cleanup |
| `useAutoDispose(creator)` | Auto-dispose resource |
| `useHook(hook)` | Use a custom hook |

### Creating Custom Hooks

There are two ways to create custom hooks:

**1. Composition Hooks (Function-based):**

Combine existing hooks into a reusable function:

```dart
import 'package:jolt_setup/jolt_setup.dart';

// Composition hook - directly compose existing hooks
T useMyCustomHook<T>(T initialValue) {
  final signal = useSignal(initialValue);
  
  useEffect(() {
    print('Value changed: ${signal.value}');
  });
  
  return signal.value;
}

// Usage in setup
class MyWidget extends SetupWidget {
  @override
  setup(context) {
    final value = useMyCustomHook(0);
    
    return () => Text('Value: $value');
  }
}
```

**2. Class-based Hooks:**

For more complex hooks, extend the `SetupHook` class and use the `use()` method:

```dart
import 'package:jolt_setup/jolt_setup.dart';

class MyCustomHook<T> extends SetupHook<T> {
  final T initialValue;
  
  MyCustomHook(this.initialValue);
  
  @override
  T call() {
    final signal = useSignal(initialValue);
    
    useEffect(() {
      print('Value changed: ${signal.value}');
    });
    
    onUnmounted(() {
      print('Hook cleanup');
    });
    
    return signal.value;
  }
}

// Usage with 'use' method
class MyWidget extends SetupWidget {
  @override
  setup(context) {
    final value = use(MyCustomHook(0));
    
    return () => Text('Value: $value');
  }
}
```

**Using `@defineHook` for Lint Checking:**

The `@defineHook` annotation is used to indicate that a function is a hook for lint checking purposes. It helps ensure proper hook usage patterns:

```dart
@defineHook
T useMyCustomHook<T>(T initialValue) {
  // Lint will ensure this hook's calls (useSignal, etc.) 
  // are only made within setup() or inside another hook
  final signal = useSignal(initialValue);
  return signal.value;
}
```

**Guidelines:**
- Use composition hooks for simple reusable logic
- Use class-based hooks for complex hooks with state or configuration
- Add `@defineHook` annotation to enable lint checking and enforce hook rules

**Hook Rules:**

Hooks must follow these rules to work correctly:

✅ **DO: Call hooks synchronously**
```dart
setup(context) {
  final count = useSignal(0);  // ✅ Correct - synchronous call
  return () => Text('${count.value}');
}
```

❌ **DON'T: Call hooks in async functions**
```dart
setup(context) {
  Future<void> loadData() async {
    final data = useSignal([]);  // ❌ Wrong - inside async function
  }
  return () => Text('...');
}
```

❌ **DON'T: Call hooks in callbacks**
```dart
setup(context) {
  ElevatedButton(
    onPressed: () {
      final count = useSignal(0);  // ❌ Wrong - inside callback
    },
  );
  return () => Text('...');
}
```

❌ **DON'T: Call hooks outside setup/hook context**
```dart
void regularFunction() {
  final count = useSignal(0);  // ❌ Wrong - outside setup context
}
```

✅ **DO: Call hooks at the top level of setup or inside another hook**
```dart
setup(context) {
  final count = useSignal(0);  // ✅ Correct
  final doubled = useComputed(() => count.value * 2);  // ✅ Correct
  
  onMounted(() {
    // ❌ Don't call hooks here - this is a callback
    print('Mounted');
  });
  
  return () => Text('${doubled.value}');
}
```

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

## Flutter Hooks

Declarative hooks for managing common Flutter resources such as controllers, focus nodes, and lifecycle states with automatic cleanup.

### Listenable Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useValueNotifier<T>(initialValue)` | Creates a value notifier | `ValueNotifier<T>` |
| `useValueListenable<T>(...)` | Listens to a value notifier and triggers rebuilds | `void` |
| `useListenable<T>(...)` | Listens to any listenable and triggers rebuilds | `void` |
| `useListenableSync<T, C>(...)` | Bidirectional sync between Signal and Listenable | `void` |
| `useChangeNotifier<T>(creator)` | Generic ChangeNotifier hook | `T extends ChangeNotifier` |

### Animation Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useSingleTickerProvider()` | Creates a single ticker provider | `TickerProvider` |
| `useTickerProvider()` | Creates a ticker provider that supports multiple tickers | `TickerProvider` |
| `useAnimationController({...})` | Creates an animation controller | `AnimationController` |

### Focus Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useFocusNode({...})` | Creates a focus node | `FocusNode` |
| `useFocusScopeNode({...})` | Creates a focus scope node | `FocusScopeNode` |

### Lifecycle Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useAppLifecycleState([initialState])` | Listens to app lifecycle state | `ReadonlySignal<AppLifecycleState?>` |

### Scroll Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useScrollController({...})` | Creates a scroll controller | `ScrollController` |
| `useTrackingScrollController({...})` | Creates a tracking scroll controller | `TrackingScrollController` |
| `useTabController({...})` | Creates a tab controller | `TabController` |
| `usePageController({...})` | Creates a page controller | `PageController` |
| `useFixedExtentScrollController({...})` | Creates a fixed extent scroll controller | `FixedExtentScrollController` |
| `useDraggableScrollableController()` | Creates a draggable scrollable controller | `DraggableScrollableController` |
| `useCarouselController({...})` | Creates a carousel controller | `CarouselController` |

### Text Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useTextEditingController([text])` | Creates a text editing controller | `TextEditingController` |
| `useTextEditingController.fromValue([value])` | Creates a text editing controller from value | `TextEditingController` |
| `useRestorableTextEditingController([value])` | Creates a restorable text editing controller | `RestorableTextEditingController` |
| `useSearchController()` | Creates a search controller | `SearchController` |
| `useUndoHistoryController({...})` | Creates an undo history controller | `UndoHistoryController` |

### Controller Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useTransformationController([value])` | Creates a transformation controller | `TransformationController` |
| `useWidgetStatesController([value])` | Creates a widget states controller | `WidgetStatesController` |
| `useExpansibleController()` | Creates an expansible controller | `ExpansibleController` |
| `useTreeSliverController()` | Creates a tree sliver controller | `TreeSliverController` |
| `useOverlayPortalController({...})` | Creates an overlay portal controller | `OverlayPortalController` |
| `useSnapshotController({...})` | Creates a snapshot controller | `SnapshotController` |
| `useCupertinoTabController({...})` | Creates a Cupertino tab controller | `CupertinoTabController` |
| `useContextMenuController({...})` | Creates a context menu controller | `ContextMenuController` |
| `useMenuController()` | Creates a menu controller | `MenuController` |
| `useMagnifierController({...})` | Creates a magnifier controller | `MagnifierController` |

### Async Hooks

| Hook | Description | Returns |
|------|-------------|---------|
| `useFuture<T>(future, {...})` | Creates a reactive future signal | `AsyncSnapshotFutureSignal<T>` |
| `useStream<T>(stream, {...})` | Creates a reactive stream signal | `AsyncSnapshotStreamSignal<T>` |
| `useStreamController<T>(...)` | Creates a stream controller | `StreamController<T>` |
| `useStreamSubscription<T>(...)` | Manages a stream subscription | `void` |

### Keep Alive Hook

| Hook | Description | Returns |
|------|-------------|---------|
| `useAutomaticKeepAlive(wantKeepAlive)` | Manages automatic keep alive with reactive signal | `void` |

## Related Packages

Jolt Setup is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |
| [jolt_lint](https://pub.dev/packages/jolt_lint) | Custom lint and code assists: Wrap widgets, convert to/from Signals, Hook conversions |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

