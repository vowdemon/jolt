---
---

# Extending Jolt

Jolt provides rich extensibility, allowing you to create your own utility tools, reactive nodes, and advanced usage techniques based on core interfaces. This guide will help you understand Jolt's extension mechanisms and demonstrate how to create custom reactive primitives.

## Understanding Core Interfaces

### ReadonlyNode Basics

`Signal`, `Computed`, etc. are all implementations of `ReadonlyNode`. Understanding `ReadonlyNode` is the foundation for extending Jolt.

```dart
abstract interface class ReadonlyNode<T>
    implements Readonly<T>, Disposable {
  /// Whether disposed
  bool get isDisposed;

  /// Release resources
  @mustCallSuper
  void dispose();
}
```

The `ReadonlyNode` interface provides the following core capabilities:

- **`.value` / `.get()`**: Read value and establish reactive dependencies (from `Readonly<T>`)
- **`.peek`**: Read value without establishing dependencies (from `Readonly<T>`)
- **`.notify()`**: Manually notify subscribers (from `Readonly<T>`)
- **`.isDisposed`**: Check if disposed
- **`.dispose()`**: Release resources

### ReadonlyNodeMixin

If you need to implement `ReadonlyNode` and require custom cleanup logic, you can use `ReadonlyNodeMixin`:

```dart
mixin ReadonlyNodeMixin<T> implements ReadonlyNode<T>, ChainedDisposable {
  @override
  bool get isDisposed => _isDisposed;
  @protected
  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    onDispose(); // Call custom cleanup logic
    JFinalizer.disposeObject(this);
  }

  /// Override this method to provide custom cleanup logic
  @protected
  void onDispose();
}
```

When using `ReadonlyNodeMixin`, you can override the `onDispose()` method to customize cleanup logic.

### Readonly Interface

The `Readonly<T>` interface defines basic operations for read-only reactive values:

```dart
abstract interface class Readonly<T> {
  T get value;
  T get();
  T get peek;
  void notify();
}
```

### Writable Interface

The `Writable<T>` interface extends `Readonly<T>`, adding write capabilities:

```dart
abstract interface class Writable<T> implements Readonly<T> {
  set value(T value);
  T set(T value);
}
```

## Type Design Principles

### Accepting Arbitrary Reactive Values

When you need to create a function or class that receives arbitrary reactive values, you should use `ReadonlyNode<T>` or `Readonly<T>` as the parameter type:

```dart
// ✅ Correct: Accept arbitrary reactive values
void processReactiveValue(ReadonlyNode<int> value) {
  print('Value: ${value.value}');
}

// ✅ Can also use Readonly<T>
void processReactiveValue2(Readonly<int> value) {
  print('Value: ${value.value}');
}

// Usage
final signal = Signal(42);
final computed = Computed(() => signal.value * 2);

processReactiveValue(signal);    // OK
processReactiveValue(computed);  // OK
```

### Best Practices for Extension Methods

If you need to write generic extensions for `Computed` or `Signal`, you should define them on their common interface:

```dart
// ✅ Correct: Define extension on ReadonlyNode
extension MyExtension<T> on ReadonlyNode<T> {
  String get displayValue => 'Value: ${value}';
}

// ✅ Correct: Define extension on Signal
extension SignalExtension<T> on Signal<T> {
  void reset() => value = null as T;
}

// ✅ Correct: Define extension on Computed
extension ComputedExtension<T> on Computed<T> {
  ReadonlyNode<T> get readonly => this;
}
```

## Extending Signal

### Signal Interface and Implementation

`Signal` is an interface, and the concrete implementation is `SignalImpl`. You can extend Signal in two ways:

1. **Extend `SignalImpl`**: Suitable for scenarios requiring modification of internal behavior
2. **Implement `Signal` interface**: Suitable for scenarios requiring completely custom implementation

### Method 1: Extending SignalImpl

`SignalImpl` uses `ReadonlyNodeMixin`, so classes extending `SignalImpl` can override `onDispose()` to customize cleanup logic.

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';
import 'dart:async';

/// Debounced signal: waits for a period after value changes before notifying subscribers
class DebouncedSignal<T> extends SignalImpl<T> {
  final Duration delay;
  Timer? _timer;

  DebouncedSignal(
    super.value, {
    required this.delay,
    super.onDebug,
  });

  @override
  T set(T value) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.set(value);
    });
    return value;
  }

  // SignalImpl uses ReadonlyNodeMixin, so can override onDispose()
  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}

// Usage
final searchQuery = DebouncedSignal(
  '',
  delay: Duration(milliseconds: 300),
);

