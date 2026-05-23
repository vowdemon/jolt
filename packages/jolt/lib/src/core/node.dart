import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/core/system.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposer;

/// Low-level reactive node that stores a mutable value.
///
/// This is the graph node behind [Signal]. It tracks subscribers, participates
/// in batching, and propagates updates when [set] or [notify] runs.
///
/// Prefer [Signal] in application code; use [SignalNode] when implementing
/// custom primitives on the core graph.
///
/// Example:
/// ```dart
/// final node = SignalNode<int>(0);
/// final effect = Effect(() => print(node.get()));
/// node.set(1);
/// effect.dispose();
/// node.dispose();
/// ```
class SignalNode<T> extends ReactiveNode {
  /// Creates a signal node initialized to [value].
  ///
  /// The same value is used for both the committed value and the pending value
  /// until the node is updated or notified.
  SignalNode(this.value, {JoltDebugOption? debug})
      : pendingValue = value,
        super(flags: ReactiveFlags.mutable) {
    assert(() {
      JoltDevTools.create(this, debug);
      return true;
    }());
  }

  /// The last value committed by [get] or [update].
  ///
  /// After [notify], this becomes `null` until [pendingValue] is committed
  /// again.
  T? value;

  /// The value that will be committed on the next [get] or [update].
  ///
  /// [set] writes here before propagation reaches subscribers.
  T? pendingValue;

  /// Returns [pendingValue] without establishing a reactive dependency.
  ///
  /// This does not mark the node clean or link it to the active subscriber.
  ///
  /// Example:
  /// ```dart
  /// final node = SignalNode<int>(0);
  /// node.set(1);
  /// print(node.peek()); // 1
  /// ```
  T peek() => pendingValue as T;

  /// Returns the current value and links this node to the active subscriber.
  ///
  /// When the node is dirty, [pendingValue] is committed before the read.
  /// After [dispose], this returns [pendingValue] without tracking.
  ///
  /// Example:
  /// ```dart
  /// final node = SignalNode<int>(0);
  /// Effect(() => node.get());
  /// ```
  T get() {
    if (!isDisposed) {
      assert(() {
        JoltDevTools.get(this);
        return true;
      }());
      if (flags & (ReactiveFlags.dirty) != 0) {
        if (update()) {
          if (subs != null) {
            shallowPropagate(subs!);
          }
        }
      }
      final sub = activeSub;
      if (sub != null) {
        link(this, sub, cycle);
      }

      return value as T;
    }
    return pendingValue as T;
  }

  /// Stores [value], marks the node dirty when it changes, and propagates.
  ///
  /// Returns the assigned [value]. When [batchDepth] is zero, queued effects
  /// flush after propagation. Disposed nodes still store the value but do not
  /// notify subscribers.
  T set(T value) {
    if (!isDisposed && pendingValue != (pendingValue = value)) {
      assert(() {
        JoltDevTools.set(this);
        return true;
      }());
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

      if (subs != null) {
        propagate(subs!, runDepth > 0);
        if (batchDepth == 0) {
          flushEffects();
        }
      }
    } else if (isDisposed) {
      this.value = value;
      pendingValue = value;
    }
    return value;
  }

  /// Commits [pendingValue] as the current [value].
  ///
  /// Returns `true` when the committed value changed and subscribers may need
  /// shallow propagation.
  @override
  bool update() {
    flags &= ReactiveFlags.mutable;

    final oldValue = value;
    return oldValue != (value = pendingValue);
  }

  /// Forces subscribers to update without changing [pendingValue].
  ///
  /// Clears the committed [value], marks the node dirty, and propagates.
  /// Use this after in-place mutations when the stored reference is unchanged.
  ///
  /// Example:
  /// ```dart
  /// final node = SignalNode<List<int>>([1, 2]);
  /// node.pendingValue!.add(3);
  /// node.notify();
  /// ```
  void notify() {
    if (!isDisposed) {
      assert(() {
        JoltDevTools.notify(this);
        return true;
      }());
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

      value = null;

      if (subs != null) {
        propagate(subs!, runDepth > 0);
        shallowPropagate(subs!);
        if (batchDepth == 0) {
          flushEffects();
        }
      }
    }
  }

