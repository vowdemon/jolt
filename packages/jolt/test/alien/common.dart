import 'package:jolt/src/core/reactive.dart';
import 'package:shared_interfaces/shared_interfaces.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/core/reactive.dart' as reactive;
export 'package:jolt/src/core/reactive.dart';

/// Create a reactive signal with initial value
T Function([T? value, bool write]) signal<T>(T initialValue) {
  final s = Signal<T>(
    initialValue,
  );
  return ([T? value, bool write = false]) {
    if (write) {
      return reactive.setSignal(s as SignalReactiveNode<T>, value as T);
    } else {
      return reactive.getSignal(s as SignalReactiveNode<T>);
    }
  };
}

/// Create a computed value that derives from other reactive values
T Function() computed<T>(T Function() getter) {
  final c = Computed<T>(
    getter,
  );

  return () => reactive.getComputed(c as ComputedReactiveNode<T>);
}

/// Create a reactive effect that runs when dependencies change
Disposer effect(void Function() fn) {
  final Effect e = Effect(fn);

  return e.dispose;
}

/// Create an effect scope for managing multiple effects
Disposer effectScope(void Function() fn) {
  final EffectScope e = EffectScope()..run(() => fn());

  return e.dispose;
}