searchQuery.value = 'j';
searchQuery.value = 'jo';
searchQuery.value = 'jolt';
// Only notifies subscribers after 300ms, with value 'jolt'
```

### Method 2: Implementing Signal Interface

If you need a completely custom implementation, you can implement the `Signal` interface:

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/core/reactive.dart';
import 'package:jolt/src/jolt/base.dart';

/// Custom Signal implementation
class CustomSignal<T> extends SignalReactiveNode<T>
    with ReadonlyNodeMixin<T>
    implements Signal<T> {
  CustomSignal(T? value, {super.onDebug})
      : super(flags: ReactiveFlags.mutable, pendingValue: value);

  @override
  T get peek => pendingValue as T;

  @override
  T get value => get();

  @override
  T get() {
    assert(!isDisposed, "Signal is disposed");
    return getSignal(this);
  }

  @override
  T set(T value) {
    assert(!isDisposed, "Signal is disposed");
    // Custom set logic
    return setSignal(this, value);
  }

  @override
  void notify() {
    assert(!isDisposed, "Signal is disposed");
    notifySignal(this);
  }

  @override
  void onDispose() {
    disposeNode(this);
  }
}
```

### Extending from Core Classes

You can also directly extend from core classes to create lower-level custom nodes:

```dart
import 'package:jolt/src/core/reactive.dart';

/// Custom reactive node
class CustomReactiveNode<T> extends SignalReactiveNode<T> {
  CustomReactiveNode(T? initialValue)
      : super(flags: ReactiveFlags.mutable, pendingValue: initialValue);

  // Implement necessary interface methods
  // ...
}
```

## Extending Computed

### Extending WritableComputed

`ConvertComputed` is a good example showing how to extend functionality by extending `WritableComputed`:

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/computed.dart';

/// Type-converting computed value
class ConvertComputedImpl<T, U> extends WritableComputedImpl<T>
    implements ConvertComputed<T, U> {
  ConvertComputedImpl(
    this.source, {
    required this.decode,
    required this.encode,
    super.onDebug,
  }) : super(
          () => decode(source.value),
          (value) => source.value = encode(value),
        );

  final WritableNode<U> source;
  final T Function(U value) decode;
  final U Function(T value) encode;
}

// Usage
final count = Signal(42);
final countText = ConvertComputed(
  count,
  decode: (int value) => value.toString(),
  encode: (String value) => int.parse(value),
);

print(countText.value); // "42"
countText.value = "100"; // count.value becomes 100
```

## Extending Hooks

### useAutoDispose Basics

In SetupWidget, `useAutoDispose` is a key Hook for automatically managing resource lifecycles. All resources created through `useAutoDispose` will automatically call `dispose()` when the Widget is unmounted:

```dart
import 'package:jolt_flutter/setup.dart';

setup(context, props) {
  // useAutoDispose automatically calls dispose() when Widget is unmounted
  final signal = useAutoDispose(() => Signal(0));
  final computed = useAutoDispose(() => Computed(() => signal.value * 2));

  return () => Text('${computed.value}');
}
```

### JoltSignalHookCreator Pattern

`useSignal` is actually an instance of `JoltSignalHookCreator`. You can extend this class to add your own signal creation methods:

```dart
import 'package:jolt_flutter/setup.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';
import 'dart:async';

/// Extend useSignal to add debounced signal method
extension DebouncedSignalExtension on JoltSignalHookCreator {
  /// Create debounced signal Hook
  Signal<T> debounce<T>(
    T value, {
    required Duration delay,
    JoltDebugFn? onDebug,
  }) {
    // useAutoDispose ensures resources are automatically released when Widget is unmounted
    return useAutoDispose(() => DebouncedSignal(
      value,
      delay: delay,
      onDebug: onDebug,
    ));
  }
}

// Usage
setup(context, props) {
  final searchQuery = useSignal.debounce(
    '',
    delay: Duration(milliseconds: 300),
  );

  return () => TextField(
    onChanged: (value) => searchQuery.value = value,
  );
}
```

### Extending useComputed

Similarly, you can also extend `useComputed`:

```dart
extension ComputedExtension on JoltUseComputed {
  /// Create debounced computed value
  Computed<T> debounced<T>(
    T Function() getter, {
    required Duration delay,
    JoltDebugFn? onDebug,
  }) {
    final source = useSignal.lazy<T>();
    Timer? timer;

    useEffect(() {
      final value = getter();
      timer?.cancel();
      timer = Timer(delay, () {
        source.value = value;
      });

      onEffectCleanup(() => timer?.cancel());
    });

    return useComputed(() => source.value);
  }
}
```

## Creating Custom Reactive Nodes

### Using CustomReactiveNode

For scenarios requiring completely custom behavior, you can use `CustomReactiveNode`:

```dart
import 'package:jolt/src/core/reactive.dart';

