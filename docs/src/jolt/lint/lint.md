---
---

# Jolt Lint

`jolt_lint` is a lint tool specifically designed for the Jolt reactive state management ecosystem, providing code transformation assists and rule checking functionality.

## Installation

Add to `analysis_options.yaml`:

```yaml
plugins:
  jolt_lint: ^2.0.0-beta.1
```

## Requirements

⚠️ **Version Requirement**: This lint tool only supports Jolt 2.0 and above.

## Code Transformation Assists

### Convert to Signal

Quickly convert regular variables to `Signal`. This feature will:

- Wrap variable type as `Signal<T>`
- Wrap initialization expression as `Signal(...)`
- Automatically add `.value` access at all reference points within the variable's scope

**Use Case**: When you want to convert a regular variable to a reactive signal.

**Example**:
```dart
// Before conversion
int count = 0;

// After conversion
Signal<int> count = Signal(0);
// All references to count are automatically changed to count.value
```

### Convert from Signal

Convert `Signal` back to a regular variable. This feature will:

- Unwrap `Signal<T>` type to `T`
- Unwrap `Signal(...)` initialization expression to original value
- Automatically remove all `.value` access within the variable's scope

**Use Case**: When you find a variable doesn't need reactive features and want to simplify code.

**Example**:
```dart
// Before conversion
Signal<int> count = Signal(0);
print(count.value);

// After conversion
int count = 0;
print(count);
```

## Widget Wrapping Assists

Multiple quick assist features for wrapping Widgets, helping you quickly integrate Jolt's reactive components.

### Wrap with JoltBuilder

Wrap Widget with `JoltBuilder`, automatically responding to all accessed signal changes.

**Use Case**: When you need Widget to respond to signal changes.

**Example**:
```dart
// Before conversion
Text('Hello')

// After conversion
JoltBuilder(builder: (context) => Text('Hello'))
```

### Wrap with JoltProvider

Wrap Widget with `JoltProvider` to provide reactive state in the Widget tree.

**Use Case**: When you need to provide shared reactive state in the Widget tree.

**Example**:
```dart
// Before conversion
MyWidget()

// After conversion
JoltProvider(
  create: (context) => null,  // Fill in actual creation logic
  builder: (context, provider) => MyWidget()
)
```

### Wrap with JoltSelector

Wrap Widget with `JoltSelector` to implement fine-grained state selection updates.

**Use Case**: When you only want to respond to specific state changes, not all signals.

**Example**:
```dart
// Before conversion
Text(counter.value.toString())

// After conversion
JoltSelector(
  selector: (prev) => null,  // Fill in selector logic
  builder: (context, state) => Text(counter.value.toString())
)
```

### Wrap with SetupBuilder

Wrap Widget with `SetupBuilder` to use Jolt's Setup pattern.

**Use Case**: When you want to use the Setup pattern to organize Widget's reactive logic.

**Example**:
```dart
// Before conversion
MyWidget()

// After conversion
SetupBuilder(setup: (context) { return ()=> MyWidget()})
```

## Lint Rules

### no_setup_this

Prohibits direct or indirect access to instance members (through `this` or implicit access) in `SetupWidget`'s `setup` method.

**Rule Description**:

This rule only applies to `SetupWidget`, ensuring that instance members can only be accessed through the `props` parameter in the `setup` method, maintaining Setup pattern purity and testability.

⚠️ **Note**: This rule does not apply to `SetupMixin`. `SetupMixin` is used in `State` classes and can normally access `this` and instance members.

**Checks**:
- ❌ Explicit use of `this.field` or `this.method()`
- ❌ Implicit access to instance members (e.g., directly using `field` or `method()`)
- ❌ Assigning `this` to a variable
- ❌ Assigning `this` to a setter

**Correct Example**:
```dart
class MyWidget extends SetupWidget {
  int count = 0;
  
  @override
  Widget setup(BuildContext context, MyWidget props) {
    // ✅ Access instance members through props()
    return Text(props().count.toString());
  }
}
```

**Incorrect Example**:
```dart
class MyWidget extends SetupWidget {
  int count = 0;
  
  @override
  Widget setup(BuildContext context, MyWidget props) {
    // ❌ Cannot directly access this.count
    return Text(this.count.toString());
    
    // ❌ Cannot implicitly access count
    return Text(count.toString());
  }
}
```

**SetupMixin Not Restricted by This Rule**:

`SetupMixin` is used in `State` classes and can normally access `this` and instance members:

```dart
class _MyWidgetState extends State<MyWidget> with SetupMixin<MyWidget> {
  int count = 0;
  
  @override
  setup(BuildContext context) {
    // ✅ SetupMixin can normally use this
    return Text(this.count.toString());
    
    // ✅ Can also implicitly access
    return Text(count.toString());
  }
}
```

**Quick Fix Support**:

This rule provides automatic fix functionality, quickly converting incorrect code to correct form:

- 🔧 **Single Fix**: Place cursor on problematic code, press `Ctrl+.` (or `Cmd+.`) and select "Replace this with props()" or "Add props() to the member" to automatically fix
- 🔧 **Batch Fix**: The fix menu also provides "Fix all setup this issues" option, which can fix all related issues in the file at once

**Fix Example**:
```dart
// Before fix
Widget setup(BuildContext context, MyWidget props) {
  return Text(this.count.toString());
  // or
  return Text(count.toString());
}

// After fix
Widget setup(BuildContext context, MyWidget props) {
  return Text(props().count.toString());
}
```

## Usage

After configuration, your IDE (such as VS Code, Android Studio) will automatically provide:

- **Code Assists**: Place cursor on variable or Widget, press `Ctrl+.` (or `Cmd+.`) to view available transformation options
- **Real-time Checking**: Code violating the `no_setup_this` rule will show error hints and automatic fix suggestions

## Important Notes

1. **IDE Support**: Code assist features require IDE support for Dart analysis server plugins
2. **Scope Limitations**: Code transformation features automatically update all references within the variable's scope
3. **Type Safety**: All transformations maintain type safety and won't break code type checking
4. **Batch Fix**: The `no_setup_this` rule supports batch fixes, allowing you to fix all related issues in the file at once

