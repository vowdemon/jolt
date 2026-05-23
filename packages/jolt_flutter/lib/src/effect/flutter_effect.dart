import 'package:flutter/scheduler.dart';
import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

/// An [Effect] that runs reactive callbacks at the end of the current frame.
///
/// Multiple dependency notifications in the same frame are coalesced into one
/// execution scheduled via [SchedulerBinding.endOfFrame]. Use this for UI work
/// that should not run synchronously during layout or paint.
///
/// When [lazy] is `false` (the default), the callback runs once when created.
/// When [lazy] is `true`, call [run] to execute. When [detach] is `true`, the
/// effect does not keep its scope alive.
abstract class FlutterEffect implements Effect {
  /// Creates a frame-aligned effect for [fn].
  factory FlutterEffect(
    void Function() fn, {
    bool lazy,
    bool detach,
    JoltDebugOption? debug,
  }) = _FlutterEffectImpl;
}

class _FlutterEffectNode extends EffectNode {
  _FlutterEffectNode(super.fn, {super.lazy, super.detach, super.debug});

  bool _isScheduled = false;

  @override
  void notifyEffect() {
    if (_isScheduled) {
      return;
    }

    _isScheduled = true;

    SchedulerBinding.instance.endOfFrame.then((_) {
      _isScheduled = false;
      run();
    });
  }
}

class _FlutterEffectImpl extends EffectImpl implements FlutterEffect {
  _FlutterEffectImpl(super.fn,
      {bool lazy = false, bool detach = false, JoltDebugOption? debug})
      : super.custom(
            node: _FlutterEffectNode(fn,
                lazy: lazy, detach: detach, debug: debug));
}