  /// Disposes this node and removes it from the dependency graph.
  ///
  /// After disposal, [get] returns [pendingValue] without tracking and [set]
  /// only stores new values.
  ///
  /// Example:
  /// ```dart
  /// final node = SignalNode<int>(0);
  /// node.dispose();
  /// assert(node.isDisposed);
  /// ```
  void dispose() {
    this
      ..depsTail = null
      ..flags = ReactiveFlags.none;

    purgeDeps(this);
    final sub = subs;
    if (sub != null) {
      unlink(sub);
    }
    assert(() {
      JoltDevTools.dispose(this);
      return true;
    }());
  }

  /// Whether [dispose] has been called on this node.
  ///
  /// Disposed signal nodes no longer propagate changes.
  bool get isDisposed => flags == ReactiveFlags.none;

  /// Called when this node loses its last subscriber.
  ///
  /// Signal nodes stay alive and keep their current value even when no longer
  /// observed.
  @override
  void unwatched() {}
}

/// Low-level reactive node that derives a value from dependencies.
///
/// This is the graph node behind [Computed]. It caches the result of [getter],
/// tracks dependencies while recomputing, and supports custom equality through
/// [equals].
///
/// Prefer [Computed] in application code; use [ComputedNode] for custom
/// derived nodes on the core graph.
///
/// Example:
/// ```dart
/// final source = SignalNode<int>(1);
/// final doubled = ComputedNode<int>(() => source.get() * 2);
/// ```
class ComputedNode<T> extends ReactiveNode {
  /// Creates a computed node that evaluates [getter] lazily and caches results.
  ///
  /// The [getter] callback runs while this node is the active subscriber. When
  /// provided, [equals] can suppress propagation by returning `true` for a
  /// newly computed value that should be treated as unchanged.
  ComputedNode(this.getter, {this.equals, JoltDebugOption? debug})
      : super(flags: ReactiveFlags.none) {
    assert(() {
      JoltDevTools.create(this, debug);
      return true;
    }());
  }

  /// Function that computes the value while this node is the active subscriber.
  final T Function() getter;

  /// Optional equality function used to suppress propagation.
  ///
  /// Return `true` when the newly computed value should be treated as equal to
  /// the previous one.
  final bool Function(T current, T? previous)? equals;

  /// The cached result of the last successful evaluation of [getter].
  T? value;

  bool _isDisposed = false;

  /// Whether [dispose] has been called on this node.
  ///
  /// Disposed computed nodes no longer recompute or track dependencies.
  bool get isDisposed => _isDisposed;

  /// Returns the current computed value without establishing a dependency.
  ///
  /// This is equivalent to calling [get] inside [untracked].
  ///
  /// Example:
  /// ```dart
  /// final node = ComputedNode<int>(() => 42);
  /// print(node.peek());
  /// ```
  T peek() => untracked(get);

  /// Returns the cached or recomputed value and links to the active subscriber.
  ///
  /// If this node has not been evaluated yet, or if dependencies marked it
  /// dirty, [getter] runs before the value is returned.
  ///
  /// Example:
  /// ```dart
  /// final node = ComputedNode<int>(() => 1);
  /// Effect(() => node.get());
  /// ```
  T get() {
    if (!isDisposed) {
      assert(() {
        JoltDevTools.get(this);
        return true;
      }());
      if (flags & ReactiveFlags.dirty != 0 ||
          (flags & ReactiveFlags.pending != 0 &&
              (checkDirty(deps!, this) ||
                  () {
                    flags = flags & ~ReactiveFlags.pending;
                    return false;
                  }()))) {
        if (update()) {
          if (subs != null) {
            shallowPropagate(subs!);
          }
        }
      } else if (flags == ReactiveFlags.none) {
        flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
        final prevSub = setActiveSub(this);
        try {
          value = getter();
          assert(() {
            JoltDevTools.set(this);
            return true;
          }());
        } finally {
          activeSub = prevSub;
          flags &= ~ReactiveFlags.recursedCheck;
        }
      }
      final sub = activeSub;
      if (sub != null) {
        link(this, sub, cycle);
      }
    }

    return value as T;
  }

