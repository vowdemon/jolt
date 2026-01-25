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
    with DisposableNodeMixin
    implements Signal<T> {
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
      : super(flags: ReactiveFlags.mutable, pendingValue: value) {
    JoltDebug.create(this, debug);
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
  T get value {
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
  set value(T value) {
    assert(!isDisposed, "Signal is disposed");
    setSignal(this, value);
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
  void notify([bool force = true]) {
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

  @override
  String toString() => value.toString();
}

/// Implementation of [Signal] that holds a value and notifies subscribers when it changes.
/// Base implementation of read-only signal for storing state and tracking dependencies.
class ReadonlySignalImpl<T> extends SignalReactiveNode<T>
    with DisposableNodeMixin
    implements ReadableNode<T>, ReadonlySignal<T> {
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
  ReadonlySignalImpl(T? value, {JoltDebugOption? debug})
      : super(flags: ReactiveFlags.mutable, pendingValue: value) {
    JoltDebug.create(this, debug);
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
  T get value {
    assert(!isDisposed, "Signal is disposed");

    return getSignal(this);
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
  void notify([bool force = true]) {
    assert(!isDisposed, "Signal is disposed");
    notifySignal(this);
  }

  @override
  String toString() => value.toString();
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
abstract interface class ReadonlySignal<T> implements ReadableNode<T> {
  /// Creates a constant read-only signal with a fixed value.
  ///
  /// The returned signal will always return the same value and cannot be modified.
  /// This is useful for creating immutable signals that don't change over time.
  ///
  /// Parameters:
  /// - [value]: The constant value for the signal
  ///
  /// Example:
  /// ```dart
  /// final constant = ReadonlySignal(42);
  /// print(constant.value); // Always 42
  /// ```
  const factory ReadonlySignal(T value) = _ConstantSignalImpl<T>;
}

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
    implements WritableNode<T>, ReadonlySignal<T> {
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

class _ConstantSignalImpl<T> implements ReadonlySignal<T> {
  const _ConstantSignalImpl(this._value);

  final T _value;

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get peek => _value;

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get value => _value;

  @override
  String toString() => value.toString();

  @override
  void dispose() {
    // noop
  }

  @override
  bool get isDisposed => false;

  @override
  void notify([bool force = true]) {
    // noop
  }
}
