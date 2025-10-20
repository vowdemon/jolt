import '../jolt/base.dart';
import '../jolt/utils.dart';
import '../jolt/computed.dart';
import '../jolt/effect.dart';
import '../jolt/signal.dart';
import 'system.dart';

class GlobalReactiveSystem extends ReactiveSystem {
  /// The queue of effects to be executed
  final queuedEffects = <JEffectNode?>[];

  /// The current cycle number
  int cycle = 0;

  /// The current batch depth
  int batchDepth = 0;

  /// The effect index in queue
  int notifyIndex = 0;

  /// The length of the queue of effects to be executed
  int queuedEffectsLength = 0;

  /// The currently active effect or scope
  ReactiveNode? activeSub;

  /// Update a signal or computed value
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  bool update(node) {
    if (node is Computed) {
      return updateComputed(node);
    } else {
      return updateSignal(node as Signal);
    }
  }

  /// Notify a subscriber about changes
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  void notify(covariant JEffectNode sub) {
    notifyEffect(sub);
  }

  /// Handle cleanup when a node is no longer watched
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  void unwatched(node) {
    if (node is JEffectNode) {
      // if (!node.flags.hasAny(ReactiveFlags.mutable)) {
      effectScopeDispose(node);
      tryDispose(node);
    } else if (node.depsTail != null) {
      node.depsTail = null;
      node.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      purgeDeps(node);
      tryDispose(node);
    }
  }

  /// Try to dispose a reactive node
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void tryDispose(ReactiveNode node) {
    if (node is EffectBaseNode) {
      node.dispose();
    } else if (node is JReadonlyValue) {
      node.tryDispose();
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  ReactiveNode? getActiveSub() => activeSub;

  /// Set the currently active subscriber
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  ReactiveNode? setActiveSub(ReactiveNode? sub) {
    final prevSub = activeSub;
    activeSub = sub;
    return prevSub;
  }

  /// Start a batch update to defer effect execution
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void startBatch() {
    ++batchDepth;
  }

  /// End a batch update and flush pending effects
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void endBatch() {
    if (!((--batchDepth) != 0)) {
      flush();
    }
  }

  /// Get the current batch depth
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  int getBatchDepth() => batchDepth;

  /// Update the computed value and return true if changed
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateComputed<T>(Computed<T> computed) {
    ++cycle;
    computed.depsTail = null;
    computed.flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(computed);

    try {
      final oldValue = computed.pendingValue;
      final isChanged =
          (oldValue != (computed.pendingValue = computed.getter()));
      if (isChanged) {
        JoltConfig.observer
            ?.onComputedUpdated(computed, computed.pendingValue, oldValue);
      }
      return isChanged;
    } finally {
      activeSub = prevSub;
      computed.flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(computed);
    }
  }

  /// Update a signal's value and return true if changed
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateSignal<T>(Signal<T> signal) {
    signal.flags = ReactiveFlags.mutable;
    final isChanged =
        signal.currentValue != (signal.currentValue = signal.pendingValue);
    if (isChanged) {
      JoltConfig.observer
          ?.onSignalUpdated(signal, signal.pendingValue, signal.currentValue);
    }
    return isChanged;
  }

  /// Notify an effect that it needs to run
  void notifyEffect(JEffectNode e) {
    final flags = e.flags;
    if (flags.notHasAny(EffectFlags.queued)) {
      e.flags = flags | EffectFlags.queued;
      final subs = e.subs;
      if (subs != null && subs.sub is JEffectNode) {
        if (subs.sub is JEffectNode) {
          notifyEffect(subs.sub as JEffectNode);
        } else {
          print('notifyEffect: ${subs.sub}');
        }
      } else {
        if (queuedEffectsLength < queuedEffects.length) {
          queuedEffects[queuedEffectsLength++] = e;
        } else {
          queuedEffects.add(e);
          queuedEffectsLength++;
        }
      }
    }
  }

  /// Remove the pending flag from a reactive node
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool _removePending(ReactiveNode e, int flags) {
    e.flags = flags & ~ReactiveFlags.pending;
    return false;
  }

  /// Run an effect with the given flags
  void run(JEffectNode e, int flags) {
    if (flags.hasAny(ReactiveFlags.dirty) ||
        (flags.hasAny(ReactiveFlags.pending) &&
            (checkDirty(e.deps!, e) || _removePending(e, flags)))) {
      ++cycle;
      e.depsTail = null;
      e.flags = ReactiveFlags.watching | ReactiveFlags.recursedCheck;
      // only effect and watcher;
      final prevSub = setActiveSub(e);
      try {
        e.effectFn();
      } finally {
        activeSub = prevSub;
        e.flags &= ~ReactiveFlags.recursedCheck;
        purgeDeps(e);
      }
    } else {
      var link = e.deps;
      while (link != null) {
        final dep = link.dep;
        final depFlags = dep.flags;
        if ((depFlags & EffectFlags.queued) != 0) {
          run(dep as JEffectNode, dep.flags = depFlags & ~EffectFlags.queued);
        }
        link = link.nextDep;
      }
    }
  }

  /// Flush all queued effects
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void flush() {
    while (notifyIndex < queuedEffectsLength) {
      final effect = queuedEffects[notifyIndex]!;
      queuedEffects[notifyIndex++] = null;
      run(effect, effect.flags &= ~EffectFlags.queued);
    }
    notifyIndex = 0;
    queuedEffectsLength = 0;
  }

  /// Get the current value of a computed, updating if necessary
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T computedGetter<T>(Computed<T> computed) {
    final flags = computed.flags;
    if (flags.hasAny(ReactiveFlags.dirty) ||
        (flags.hasAny(ReactiveFlags.pending) &&
            (checkDirty(computed.deps!, computed) ||
                _removePending(computed, flags)))) {
      if (updateComputed(computed)) {
        final subs = computed.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
        JoltConfig.observer?.onComputedNotified(computed);
      }
    }
    final sub = activeSub;
    if (sub != null) {
      link(computed, sub, cycle);
    }
    return computed.pendingValue as T;
  }

  /// Force update a computed without changing its value
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void computedNotify<T>(Computed<T> computed) {
    if (updateComputed(computed)) {
      final subs = computed.subs;
      if (subs != null) {
        subs.sub.flags |= ReactiveFlags.pending;
        shallowPropagate(subs);
      }
    }
  }

  /// Set a signal's value and trigger updates
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T signalSetter<T>(Signal<T> signal, T newValue) {
    if (signal.pendingValue != (signal.pendingValue = newValue)) {
      signal.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) {
          flush();
        }
      }
    }
    return newValue;
  }

