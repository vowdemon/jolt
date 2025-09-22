import 'package:jolt/jolt.dart' as jolt;

import 'value_notifier.dart';

/// A read-only signal that integrates with Flutter's ValueNotifier system.
///
/// [ReadonlySignal] provides a read-only interface to reactive values that
/// can be observed by Flutter widgets. It implements both Jolt's signal
/// interface and Flutter's ValueNotifier for seamless integration.
///
/// ## Example
///
/// ```dart
/// final ReadonlySignal<int> counter = Signal(0).readonly();
///
/// // Use in widgets
/// ValueListenableBuilder<int>(
///   valueListenable: counter,
///   builder: (context, value, child) => Text('$value'),
/// )
/// ```
abstract class ReadonlySignal<T>
    implements jolt.ReadonlySignal<T>, JoltValueNotifier<T> {}

/// A mutable reactive signal that integrates with Flutter's ValueNotifier system.
///
/// [Signal] is the primary way to create reactive state in Flutter apps using Jolt.
/// It holds a value that can be read and written, automatically notifying listeners
/// when the value changes.
///
/// ## Parameters
///
/// - [value]: The initial value of the signal
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final counter = Signal(0);
///
/// // Read the value
/// print(counter.value); // 0
///
/// // Update the value
/// counter.value = 5;
///
/// // Use in reactive widgets
/// JoltBuilder(
///   builder: (context) => Text('Count: ${counter.value}'),
/// )
/// ```
class Signal<T> extends jolt.Signal<T>
    with JoltValueNotifier<T>
    implements ReadonlySignal<T> {
  Signal(super.value, {super.autoDispose});
}

/// Extension methods for [Signal] to provide additional Flutter integration.
extension JoltFlutterSignalExtension<T> on Signal<T> {
  /// Returns a read-only view of this signal.
  ///
  /// This method provides a way to expose a signal as read-only to prevent
  /// external code from modifying its value while still allowing observation.
  ///
  /// ## Returns
  ///
  /// A [ReadonlySignal] view of this signal
  ///
  /// ## Example
  ///
  /// ```dart
  /// final _counter = Signal(0);
  /// ReadonlySignal<int> get counter => _counter.readonly();
  ///
  /// // External code can only read, not write
  /// print(counter.value); // OK
  /// // counter.value = 5; // Compile error
  /// ```
  ReadonlySignal<T> readonly() => this;
}
