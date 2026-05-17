import "package:jolt/core.dart";
import "package:meta/meta.dart";

export "package:jolt/src/core/system.dart"
    show link, unlink, propagate, shallowPropagate;

/// Ported from and adapted from:
/// https://github.com/stackblitz/alien-signals
///
/// This file has been modified to fit Jolt's Dart APIs, runtime behavior, and
/// project conventions.

@internal
int cycle = 0;

@internal
int runDepth = 0;

@internal
int batchDepth = 0;

@internal
int notifyIndex = 0;

@internal
int queuedLength = 0;

@internal
final List<EffectNode?> queued = List.filled(64, null, growable: true);

@internal
ReactiveNode? activeSub;

@internal
EffectScopeNode? activeScope;

/// Updates either a [ComputedNode] or [SignalNode] and returns
/// whether its cached value changed.
///
/// Parameters:
/// - [node]: Reactive node to bring up to date
///
/// Example:
/// ```dart
/// final signalNode = CustomSignalNode<int>(0);
/// final changed = updateNode(signalNode);
/// if (changed && signalNode.subs != null) {
///   shallowPropagate(signalNode.subs!);
/// }
/// ```
@override
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
bool updateNode(ReactiveNode node) {
  final result = switch (node) {
    ComputedNode() => node.update(),
    SignalNode() => node.update(),
    EffectScopeNode() => node.update(),
    CustomReactiveNode() => node.update(),
    _ => throw UnsupportedError("Unsupported node type: ${node.runtimeType}")
  };
  return result;
}

@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void setEffectQueue(int index, EffectNode? e) {
  if (index < queued.length) {
    queued[index] = e;
  } else {
    queued.add(e);
  }
}

@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")

/// Returns the effect or computed currently being tracked.
///
/// Example:
/// ```dart
/// final currentlyTracking = getActiveSub();
/// if (currentlyTracking != null) {
///   // mutate diagnostics
/// }
/// ```
ReactiveNode? getActiveSub() => activeSub;

/// Sets the currently active effect or computed and returns the previous one.
///
/// Parameters:
/// - [sub]: Node that should collect dependencies
///
/// Example:
/// ```dart
/// final myEffect = CustomEffectNode();
/// final prev = setActiveSub(myEffect);
/// try {
///   myEffect.effectFn();
/// } finally {
///   setActiveSub(prev);
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
ReactiveNode? setActiveSub([ReactiveNode? sub]) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")

/// Returns the [EffectScopeNode] that is currently open.
///
/// Example:
/// ```dart
/// final scope = getActiveScope();
/// scope?.dispose();
/// ```
EffectScopeNode? getActiveScope() => activeScope;

/// Sets the ambient [EffectScopeNode] and returns the previous scope.
///
/// Parameters:
/// - [scope]: Scope that should own subsequently created effects
///
/// Example:
/// ```dart
/// final rootScope = CustomEffectScope();
/// final prevScope = setActiveScope(rootScope);
/// try {
///   rootScope.flags |= ReactiveFlags.watching;
/// } finally {
///   setActiveScope(prevScope);
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
EffectScopeNode? setActiveScope([EffectScopeNode? scope]) {
  final prevScope = activeScope;
  activeScope = scope;
  return prevScope;
}

/// Begins a batch so multiple writes can be coalesced before effects run.
///
/// Example:
/// ```dart
/// final signalNode = CustomSignalNode<int>(0);
/// startBatch();
/// setSignal(signalNode, 1);
/// setSignal(signalNode, 2);
/// endBatch(); // Effects run once.
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void startBatch() {
  ++batchDepth;
}

/// Ends the current batch and flushes pending effects when depth reaches zero.
///
/// Example:
/// ```dart
/// final signalNode = CustomSignalNode<int>(0);
/// startBatch();
/// setSignal(signalNode, 1);
/// endBatch(); // Runs queued effects when this is the outer batch.
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void endBatch() {
  batchDepth--;
  assert(batchDepth >= 0, "endBatch called without matching startBatch");
  if (batchDepth == 0) {
    flushEffects();
  }
}

