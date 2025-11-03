---
---

# PersistSignal

PersistSignal is used in the reactive system to create signals that automatically persist to storage. It automatically writes to storage when values change and loads values from storage when needed, suitable for saving user settings, theme preferences, cached data, and other scenarios requiring persistence.

```dart
import 'package:jolt/jolt.dart';
import 'package:jolt/tricks.dart';
import 'package:shared_preferences/shared_preferences.dart';

final theme = PersistSignal(
  initialValue: () => 'light',
  read: () => SharedPreferences.getInstance()
    .then((prefs) => prefs.getString('theme') ?? 'light'),
  write: (value) => SharedPreferences.getInstance()
    .then((prefs) => prefs.setString('theme', value)),
);

// Setting value automatically saves
theme.value = 'dark'; // Automatically saved to SharedPreferences

// Reading value automatically loads from storage
print(theme.value); // Outputs saved value
```

## Creation

Use the `PersistSignal` constructor to create a persistent signal:

```dart
final signal = PersistSignal(
  initialValue: () => defaultValue,
  read: () async => loadFromStorage(),
  write: (value) async => saveToStorage(value),
  lazy: false, // Whether to lazy load
  writeDelay: Duration(milliseconds: 100), // Debounce write delay
);
```

Parameter description:
- `initialValue`: Function that returns the initial value
- `read`: Async function that reads value from storage
- `write`: Async function that writes value to storage
- `lazy`: Whether to lazy load (defaults to false, loads immediately)
- `writeDelay`: Write debounce delay (optional)

## Lazy Loading

By default, PersistSignal immediately loads values from storage. Using `lazy: true` delays value loading until first access:

```dart
// Immediate load (default)
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () async => loadTheme(),
  write: (value) async => saveTheme(value),
  lazy: false, // Immediate load
);

// Lazy load
final settings = PersistSignal(
  initialValue: () => Settings(),
  read: () async => loadSettings(),
  write: (value) async => saveSettings(value),
  lazy: true, // Lazy load, only loads on first access
);
```

## Debouncing

Using `writeDelay` can debounce write operations, avoiding frequent writes. When values change multiple times in a short period, only the last change will be written to storage:

```dart
final text = PersistSignal(
  initialValue: () => '',
  read: () async => loadText(),
  write: (value) async => saveText(value),
  writeDelay: Duration(milliseconds: 500), // 500ms debounce
);

text.value = 'a';
text.value = 'ab';
text.value = 'abc';
// Only writes 'abc' after waiting 500ms after the last change
```

## Guaranteed Read

Use the `getEnsured()` method to ensure the value has been loaded from storage before returning:

```dart
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () async => loadTheme(),
  write: (value) async => saveTheme(value),
  lazy: true, // Lazy load
);

// Ensure value is loaded from storage
final value = await theme.getEnsured();
print(value); // Guaranteed to be the value from storage
```

## Guaranteed Write

Use the `setEnsured()` method to ensure the value is written to storage before returning. Can be used with the `optimistic` parameter:

```dart
final theme = PersistSignal(
  initialValue: () => 'light',
  read: () async => loadTheme(),
  write: (value) async => saveTheme(value),
);

// Immediately update value, then asynchronously write to storage
final success = await theme.setEnsured('dark', optimistic: true);
if (success) {
  print('Save successful');
} else {
  print('Save failed');
}

// Wait for write to complete before updating value
await theme.setEnsured('dark', optimistic: false);
```

