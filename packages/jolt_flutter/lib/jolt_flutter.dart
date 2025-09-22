/// A Flutter integration package for Jolt reactive state management.
///
/// This package provides Flutter-specific widgets and utilities for working with
/// Jolt signals, computed values, and reactive state. It includes widgets like
/// [JoltBuilder] for reactive UI updates and seamless integration with Flutter's
/// ValueNotifier system.
///
/// ## Example
///
/// ```dart
/// import 'package:jolt_flutter/jolt_flutter.dart';
///
/// final counter = Signal(0);
///
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return JoltBuilder(
///       builder: (context) => Text('Count: ${counter.value}'),
///     );
///   }
/// }
/// ```
library;

export 'src/jolt_builder.dart';
export 'src/signal.dart';
export 'src/computed.dart';
export 'src/collection.dart';
export 'src/async.dart';
export 'src/extension.dart';
export 'src/value_notifier.dart';
export 'package:jolt/jolt.dart'
    hide
        Computed,
        WritableComputed,
        Signal,
        ReadonlySignal,
        AsyncSignal,
        FutureSignal,
        StreamSignal,
        IterableSignal,
        ListSignal,
        MapSignal,
        SetSignal;