  /// Recomputes [getter] and updates the cached [value].
  ///
  /// Returns `true` when the new result is not equal to the previous result
  /// according to [equals] or `!=`.
  @override
  bool update() {
    if (flags & ReactiveFlags.hasChildEffect != 0) {
      var link = depsTail;
      while (link != null) {
        final prev = link.prevDep;
        final dep = link.dep;
        if (dep is BaseEffectNode) {
          unlink(link, this);
        }
        link = prev;
      }
    }

    this
      ..depsTail = null
      ..flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(this);

    try {
      ++cycle;
      final oldValue = value;
      final newValue = getter();
      final isNotEqual = switch (equals == null) {
        true => oldValue != newValue,
        false => !equals!(newValue, oldValue),
      };

      value = newValue;
      if (isNotEqual) {
        assert(() {
          JoltDevTools.set(this);
          return true;
        }());
      }

      return isNotEqual;
    } finally {
      activeSub = prevSub;
      flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(this);
    }
  }

  /// Recomputes immediately and always schedules subscribers for update.
  ///
  /// Unlike [notifySoft], subscribers are marked pending even when [equals]
  /// reports no value change. When not inside a batch, queued effects flush
  /// before this call returns.
  void notify() {
    if (!isDisposed) {
      assert(() {
        JoltDevTools.notify(this);
        return true;
      }());
      update();

      var subs = this.subs;

      while (subs != null) {
        subs.sub?.flags |= ReactiveFlags.pending;
        shallowPropagate(subs);
        subs = subs.nextSub;
      }

      if (this.subs != null && batchDepth == 0) {
        flushEffects();
      }
    }
  }

  /// Recomputes immediately and schedules subscribers only when the value changes.
  ///
  /// When not inside a batch, queued effects flush before this call returns.
  ///
  /// Example:
  /// ```dart
  /// final node = ComputedNode<int>(() => 1);
  /// node.notifySoft();
  /// ```
  void notifySoft() {
    if (!isDisposed) {
      assert(() {
        JoltDevTools.notify(this);
        return true;
      }());
      final updated = update();

      if (!updated) return;

      var subs = this.subs;

      while (subs != null) {
        subs.sub?.flags |= ReactiveFlags.pending;
        shallowPropagate(subs);
        subs = subs.nextSub;
      }

      if (this.subs != null && batchDepth == 0) {
        flushEffects();
      }
    }
  }

  /// Disposes this node and removes it from the dependency graph.
  ///
  /// Subsequent [get] calls return the last cached [value] without tracking or
  /// recomputation.
  ///
  /// Example:
  /// ```dart
  /// final node = ComputedNode<int>(() => 1);
  /// node.dispose();
  /// ```
  void dispose() {
    if (isDisposed) return;
    _isDisposed = true;
    this
      ..depsTail = null
      ..flags = ReactiveFlags.none;

    purgeDeps(this);
    final sub = subs;
    if (sub != null) {
      unlink(sub);
    }
    assert(() {
      JoltDevTools.dispose(this);
      return true;
    }());
  }

  /// Called when this node loses its last subscriber.
  ///
  /// This clears dependency links and marks the node dirty so the next read
  /// recomputes from scratch.
  @override
  void unwatched() {
    if (depsTail != null) {
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      _disposeDepsInReverse(this);
    }
  }
}

/// Registers disposers that run when an effect node is cleaned up or disposed.
///
/// Applied to [BaseEffectNode] implementations such as [EffectNode] and
/// [EffectScopeNode]. Cleanup runs inside [untracked] so disposers do not
/// create new dependencies.
///
/// Example:
/// ```dart
/// class LoggingEffect extends BaseEffectNode {
///   LoggingEffect() : super(flags: ReactiveFlags.watching) {
///     onCleanup(() => print('effect cleaned up'));
///   }
/// }
/// ```
mixin CleanableNode {
  final Set<Disposer> _cleanups = {};

  /// Runs all registered cleanup callbacks and clears the registry.
  ///
  /// Cleanups run inside [untracked], so they do not create new dependencies.
  void cleanup() {
    if (_cleanups.isNotEmpty) {
      final cleanupsCopy = {..._cleanups};
      _cleanups.clear();
      untracked(() {
        for (final cleanup in cleanupsCopy) {
          cleanup();
        }
      });
    }
  }

  /// Registers [cleanup] to run on the next [cleanup] or dispose.
  ///
  /// The callback runs inside [untracked].
  void onCleanup(Disposer cleanup) {
    _cleanups.add(cleanup);
  }
}

