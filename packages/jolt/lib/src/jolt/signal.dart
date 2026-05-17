import "package:jolt/core.dart";

/// A writable interface for signals that allows modification.
///
/// This interface extends ReadonlySignal to provide write access
/// to the signal's value.
///
/// Example:
/// ```dart
/// Signal<int> counter = Signal(0);
/// counter.value++;
/// ```
abstract interface class Signal<T>
    implements Readable<T>, Writable<T>, Notifiable, DisposableNode {
  /// {@macro jolt_signal_impl}
  factory Signal(T value, {JoltDebugOption? debug}) = SignalImpl;

  /// Creates a new lazy signal.
  ///
  /// Parameters:
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final name = Signal<String>.lazy();
  /// ```
  factory Signal.lazy({JoltDebugOption? debug}) =>
      SignalImpl(null, debug: debug);
}
