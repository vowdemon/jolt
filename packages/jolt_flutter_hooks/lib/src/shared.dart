import 'package:jolt_flutter/setup.dart';

class SimpleSetupHook<T> extends SetupHook<T> {
  SimpleSetupHook(this.creator, {void Function(T state)? onUnmount})
      : _onUnmount = onUnmount;

  final T Function() creator;
  final void Function(T state)? _onUnmount;

  @override
  T createState() => creator();

  @override
  void unmount() {
    _onUnmount?.call(state);
  }
}
