import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

class EffectScopeImpl implements EffectScope {
  final EffectScopeNode raw;

  EffectScopeImpl({bool detach = false, JoltDebugOption? debug})
      : raw = EffectScopeNode(detach: detach, debug: debug);

  @override
  T run<T>(T Function() fn) => raw.run(fn);

  @override
  void dispose() => raw.dispose();

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  void onCleanup(Disposer fn) => raw.onCleanup(fn);
}

/// Registers a cleanup function for the current effect scope.
///
/// The [fn] callback runs when the selected scope disposes. When [owner] is
/// omitted, Jolt uses the active [EffectScope] or raw scope node from the
/// current context.
///
/// Call this inside [EffectScope.run] or pass [owner] explicitly.
///
/// Example:
/// ```dart
/// final scope = EffectScope()
///   ..run(() {
///     final subscription = someStream.listen((data) {});
///     onScopeDispose(() => subscription.cancel());
///   });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void onScopeDispose(Disposer fn, {EffectScope? owner}) {
  final e = owner ?? getActiveScope();

  assert(e is EffectScope || e is EffectScopeNode,
      "Cannot add cleanup on a non-effect scope");
  if (e is EffectScopeNode) {
    e.onCleanup(fn);
  } else if (e is EffectScope) {
    e.onCleanup(fn);
  }
}
