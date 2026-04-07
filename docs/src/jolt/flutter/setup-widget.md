---
---

# SetupWidget

`SetupWidget` is a Flutter Widget system based on the Composition API, similar to Vue's Composition API. In the `setup` function, you can use various Hooks to manage state and lifecycle. The `setup` function only executes once when the Widget is created.

> **⚠️ Important Note**
>
> Setup Widget and its Hooks are **not** part of the `flutter_hooks` ecosystem. If you need `flutter_hooks`-compatible APIs, please use the [`jolt_hooks`](https://pub.dev/packages/jolt_hooks) package.
>
> **Key Execution Differences:**
> - **Setup Widget**: The `setup` function executes **only once** when the Widget is created (similar to Vue / SolidJS), then rebuilds are driven by the reactive system
> - **flutter_hooks**: Hook functions execute on **every build** (similar to React Hooks)
>
> These are different execution models. Mixing them in the same component usually makes hook behavior harder to reason about.

## Why Setup Widget?

Setup Widget uses a composition-style API for Flutter widgets. It runs `setup` once at creation time and handles hook cleanup automatically.

### Key Features

- Composition-based logic  
- Automatic resource cleanup  
- `setup` runs once instead of on every rebuild  
- Built on Jolt signals  
- Hook APIs for controllers, focus nodes, animations, and lifecycle  
- Works with `SetupWidget`, `SetupMixin`, and `SetupBuilder`  

### Comparison

The example below shows the same widget implemented with `SetupWidget` and with a `StatefulWidget`.

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

**Differences in this example:**
- Fewer lifecycle methods
- No manual listener disposal in the widget code
- Logic is grouped inside `setup`

## Use with jolt_lint

`jolt_lint` adds static checks and assists for `setup` and hook usage:

```yaml
# analysis_options.yaml

plugins:
  jolt_lint: ^3.0.0
```

**jolt_lint includes:**
- Hook rule checks
- Compile-time diagnostics for invalid async/callback hook usage
- Code assists for common conversions

Without `jolt_lint`, some hook placement errors are only detected at runtime.

See [jolt_lint documentation](https://pub.dev/packages/jolt_lint) for setup and configuration.

## Basic Concepts

The core idea of `SetupWidget` is to separate Widget build logic into two parts:
1. **setup function**: Executes once when the Widget is created, used for initializing state, creating Hooks, etc.
2. **Returned build function**: Used to build the actual Widget, can access state created in setup

## SetupBuilder

`SetupBuilder` is the smallest entry point for the API:

```dart
import 'package:jolt_setup/jolt_setup.dart';

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

**When to use SetupBuilder:**
- Inline or local widget state
- Creating simple, self-contained components
- Don't need custom Widget properties
- Component logic fits in one place

**When to use SetupWidget subclass:**
- Need custom properties (title, count, callback, etc.)
- Building reusable components with clear APIs
- Component is complex or will be used in multiple places
- Want a dedicated widget type and property surface

## SetupWidget vs SetupMixin

Before diving into each API, understand their differences:

| Feature | SetupWidget | SetupMixin |
|---------|-------------|------------|
| Base Class | Extends `Widget` | Mixin for `State<T>` |
| Mutability | Similar to `StatelessWidget`, immutable | Mutable State class |
| `this` Reference | ❌ Not available | ✅ Full access |
| Instance Methods/Fields | ❌ Should not use | ✅ Can freely define |
| Setup Signature | `setup(context, props)` | `setup(context)` |
| Reactive Props Access | `props().property` | `props.property` |
| Non-Reactive Props Access | `props.peek.property` | `widget.property` |
| Lifecycle Methods | Only through hooks | Hooks + State methods |
| Use Cases | Simple immutable Widgets | Need State capabilities |

## SetupWidget

Create custom Widgets by extending `SetupWidget`:

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
  - `props`: `PropsReadonlyNode<YourWidgetType>`, provides reactive access to Widget instance

- **Props Access Methods:**
  - `props()` / `props.value` - Reactive access, establishes dependencies
  - `props.peek` - Non-reactive access, used for one-time initialization

- **Similar to `StatelessWidget`**: Widget class should be immutable, should not hold mutable state or define instance methods

### Reactive Property Access

Access Widget properties reactively through `props()`:

```dart
class UserCard extends SetupWidget<UserCard> {
  final String name;
  final int age;

  const UserCard({super.key, required this.name, required this.age});

  @override
  setup(context, props) {
    // Reactive access to props - rebuilds when name changes
    final displayName = useComputed(() => 'User: ${props().name}');

    return () => Text(displayName.value);
  }
}
```

## SetupMixin

Add Composition API support to existing `StatefulWidget`:

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

- `setup` only receives one parameter: `context` (no `props` parameter)
- Provides `props` getter for reactive access to Widget properties
- Compatible with traditional `State` lifecycle methods (`initState`, `dispose`, etc.)

**Two Ways to Access Widget Properties:**

```dart
setup(context) {
  // 1. widget.property - Non-reactive (equivalent to props.peek in SetupWidget)
  //    Used for one-time initialization, won't trigger updates on changes
  final initial = widget.initialValue;
  
  // 2. props.property - Reactive (equivalent to props() in SetupWidget)
  //    Used in computed/effects to respond to property changes
  final reactive = useComputed(() => props.initialValue * 2);
  
  return () => Text('${reactive.value}');
}
```

**State Context and `this` Reference:**

Unlike `SetupWidget` (similar to `StatelessWidget`), `SetupMixin` runs in a `State` class, giving you full access to `this` and mutable state:

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

**Key Point**: `SetupWidget` is similar to `StatelessWidget` - the Widget class itself should be immutable. `SetupMixin` works in a `State` class where you can freely use `this`, define methods, maintain fields, and leverage the full capabilities of stateful Widgets.

## Choosing the Right Pattern

SetupWidget, SetupMixin, and standard Flutter widget patterns solve different constraints. Use the one that matches the widget shape and lifecycle needs of the code you are writing.

**When to use SetupWidget:**
- Creating simple, immutable Widgets (similar to `StatelessWidget`)
- Want pure Composition API
- Don't need instance methods, mutable fields, or `this` reference
- All logic can be expressed through reactive hooks

**When to use SetupMixin:**
- Need instance methods, fields, or access to `this`
- Need to use existing State mixins, special State base classes, or State extensions
- Want to combine Composition API with imperative logic
- Need full control over `State` lifecycle methods (`initState`, `dispose`, `didUpdateWidget`, etc.)
- Handling complex Widget logic that can benefit from both approaches

## Available Hooks

Setup Widget provides hooks for all Jolt reactive primitives:

> **💡 About Using Hooks**
>
> For reactive objects like `Signal` and `Computed`, if they will be garbage collected when the widget unmounts (e.g., local variables in the setup function), you can create them directly without using hooks. The main purpose of Hooks is to ensure proper cleanup and state preservation during widget unmount or hot reload.
>
> ```dart
> setup(context, props) {
>   // Using hooks - hook-managed lifecycle
>   final count = useSignal(0);
>   
>   // Not using hooks - Also fine, will be GC'd after widget unmount
>   final temp = Signal(0);
>   
>   return () => Text('Count: ${count.value}');
> }
> ```

### Reactive State Hooks

| Hook | Description |
|------|-------------|
| `useSignal(initial)` | Create reactive Signal |
| `useSignal.lazy<T>()` | Create lazy-loaded Signal |
| `useSignal.list(initial)` | Create reactive list |
| `useSignal.map(initial)` | Create reactive Map |
| `useSignal.set(initial)` | Create reactive Set |
| `useSignal.iterable(getter)` | Create reactive Iterable |
| `useSignal.async(source)` | Create async Signal |
| `useSignal.persist(...)` | Create persistent Signal |

### Computed Value Hooks

| Hook | Description |
|------|-------------|
| `useComputed(fn)` | Create computed value |
| `useComputed.withPrevious(getter)` | Create computed value with access to previous value |
| `useComputed.writable(getter, setter)` | Create writable computed value |
| `useComputed.writableWithPrevious(getter, setter)` | Create writable computed value with access to previous value |
| `useComputed.convert(source, decode, encode)` | Create type-converting computed value |

### Effect Hooks

| Hook | Description |
|------|-------------|
| `useEffect(fn)` | Create side effect |
| `useEffect.lazy(fn)` | Create deferred side effect (call `run()` to start tracking) |
| `useWatcher(sourcesFn, fn)` | Create watcher |
| `useWatcher.immediately(...)` | Create immediately executing watcher |
| `useWatcher.once(...)` | Create one-time watcher |

### Lifecycle Hooks

| Hook | Description |
|------|-------------|
| `onMounted(fn)` | Callback when Widget is mounted |
| `onUnmounted(fn)` | Callback when Widget is unmounted |
| `onDidUpdateWidget(fn)` | Callback when Widget is updated |
| `onDidChangeDependencies(fn)` | Callback when dependencies change |
| `onActivated(fn)` | Callback when Widget is activated |
| `onDeactivated(fn)` | Callback when Widget is deactivated |

### Utility Hooks

| Hook | Description |
|------|-------------|
| `useContext()` | Get BuildContext |
| `useSetupContext()` | Get JoltSetupContext |
| `useEffectScope()` | Create effect scope |
| `useJoltStream(value)` | Create stream from reactive value |
| `useUntil(source, predicate)` | Wait for a reactive value to satisfy a condition |
| `useUntil.when(source, value)` | Wait for a reactive value to equal a specific value |
| `useUntil.changed(source)` | Wait for a reactive value to change from its current value |
| `useMemoized(creator, [disposer])` | Memoize value with optional cleanup function |
| `useAutoDispose(creator)` | Auto-dispose resource |
| `useHook(hook)` | Use custom hook |

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

**Guidelines:**
- Use composition hooks for simple reusable logic
- Use class-based hooks for complex hooks with state or configuration
- Add `@defineHook` annotation to enable lint checking and enforce hook rules

**Usage Examples:**

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

### Flutter Resource Hooks

You can use Hooks provided by the `jolt_setup` package:

```dart
import 'package:jolt_setup/hooks.dart';

setup(context, props) {
  final controller = useTextEditingController('Initial text');
  final focusNode = useFocusNode();
  final scrollController = useScrollController();

  return () => TextField(
    controller: controller,
    focusNode: focusNode,
  );
}
```

## Automatic Resource Cleanup

All hooks automatically clean up their resources when Widgets are unmounted, ensuring proper cleanup and preventing memory leaks:

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

## Reactive Updates

When accessing reactive values in the returned build function, Widgets automatically rebuild when dependencies change:

```dart
setup(context, props) {
  final count = useSignal(0);
  final doubled = useComputed(() => count.value * 2);

  return () => Column(
    children: [
      Text('Count: ${count.value}'),      // Rebuilds when count changes
      Text('Doubled: ${doubled.value}'),  // Rebuilds when doubled changes
    ],
  );
}
```

## Complete Examples

### Counter Example

```dart
class CounterWidget extends SetupWidget<CounterWidget> {
  const CounterWidget({super.key});

  @override
  setup(context, props) {
    final count = useSignal(0);

    onMounted(() {
      print('Counter widget mounted');
    });

    onUnmounted(() {
      print('Counter widget unmounted');
    });

    return () => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Count: ${count.value}'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => count.value--,
              child: Text('-'),
            ),
            SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => count.value++,
              child: Text('+'),
            ),
          ],
        ),
      ],
    );
  }
}
```

### Form Example

```dart
class LoginForm extends SetupWidget<LoginForm> {
  const LoginForm({super.key});

