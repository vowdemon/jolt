import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';

/// Implementation of [Computed] that automatically updates when its dependencies change.
///
/// This is the concrete implementation of the [Computed] interface. Computed values
/// are derived from other reactive values and are recalculated only when their
/// dependencies change. They are cached and only recompute when necessary, making
/// them efficient for expensive calculations.
///
/// See [Computed] for the public interface and usage examples.
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
class ComputedImpl<T> implements Computed<T> {
  late final ComputedNode<T> raw;

  /// {@template jolt_computed_impl}
  /// Creates a new computed value with the given getter function.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value based on dependencies
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubled = Computed(() => count.value * 2);
  /// final expensive = Computed(() => heavyCalculation(count.value));
  /// ```
  /// {@endtemplate}
  ComputedImpl(
    T Function() getter, {
    bool Function(T current, T? previous)? equals,
    JoltDebugOption? debug,
  }) : raw = ComputedNode(getter, equals: equals) {
    // assert(() {
    //   JoltDebug.create(this, debug);
    //   return true;
    // }());
  }

  /// {@template jolt_computed_impl_with_previous}
  /// Creates a computed value with a getter that receives the previous value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value, receiving the previous value
  ///   (or `null` on first computation) as a parameter
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal<List<int>>([1, 2, 3]);
  /// final computed = Computed<List<int>>.withPrevious((prev) {
  ///   final newList = List<int>.from(signal.value);
  ///   if (prev != null &&
  ///       prev.length == newList.length &&
  ///       prev.every((item) => newList.contains(item))) {
  ///     return prev; // Return previous to maintain stability
  ///   }
  ///   return newList;
  /// });
  /// ```
  /// {@endtemplate}
  factory ComputedImpl.withPrevious(
    T Function(T?) getter, {
    EqualFn? equals,
    JoltDebugOption? debug,
  }) {
    late final ComputedImpl<T> computed;
    T fn() => getter(computed.raw.value);

    computed = ComputedImpl(fn, debug: debug);
    return computed;
  }

  /// Returns the current computed value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity.
  /// Unlike [peekCached], this method always recomputes the value if needed,
  /// ensuring you get the latest result. Use [peekCached] when you need a
  /// quick cached value and can tolerate staleness.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// print(computed.peek); // Gets latest value without creating dependency
  /// ```
  @override
  T get peek => raw.peek();

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
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get value => raw.get();

  /// Manually notifies all subscribers that this computed value has changed.
  ///
  /// This is typically called automatically by the reactive system when
  /// dependencies change, but can be called manually for custom scenarios.
  ///
  /// Parameters:
  /// - [force]: If `true`, forces notification even if the value hasn't changed
  ///   (soft update when `false`, force update when `true`). Defaults to `true`.
  ///
  /// When `force` is `false` (soft update), subscribers are only notified if
  /// the computed value actually changed. When `force` is `true` (force update),
  /// subscribers are notified regardless of whether the value changed.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// computed.notify(); // Force update: always notifies subscribers
  /// computed.notify(false); // Soft update: only notifies if value changed
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void notify([bool force = true]) => raw.notify(force);

  /// Disposes the computed value and cleans up resources.
  ///
  /// The computed is no longer reactive and will not participate in updates or propagation.
  ///
  /// Example:
  /// ```dart
  /// computed.dispose();
  /// ```
  @override
  @mustCallSuper
  void dispose() {
    raw.dispose();
  }

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  String toString() => value.toString();
}

/// Implementation of [WritableComputed] that can be both read and written.
///
/// This is the concrete implementation of the [WritableComputed] interface.
/// WritableComputed allows you to create computed values that can also be
/// set directly. When set, the setter function is called, which typically
/// updates the underlying dependencies.
///
/// See [WritableComputed] for the public interface and usage examples.
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
class WritableComputedImpl<T> extends ComputedImpl<T>
    implements WritableComputed<T> {
  /// {@template jolt_writable_computed_impl}
  /// Creates a new writable computed value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value from dependencies
  /// - [setter]: Function called when the computed value is set
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubleCount = WritableComputed(
  ///   () => count.value * 2,
  ///   (value) => count.value = value ~/ 2,
  /// );
  /// ```
  /// {@endtemplate}
  WritableComputedImpl(super.getter, this.setter, {super.equals, super.debug});

  /// {@template jolt_writable_computed_impl_with_previous}
  /// Creates a writable computed value with a getter that receives the previous value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value, receiving the previous value
  ///   (or `null` on first computation) as a parameter
  /// - [setter]: Function called when the computed value is set
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal([5]);
  /// final computed = WritableComputed<int>.withPrevious(
  ///   (prev) {
  ///     final newValue = signal.value[0] * 2;
  ///     if (prev != null && prev == newValue) {
  ///       return prev;
  ///     }
  ///     return newValue;
  ///   },
  ///   (value) => signal.value = [value ~/ 2],
  /// );
  /// ```
  /// {@endtemplate}
  factory WritableComputedImpl.withPrevious(
    T Function(T?) getter,
    void Function(T) setter, {
    EqualFn? equals,
    JoltDebugOption? debug,
  }) {
    late final WritableComputedImpl<T> computed;
    T fn() => getter(computed.raw.value);

    computed = WritableComputedImpl(fn, setter, equals: equals, debug: debug);
    return computed;
  }

  /// The function called when this computed value is set.
  final void Function(T) setter;

  /// {@template jolt_writable_computed_set}
  /// Sets a new value for this writable computed by delegating to the
  /// user-provided setter inside a batch so downstream watchers flush once.
  ///
  /// Parameters:
  /// - [newValue]: Value forwarded to the setter
  ///
  /// Example:
  /// ```dart
  /// final writableComputed = WritableComputed(getter, setter);
  /// writableComputed.value = newValue; // Calls setter(newValue)
  /// ```
  /// {@endtemplate}
  ///
  /// {@macro jolt_writable_computed_set}
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  set value(T newValue) => batch(() => setter(newValue));
}
