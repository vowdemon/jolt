import '../jolt/base.dart';
import '../jolt/utils.dart';
import '../jolt/computed.dart';
import '../jolt/effect.dart';
import '../jolt/signal.dart';
import 'system.dart';

class GlobalReactiveSystem extends ReactiveSystem {
  /// The current cycle number
  int cycle = 0;

  /// The current batch depth
  int batchDepth = 0;

  /// The effect index in queue
  int notifyIndex = 0;

  /// The length of the queue of effects to be executed
  int queuedLength = 0;

  /// The queue of effects to be executed
  final List<JEffectNode?> queued = List.filled(64, null, growable: true);

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
  @override
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notify(covariant EffectBaseNode e) {
    EffectBaseNode? effect = e;
    int insertIndex = queuedLength;
    int firstInsertedIndex = insertIndex;

    do {
      effect!.flags &= ~2 /* ReactiveFlags.watching */;

      // queued[insertIndex++] = effect;
      _queueSet(insertIndex++, effect as JEffectNode?);
      effect = effect.subs?.sub as EffectBaseNode?;
      if (effect == null ||
          effect.flags & 2 /** ReactiveFlags.watching */ == 0) {
        break;
      }
    } while (true);

    queuedLength = insertIndex;

    while (firstInsertedIndex < --insertIndex) {
      final left = queued[firstInsertedIndex];
      // queued[firstInsertedIndex++] = queued[insertIndex];
      _queueSet(firstInsertedIndex++, queued[insertIndex]);
      queued[insertIndex] = left;
    }
  }

  /// Handle cleanup when a node is no longer watched
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  void unwatched(node) {
    if (node is EffectBaseNode) {
      // if (!node.flags.hasAny(ReactiveFlags.mutable)) {
      effectScopeDispose(node);
      tryDispose(node);
    } else if (node.depsTail != null) {
      node.depsTail = null;
      node.flags = 17 /* ReactiveFlags.mutable | ReactiveFlags.dirty */;
      purgeDeps(node);
      tryDispose(node);
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void _queueSet(int index, JEffectNode? e) {
    if (index < queued.length) {
      queued[index] = e;
    } else {
      queued.add(e);
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
    computed.flags =
        5 /* ReactiveFlags.mutable | ReactiveFlags.recursedCheck */;
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
      computed.flags &= ~4 /* ReactiveFlags.recursedCheck */;
      purgeDeps(computed);
    }
  }

  /// Update a signal's value and return true if changed
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateSignal<T>(Signal<T> signal) {
    signal.flags = 1 /* ReactiveFlags.mutable */;
    final isChanged =
        signal.currentValue != (signal.currentValue = signal.pendingValue);
    if (isChanged) {
      JoltConfig.observer
          ?.onSignalUpdated(signal, signal.pendingValue, signal.currentValue);
    }
    return isChanged;
  }

  /// Remove the pending flag from a reactive node
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool _removePending(ReactiveNode e, int flags) {
    e.flags = flags & ~32 /* ReactiveFlags.pending */;
    return false;
  }

  /// Run an effect with the given flags
  void run(JEffectNode e) {
    final flags = e.flags;
    if (flags & 16 /** ReactiveFlags.dirty */ != 0 ||
        (flags & 32 /** ReactiveFlags.pending */ != 0 &&
            checkDirty(e.deps!, e))) {
      ++cycle;
      e.depsTail = null;
      e.flags = 6 /* ReactiveFlags.watching | ReactiveFlags.recursedCheck */;

      // only effect and watcher;
      final prevSub = setActiveSub(e);
      try {
        e.effectFn();
      } finally {
        activeSub = prevSub;
        e.flags &= ~4 /* ReactiveFlags.recursedCheck */;
        purgeDeps(e);
      }
    } else {
      e.flags = 2 /* ReactiveFlags.watching */;
    }
  }

  /// Flush all queued effects
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void flush() {
    while (notifyIndex < queuedLength) {
      final effect = queued[notifyIndex]!;
      queued[notifyIndex++] = null;
      run(effect);
    }
    notifyIndex = 0;
    queuedLength = 0;
  }

  /// Get the current value of a computed, updating if necessary
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T computedGetter<T>(Computed<T> computed) {
    final flags = computed.flags;
    if (flags & 16 /** ReactiveFlags.dirty */ != 0 ||
        (flags & 32 /** ReactiveFlags.pending */ != 0 &&
            (checkDirty(computed.deps!, computed) ||
                _removePending(computed, flags)))) {
      if (updateComputed(computed)) {
        final subs = computed.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
        JoltConfig.observer?.onComputedNotified(computed);
      }
    } else if (flags == 0 /* ReactiveFlags.none */) {
      computed.flags = 1 /* ReactiveFlags.mutable */;
      final prevSub = setActiveSub(computed);
      try {
        computed.pendingValue = computed.getter();
      } finally {
        activeSub = prevSub;
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
    updateComputed(computed);

    Link? subs = computed.subs;

    while (subs != null) {
      subs.sub.flags |= 32 /* ReactiveFlags.pending */;
      shallowPropagate(subs);
      subs = subs.nextSub;
    }

    if (computed.subs != null && batchDepth == 0) {
      flush();
    }
  }

  /// Set a signal's value and trigger updates
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T signalSetter<T>(Signal<T> signal, T newValue) {
    if (signal.pendingValue != (signal.pendingValue = newValue)) {
      signal.flags = 17 /* ReactiveFlags.mutable | ReactiveFlags.dirty */;

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
    if (signal.flags & 16 /** ReactiveFlags.dirty */ != 0) {
      if (updateSignal<T>(signal)) {
        final subs = signal.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & 3 /** ReactiveFlags.mutable | ReactiveFlags.watching */ !=
          0) {
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
    signal.flags = 17 /* ReactiveFlags.mutable | ReactiveFlags.dirty */;

    Link? subs = signal.subs;

    while (subs != null) {
      subs.sub.flags |= 32 /* ReactiveFlags.pending */;
      shallowPropagate(subs);
      subs = subs.nextSub;
    }

    if (signal.subs != null && batchDepth == 0) {
      flush();
    }
  }

  /// Dispose an effect and clean up its dependencies
  void nodeDispose(ReactiveNode e) {
    e.depsTail = null;
    e.flags = 0 /* ReactiveFlags.none */;
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
