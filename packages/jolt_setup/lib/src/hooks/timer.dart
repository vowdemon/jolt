import 'dart:async';

import '../setup/framework.dart';
import 'annotation.dart';

/// Timer hook factory methods.
final class JoltSetupHookTimerCreator {
  const JoltSetupHookTimerCreator._();

  /// Creates a one-shot timer that invokes [callback] after [duration].
  @defineHook
  TimerHook call(Duration duration, void Function() callback,
      {TimerStart start = TimerStart.mounted}) {
    return useHook(_TimerHook(
        duration: duration,
        callback: callback,
        immediately: start == TimerStart.immediate));
  }

  /// Creates a periodic timer that invokes [callback] every [duration].
  @defineHook
  TimerHook periodic(Duration duration, void Function(Timer timer) callback,
      {TimerStart start = TimerStart.mounted}) {
    return useHook(_TimerPeriodicHook(
        duration: duration,
        callback: callback,
        immediately: start == TimerStart.immediate));
  }
}

/// Controls when a timer starts counting.
enum TimerStart {
  /// Starts during hook creation.
  immediate,

  /// Starts after the setup scope has mounted.
  mounted,
}

/// Creates a one-shot or periodic timer for the current setup scope.
///
/// By default, the timer starts after the setup scope mounts. Pass
/// [TimerStart.immediate] to [JoltSetupHookTimerCreator.call] or
/// [JoltSetupHookTimerCreator.periodic] when the countdown should begin during
/// hook creation. The returned [TimerHook] is cancelled automatically when the
/// setup scope unmounts.
///
/// ```dart
/// setup(context, props) {
///   final visible = useSignal(false);
///   useTimer(const Duration(milliseconds: 300), () {
///     visible.value = true;
///   });
///
///   return () => AnimatedOpacity(
///     opacity: visible.value ? 1 : 0,
///     duration: const Duration(milliseconds: 150),
///     child: const Text('Ready'),
///   );
/// }
/// ```
const useTimer = JoltSetupHookTimerCreator._();

/// A setup-owned timer handle returned by [useTimer].
///
/// The handle implements [Timer] and is cancelled automatically on unmount.
/// Call [pause] and [resume] to temporarily stop and restart the timer, or
/// [reset] to restart from the beginning.
abstract class TimerHook implements Timer {
  /// Stops the timer without cancelling; call [resume] to run again.
  void pause();

  /// Restarts the timer after [pause].
  void resume();

  /// Stops and restarts: equivalent to [pause] then [resume].
  /// For one-shot, resets the delay; for periodic, restarts from tick 0.
  void reset();
}

abstract class _TimerBaseHook extends SetupHook<TimerHook>
    implements TimerHook {
  _TimerBaseHook({required this.duration, required this.immediately});

  late Duration duration;
  Timer? timer;
  final bool immediately;

  bool isCancelled = false;

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

  @override
  void reassemble(covariant _TimerBaseHook newHook) {
    if (newHook.duration != duration) {
      duration = newHook.duration;
      if (timer != null) {
        pause();
        start();
      }
    }
  }
}

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

  @override
  reassemble(covariant _TimerHook newHook) {
    callback = newHook.callback;
    super.reassemble(newHook);
  }
}

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

  @override
  reassemble(covariant _TimerPeriodicHook newHook) {
    callback = newHook.callback;
    super.reassemble(newHook);
  }
}
