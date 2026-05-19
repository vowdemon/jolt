import 'package:jolt/src/core/interface.dart';
import 'package:jolt/src/core/node.dart';
import 'package:jolt/src/core/reactive.dart';

/// Returns the backing [ReactiveNode] for [readable], if one can be resolved.
///
/// The [readable] value is read under a detached temporary effect so the node
/// can be discovered without leaving a subscriber attached. Returns `null`
/// when [readable] is not backed by a Jolt reactive node.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// final node = captureReactiveNode(count);
/// ```
ReactiveNode? captureReactiveNode(Readable<dynamic> readable) {
  final sub = EffectNode(() {}, lazy: true, detach: true);
  final prevSub = setActiveSub(sub);

  try {
    readable.value;
  } finally {
    setActiveSub(prevSub);
  }

  final node = sub.depsTail?.dep ?? sub.deps?.dep;
  sub.flags = ReactiveFlags.none;
  purgeDeps(sub);
  return node;
}
