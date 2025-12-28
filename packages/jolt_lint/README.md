# Jolt Lint

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_lint](https://img.shields.io/pub/v/jolt_lint?label=jolt_lint)](https://pub.dev/packages/jolt_lint)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A lint tool designed for the Jolt reactive state management ecosystem, providing code transformation assists, quick fixes, and rule checks.

## Installation

Add to `analysis_options.yaml`:

```yaml
plugins:
  jolt_lint: ^3.0.0
```

## Features

### 🔄 Code Transformation Assists

#### Convert to Signal

Quickly convert a regular variable to a `Signal`. This feature will:

- Wrap the variable type as `Signal<T>`
- Wrap the initialization expression as `Signal(...)`
- Automatically add `.value` access to all references within the variable's scope

**Use case**: When you want to convert a regular variable to a reactive signal.

**Example**:
```dart
// Before
int count = 0;
print(count);

// After
Signal<int> count = Signal(0);
print(count.value);
```

#### Convert from Signal

Convert a `Signal` back to a regular variable. This feature will:

- Unwrap the `Signal<T>` type to `T`
- Unwrap the `Signal(...)` initialization expression to the original value
- Automatically remove all `.value` access within the variable's scope

**Use case**: When you find that a variable doesn't need reactivity and want to simplify your code.

**Example**:
```dart
// Before
Signal<int> count = Signal(0);
print(count.value);

// After
int count = 0;
print(count);
```

#### Convert StatelessWidget to SetupWidget

Convert a `StatelessWidget` to a `SetupWidget` using Jolt's Setup pattern. This feature will:

- Change the class to extend `SetupWidget` instead of `StatelessWidget`
- Convert the `build` method to a `setup` method with `props` parameter
- Replace `this` and implicit instance member accesses with `props()` calls
- Add necessary imports

**Use case**: When you want to migrate a `StatelessWidget` to use Jolt's reactive Setup pattern.

**Example**:
```dart
// Before
class MyWidget extends StatelessWidget {
  final int count;
  
  const MyWidget({required this.count});
  
  @override
  Widget build(BuildContext context) {
    return Text(count.toString());
  }
}

// After
class MyWidget extends SetupWidget<MyWidget> {
  final int count;
  
  const MyWidget({required this.count});
  
  @override
  setup(context, props) {
    return () {
      return Text(props().count.toString());
    }
  }
}
```

#### Convert SetupWidget to StatelessWidget

Convert a `SetupWidget` back to a standard `StatelessWidget`. This feature will:

- Change the class to extend `StatelessWidget` instead of `SetupWidget`
- Convert the `setup` method to a `build` method
- Replace `props()` calls with direct instance member accesses
- Remove unnecessary imports

**Use case**: When you want to migrate away from the Setup pattern back to standard Flutter widgets.

**Example**:
```dart
// Before
class MyWidget extends SetupWidget<MyWidget> {
  final int count;
  
  const MyWidget({required this.count});
  
  @override
  setup(context, props) {
    return () => Text(props().count.toString());
  }
}

// After
class MyWidget extends StatelessWidget {
  final int count;
  
  const MyWidget({required this.count});
  
  @override
  Widget build(BuildContext context) {
    return Text(count.toString());
  }
}
```

#### Convert StatefulWidget to SetupMixin

Convert a `StatefulWidget` to use `SetupMixin`. This feature will:

- Add `SetupMixin<WidgetClass>` to the `State` class
- Convert the `build` method to a `setup` method
- Wrap the build body to return a function that returns the widget
- Add necessary imports

**Use case**: When you want to migrate a `StatefulWidget` to use Jolt's Setup pattern while keeping stateful behavior.

**Example**:
```dart
// Before
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Text('Hello');
  }
}

// After
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> with SetupMixin<MyWidget> {
  @override
  setup(BuildContext context) {
    return () {
      return Text('Hello');
    };
  }
}

```

#### Convert SetupMixin to StatefulWidget

Convert a `State` class using `SetupMixin` back to a standard `StatefulWidget`. This feature will:

- Remove `SetupMixin` from the `State` class
- Convert the `setup` method back to a `build` method
- Unwrap the setup body (remove the function wrapper)
- Replace `props()` calls with `widget` references
- Remove unnecessary imports

**Use case**: When you want to migrate away from `SetupMixin` back to standard Flutter stateful widgets.

### 📦 Widget Wrapping Assists

Multiple quick-assist features to wrap widgets, helping you rapidly integrate Jolt's reactive components.

#### Wrap with JoltBuilder

Wrap a widget with `JoltBuilder` to automatically react to changes in all accessed signals.

**Use case**: When you need a widget to react to signal changes.

**Example**:
```dart
// Before
Text('Hello')

// After
JoltBuilder(builder: (context) => Text('Hello'))
```

#### Wrap with JoltSelector

Wrap a widget with `JoltSelector` to achieve fine-grained state selection updates.

**Use case**: When you only want to react to specific state changes, rather than all signals.

**Example**:
```dart
// Before
Text(counter.value.toString())

// After
JoltSelector(
  selector: (prev) => null,  // Fill in the selector logic
  builder: (context, state) => Text(counter.value.toString())
)
```

#### Wrap with SetupBuilder

Wrap a widget with `SetupBuilder` to use Jolt's Setup pattern.

**Use case**: When you want to organize widget reactive logic using the Setup pattern.

**Example**:
```dart
// Before
MyWidget()

// After
SetupBuilder(setup: (context) { return () => MyWidget(); })
```

### ⚠️ Lint Rules

#### no_setup_this

Prohibits direct or indirect access to instance members in the `setup` method (via `this` or implicit access).

**Rule Description**:

This rule ensures that instance members can only be accessed through the `props` parameter in the `setup` method, maintaining the purity and testability of the Setup pattern.

**Checks**:
- ❌ Explicit use of `this.field` or `this.method()`
- ❌ Implicit access to instance members (e.g., directly using `field` or `method()`)
- ❌ Assigning `this` to a variable
- ❌ Assigning `this` to a setter

**Correct Example**:
```dart
class MyWidget extends SetupWidget<MyWidget> {
  int count = 0;
  
  @override
  setup(context, props) {
    // ✅ Access instance members through props()
    return () => Text(props().count.toString());
  }
}
```

**Incorrect Example**:
```dart
class MyWidget extends SetupWidget {
  int count = 0;
  
  @override
  setup(context, props) {
    // ❌ Cannot directly access this.count
    return () => Text(this.count.toString());
    
    // ❌ Cannot implicitly access count
    return () => Text(count.toString());
  }
}
```



#### no_mutable_collection_value_operation

Warns against dangerous mutation operations on mutable collection signals' `.value` property.

**Rule Description**:

This rule detects when you're performing mutation operations (other than direct assignment or simple reads) on the `.value` property of signals that implement `IMutableCollection`. These operations are dangerous because they mutate the collection without triggering reactivity.

**Checks**:
- ⚠️ Method calls on `.value` (e.g., `list.value.add()`, `map.value.clear()`)
- ⚠️ Property access mutations on `.value` (e.g., `list.value.length = 5`)
- ⚠️ Index mutations on `.value` (e.g., `list.value[0] = item`)
- ⚠️ `.get()` method calls on mutable collection signals
- ⚠️ Function call operator `()` on mutable collection signals

**Correct Example**:
```dart
final list = ListSignal<int>([1, 2, 3]);

// ✅ Direct assignment (allowed)
list.value = [4, 5, 6];

// ✅ Simple read (allowed)
print(list.value);

// ✅ Use signal's mutation methods
list.add(4);
list.remove(2);
```

**Incorrect Example**:
```dart
final list = ListSignal<int>([1, 2, 3]);

// ⚠️ Dangerous: Mutating collection directly
list.value.add(4);        // Won't trigger reactivity
list.value[0] = 10;       // Won't trigger reactivity
list.value.clear();       // Won't trigger reactivity
list.get().add(5);        // Won't trigger reactivity
```

#### no_invalid_hook_call

Enforces correct placement of hook calls (useXXX and lifecycle hooks like onMounted, onUnmounted) within `setup` functions and `SetupBuilder`.

**Rule Description**:

This rule ensures that hook calls are only placed in valid locations:
- Inside `setup` methods (but not inside the returned function)
- Inside `SetupBuilder`'s `setup` parameter method (but not inside the returned function)
- As arguments to other hook calls

**Checks**:
- ❌ Hook calls inside the returned function from `setup`
- ✅ Hook calls in `setup` method body (outside the return statement)
- ✅ Hook calls in `SetupBuilder`'s `setup` parameter method body (outside the return statement)
- ✅ Hook calls as arguments to other hook calls

**Correct Example**:
```dart
// ✅ In SetupWidget's setup method
class MyWidget extends SetupWidget<MyWidget> {
  @override
  setup(context, props) {
    // ✅ Top-level hook calls in setup method body
    final count = useSignal(0);
    final computed = useComputed(() => count.value + 1);
    return () => Text(computed.value.toString());
  }
}
```

**Incorrect Example**:
```dart
class MyWidget extends SetupWidget<MyWidget> {
  @override
  setup(context, props) {
    // ❌ Hook call inside returned function
    return () {
      final count = useSignal(0);
      return Text(count.value.toString());
    };
  }
}
```

## Usage

After configuration, your IDE (e.g., VS Code, Android Studio) will automatically provide:

## License

MIT License
