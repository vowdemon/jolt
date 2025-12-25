/// A Flutter integration package for [Jolt](https://pub.dev/packages/jolt) reactive state management.
///
/// This package provides Flutter-specific widgets and utilities for working with
/// Jolt signals, computed values, and reactive state. It includes widgets like
/// [JoltBuilder] for reactive UI updates and seamless integration with Flutter's
/// ValueNotifier system.
///
/// ## Documentation
///
/// [Official Documentation](https://jolt.vowdemon.com)
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

export 'package:jolt/jolt.dart';

export 'src/listenable/listenable.dart'
    hide
        JoltValueNotifierExtension,
        JoltValueListenableExtension,
        JoltValueListenableSignalExtension,
        JoltValueNotifierSignalExtension;

export 'src/widgets/jolt_builder.dart';
export 'src/widgets/jolt_selector.dart';

export 'src/widgets/jolt_watch_builder.dart';

export 'src/effect/flutter_effect.dart' show FlutterEffect;
