import 'package:jolt/src/core/interface.dart';
import 'package:jolt/src/core/node.dart';
import 'package:jolt/src/core/reactive.dart';

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
