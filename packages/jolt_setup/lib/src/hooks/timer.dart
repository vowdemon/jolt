import 'dart:async';

import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

/// Hook factory for creating one-shot or periodic timers in Setup components.
///
/// Usage:
/// - One-shot: [useTimer] invokes [callback] once after [duration].
/// - Periodic: [useTimer].periodic invokes [callback] every [duration]; cancel via the returned [TimerHook].
///
/// When [immediately] is true, the timer is started during build; when false, after mount.
/// The timer is cancelled automatically when the component unmounts.
final class TimerHookCreator {
  const TimerHookCreator._();

  /// Creates a one-shot timer that invokes [callback] after [duration].
  ///
  /// Returns a [TimerHook]; call [TimerHook.cancel] to cancel before it fires.
  @defineHook
  TimerHook call(Duration duration, void Function() callback,
      {bool immediately = false}) {
    return useHook(_TimerHook(
        duration: duration, callback: callback, immediately: immediately));
  }

  /// Creates a periodic timer that invokes [callback] every [duration].
  ///
  /// [callback] receives the current [Timer] instance. Returns a [TimerHook];
  /// call [TimerHook.cancel] to stop. [TimerHook.tick] increments on each callback.
  @defineHook
  TimerHook periodic(Duration duration, void Function(Timer timer) callback,
      {bool immediately = false}) {
    return useHook(_TimerPeriodicHook(
        duration: duration, callback: callback, immediately: immediately));
  }
}

/// Hook for creating one-shot or periodic timers in Setup components.
///
/// Use [useTimer](duration, callback) for a one-shot timer,
/// and [useTimer].periodic(duration, callback) for a periodic timer.
const useTimer = TimerHookCreator._();

/// Return type of the timer hook; implements [Timer]'s [cancel], [isActive], [tick], etc.
///
/// Cancelled automatically on unmount; call [cancel] to cancel earlier if needed.
/// Use [pause] / [resume] to temporarily stop and restart without losing the hook;
/// use [reset] to restart from the beginning (for one-shot, resets the delay).
abstract class TimerHook implements Timer {
  /// Stops the timer without cancelling; call [resume] to run again.
  void pause();

  /// Restarts the timer after [pause].
  void resume();

  /// Stops and restarts: equivalent to [pause] then [resume].
  /// For one-shot, resets the delay; for periodic, restarts from tick 0.
  void reset();
}

/// Base implementation for one-shot and periodic timer hooks.
abstract class _TimerBaseHook extends SetupHook<TimerHook>
    implements TimerHook {
  _TimerBaseHook({required this.duration, required this.immediately});

  late Duration duration;
  Timer? timer;
  final bool immediately;

  /// True after [cancel]; [resume] will no longer start.
  bool isCancelled = false;

  /// Starts the underlying [Timer]; no-op if already running or cancelled.
  void start();

  @override
  void cancel() {
    isCancelled = true;
    pause();
  }

  @override
  void pause() {
    timer?.cancel();
    timer = null;
  }

  @override
  void resume() {
    start();
  }

  @override
  void reset() {
    pause();
    start();
  }

  @override
  bool get isActive => timer != null && timer!.isActive;

  @override
  int get tick => timer?.tick ?? 0;

  @override
  TimerHook build() {
    if (immediately) {
      start();
    }
    return this;
  }

  @override
  void mount() {
    start();
  }

  @override
  void unmount() {
    cancel();
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _TimerBaseHook newHook) {
    if (newHook.duration != duration) {
      duration = newHook.duration;
      if (timer != null) {
        cancel();
        start();
      }
    }
  }
  // coverage:ignore-end
}

/// One-shot timer: fires [callback] once after [duration].
class _TimerHook extends _TimerBaseHook {
  _TimerHook(
      {required super.duration,
      required super.immediately,
      required this.callback});

  late void Function() callback;

  void _onTimer() => callback();

  @override
  void start() {
    if (timer != null || isCancelled || !context.mounted) return;
    timer = Timer(duration, _onTimer);
  }

  // coverage:ignore-start
  @override
  reassemble(covariant _TimerHook newHook) {
    callback = newHook.callback;
    super.reassemble(newHook);
  }
  // coverage:ignore-end
}

/// Periodic timer: invokes [callback] every [duration] with the current [Timer].
class _TimerPeriodicHook extends _TimerBaseHook {
  _TimerPeriodicHook(
      {required super.duration,
      required super.immediately,
      required this.callback});
  late void Function(Timer timer) callback;

  void _onTick(Timer t) => callback(t);

  @override
  void start() {
    if (timer != null || isCancelled || !context.mounted) return;
    timer = Timer.periodic(duration, _onTick);
  }

  // coverage:ignore-start
  @override
  reassemble(covariant _TimerPeriodicHook newHook) {
    callback = newHook.callback;
    super.reassemble(newHook);
  }
  // coverage:ignore-end
}
