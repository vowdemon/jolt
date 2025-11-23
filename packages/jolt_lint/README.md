# Jolt Lint

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_lint](https://img.shields.io/pub/v/jolt_lint?label=jolt_lint)](https://pub.dev/packages/jolt_lint)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

A lint tool designed for the Jolt reactive state management ecosystem, providing code transformation assists and rule checks.

## Installation

Add to `analysis_options.yaml`:

```yaml
plugins:
  jolt_lint: ^2.0.0-beta.1
```

## Requirements

⚠️ **Version Requirement**: This lint tool only supports Jolt version 2.0 and above.

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

// After
Signal<int> count = Signal(0);
// All references to count are automatically changed to count.value
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

#### Wrap with JoltProvider

Wrap a widget with `JoltProvider` to provide reactive state in the widget tree.

**Use case**: When you need to provide shared reactive state in the widget tree.

**Example**:
```dart
// Before
MyWidget()

// After
JoltProvider(
  create: (context) => null,  // Fill in the actual creation logic
  builder: (context, provider) => MyWidget()
)
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
SetupBuilder(setup: (context) { return ()=> MyWidget()})
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

**Quick Fix Support**:

This rule provides automatic fixes to quickly transform incorrect code into the correct form:

- 🔧 **Single Fix**: Place the cursor on the problematic code, press `Ctrl+.` (or `Cmd+.`) and select "Replace this with props()" or "Add props() to the member" to automatically fix it
- 🔧 **Bulk Fix**: The fix menu also provides a "Fix all setup this issues" option to fix all related issues in the file at once

⚠️ **Note**: Due to a bug in the `analysis_server_plugin` package, the multi-fix in file feature may not work properly. If you don't see the "Fix all setup this issues" option, you may need to apply a temporary workaround. See [fix_all_patch.md](fix_all_patch.md) for details.

**Fix Example**:
```dart
// Before
Widget setup(BuildContext context, MyWidget props) {
  return Text(this.count.toString());
  // or
  return Text(count.toString());
}

// After
Widget setup(BuildContext context, MyWidget props) {
  return Text(props().count.toString());
}
```


## Usage

After configuration, your IDE (e.g., VS Code, Android Studio) will automatically provide:

- **Code Assists**: Place the cursor on a variable or widget, press `Ctrl+.` (or `Cmd+.`) to view available transformation options
- **Real-time Checks**: Code that violates the `no_setup_this` rule will display error hints and automatic fix suggestions

## License

MIT License