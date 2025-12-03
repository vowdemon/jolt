/// Core reactive system APIs for advanced usage.
///
/// This library exposes the low-level reactive system APIs including
/// reactive nodes, dependency tracking, and the global reactive system.
/// These APIs are typically used by framework implementers or for
/// advanced reactive programming scenarios.
library;

export 'src/core/reactive.dart';
export 'src/jolt/shared.dart' show JFinalizer;
export 'src/core/debug.dart'
    show JoltDebug, DebugNodeOperationType, JoltDebugFn;

export "src/jolt/base.dart" show ReadonlyNodeMixin, EffectNodeMixin;
export "src/jolt/signal.dart" show SignalImpl;
export "src/jolt/computed.dart" show ComputedImpl, WritableComputedImpl;
export "src/jolt/effect.dart" show EffectImpl, EffectScopeImpl, WatcherImpl;
export "src/jolt/async.dart" show AsyncSignalImpl;

export "src/jolt/collection/iterable_signal.dart" show IterableSignalImpl;
export "src/jolt/collection/list_signal.dart" show ListSignalImpl;
export "src/jolt/collection/map_signal.dart" show MapSignalImpl;
export "src/jolt/collection/set_signal.dart" show SetSignalImpl;

export "src/tricks/convert_computed.dart" show ConvertComputedImpl;
export "src/tricks/persist_signal.dart" show PersistSignalImpl;
