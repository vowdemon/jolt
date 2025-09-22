import 'package:free_disposer/free_disposer.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/reactive.dart';

/// Create a reactive signal with initial value
T Function([T? value, bool write]) signal<T>(T initialValue) {
  final s = Signal<T>(
    initialValue,
  );
  return ([T? value, bool write = false]) {
    if (write) {
      return globalReactiveSystem.signalSetter(s, value as T);
    } else {
      return globalReactiveSystem.signalGetter(s);
    }
  };
}

/// Create a computed value that derives from other reactive values
T Function() computed<T>(T Function() getter) {
  final c = Computed<T>(
    getter,
  );

  return () => globalReactiveSystem.computedGetter(c);
}

/// Create a reactive effect that runs when dependencies change
Disposer effect(void Function() fn) {
  final Effect e = Effect(fn);

  return e.dispose;
}

/// Create an effect scope for managing multiple effects
Disposer effectScope(void Function() fn) {
  final EffectScope e = EffectScope((_) => fn());

  return e.dispose;
}

final startBatch = globalReactiveSystem.startBatch;
final endBatch = globalReactiveSystem.endBatch;
final setCurrentSub = globalReactiveSystem.setCurrentSub;
final getCurrentSub = globalReactiveSystem.getCurrentSub;
final setCurrentScope = globalReactiveSystem.setCurrentScope;
final getCurrentScope = globalReactiveSystem.getCurrentScope;
