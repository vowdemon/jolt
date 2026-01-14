# Jolt Flutter Hooks

> **⚠️ This package has been migrated**
>
> This package name (`jolt_flutter_hooks`) was ambiguous and could be confused with the `flutter_hooks` ecosystem. All functionality has been migrated to [`jolt_setup`](https://pub.dev/packages/jolt_setup).
>
> **Please use [`jolt_setup`](https://pub.dev/packages/jolt_setup) instead.**
>
> The `jolt_setup` package includes:
> - Setup Widget API (SetupWidget, SetupMixin, SetupBuilder)
> - All Flutter hooks (useTextEditingController, useScrollController, useFocusNode, etc.)
> - All reactive hooks (useSignal, useComputed, useEffect, etc.)

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_setup](https://img.shields.io/pub/v/jolt_setup?label=jolt_setup)](https://pub.dev/packages/jolt_setup)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

## Migration Guide

### Update your dependencies

**Before:**
```yaml
dependencies:
  jolt_flutter_hooks: ^1.0.0
```

**After:**
```yaml
dependencies:
  jolt_setup: ^1.0.0
```

### Update your imports

**Before:**
```dart
import 'package:jolt_flutter_hooks/jolt_flutter_hooks.dart';
```

**After:**
```dart
import 'package:jolt_setup/hooks.dart';
```

All APIs remain the same - only the package name has changed.

## Quick Start (jolt_setup)

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

## Related Packages

Jolt Setup is part of the Jolt ecosystem. Explore these related packages:

| Package | Description |
|---------|-------------|
| [jolt](https://pub.dev/packages/jolt) | Core library providing Signals, Computed, Effects, and reactive collections |
| [jolt_setup](https://pub.dev/packages/jolt_setup) | Setup Widget API and Flutter hooks: SetupWidget, SetupMixin, useTextEditingController, useScrollController, etc. |
| [jolt_hooks](https://pub.dev/packages/jolt_hooks) | Hooks API: useSignal, useComputed, useJoltEffect, useJoltWidget |
| [jolt_surge](https://pub.dev/packages/jolt_surge) | Signal-powered Cubit pattern: Surge, SurgeProvider, SurgeConsumer |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