/// Flushes all queued effects and executes them.
///
/// This function processes all effects that have been queued for execution
/// and runs them in order. It's typically called automatically by the reactive
/// system, but can be called manually to force immediate execution of queued effects.
///
/// Example:
/// ```dart
/// final signal1 = Signal(0);
/// final signal2 = Signal(0);
/// final signal3 = Signal(0);
///
/// // Multiple signal updates
/// signal1.value = 1;
/// signal2.value = 2;
/// signal3.value = 3;
///
/// // Force immediate execution of all queued effects
/// flushEffects();
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
@pragma("vm:align-loops")
@pragma('vm:unsafe:no-bounds-checks')
void flushEffects() {
  try {
    while (notifyIndex < queuedLength) {
      final effect = queued[notifyIndex]!;
      queued[notifyIndex++] = null;
      effect.run();
    }
  } finally {
    while (notifyIndex < queuedLength) {
      final effect = queued[notifyIndex]!;
      queued[notifyIndex++] = null;
      effect.flags |= ReactiveFlags.watching | ReactiveFlags.recursed;
    }
    notifyIndex = 0;
    queuedLength = 0;
  }
}

/// Disposes a reactive node: marks it inactive, detaches
/// dependencies/subscribers. The node no longer participates in updates or propagation.
///
/// Parameters:
/// - [e]: Node to dispose
///
/// Example:
/// ```dart
/// final effectNode = CustomEffectNode();
/// disposeNode(effectNode);
/// ```
void disposeNode(ReactiveNode e) {
  e
    ..depsTail = null
    ..flags = ReactiveFlags.none;
  purgeDeps(e);
  final sub = e.subs;
  if (sub != null) {
    unlink(sub);
  }

  assert(() {
    JoltDebug.dispose(e);
    return true;
  }());
}

/// Removes all dependencies from [sub] in reverse dependency order.
///
/// This is used for disposal paths where child effects must clean up in LIFO
/// order while ordinary signal/computed dependencies still need to be detached.
@internal
void disposeDepsInReverse(ReactiveNode sub) {
  var link = sub.depsTail;
  while (link != null) {
    final prev = link.prevDep;
    unlink(link, sub);
    link = prev;
  }
}

/// Removes all dependency links from a subscriber so future tracking starts
/// from a clean slate.
///
/// Parameters:
/// - [sub]: Subscriber node whose dependencies should be detached
///
/// Example:
/// ```dart
/// final effectNode = CustomEffectNode();
/// purgeDeps(effectNode);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void purgeDeps(ReactiveNode sub) {
  final depsTail = sub.depsTail;
  var dep = depsTail != null ? depsTail.nextDep : sub.deps;
  while (dep != null) {
    dep = unlink(dep, sub);
  }
}

/// Executes [fn] inside a temporary subscriber and propagates any triggered
/// signals once the callback finishes.
///
/// Parameters:
/// - [fn]: Callback that performs reactive writes
///
/// Example:
/// ```dart
/// final list = <int>[];
/// final signal = Signal(list);
/// list.add(1);
/// trigger(() {
///   signal.value;
/// });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T trigger<T>(T Function() fn) {
  final sub = EffectNode(() {}, detach: true);
  final prevSub = setActiveSub(sub);

  try {
    return fn();
  } finally {
    activeSub = prevSub;
    sub.flags = ReactiveFlags.none;
    var link = sub.deps;
    while (link != null) {
      final dep = link.dep;
      link = unlink(link, sub);
      final subs = dep.subs;
      if (subs != null) {
        propagate(subs, runDepth > 0);
        shallowPropagate(subs);
      }
    }
    if (batchDepth == 0) {
      flushEffects();
    }
  }
}

int getBatchDepth() => batchDepth;
int getCycle() => cycle;
int getRunDepth() => runDepth;
List<EffectNode?> getEffectQueue() => queued;
