import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';

/// Implementation of [Signal] that holds a value and notifies subscribers when it changes.
///
/// This is the concrete implementation of the [Signal] interface. Signals are the
/// foundation of the reactive system. They store state and automatically track
/// dependencies when accessed within reactive contexts.
///
/// See [Signal] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final counter = Signal(0);
///
/// // Read the value
/// print(counter.value); // 0
///
/// // Update the value
/// counter.value = 1;
///
/// // Use in computed values
/// final doubled = Computed(() => counter.value * 2);
/// ```
class SignalImpl<T> implements Signal<T> {
  final SignalNode<T> raw;

  /// {@template jolt_signal_impl}
  /// Creates a new signal with the given initial value.
  ///
  /// Parameters:
  /// - [value]: The initial value of the signal
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final name = Signal('Alice');
  /// final counter = Signal(0);
  /// ```
  /// {@endtemplate}
  SignalImpl(T? value, {JoltDebugOption? debug})
      : raw = SignalNode(value, debug: debug);

  /// Returns the current value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity,
  /// such as in event handlers or side effects.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// print(counter.peek); // Doesn't create dependency
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get peek => raw.peek();

  /// Returns the current value and establishes a reactive dependency.
  ///
  /// When accessed within a reactive context (like a Computed or Effect),
  /// the context will be notified when this signal changes.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final doubled = Computed(() => counter.value * 2); // Creates dependency
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get value => raw.get();

  /// {@template jolt_signal_set}
  /// Sets a new value for the signal and notifies subscribers when it changes.
  ///
  /// Parameters:
  /// - [value]: The new value to set
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// counter.value = 10;
  /// counter.set(11);
  /// ```
  /// {@endtemplate}
  ///
  /// {@macro jolt_signal_set}
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  set value(T value) => raw.set(value);

  /// Manually notifies all subscribers that this signal has changed.
  ///
  /// This is typically called automatically when the value changes,
  /// but can be called manually for custom notification scenarios.
  ///
  /// Example:
  /// ```dart
  /// counter.notify(); // Force downstream effects to run
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void notify() => raw.notify();

  /// Disposes the signal and cleans up resources.
  ///
  /// The signal is no longer reactive and will not participate in updates or propagation.
  ///
  /// Example:
  /// ```dart
  /// counter.dispose();
  /// ```
  @override
  @mustCallSuper
  void dispose() => raw.dispose();

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  String toString() => value.toString();
}
