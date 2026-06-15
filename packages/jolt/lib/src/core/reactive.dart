import "package:jolt/core.dart";
import "package:meta/meta.dart";

export "package:jolt/src/core/system.dart"
    show link, unlink, propagate, shallowPropagate;

// Ported from and adapted from:
// https://github.com/stackblitz/alien-signals
//
// This file has been modified to fit Jolt's Dart APIs, runtime behavior, and
// project conventions.

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

/// Stores [e] in the global effect queue at [index].
///
/// The queue grows when [index] is beyond the current capacity.
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

/// The effect or computed node that is currently collecting dependencies.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
ReactiveNode? getActiveSub() => activeSub;

/// Sets the subscriber that should collect subsequent dependencies.
///
/// Returns the previously active subscriber, if any.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
ReactiveNode? setActiveSub([ReactiveNode? sub]) {
  final prevSub = activeSub;
  activeSub = sub;
  return prevSub;
}

/// The effect scope that currently owns newly created effects.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
EffectScopeNode? getActiveScope() => activeScope;

/// Sets the ambient scope for newly created effects.
///
/// Returns the previously active scope, if any.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
EffectScopeNode? setActiveScope([EffectScopeNode? scope]) {
  final prevScope = activeScope;
  activeScope = scope;
  return prevScope;
}

/// Begins a batch so multiple writes can be coalesced before effects run.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void startBatch() {
  ++batchDepth;
}

/// Ends the current batch and flushes pending effects when the outer batch ends.
///
/// In debug mode, this asserts if it is called more times than [startBatch].
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

/// Runs every effect currently queued for notification.
///
/// The queue is drained in order. If an effect throws, remaining queued effects
/// are restored to a watchable state before the queue is reset.
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

/// Removes all dependency links from a subscriber so future tracking starts
/// from a clean slate.
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

/// Runs [fn] while collecting the nodes it reads, then propagates those nodes.
///
/// This is useful for in-place mutations that keep object identity the same.
/// Reads inside [fn] decide which dependencies should notify subscribers after
/// the callback finishes.
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

/// Returns the current nested batch depth.
///
/// Each [startBatch] increments this counter and [endBatch] decrements it.
/// Queued effects flush only when the depth returns to zero.
int getBatchDepth() => batchDepth;

/// Returns the current dependency-tracking generation.
///
/// The reactive system bumps this counter when recomputing nodes so dependency
/// [link] versions can distinguish fresh reads from stale ones.
int getCycle() => cycle;

/// Returns how many effects are currently executing.
///
/// The depth increases while an effect body runs and is used to classify
/// writes as inner or outer during propagation.
int getRunDepth() => runDepth;
