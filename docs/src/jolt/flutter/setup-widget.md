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
> These are two fundamentally different models. Avoid mixing them to prevent confusion.

## Basic Concepts

The core idea of `SetupWidget` is to separate Widget build logic into two parts:
1. **setup function**: Executes once when the Widget is created, used for initializing state, creating Hooks, etc.
2. **Returned build function**: Used to build the actual Widget, can access state created in setup

## SetupBuilder

`SetupBuilder` is the simplest way to use Setup Widget, suitable for rapid prototyping, simple components, or inline reactive Widgets:

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
- Rapid prototyping or experimenting with reactive state
- Creating simple, self-contained components
- Don't need custom Widget properties
- Component logic is simple and straightforward

**When to use SetupWidget subclass:**
- Need custom properties (title, count, callback, etc.)
- Building reusable components with clear APIs
- Component is complex or will be used in multiple places
- Need better IDE support and property type checking

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

> **💡 There's No Right or Wrong**
>
> In Jolt, there's no single "correct" way to build Widgets. SetupWidget, SetupMixin, and traditional Flutter patterns (StatelessWidget, StatefulWidget) are all first-class citizens. Each pattern has advantages in different scenarios—what's important is knowing when to use which, keeping code clear and maintainable.
>
> The Setup API itself is completely optional. If your team is familiar with standard Flutter patterns and they work well, there's no need to change. You can also use Riverpod, flutter_hooks, or any other state management solution you prefer, and even mix them in the same project.
>
> When you need composition-based logic, reactive state, or Vue/Solid-style patterns, the Setup API can provide additional capabilities—without forcing you to rewrite existing code.

**When to use SetupWidget:**
- Creating simple, immutable Widgets (similar to `StatelessWidget`)
- Want pure Composition API
- Don't need instance methods, mutable fields, or `this` reference
- Prefer cleaner, more concise code
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
>   // Using hooks - Recommended, automatic lifecycle management
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
| `useEffect.lazy(fn)` | Create side effect with lazy dependency collection |
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
| `useMemoized(creator, [disposer])` | Memoize value with optional cleanup function |
| `useAutoDispose(creator)` | Auto-dispose resource |
| `useHook(hook)` | Use custom hook |

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

2. **Hook order**: Hook call order must remain consistent. Hooks cannot be called in conditional statements.

3. **Automatic cleanup**: All resources created through Hooks are automatically cleaned up when Widgets are unmounted.

4. **Reactive updates**: When accessing reactive values in the returned build function, Widgets automatically rebuild when dependencies change.

5. **Type safety**: `SetupWidget` provides complete type safety with compile-time type checking.

6. **Hot reload support**: `SetupWidget` supports hot reload, and Hook state is preserved during hot reload.

