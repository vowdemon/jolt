/// Jolt is a reactive state management library for Dart and Flutter.
///
/// Start with a writable signal, derive read-only views from it, and react to
/// visible changes with effects:
///
/// ```dart
/// final count = Signal(0);
/// final doubled = Computed(() => count.value * 2);
///
/// Effect(() {
///   print('count=${count.value}, doubled=${doubled.value}');
/// });
/// ```
///
/// For a guided introduction, start with the package tutorial topics. For type
/// and member details, use the generated API reference for this library.
library;

export "src/core/debug.dart"
    show DebugNodeOperationType, JoltDebugFn, JoltDebug, JoltDebugOption;
export "src/core/interface.dart" show Readable, Writable;

export "src/jolt/signal.dart";
export "src/jolt/computed.dart";
export "src/jolt/effect.dart";
export "src/jolt/readonly.dart";
export "src/jolt/effect_scope.dart";
export "src/jolt/watcher.dart";
export "src/jolt/async.dart";
export "src/jolt/batch.dart";
export "src/jolt/track.dart";
export "src/jolt/collection/iterable_signal.dart";
export "src/jolt/collection/list_signal.dart";
export "src/jolt/collection/map_signal.dart";
export "src/jolt/collection/set_signal.dart";

export "src/utils/until.dart";
export "src/utils/readable.dart";
export "src/utils/writable.dart";
export "src/utils/stream.dart";
export "src/tricks/convert_computed.dart";
export "src/tricks/persist_signal.dart";