  @override
  setup(context, props) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useSignal(false);

    final canSubmit = useComputed(() {
      return emailController.text.isNotEmpty &&
             passwordController.text.isNotEmpty &&
             !isLoading.value;
    });

    return () => Column(
      children: [
        TextField(
          controller: emailController,
          decoration: InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        ElevatedButton(
          onPressed: canSubmit.value ? () {
            isLoading.value = true;
            // Handle login
          } : null,
          child: isLoading.value
              ? CircularProgressIndicator()
              : Text('Login'),
        ),
      ],
    );
  }
}
```

## Important Notes

1. **setup executes only once**: The `setup` function only executes once when the Widget is created, not on every rebuild.

2. **Hook synchronous calls**: Hooks must be called synchronously within the `setup` function, and cannot be called in async functions or callbacks.

3. **Automatic cleanup**: All resources created through Hooks are automatically cleaned up when Widgets are unmounted.

4. **Reactive updates**: When accessing reactive values in the returned build function, Widgets automatically rebuild when dependencies change.

5. **Type safety**: `SetupWidget` provides complete type safety with compile-time type checking.

6. **Hot reload support**: `SetupWidget` supports hot reload, and Hook state is preserved during hot reload. The following hooks support fine-grained hot reload, updating their callback functions, condition functions, and configuration parameters during hot reload:
   - `useEffect` / `useFlutterEffect`
   - `useWatcher`
   - `useFuture` / `useStreamSubscription`
   - `useAppLifecycle`
   - `useValueListenable` / `useListenable`
   
   When you modify these hooks' parameters (such as effect functions, watcher callbacks, future sources, or listener callbacks) during hot reload, the hooks will automatically update their internal state without requiring a full widget rebuild.
