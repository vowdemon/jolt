import 'package:meta/meta.dart';

import '../core/debug.dart';
import '../core/reactive.dart';
import 'base.dart';
import 'signal.dart';

/// A computed value that automatically updates when its dependencies change.
///
/// Computed values are derived from other reactive values and are recalculated
/// only when their dependencies change. They are cached and only recompute
/// when necessary, making them efficient for expensive calculations.
///
/// Example:
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// print(fullName.value); // "John Doe"
/// firstName.value = 'Jane';
/// print(fullName.value); // "Jane Doe" - automatically updated
/// ```
class Computed<T> extends JReadonlyValue<T> implements ReadonlySignal<T> {
  /// Creates a new computed value with the given getter function.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value based on dependencies
  /// - [initialValue]: Optional initial value to avoid first computation
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubled = Computed(() => count.value * 2);
  /// final expensive = Computed(
  ///   () => heavyCalculation(count.value),
  ///   initialValue: 0, // Avoid first computation
  /// );
  /// ```
  Computed(
    this.getter, {
    T? initialValue,
    JoltDebugFn? onDebug,
  }) : super(flags: 0 /* ReactiveFlags.none */, pendingValue: initialValue) {
    assert(() {
      if (onDebug != null) {
        setJoltDebugFn(this, onDebug);
        onDebug(DebugNodeOperationType.create, this);
      }
      return true;
    }());
  }

  /// The function that computes the value of this computed.
  T Function() getter;

  /// Returns the current computed value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity.
  /// Note that the value may be stale if dependencies have changed.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// print(computed.peek); // Doesn't trigger recomputation
  /// ```
  @override
  T get peek {
    assert(!isDisposed);

    return pendingValue as T;
  }

  /// Returns the current computed value and establishes a reactive dependency.
  ///
  /// When accessed within a reactive context, the context will be notified
  /// when this computed value changes. The value is recalculated if needed.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => signal.value * 2);
  /// final effect = Effect(() => print(computed.value)); // Creates dependency
  /// ```
  @override
  T get value => get();

  /// Returns the current computed value and establishes a reactive dependency.
  ///
  /// This method ensures the computed value is up-to-date by recalculating
  /// if any dependencies have changed since the last computation.
  ///
  /// Returns: The current computed value
  @override
  T get() {
    assert(!isDisposed);

    return globalReactiveSystem.computedGetter(this);
  }

  /// Manually notifies all subscribers that this computed value has changed.
  ///
  /// This is typically called automatically by the reactive system when
  /// dependencies change, but can be called manually for custom scenarios.
  @override
  void notify() {
    super.notify();
    globalReactiveSystem.computedNotify(this);
  }

  @override
  @internal
  void onDispose() {
    globalReactiveSystem.nodeDispose(this);
    pendingValue = null;
  }
}

/// A writable computed value that can be both read and written.
///
/// WritableComputed allows you to create computed values that can also be
/// set directly. When set, the setter function is called, which typically
/// updates the underlying dependencies.
///
/// Example:
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
///
/// final fullName = WritableComputed(
///   () => '${firstName.value} ${lastName.value}',
///   (value) {
///     final parts = value.split(' ');
///     firstName.value = parts[0];
///     lastName.value = parts[1];
///   },
/// );
///
/// print(fullName.value); // "John Doe"
/// fullName.value = 'Jane Smith'; // Updates firstName and lastName
/// ```
class WritableComputed<T> extends Computed<T> implements Signal<T> {
  /// Creates a new writable computed value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value from dependencies
  /// - [setter]: Function called when the computed value is set
  /// - [initialValue]: Optional initial value
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubleCount = WritableComputed(
  ///   () => count.value * 2,
  ///   (value) => count.value = value ~/ 2,
  /// );
  /// ```
  WritableComputed(super.getter, this.setter,
      {super.initialValue, super.onDebug});

  /// The function called when this computed value is set.
  final void Function(T) setter;

  @override
  Object? currentValue;

  /// Sets a new value for this writable computed.
  ///
  /// This calls the setter function with the new value, which should
  /// update the underlying dependencies appropriately.
  ///
  /// Example:
  /// ```dart
  /// final writableComputed = WritableComputed(getter, setter);
  /// writableComputed.value = newValue; // Calls setter(newValue)
  /// ```
  @override
  set value(T newValue) => set(newValue);

  /// Sets a new value for this writable computed.
  ///
  /// Parameters:
  /// - [newValue]: The new value to set
  ///
  /// This calls the setter function and notifies subscribers of the change.
  ///
  /// Example:
  /// ```dart
  /// final writableComputed = WritableComputed(getter, setter);
  /// writableComputed.set(newValue); // Calls setter(newValue)
  /// ```
  @override
  void set(T newValue) {
    assert(!isDisposed);
    currentValue = newValue;
    setter(newValue);
  }
}

/// Extension methods for WritableComputed to provide additional functionality.
extension JoltWritableComputedExtension<T> on WritableComputed<T> {
  /// Returns a read-only view of this writable computed.
  ///
  /// The returned Computed cannot be used to modify the value,
  /// but still provides reactive access to the computed value.
  ///
  /// Returns: A read-only interface to this writable computed
  ///
  /// Example:
  /// ```dart
  /// final writableComputed = WritableComputed(getter, setter);
  /// final readonlyComputed = writableComputed.readonly();
  ///
  /// print(readonlyComputed.value); // OK
  /// // readonlyComputed.value = 1; // Compile error
  /// ```
  Computed<T> readonly() => this;
}