  /// Get a signal's value and track dependencies
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T signalGetter<T>(Signal<T> signal) {
    if (signal.flags.hasAny(ReactiveFlags.dirty)) {
      if (updateSignal<T>(signal)) {
        final subs = signal.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags.hasAny(ReactiveFlags.mutable | ReactiveFlags.watching)) {
        link(signal, sub, cycle);
        break;
      }
      sub = sub.subs?.sub;
    }
    return signal.currentValue as T;
  }

  /// Force update a signal without changing its value
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void signalNotify<T>(ReadonlySignal<T> signal) {
    signal.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

    final subs = signal.subs;
    if (subs != null) {
      subs.sub.flags |= ReactiveFlags.pending;
      shallowPropagate(subs);
      if (batchDepth == 0) {
        flush();
      }
    }
  }

  /// Dispose an effect and clean up its dependencies
  void nodeDispose(ReactiveNode e) {
    e.depsTail = null;
    e.flags = ReactiveFlags.none;
    purgeDeps(e);
    final sub = e.subs;
    if (sub != null) {
      unlink(sub);
    }
  }

  /// Dispose an effect and clean up its dependencies
  late final effectDispose = nodeDispose;

  /// Dispose an effect scope and clean up its dependencies
  late final effectScopeDispose = nodeDispose;

  /// Purge the dependencies of a reactive node
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void purgeDeps(ReactiveNode sub) {
    final depsTail = sub.depsTail;
    var dep = depsTail != null ? depsTail.nextDep : sub.deps;
    while (dep != null) {
      dep = unlink(dep, sub);
    }
  }
}

/// The global reactive system instance
final globalReactiveSystem = GlobalReactiveSystem();
