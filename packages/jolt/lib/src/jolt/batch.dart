import "package:jolt/core.dart";

/// Runs [fn] inside a batched notification cycle.
///
/// Reactive writes performed before [fn] returns are flushed once at the end of
/// the outermost batch. This lets related updates settle before effects,
/// watchers, streams, and other subscribers observe the final state.
///
/// If [fn] throws, the batch still ends and pending notifications still flush
/// before the error escapes. If [fn] is `async`, only the synchronous prefix
/// before the first `await` stays inside this batch.
///
/// ```dart
/// final first = Signal(1);
/// final second = Signal(2);
/// final seen = <int>[];
///
/// Effect(() => seen.add(first.value + second.value));
///
/// batch(() {
///   first.value = 10;
///   second.value = 20;
/// });
///
/// print(seen); // [3, 30]
/// ```
/// {@category Advanced Techniques}
T batch<T>(T Function() fn) {
  startBatch();
  try {
    return fn();
  } finally {
    endBatch();
  }
}
