import 'package:meta/meta.dart';

import 'system.dart';

/// Types of operations that can be debugged in the reactive system.
///
/// This enum defines the different lifecycle events and operations
/// that can be tracked for debugging reactive nodes.
enum DebugNodeOperationType {
  /// Node was created.
  create,

  /// Node was disposed.
  dispose,

  /// Node was linked to a dependency.
  linked,

  /// Node was unlinked from a dependency.
  unlinked,

  /// Node value was accessed (get operation).
  get,

  /// Node value was set (set operation).
  set,

  /// Node notified its subscribers.
  notify,

  /// Effect was executed.
  effect,
}

/// Function type for debugging reactive system operations.
///
/// This callback is invoked whenever a debug operation occurs,
/// allowing you to track the lifecycle and behavior of reactive nodes.
///
/// Parameters:
/// - [type]: The type of operation that occurred
/// - [node]: The reactive node involved in the operation
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
