import 'package:meta/meta.dart';

import 'utils.dart';
import 'computed.dart';
import 'effect.dart';
import 'signal.dart';
import 'system.dart';

@internal
class GlobalReactiveSystem extends ReactiveSystem {
  final queuedEffects = <JEffectNode?>[];

  int batchDepth = 0;

  int notifyIndex = 0;

  int queuedEffectsLength = 0;

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
      return updateSignal(node as Signal, node.nodeValue);
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
    if (node is Computed) {
      var toRemove = node.deps;
      if (toRemove != null) {
        node.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
        do {
          toRemove = unlink(toRemove!, node);
        } while (toRemove != null);
      }

      node.tryDispose();
    } else if (node is ReadonlySignal) {
      node.tryDispose();
    } else {
      (node as EffectBaseNode).dispose();
    }
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  ReactiveNode? getCurrentSub() => activeSub;

  /// Set the currently active subscriber
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  ReactiveNode? setCurrentSub(ReactiveNode? sub) {
    final prevSub = activeSub;
    activeSub = sub;
    return prevSub;
  }

  /// Get the currently active effect scope
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  EffectScope? getCurrentScope() => activeScope;

  /// Set the currently active effect scope
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  EffectScope? setCurrentScope(EffectScope? scope) {
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

  /// Update the computed value and return true if changed
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateComputed<T>(Computed<T> computed) {
    final prevSub = setCurrentSub(computed);
    startTracking(computed);
    try {
      final oldValue = computed.nodeValue;
      final isChanged = (oldValue != (computed.nodeValue = computed.getter()));
      if (isChanged) {
        JConfig.observer?.onUpdated(computed, computed.nodeValue, oldValue);
      }
      return isChanged;
    } finally {
      setCurrentSub(prevSub);
      endTracking(computed);
    }
  }

  /// Update a signal's value and return true if changed
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool updateSignal<T>(Signal<T> signal, T value) {
    signal.flags = ReactiveFlags.mutable;
    final isChanged =
        signal.nodePreviousValue != (signal.nodePreviousValue = value);
    if (isChanged) {
      JConfig.observer?.onUpdated(signal, value, signal.nodePreviousValue);
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

  /// Run an effect with the given flags
  void run(JEffectNode e, int flags) {
    if (flags.hasAny(ReactiveFlags.dirty) ||
        (flags.hasAny(ReactiveFlags.pending) && checkDirty(e.deps!, e))) {
      // only effect and watcher;
      final prev = setCurrentSub(e);
      startTracking(e);
      try {
        e.effectFn();
      } finally {
        setCurrentSub(prev);
        endTracking(e);
      }

      return;
    } else if (flags.hasAny(ReactiveFlags.pending)) {
      e.flags = flags & ~(ReactiveFlags.pending);
    }
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

  /// Flush all queued effects
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
            checkDirty(computed.deps!, computed))) {
      if (updateComputed(computed)) {
        final subs = computed.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    } else if (flags.hasAny(ReactiveFlags.pending)) {
      computed.flags = flags & ~ReactiveFlags.pending;
    }
    if (activeSub != null) {
      link(computed, activeSub!);
    } else if (activeScope != null) {
      link(computed, activeScope!);
    }
    return computed.nodeValue as T;
  }

  /// Force update a computed without changing its value
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void computedNotify<T>(Computed<T> computed) {
    JConfig.observer?.onNotify(computed);
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
    if (signal.nodeValue != (signal.nodeValue = newValue)) {
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
    final value = signal.nodeValue as T;

    if (signal.flags.hasAny(ReactiveFlags.dirty)) {
      if (updateSignal<T>(signal, value)) {
        final subs = signal.subs;
        if (subs != null) {
          shallowPropagate(subs);
        }
      }
    }

    if (activeSub != null) {
      link(signal, activeSub!);
    }

    return value;
  }

  /// Force update a signal without changing its value
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void signalNotify<T>(ReadonlySignal<T> signal) {
    JConfig.observer?.onNotify(signal);

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
    var dep = e.deps;
    while (dep != null) {
      dep = unlink(dep, e);
    }
    final sub = e.subs;
    if (sub != null) {
      unlink(sub);
    }
    e.flags = ReactiveFlags.none;
  }
}

final globalReactiveSystem = GlobalReactiveSystem();
