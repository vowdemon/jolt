import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';

class ComputedImpl<T> implements Computed<T> {
  late final ComputedNode<T> raw;

  ComputedImpl(
    T Function() getter, {
    bool Function(T current, T? previous)? equals,
    JoltDebugOption? debug,
  }) : raw = ComputedNode(getter, equals: equals, debug: debug);

  factory ComputedImpl.withPrevious(
    T Function(T?) getter, {
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) {
    late final ComputedImpl<T> computed;
    T fn() => getter(computed.raw.value);

    computed = ComputedImpl(fn, debug: debug);
    return computed;
  }

  @override
  T get peek => raw.peek();

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  T get value => raw.get();

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void notify() => raw.notify();

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void notifySoft() => raw.notifySoft();

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

class WritableComputedImpl<T> extends ComputedImpl<T>
    implements WritableComputed<T> {
  WritableComputedImpl(super.getter, this.setter, {super.equals, super.debug});

  factory WritableComputedImpl.withPrevious(
    T Function(T?) getter,
    void Function(T) setter, {
    ComputedEqualsFn? equals,
    JoltDebugOption? debug,
  }) {
    late final WritableComputedImpl<T> computed;
    T fn() => getter(computed.raw.value);

    computed = WritableComputedImpl(fn, setter, equals: equals, debug: debug);
    return computed;
  }

  /// The function called when this computed value is set.
  final void Function(T) setter;

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  set value(T newValue) => batch(() => setter(newValue));
}