/// Custom reactive node example
class CustomWidgetPropsNode<T extends Widget>
    extends CustomReactiveNode<T> {
  CustomWidgetPropsNode(this._context)
      : super(flags: ReactiveFlags.mutable);

  final BuildContext _context;
  bool _dirty = false;

  @override
  T get() {
    // Establish dependencies
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(this, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }

    return _context.widget as T;
  }

  @override
  void notify() {
    _dirty = true;
    notifyCustom(this);
  }

  @override
  T get peek => _context.widget as T;

  @override
  T get value => get();

  @override
  bool updateNode() {
    if (_dirty) {
      _dirty = false;
      return true; // Value changed, notify subscribers
    }
    return false; // No change
  }

  @override
  bool get isDisposed => !_context.mounted;

  @override
  void onDispose() {
    disposeNode(this);
  }
}
```

## Practical Extension Examples

### Example 1: Throttled Signal

```dart
import 'dart:async';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';

/// Throttled signal: notifies at most once within specified time interval
class ThrottledSignal<T> extends SignalImpl<T> {
  final Duration interval;
  Timer? _timer;
  T? _pendingValue;
  bool _hasPendingValue = false;

  ThrottledSignal(
    super.value, {
    required this.interval,
    super.onDebug,
  });

  @override
  T set(T value) {
    _pendingValue = value;
    _hasPendingValue = true;

    if (_timer == null) {
      _timer = Timer.periodic(interval, (_) {
        if (_hasPendingValue) {
          super.set(_pendingValue as T);
          _hasPendingValue = false;
        } else {
          _timer?.cancel();
          _timer = null;
        }
      });
    }

    return value;
  }

  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}
```

### Example 2: Cached Signal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';

/// Cached signal: caches the most recent N values
class CachedSignal<T> extends SignalImpl<T> {
  final int cacheSize;
  final List<T> _cache = [];

  CachedSignal(
    super.value, {
    this.cacheSize = 10,
    super.onDebug,
  }) {
    if (value != null) {
      _cache.add(value as T);
    }
  }

  @override
  T set(T value) {
    _cache.add(value);
    if (_cache.length > cacheSize) {
      _cache.removeAt(0);
    }
    return super.set(value);
  }

  /// Get cached historical values
  List<T> get history => List.unmodifiable(_cache);

  /// Get the Nth historical value
  T? getHistory(int index) {
    if (index < 0 || index >= _cache.length) return null;
    return _cache[_cache.length - 1 - index];
  }
}
```

### Example 3: Validated Signal

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/src/jolt/signal.dart';

/// Validated signal: validates before setting value
class ValidatedSignal<T> extends SignalImpl<T> {
  final bool Function(T value) validator;
  final T Function(T invalidValue)? onInvalid;

  ValidatedSignal(
    super.value, {
    required this.validator,
    this.onInvalid,
    super.onDebug,
  });

  @override
  T set(T value) {
    if (validator(value)) {
      return super.set(value);
    } else {
      if (onInvalid != null) {
        return super.set(onInvalid!(value));
      }
      // Validation failed, don't update value
      return peek;
    }
  }
}

// Usage
final age = ValidatedSignal<int>(
  0,
  validator: (value) => value >= 0 && value <= 150,
  onInvalid: (value) {
    print('Invalid age: $value');
    return 0; // Return default value
  },
);

age.value = 25;  // OK
age.value = 200; // Validation failed, value remains 25
```

### Example 4: Extending useSignal to Add Throttle Method

```dart
import 'package:jolt_flutter/setup.dart';

extension ThrottledSignalExtension on JoltSignalHookCreator {
  /// Create throttled signal Hook
  Signal<T> throttle<T>(
    T value, {
    required Duration interval,
    JoltDebugFn? onDebug,
  }) {
    // useAutoDispose ensures resources are automatically released when Widget is unmounted
    return useAutoDispose(() => ThrottledSignal(
      value,
      interval: interval,
      onDebug: onDebug,
    ));
  }
}

// Usage
setup(context, props) {
  final scrollPosition = useSignal.throttle(
    0.0,
    interval: Duration(milliseconds: 100),
  );

  return () => ListView(
    onScroll: (position) => scrollPosition.value = position,
  );
}
```

### Example 5: Creating Custom Hook

You can also create completely custom Hooks:

```dart
import 'package:jolt_flutter/setup.dart';

/// Custom Hook: auto-refreshing data
class AutoRefreshHook<T> extends SetupHook<Signal<T>> {
  AutoRefreshHook({
    required this.fetch,
    required this.interval,
  });

  final Future<T> Function() fetch;
  final Duration interval;
  Timer? _timer;

  @override
  Signal<T> build() {
    final signal = useAutoDispose(() => Signal.lazy<T>());
    
    // Fetch immediately once
    _refresh(signal);
    
    // Periodic refresh
    _timer = Timer.periodic(interval, (_) => _refresh(signal));
    
    return signal;
  }

