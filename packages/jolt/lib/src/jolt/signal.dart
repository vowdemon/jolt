import "package:jolt/core.dart";
import "package:jolt/src/jolt/base.dart";
import "package:meta/meta.dart";

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
class SignalImpl<T> extends SignalReactiveNode<T>
    with ReadonlyNodeMixin<T>
    implements Signal<T> {
  /// Creates a new signal with the given initial value.
  ///
  /// Parameters:
  /// - [value]: The initial value of the signal
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final name = Signal('Alice');
  /// final counter = Signal(0);
  /// ```
  SignalImpl(T? value, {JoltDebugFn? onDebug})
      : super(flags: ReactiveFlags.mutable, pendingValue: value) {
    JoltDebug.create(this, onDebug);
  }

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
  T get peek {
    assert(!isDisposed, "Signal is disposed");
    return pendingValue as T;
  }

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
  T get value => get();

  /// Returns the current value and establishes a reactive dependency.
  ///
  /// This is equivalent to accessing the [value] getter.
  ///
  /// Returns: The current value of the signal
  ///
  /// Example:
  /// ```dart
  /// final current = counter.get();
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get() {
    assert(!isDisposed, "Signal is disposed");

    return getSignal(this);
  }

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
  set value(T value) => set(value);

  /// {@macro jolt_signal_set}
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T set(T value) {
    assert(!isDisposed, "Signal is disposed");
    return setSignal(this, value);
  }

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
  void notify() {
    assert(!isDisposed, "Signal is disposed");
    notifySignal(this);
  }

  /// Disposes the signal and cleans up resources.
  ///
  /// Removes the signal from the reactive system and clears stored values.
  ///
  /// Example:
  /// ```dart
  /// counter.dispose();
  /// ```
  @override
  @mustCallSuper
  @protected
  void onDispose() {
    disposeNode(this);
  }
}

/// A read-only interface for signals that prevents modification.
///
/// This is useful for exposing signals publicly while maintaining
/// write access control internally.
///
/// Example:
/// ```dart
/// class Counter {
///   final _count = Signal(0);
///
///   ReadonlySignal<int> get count => _count.readonly();
///
///   void increment() => _count.value++;
/// }
/// ```
abstract interface class ReadonlySignal<T>
    implements Readonly<T>, ReadonlyNode<T> {}

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
    implements
        Writable<T>,
        WritableNode<T>,
        ReadonlyNode<T>,
        ReadonlySignal<T> {
  factory Signal(T value, {JoltDebugFn? onDebug}) = SignalImpl;
}
