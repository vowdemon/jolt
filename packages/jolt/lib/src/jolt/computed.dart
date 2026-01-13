import "package:jolt/core.dart";
import "package:jolt/src/jolt/base.dart";
import "package:jolt/src/jolt/signal.dart";
import "package:jolt/src/jolt/track.dart";
import "package:meta/meta.dart";

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
class ComputedImpl<T> extends ComputedReactiveNode<T>
    with DisposableNodeMixin
    implements Computed<T>, ReadableNode<T>, ReadonlySignal<T> {
  /// {@template jolt_computed_impl}
  /// Creates a new computed value with the given getter function.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value based on dependencies
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubled = Computed(() => count.value * 2);
  /// final expensive = Computed(() => heavyCalculation(count.value));
  /// ```
  /// {@endtemplate}
  ComputedImpl(
    super.getter, {
    super.equals,
    JoltDebugFn? onDebug,
  }) : super(flags: ReactiveFlags.none) {
    JoltDebug.create(this, onDebug);
  }

  /// {@template jolt_computed_impl_with_previous}
  /// Creates a computed value with a getter that receives the previous value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value, receiving the previous value
  ///   (or `null` on first computation) as a parameter
  /// - [onDebug]: Optional debug callback for reactive system debugging
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
    JoltDebugFn? onDebug,
  }) {
    late final ComputedImpl<T> computed;
    T fn() => getter(computed.pendingValue);

    computed = ComputedImpl(fn, onDebug: onDebug);
    return computed;
  }

  /// Returns the current computed value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity.
  /// Note that the value may be stale if dependencies have changed.
  ///
  /// Unlike [peekCached], this method always recomputes the value (if needed)
  /// rather than returning a cached value. This ensures you get the latest
  /// computed result, but may be less efficient if you just need a quick
  /// cached value check.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// print(computed.peek); // Doesn't trigger recomputation but may recompute internally
  /// ```
  @override
  T get peek {
    assert(!isDisposed, "Computed is disposed");

    return untracked(() => getComputed(this));
  }

  /// Returns the cached computed value without establishing a reactive dependency.
  ///
  /// This method returns the cached value directly if available, without
  /// recomputing. Only computes the value if no cache exists (initial state).
  ///
  /// **Difference from [peek]:**
  /// - [peek]: Always recomputes the value if needed, ensuring you get the
  ///   latest result (though still without establishing dependencies)
  /// - [peekCached]: Returns the cached value immediately if available, only
  ///   computing when no cache exists. This is more efficient when you just
  ///   need to check the last computed value, but the value may be stale
  ///   if dependencies have changed since the last computation.
  ///
  /// Use this when you need a quick, efficient access to the last computed
  /// value and don't care if it might be slightly out of date.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// print(computed.peekCached); // Returns cached value immediately if available
  /// ```
  @override
  T get peekCached {
    assert(!isDisposed, "Computed is disposed");

    if (flags == ReactiveFlags.none) {
      return untracked(() => getComputed(this));
    }

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
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get value {
    assert(!isDisposed, "Computed is disposed");

    return getComputed(this);
  }

  /// Manually notifies all subscribers that this computed value has changed.
  ///
  /// This is typically called automatically by the reactive system when
  /// dependencies change, but can be called manually for custom scenarios.
  ///
  /// Example:
  /// ```dart
  /// computed.notify(); // Force downstream effects to re-run
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void notify() {
    assert(!isDisposed, "Computed is disposed");
    notifyComputed(this);
  }

  /// Disposes the computed value and cleans up resources.
  ///
  /// Removes the computed value from the reactive system and clears stored values.
  ///
  /// Example:
  /// ```dart
  /// computed.dispose();
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

/// Interface for computed reactive values.
///
/// Computed values are derived from other reactive values and automatically
/// update when their dependencies change. They are cached and only recompute
/// when necessary.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// Computed<int> doubled = Computed(() => count.value * 2);
/// print(doubled.value); // 0
/// count.value = 5;
/// print(doubled.value); // 10
/// ```
abstract interface class Computed<T> implements ReadableNode<T> {
  /// {@macro jolt_computed_impl}
  factory Computed(T Function() getter,
      {EqualFn? equals, JoltDebugFn? onDebug}) = ComputedImpl;

  /// {@macro jolt_computed_impl_with_previous}
  factory Computed.withPrevious(
    T Function(T?) getter, {
    EqualFn? equals,
    JoltDebugFn? onDebug,
  }) = ComputedImpl.withPrevious;

  /// Returns the cached computed value without establishing a reactive dependency.
  ///
  /// This method returns the cached value directly if available, without
  /// recomputing. Only computes the value if no cache exists (initial state).
  ///
  /// **Difference from [peek]:**
  /// - [peek]: Always recomputes the value if needed, ensuring you get the
  ///   latest result (though still without establishing dependencies)
  /// - [peekCached]: Returns the cached value immediately if available, only
  ///   computing when no cache exists. This is more efficient when you just
  ///   need to check the last computed value, but the value may be stale
  ///   if dependencies have changed since the last computation.
  ///
  /// Use this when you need a quick, efficient access to the last computed
  /// value and don't care if it might be slightly out of date.
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// print(computed.peekCached); // Returns cached value immediately if available
  /// ```
  T get peekCached;

  /// {@macro jolt_computed_get_peek}
  static const getPeek = ComputedReactiveNode.getPeek;
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
    implements WritableComputed<T>, Signal<T> {
  /// {@template jolt_writable_computed_impl}
  /// Creates a new writable computed value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value from dependencies
  /// - [setter]: Function called when the computed value is set
  /// - [onDebug]: Optional debug callback for reactive system debugging
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
  WritableComputedImpl(super.getter, this.setter,
      {super.equals, super.onDebug});

  /// {@template jolt_writable_computed_impl_with_previous}
  /// Creates a writable computed value with a getter that receives the previous value.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value, receiving the previous value
  ///   (or `null` on first computation) as a parameter
  /// - [setter]: Function called when the computed value is set
  /// - [onDebug]: Optional debug callback for reactive system debugging
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
    JoltDebugFn? onDebug,
  }) {
    late final WritableComputedImpl<T> computed;
    T fn() => getter(computed.pendingValue);

    computed =
        WritableComputedImpl(fn, setter, equals: equals, onDebug: onDebug);
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
  set value(T newValue) {
    assert(!isDisposed, "WritableComputed is disposed");
    startBatch();
    try {
      setter(newValue);
    } finally {
      endBatch();
    }
  }
}

/// Interface for writable computed reactive values.
///
/// WritableComputed allows you to create computed values that can also be
/// set directly. When set, the setter function is called to update the
/// underlying dependencies.
///
/// Example:
/// ```dart
/// final firstName = Signal('John');
/// final lastName = Signal('Doe');
///
/// WritableComputed<String> fullName = WritableComputed(
///   () => '${firstName.value} ${lastName.value}',
///   (value) {
///     final parts = value.split(' ');
///     firstName.value = parts[0];
///     lastName.value = parts[1];
///   },
/// );
/// ```
abstract interface class WritableComputed<T> implements Computed<T>, Signal<T> {
  /// {@macro jolt_writable_computed_impl}
  factory WritableComputed(
    T Function() getter,
    void Function(T) setter, {
    EqualFn? equals,
    JoltDebugFn? onDebug,
  }) = WritableComputedImpl<T>;

  /// {@macro jolt_writable_computed_impl_with_previous}
  factory WritableComputed.withPrevious(
    T Function(T?) getter,
    void Function(T) setter, {
    EqualFn? equals,
    JoltDebugFn? onDebug,
  }) = WritableComputedImpl.withPrevious;
}