  Future<void> _refresh(Signal<T> signal) async {
    try {
      final data = await fetch();
      signal.value = data;
    } catch (e) {
      // Handle error
    }
  }

  @override
  void unmount() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Extension method for convenience
extension AutoRefreshExtension on JoltSignalHookCreator {
  Signal<T> autoRefresh<T>({
    required Future<T> Function() fetch,
    required Duration interval,
  }) {
    return useHook(AutoRefreshHook<T>(
      fetch: fetch,
      interval: interval,
    ));
  }
}

// Usage
setup(context, props) {
  final data = useSignal.autoRefresh(
    fetch: () => api.fetchData(),
    interval: Duration(seconds: 30),
  );

  return () => data.value.map(
    loading: () => CircularProgressIndicator(),
    success: (value) => Text('Data: $value'),
    error: (error, _) => Text('Error: $error'),
  ) ?? SizedBox();
}
```

## Best Practices

### 1. Prefer Composition Over Inheritance

In most cases, composing existing reactive primitives is simpler than creating new implementations:

```dart
// ✅ Recommended: Use Computed composition
final debouncedValue = Computed(() {
  // Use existing debounce logic
  return debounceFunction(source.value);
});

// ❌ Not recommended: Unless you really need custom behavior
class CustomDebouncedSignal extends SignalImpl<T> {
  // Complex custom implementation
}
```

### 2. Implement Necessary Lifecycle Methods

If you use `ReadonlyNodeMixin` or extend from a class that uses `ReadonlyNodeMixin` (such as `SignalImpl`), you can override `onDispose()` to clean up resources. `onDispose()` is of type `void` and is automatically called in the `dispose()` method:

```dart
// Extend SignalImpl (which uses ReadonlyNodeMixin)
class MySignal<T> extends SignalImpl<T> {
  Timer? _timer;
  
  @override
  void onDispose() {
    // Clean up timers, subscriptions, etc.
    _timer?.cancel();
    super.onDispose(); // Call parent's onDispose
  }
}

// Or use ReadonlyNodeMixin
class MyNode<T> with ReadonlyNodeMixin<T> implements ReadonlyNode<T> {
  Timer? _timer;
  
  @override
  T get value => throw UnimplementedError();
  
  @override
  void onDispose() {
    _timer?.cancel();
    super.onDispose();
  }
}
```

**Note**:
- The `ReadonlyNode` interface itself does not have an `onDispose()` method
- You can only override `onDispose()` when using `ReadonlyNodeMixin`
- `onDispose()` is a synchronous method. If you need async cleanup, you should start async operations in `onDispose()` but not wait for them to complete

### 3. Maintain Type Safety

Use generics to maintain type safety:

```dart
// ✅ Correct: Use generics
class MySignal<T> extends SignalImpl<T> { }

// ❌ Wrong: Loses type information
class MySignal extends SignalImpl<dynamic> { }
```

### 4. Follow Interface Contracts

If implementing interfaces, ensure you follow all contracts:

```dart
// Signal interface requires implementing these methods
@override
T get value => get();

@override
T get() { /* ... */ }

@override
T set(T value) { /* ... */ }

@override
void notify() { /* ... */ }
```

### 5. Use Extension Methods to Enhance Functionality

For scenarios that don't require modifying core behavior, use extension methods:

```dart
extension SignalHelpers<T> on Signal<T> {
  /// Reset to initial value
  void resetTo(T initialValue) => value = initialValue;

  /// Toggle boolean value
  void toggle() {
    if (value is bool) {
      value = !(value as bool) as T;
    }
  }
}
```

## Reference Implementations

Reviewing Jolt's existing implementations can help you learn extension patterns:

- **PersistSignal**: `packages/jolt/lib/src/tricks/persist_signal.dart` - Persistent signal implementation
- **ConvertComputed**: `packages/jolt/lib/src/tricks/convert_computed.dart` - Type-converting computed value
- **AsyncSignal**: `packages/jolt/lib/src/jolt/async.dart` - Async signal implementation
- **ListSignal**: `packages/jolt/lib/src/jolt/collection/list_signal.dart` - List signal implementation

These implementations demonstrate how to:
- Extend `SignalImpl` or `WritableComputedImpl`
- Implement custom `set` and `get` logic
- Handle async operations
- Manage resource lifecycles

## Important Notes

1. **Performance Considerations**: Custom implementations should remain efficient, avoiding unnecessary computations or memory allocations

2. **Thread Safety**: If you need to use in multi-threaded environments, ensure implementations are thread-safe

3. **Test Coverage**: Write comprehensive tests for custom implementations to ensure behavior meets expectations

4. **Documentation**: Write clear documentation for custom extensions, explaining use cases and important notes

5. **Backward Compatibility**: If creating public libraries, consider backward compatibility to avoid breaking changes

