import "package:jolt/core.dart";

/// Runs [fn] without recording reactive dependencies.
///
/// Reads performed inside [fn] do not subscribe the current reactive context.
/// Use [untracked] for incidental reads that should not trigger future re-runs.
///
/// ```dart
/// final tracked = Signal(1);
/// final ignored = Signal(2);
/// final seen = <String>[];
///
/// Effect(() {
///   seen.add('${tracked.value}:${untracked(() => ignored.value)}');
/// });
///
/// ignored.value = 3;
/// print(seen); // ['1:2']
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T untracked<T>(T Function() fn) {
  final prevSub = setActiveSub(null);
  try {
    return fn();
  } finally {
    setActiveSub(prevSub);
  }
}

/// Runs [fn] in a temporary tracking context and propagates the touched values.
///
/// Reads performed inside [fn] are treated as if they were manually touched for
/// notification purposes, but the current caller does not stay subscribed after
/// [fn] returns. Returns the result of [fn].
///
/// ```dart
/// final signal = Signal(1);
/// final seen = <int>[];
///
/// Effect(() => seen.add(signal.value));
///
/// triggerTracked(() => signal.value);
/// print(seen); // [1, 1]
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T triggerTracked<T>(T Function() fn) => trigger(fn);
