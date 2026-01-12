/// Core reactive system APIs for advanced usage.
///
/// This library exposes the low-level reactive system APIs including
/// reactive nodes, dependency tracking, and the global reactive system.
/// These APIs are typically used by framework implementers or for
/// advanced reactive programming scenarios.
library;

export 'src/core/reactive.dart';
export 'src/core/debug.dart'
    show JoltDebug, DebugNodeOperationType, JoltDebugFn, setJoltDebugFn;

export "src/jolt/base.dart" show DisposableNodeMixin;
export "src/jolt/signal.dart" show SignalImpl, ReadonlySignalImpl;
export "src/jolt/computed.dart" show ComputedImpl, WritableComputedImpl;
export "src/jolt/effect.dart" show EffectImpl, EffectScopeImpl, WatcherImpl;
export "src/jolt/async.dart" show AsyncSignalImpl;

export "src/jolt/collection/iterable_signal.dart" show IterableSignalImpl;
export "src/jolt/collection/list_signal.dart" show ListSignalImpl;
export "src/jolt/collection/map_signal.dart" show MapSignalImpl;
export "src/jolt/collection/set_signal.dart" show SetSignalImpl;

export "src/utils/finalizer.dart" show JFinalizer;
export "src/utils/delegated.dart";
export "src/utils/stream.dart" show JoltStreamHelper;
