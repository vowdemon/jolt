/// Core reactive system APIs for advanced usage.
///
/// This library exposes the low-level reactive system APIs including
/// reactive nodes, dependency tracking, and the global reactive system.
/// These APIs are typically used by framework implementers or for
/// advanced reactive programming scenarios.
library;

export 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

export 'src/core/reactive.dart' hide disposeDepsInReverse;
export 'src/core/interface.dart';
export 'src/core/node.dart';
export 'src/core/debug.dart'
    show JoltDebug, DebugNodeOperationType, JoltDebugFn, JoltDebugOption;

export "src/jolt/base.dart";
export "src/jolt/impl/effect.dart";
export "src/jolt/impl/effect_scope.dart";
export "src/jolt/impl/watcher.dart";
export "src/jolt/impl/signal.dart";
export "src/jolt/impl/readonly.dart";
export "src/jolt/impl/computed.dart";
export "src/jolt/impl/async.dart";

export "src/jolt/collection/iterable_signal.dart" show IterableSignalImpl;
export "src/jolt/collection/list_signal.dart" show ListSignalImpl;
export "src/jolt/collection/map_signal.dart" show MapSignalImpl;
export "src/jolt/collection/set_signal.dart" show SetSignalImpl;

export "src/utils/finalizer.dart" show JFinalizer;
export "src/utils/delegated.dart";
export "src/utils/stream.dart" show JoltStreamHelper;
