import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

@internal
mixin JoltCommonEffectBuilder on Element {
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void joltBuildTriggerEffect() {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (dirty || !mounted) return;
        markNeedsBuild();
      });
    } else {
      if (dirty) return;
      markNeedsBuild();
    }
  }
}
