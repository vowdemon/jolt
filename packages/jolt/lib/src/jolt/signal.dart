import 'package:jolt/src/core/debug.dart';
import 'package:meta/meta.dart';

import 'base.dart';
import '../core/reactive.dart';

/// A reactive signal that holds a value and notifies subscribers when it changes.
///
/// Signals are the foundation of the reactive system. They store state and
/// automatically track dependencies when accessed within reactive contexts.
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
class Signal<T> extends JReadonlyValue<T> implements WritableSignal<T> {
  /// Creates a new signal with the given initial value.
  ///
  /// Parameters:
  /// - [value]: The initial value of the signal
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  ///
  /// Example:
  /// ```dart
  /// final name = Signal('Alice');
  /// final counter = Signal(0, autoDispose: true);
  /// ```
  Signal(T? value, {JoltDebugFn? onDebug})
      : currentValue = value,
        super(flags: 1 /* ReactiveFlags.mutable */, pendingValue: value) {
    assert(() {
      if (onDebug != null) {
        setJoltDebugFn(this, onDebug);
        onDebug(DebugNodeOperationType.create, this);
      }
      return true;
    }());
  }

  @internal
  dynamic currentValue;

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
  @override
  T get peek {
    assert(!isDisposed);
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
  @override
  T get value => get();

  /// Returns the current value and establishes a reactive dependency.
  ///
  /// This is equivalent to accessing the [value] getter.
  ///
  /// Returns: The current value of the signal
  @override
  T get() {
    assert(!isDisposed);

    return globalReactiveSystem.signalGetter(this);
  }

  /// Sets a new value for the signal.
  ///
  /// This will notify all subscribers if the value has changed.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// counter.value = 10; // Notifies subscribers
  /// ```
  @override
  set value(T value) => set(value);

  /// Sets a new value for the signal.
  ///
  /// Parameters:
  /// - [value]: The new value to set
  ///
  /// This will notify all subscribers if the value has changed.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// counter.set(10); // Notifies subscribers
  /// ```
  @override
  void set(T value) {
    assert(!isDisposed);
    globalReactiveSystem.signalSetter(this, value);
  }

  /// Manually notifies all subscribers that this signal has changed.
  ///
  /// This is typically called automatically when the value changes,
  /// but can be called manually for custom notification scenarios.
  @override
  void notify() {
    super.notify();
    globalReactiveSystem.signalNotify(this);
  }

  @override
  @internal
  void onDispose() {
    globalReactiveSystem.nodeDispose(this);
    currentValue = null;
    pendingValue = null;
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
abstract interface class ReadonlySignal<T> implements JReadonlyValue<T> {}

abstract interface class WritableSignal<T>
    implements JWritableValue<T>, ReadonlySignal<T> {}

/// Extension methods for Signal to provide additional functionality.
extension JoltSignalExtension<T> on Signal<T> {
  /// Returns a read-only view of this signal.
  ///
  /// The returned ReadonlySignal cannot be used to modify the value,
  /// but still provides reactive access to the current value.
  ///
  /// Returns: A read-only interface to this signal
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final readonlyCounter = counter.readonly();
  ///
  /// print(readonlyCounter.value); // OK
  /// // readonlyCounter.value = 1; // Compile error
  /// ```
  ReadonlySignal<T> readonly() => this;
}
