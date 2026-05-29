import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

class EffectImpl implements Effect {
  final EffectNode raw;

  EffectImpl(this.fn,
      {bool lazy = false, bool detach = false, JoltDebugOption? debug})
      : raw = EffectNode(fn, lazy: lazy, detach: detach, debug: debug);

  EffectImpl.custom(this.fn, {required EffectNode node}) : raw = node;

  factory EffectImpl.lazy(void Function() fn,
      {bool detach = false, JoltDebugOption? debug}) {
    return EffectImpl(fn, lazy: true, detach: detach, debug: debug);
  }

  /// The function that defines the effect's behavior.
  @protected
  final void Function() fn;

  @override
  void run() {
    assert(
      raw.flags != ReactiveFlags.none,
      'Cannot call run() on a disposed $runtimeType',
    );
    if (raw.flags != ReactiveFlags.none) {
      raw.flags |= ReactiveFlags.dirty;
    }
    raw.run();
  }

  @override
  void dispose() => raw.dispose();

  @override
  void onCleanup(Disposer fn) => raw.onCleanup(fn);

  @override
  bool get isDisposed => raw.isDisposed;

  T track<T>(T Function() fn, [bool purge = true]) => raw.track(fn, purge);
}

/// Registers a cleanup function for the current effect or watcher callback.
///
/// The [fn] callback runs before the selected owner re-runs and when that
/// owner disposes. When [owner] is omitted, Jolt uses the active effect,
/// watcher callback, or raw effect node from the current context.
///
/// Call this inside an [Effect] body, a [Watcher] callback, or while a matching
/// raw effect owner is active.
///
/// Example:
/// ```dart
/// Effect(() {
///   final timer = Timer.periodic(Duration(seconds: 1), (_) {});
///   onEffectCleanup(() => timer.cancel());
/// });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void onEffectCleanup(Disposer fn, {Object? owner}) {
  final e = owner ?? Watcher.activeWatcher ?? getActiveSub();
  assert(e is Effect || e is Watcher || e is EffectNode,
      "Cannot add cleanup on a non-effect or non-watcher");
  if (e is EffectNode) {
    e.onCleanup(fn);
  } else if (e is Watcher) {
    e.onCleanup(fn);
  } else if (e is Effect) {
    e.onCleanup(fn);
  }
}