final Set<BaseEffectNode> _retainedEffects = {};

/// Base graph node for effects and effect scopes.
///
/// Extends [ReactiveNode] with [CleanableNode] so nested resources can register
/// disposers. Subclasses include [EffectNode] and [EffectScopeNode].
abstract class BaseEffectNode extends ReactiveNode with CleanableNode {
  /// Creates an effect-owned node with the supplied scheduling [flags].
  BaseEffectNode({required super.flags});

  /// Disposes this node, unlinks dependencies, and runs [cleanup].
  ///
  /// Registered cleanups run after dependency teardown and subscriber unlinking.
  void dispose() {
    _retainedEffects.remove(this);
    flags = ReactiveFlags.none;
    _disposeDepsInReverse(this);

    var sub = subs;
    if (sub != null) {
      unlink(sub);
    }
    cleanup();
    assert(() {
      JoltDevTools.dispose(this);
      return true;
    }());
  }
}

/// Low-level node that owns effects created within a scope.
///
/// This is the graph node behind [EffectScope]. While active, it becomes the
/// ambient scope for newly created effects unless [detach] is true.
///
/// Prefer [EffectScope] in application code; use [EffectScopeNode] when
/// integrating custom lifecycle management with the core graph.
///
/// Example:
/// ```dart
/// final scope = EffectScopeNode();
/// scope.run(() {
///   EffectNode(() => print('inside scope'));
/// });
/// scope.dispose();
/// ```
class EffectScopeNode extends BaseEffectNode {
  /// Creates a scope node.
  ///
  /// When [detach] is `false`, this scope is retained and linked to the active
  /// subscriber so it disposes with its parent.
  EffectScopeNode({bool detach = false, JoltDebugOption? debug})
      : super(flags: ReactiveFlags.mutable) {
    assert(() {
      JoltDevTools.create(this, debug);
      return true;
    }());
    if (!detach) {
      _retainedEffects.add(this);
    }
    if (!detach) {
      final prevSub = getActiveSub();
      if (prevSub != null) {
        link(this, prevSub, 0);
        prevSub.flags |= ReactiveFlags.hasChildEffect;
      }
    }
  }

  /// Runs [fn] with this scope as the active subscriber and ambient scope.
  ///
  /// Returns the result of [fn]. Effects created inside [fn] are owned by this
  /// scope unless they are detached.
  T run<T>(T Function() fn) {
    final prevSub = setActiveSub(this);
    final prevScope = setActiveScope(this);
    try {
      return fn();
    } finally {
      setActiveScope(prevScope);
      setActiveSub(prevSub);
    }
  }

  /// Whether [dispose] has been called on this scope.
  bool get isDisposed => flags == ReactiveFlags.none;

  /// Resets transient scheduling flags on this scope.
  ///
  /// Effect scopes do not compute values, so this keeps the scope active in
  /// the graph and always reports success.
  @override
  bool update() {
    flags = ReactiveFlags.mutable;
    return true;
  }

  /// Disposes this scope when it loses its last watcher.
  @override
  void unwatched() {
    dispose();
  }
}

