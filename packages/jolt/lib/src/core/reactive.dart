import '../jolt/computed.dart';
import '../jolt/effect.dart';
import '../jolt/signal.dart';
import 'debug.dart';
import 'system.dart';

/// The global reactive system
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
  final List<EffectBase?> queued = List.filled(64, null, growable: true);

  /// The currently active effect or scope
  ReactiveNode? activeSub;

  EffectScope? activeScope;

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
  void notify(covariant JEffect e) {
    JEffect? effect = e;
    int insertIndex = queuedLength;
    int firstInsertedIndex = insertIndex;

    do {
      effect!.flags &= ~(ReactiveFlags.watching);

      // queued[insertIndex++] = effect;
      _queueSet(insertIndex++, effect as EffectBase?);
      effect = effect.subs?.sub as JEffect?;
      if (effect == null || effect.flags & (ReactiveFlags.watching) == 0) {
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
    if (node is JEffect) {
      // if (!node.flags.hasAny(ReactiveFlags.mutable)) {
      node.dispose();
    } else if (node.depsTail != null) {
      node.depsTail = null;
      node.flags = (ReactiveFlags.mutable | ReactiveFlags.dirty);
      purgeDeps(node);
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void _queueSet(int index, EffectBase? e) {
    if (index < queued.length) {
      queued[index] = e;
    } else {
      queued.add(e);
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

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  EffectScope? getActiveScope() => activeScope;

  /// Set the currently active subscriber
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  EffectScope? setActiveScope(EffectScope? scope) {
    final prevScope = activeScope;
    activeScope = scope;
    return prevScope;
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
    computed.flags = (ReactiveFlags.mutable | ReactiveFlags.recursedCheck);
    final prevSub = setActiveSub(computed);

    try {
      final oldValue = computed.pendingValue;

      return (oldValue != (computed.pendingValue = computed.getter()));
    } finally {
      activeSub = prevSub;
      computed.flags &= ~(ReactiveFlags.recursedCheck);
      purgeDeps(computed);
    }
  }

  /// Update a signal's value and return true if changed
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateSignal<T>(Signal<T> signal) {
    signal.flags = (ReactiveFlags.mutable);

    return signal.cachedValue != (signal.cachedValue = signal.pendingValue);
  }

  /// Remove the pending flag from a reactive node
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool _removePending(ReactiveNode e, int flags) {
    e.flags = flags & ~(ReactiveFlags.pending);
    return false;
  }

  /// Run an effect with the given flags
  void run(EffectBase e) {
    final flags = e.flags;
    if (flags & (ReactiveFlags.dirty) != 0 ||
        (flags & (ReactiveFlags.pending) != 0 && checkDirty(e.deps!, e))) {
      ++cycle;
      e.depsTail = null;
      e.flags = (ReactiveFlags.watching | ReactiveFlags.recursedCheck);

      // only effect and watcher;
      final prevSub = setActiveSub(e);
      try {
        e.effectFn();
      } finally {
        activeSub = prevSub;
        e.flags &= ~(ReactiveFlags.recursedCheck);
        purgeDeps(e);
      }
    } else {
      e.flags = (ReactiveFlags.watching);
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
    if (flags & (ReactiveFlags.dirty) != 0 ||
        (flags & (ReactiveFlags.pending) != 0 &&
            (checkDirty(computed.deps!, computed) ||
                _removePending(computed, flags)))) {
      if (updateComputed(computed)) {
        final subs = computed.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }

        assert(() {
          getJoltDebugFn(computed)?.call(DebugNodeOperationType.set, computed);
          return true;
        }());
      }
    } else if (flags == (ReactiveFlags.none)) {
      computed.flags = (ReactiveFlags.mutable);
      final prevSub = setActiveSub(computed);
      try {
        computed.pendingValue = computed.getter();
      } finally {
        activeSub = prevSub;
      }

      assert(() {
        getJoltDebugFn(computed)?.call(DebugNodeOperationType.set, computed);
        return true;
      }());
    }
    final sub = activeSub;
    if (sub != null) {
      link(computed, sub, cycle);
    }

    assert(() {
      getJoltDebugFn(computed)?.call(DebugNodeOperationType.get, computed);
      return true;
    }());

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
      subs.sub.flags |= (ReactiveFlags.pending);
      shallowPropagate(subs);
      subs = subs.nextSub;
    }

    if (computed.subs != null && batchDepth == 0) {
      flush();
    }

    assert(() {
      getJoltDebugFn(computed)?.call(DebugNodeOperationType.notify, computed);
      return true;
    }());
  }

  /// Set a signal's value and trigger updates
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T signalSetter<T>(Signal<T> signal, T newValue) {
    if (signal.pendingValue != (signal.pendingValue = newValue)) {
      signal.flags = (ReactiveFlags.mutable | ReactiveFlags.dirty);

      final subs = signal.subs;
      if (subs != null) {
        propagate(subs);
        if (batchDepth == 0) {
          flush();
        }
      }

      assert(() {
        getJoltDebugFn(signal)?.call(DebugNodeOperationType.set, signal);

        return true;
      }());
    }
    return newValue;
  }

  /// Get a signal's value and track dependencies
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T signalGetter<T>(Signal<T> signal) {
    if (signal.flags & (ReactiveFlags.dirty) != 0) {
      if (updateSignal<T>(signal)) {
        final subs = signal.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(signal, sub, cycle);

        break;
      }
      sub = sub.subs?.sub;
    }

    assert(() {
      getJoltDebugFn(signal)?.call(DebugNodeOperationType.get, signal);
      return true;
    }());

    return signal.cachedValue as T;
  }

  /// Force update a signal without changing its value
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void signalNotify<T>(ReadonlySignal<T> signal) {
    signal.flags = (ReactiveFlags.mutable | ReactiveFlags.dirty);

    Link? subs = signal.subs;

    while (subs != null) {
      subs.sub.flags |= (ReactiveFlags.pending);
      shallowPropagate(subs);
      subs = subs.nextSub;
    }

    if (signal.subs != null && batchDepth == 0) {
      flush();
    }

    assert(() {
      getJoltDebugFn(signal)?.call(DebugNodeOperationType.notify, signal);
      return true;
    }());
  }

  /// Dispose an effect and clean up its dependencies
  void nodeDispose(ReactiveNode e) {
    assert(() {
      getJoltDebugFn(e)?.call(DebugNodeOperationType.dispose, e);
      return true;
    }());

    e.depsTail = null;
    e.flags = (ReactiveFlags.none);
    purgeDeps(e);
    final sub = e.subs;
    if (sub != null) {
      unlink(sub);
    }
  }

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
