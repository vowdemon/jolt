/// Jolt - A reactive system for Dart and Flutter.
///
/// ## Documentation
///
/// [Official Documentation](https://jolt.vowdemon.com)
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:jolt/jolt.dart';
///
/// void main() {
///   // Create reactive state
///   final count = Signal(0);
///   final doubled = Computed(() => count.value * 2);
///
///   // React to changes
///   Effect(() {
///     print('Count: ${count.value}, Doubled: ${doubled.value}');
///   });
///
///   count.value = 5; // Prints: "Count: 5, Doubled: 10"
/// }
/// ```
library;

export 'src/jolt/base.dart';
export 'src/jolt/effect.dart';
export 'src/jolt/computed.dart';
export 'src/jolt/signal.dart';
export 'src/jolt/async.dart';
export 'src/jolt/track.dart';
export 'src/jolt/batch.dart';

export 'src/jolt/collection/iterable_signal.dart';
export 'src/jolt/collection/list_signal.dart';
export 'src/jolt/collection/map_signal.dart';
export 'src/jolt/collection/set_signal.dart';
export 'src/jolt/extension/signal.dart';
export 'src/jolt/extension/stream.dart';
export 'src/core/debug.dart' show JoltDebugFn, DebugNodeOperationType;
