import "package:jolt/core.dart";

/// A writable reactive value that stores owned state.
///
/// Use [Signal] for owned mutable state. Expose [Readonly] instead when callers
/// should observe the value without being able to write to it.
abstract interface class Signal<T>
    implements Readable<T>, Writable<T>, Notifiable, DisposableNode {
  /// Creates a signal with [value] as its initial state.
  ///
  /// Reads through [value] participate in dependency tracking, and writes
  /// through [Signal.value] notify dependents when this signal changes.
  factory Signal(T value, {JoltDebugOption? debug}) = SignalImpl;

  /// Creates a signal without an initial value.
  ///
  /// Reading [value] or [peek] before the first write throws. Assign a value
  /// before exposing the signal to code that expects it to be initialized.
  factory Signal.lazy({JoltDebugOption? debug}) =>
      SignalImpl(null, debug: debug);

  /// The current value without establishing a reactive dependency.
  @override
  T get peek;

  /// The current value using this signal's tracked read semantics.
  ///
  /// Reading [value] inside an effect or computed value makes that subscriber
  /// react to later writes.
  @override
  T get value;

  /// Sets the current value and notifies dependents when the visible value changes.
  @override
  set value(T value);

  /// Notifies dependents without writing a new value.
  ///
  /// Use [notify] after mutating data in place or when this signal should flush
  /// subscribers even though the stored reference stays the same.
  @override
  void notify();

  /// Disposes this signal and removes it from future propagation.
  @override
  void dispose();
}
