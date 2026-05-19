import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';

class SignalImpl<T> implements Signal<T> {
  final SignalNode<T> raw;

  SignalImpl(T? value, {JoltDebugOption? debug})
      : raw = SignalNode(value, debug: debug);

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
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
  set value(T value) => raw.set(value);

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void notify() => raw.notify();

  @override
  @mustCallSuper
  void dispose() => raw.dispose();

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  String toString() => value.toString();
}
