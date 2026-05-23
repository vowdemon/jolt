# Jolt Flutter

[![CI/CD](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml/badge.svg)](https://github.com/vowdemon/jolt/actions/workflows/cicd.yml)
[![codecov](https://codecov.io/gh/vowdemon/jolt/graph/badge.svg?token=CBL7C4ZRZD)](https://codecov.io/gh/vowdemon/jolt)
[![jolt_flutter](https://img.shields.io/pub/v/jolt_flutter?label=jolt_flutter)](https://pub.dev/packages/jolt_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/vowdemon/jolt/blob/main/LICENSE)

Flutter widgets that rebuild from Jolt reads.

`jolt_flutter` lets Flutter views read `Signal`, `Computed`, and other Jolt values directly inside `JoltBuilder`. When those reads change, Flutter rebuilds that part of the tree.

It re-exports `jolt`, so most Flutter apps can import `package:jolt_flutter/jolt_flutter.dart` and start there.

## A Small Example

```dart
import 'package:flutter/material.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

final counter = Signal(0);

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JoltBuilder(
            builder: (context) => Text('Count: ${counter.value}'),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => counter.value++,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

`JoltBuilder` is the default entry point. It runs `builder` in a reactive scope, so any Jolt value read there becomes a rebuild dependency.

## License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/vowdemon/jolt/blob/main/LICENSE) file for details.
