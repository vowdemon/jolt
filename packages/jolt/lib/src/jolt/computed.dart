import "package:jolt/core.dart";

/// A cached reactive value derived from other reactive state.
///
/// [Computed] is read-only to callers and recomputes when tracked
/// dependencies change. Choose [WritableComputed] when the derived value also
/// needs a write-back API.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// Computed<int> doubled = Computed(() => count.value * 2);
/// print(doubled.value); // 0
/// count.value = 5;
/// print(doubled.value); // 10
/// ```
/// {@category Derive State}
abstract interface class Computed<T>
    implements Readable<T>, Notifiable, DisposableNode {
  /// Creates a computed value from [getter].
  ///
  /// The [getter] callback returns the derived value and re-runs when tracked
  /// dependencies change. The optional [equals] callback suppresses downstream
  /// notifications when recomputed values should be treated as unchanged.
  factory Computed(
    T Function() getter, {
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) = ComputedImpl;

  /// Creates a computed value whose [getter] receives the previous result.
  ///
  /// The first successful computation receives `null`. This factory currently
  /// ignores [equals], so callers that need stable identities must handle that
  /// inside [getter].
  factory Computed.withPrevious(
    T Function(T?) getter, {
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) = ComputedImpl.withPrevious;

  /// The current derived value without establishing a reactive dependency.
  @override
  T get peek;

  /// The current derived value using this computed value's tracked read semantics.
  ///
  /// Reading [value] inside another reactive subscriber makes that subscriber
  /// react to later changes in this derived result.
  @override
  T get value;

  /// Notifies dependents that this computed value should be treated as changed.
  ///
  /// Use [notify] when external state affected by [getter] changed without
  /// flowing through tracked dependencies.
  @override
  void notify();

  /// Recomputes this value and only notifies subscribers when the result changed.
  ///
  /// Use this to refresh a computed value whose dependencies are not tracked
  /// automatically but whose derived output may have changed.
  void notifySoft();

  /// Disposes this computed value and removes it from future propagation.
  @override
  void dispose();
}

/// A computed value that can also write back to its source state.
///
/// Choose [WritableComputed] when callers should read a derived value and also
/// assign through it. Use [Computed] when the derivation should stay read-only.
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
abstract interface class WritableComputed<T>
    implements Computed<T>, Writable<T> {
  /// Creates a writable computed value.
  ///
  /// The [getter] callback returns the derived value, and the [setter]
  /// callback receives values assigned through [WritableComputed.value]. The
  /// optional [equals] callback suppresses downstream notifications when
  /// recomputed values should be treated as unchanged.
  factory WritableComputed(
    T Function() getter,
    void Function(T) setter, {
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) = WritableComputedImpl<T>;

  /// Creates a writable computed value whose [getter] receives the previous result.
  ///
  /// The first successful computation receives `null`. The [setter] callback
  /// receives values assigned through [WritableComputed.value]. The optional
  /// [equals] callback suppresses downstream notifications when recomputed
  /// values should be treated as unchanged.
  factory WritableComputed.withPrevious(
    T Function(T?) getter,
    void Function(T) setter, {
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) = WritableComputedImpl.withPrevious;

  /// Sets this derived value by delegating to the user-provided setter.
  ///
  /// Implementations may batch the write so downstream watchers flush once
  /// after the assignment completes.
  @override
  set value(T value);
}
