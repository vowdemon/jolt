import 'package:meta/meta.dart';

import 'system.dart';

enum DebugNodeOperationType {
  create,
  dispose,
  linked,
  unlinked,
  get,
  set,
  notify,
  effect,
}

typedef JoltDebugFn = void Function(
  DebugNodeOperationType type,
  ReactiveNode node,
);

@internal
final joltDebugFns = Expando<JoltDebugFn>();

@internal
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
void setJoltDebugFn(Object target, JoltDebugFn fn) {
  joltDebugFns[target] = fn;
}

@internal
@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
JoltDebugFn? getJoltDebugFn(Object target) {
  return joltDebugFns[target];
}
