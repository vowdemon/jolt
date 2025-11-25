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
    with ReadonlyNodeMixin<T>
    implements Computed<T> {
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
  ComputedImpl(
    super.getter, {
    JoltDebugFn? onDebug,
  }) : super(flags: ReactiveFlags.none) {
    JoltDebug.create(this, onDebug);
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
  T get value => get();

  /// Returns the current computed value (same as `value`).
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T call() => get();

  /// Returns the current computed value and establishes a reactive dependency.
  ///
  /// This method ensures the computed value is up-to-date by recalculating
  /// if any dependencies have changed since the last computation.
  ///
  /// Returns: The current computed value
  ///
  /// Example:
  /// ```dart
  /// final snapshot = computed.get();
  /// ```
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get() {
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
abstract interface class Computed<T> implements Readonly<T>, ReadonlyNode<T> {
  /// Creates a computed value with the given getter function.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value based on dependencies
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final computed = Computed(() => expensiveCalculation());
  /// ```
  factory Computed(T Function() getter, {JoltDebugFn? onDebug}) = ComputedImpl;

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

  /// Returns the current computed value (same as `value`).
  T call();
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
  WritableComputedImpl(super.getter, this.setter, {super.onDebug});

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
  set value(T newValue) => set(newValue);

  /// {@macro jolt_writable_computed_set}
  @override
  T set(T newValue) {
    assert(!isDisposed, "WritableComputed is disposed");
    startBatch();
    try {
      setter(newValue);

      return newValue;
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
  /// Creates a writable computed value with the given getter and setter.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the value from dependencies
  /// - [setter]: Function called when the computed value is set
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final writableComputed = WritableComputed(
  ///   () => count.value * 2,
  ///   (value) => count.value = value ~/ 2,
  /// );
  /// ```
  factory WritableComputed(
    T Function() getter,
    void Function(T) setter, {
    JoltDebugFn? onDebug,
  }) = WritableComputedImpl<T>;

  /// Returns the current computed value (same as `value`).
  @override
  T call();
}
