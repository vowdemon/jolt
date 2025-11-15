import "package:jolt/jolt.dart";
import "package:jolt/src/core/reactive.dart" as reactive;
import "package:jolt/src/core/reactive.dart";

export "package:jolt/src/core/reactive.dart";

/// Create a reactive signal with initial value
// alien_signals function
// ignore: avoid_positional_boolean_parameters
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
void Function() effect(void Function() fn) {
  final e = Effect(fn);

  return e.dispose;
}

/// Create an effect scope for managing multiple effects
void Function() effectScope(void Function() fn) {
  final e = EffectScope()..run(() => fn());

  return e.dispose;
}
