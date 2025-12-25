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

export "src/jolt/base.dart" hide DisposableNodeMixin;
export "src/jolt/signal.dart" hide SignalImpl, ReadonlySignalImpl;
export "src/jolt/computed.dart" hide ComputedImpl, WritableComputedImpl;
export "src/jolt/effect.dart" hide EffectImpl, EffectScopeImpl, WatcherImpl;
export "src/jolt/async.dart" hide AsyncSignalImpl;
export "src/jolt/batch.dart";
export "src/jolt/track.dart";
export "src/jolt/collection/iterable_signal.dart" hide IterableSignalImpl;
export "src/jolt/collection/list_signal.dart" hide ListSignalImpl;
export "src/jolt/collection/map_signal.dart" hide MapSignalImpl;
export "src/jolt/collection/set_signal.dart" hide SetSignalImpl;

export "src/core/debug.dart" show DebugNodeOperationType, JoltDebugFn;