/// Low-level node that runs a side-effect function when dependencies change.
///
/// This is the graph node behind [Effect] and [Watcher]. It tracks
/// dependencies on each run and queues re-runs through the global effect queue.
///
/// Prefer [Effect] in application code; use [EffectNode] for custom reactive
/// side effects on the core graph.
///
/// Example:
/// ```dart
/// final source = SignalNode(0);
/// final effect = EffectNode(() => print(source.get()));
/// effect.run();
/// effect.dispose();
/// ```
class EffectNode extends BaseEffectNode {
  /// Creates an effect node that invokes [fn] in a reactive subscriber context.
  ///
  /// Unless [lazy] is `true`, [fn] runs immediately. When [detach] is `true`,
  /// this effect is not linked to the current parent scope or subscriber.
  EffectNode(this.fn,
      {bool lazy = false, bool detach = false, JoltDebugOption? debug})
      : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck) {
    assert(() {
      JoltDevTools.create(this, debug);
      return true;
    }());
    if (!detach) {
      _retainedEffects.add(this);
    }
    final prevSub = setActiveSub(this);
    if (prevSub != null && !detach) {
      link(this, prevSub, 0);
      prevSub.flags |= ReactiveFlags.hasChildEffect;
    }

    if (!lazy) {
      try {
        ++runDepth;
        fn();
      } finally {
        --runDepth;
        assert(() {
          JoltDevTools.effect(this);
          return true;
        }());
      }
    }
    setActiveSub(prevSub);
    flags &= ~ReactiveFlags.recursedCheck;
  }

  /// Side-effect body executed on the initial run and scheduled reruns.
  final void Function() fn;

  /// Runs [fn] when this node is dirty or has pending dependencies.
  ///
  /// Registered cleanups run before the body reruns. Dependency collection uses
  /// the active subscriber stack, and disposed effects are ignored.
  ///
  /// Example:
  /// ```dart
  /// final effect = EffectNode(() => print('tick'), lazy: true);
  /// effect.run();
  /// ```
  void run() {
    final flags = this.flags;

    if (flags & (ReactiveFlags.dirty) != 0 ||
        (flags & (ReactiveFlags.pending) != 0 && checkDirty(deps!, this))) {
      if (flags & ReactiveFlags.hasChildEffect != 0) {
        var link = depsTail;
        while (link != null) {
          final prev = link.prevDep;
          final dep = link.dep;
          if (dep is BaseEffectNode) {
            unlink(link, this);
          }
          link = prev;
        }
      }

      cleanup();
      if (this.flags == ReactiveFlags.none) {
        return;
      }

      this
        ..depsTail = null
        ..flags = ReactiveFlags.watching | ReactiveFlags.recursedCheck;

      final prevSub = setActiveSub(this);
      try {
        ++cycle;
        ++runDepth;
        fn();
      } finally {
        --runDepth;
        assert(() {
          JoltDevTools.effect(this);
          return true;
        }());
        activeSub = prevSub;
        this.flags &= ~ReactiveFlags.recursedCheck;
        purgeDeps(this);
      }
    } else if (deps != null) {
      this.flags =
          ReactiveFlags.watching | (flags & ReactiveFlags.hasChildEffect);
    }
  }

  /// Whether [dispose] has been called on this effect.
  bool get isDisposed => flags == ReactiveFlags.none;

  /// Executes [fn] while this effect is the active subscriber.
  ///
  /// Returns the result of [fn]. When [purge] is true (default), dependency
  /// links from prior runs are cleared before and after [fn] so only
  /// dependencies read inside [fn] remain.
  T track<T>(T Function() fn, [bool purge = true]) {
    if (purge) {
      ++cycle;
      depsTail = null;
    }
    final prevSub = setActiveSub(this);
    try {
      return fn();
    } finally {
      setActiveSub(prevSub);
      if (purge) {
        flags = ReactiveFlags.watching;
        purgeDeps(this);
      }
    }
  }

  /// Enqueues this effect and parent watching effects for execution.
  ///
  /// Called by the propagation system when this node is marked
  /// [ReactiveFlags.watching]. Parent effects are inserted ahead of children to
  /// preserve cleanup and run order.
  void notifyEffect() {
    BaseEffectNode? effect = this;

    var insertIndex = queuedLength;
    var firstInsertedIndex = insertIndex;

    // allow do-while loop
    // ignore: literal_only_boolean_expressions
    do {
      effect!.flags &= ~ReactiveFlags.watching;

      // queued[insertIndex++] = effect;
      setEffectQueue(insertIndex++, effect as EffectNode?);
      effect = effect.subs?.sub as BaseEffectNode?;
      if (effect == null || effect.flags & (ReactiveFlags.watching) == 0) {
        break;
      }
    } while (true);

    queuedLength = insertIndex;

    while (firstInsertedIndex < --insertIndex) {
      final left = queued[firstInsertedIndex];
      // queued[firstInsertedIndex++] = queued[insertIndex];
      setEffectQueue(firstInsertedIndex++, queued[insertIndex]);
      queued[insertIndex] = left;
    }
  }

  /// Disposes this effect when it loses its last watcher.
  @override
  void unwatched() {
    dispose();
  }

  /// Returns `false` because effect nodes do not compute cached values.
  @override
  bool update() => false;
}

void _disposeDepsInReverse(ReactiveNode sub) {
  var link = sub.depsTail;
  while (link != null) {
    final prev = link.prevDep;
    unlink(link, sub);
    link = prev;
  }
}
