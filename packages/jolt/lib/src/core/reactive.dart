import "package:jolt/src/core/debug.dart";
import "package:meta/meta.dart";
import "package:shared_interfaces/shared_interfaces.dart";

part "system.dart";

/// Monotonically increasing counter used to stamp dependency links during
/// recomputation cycles.
///
/// Example:
/// ```dart
/// final startCycle = cycle;
/// flushEffects();
/// assert(cycle >= startCycle);
/// ```
int cycle = 0;

/// Current nesting depth of [`startBatch`]/[`endBatch`] calls.
///
/// Example:
/// ```dart
/// startBatch();
/// assert(batchDepth > 0);
/// endBatch();
/// ```
int batchDepth = 0;

/// Index of the next effect to flush from [queued].
///
/// Example:
/// ```dart
/// while (notifyIndex < queuedLength) {
///   final effect = queued[notifyIndex++]!;
///   runEffect(effect);
/// }
/// ```
int notifyIndex = 0;

/// Number of scheduled effects stored inside [queued].
///
/// Example:
/// ```dart
/// final effect = CustomEffectNode(); // Implements EffectReactiveNode
/// queued[queuedLength++] = effect;
/// if (batchDepth == 0) {
///   flushEffects();
/// }
/// ```
int queuedLength = 0;

/// Ring buffer that stores pending [EffectReactiveNode] instances.
///
/// Example:
/// ```dart
/// final effect = CustomEffectNode();
/// final slot = queuedLength++;
/// queued[slot] = effect;
/// flushEffects();
/// ```
final List<EffectReactiveNode?> queued = List.filled(64, null, growable: true);

/// Effect or computed that is currently collecting dependencies.
///
/// Example:
/// ```dart
/// final customEffect = CustomEffectNode();
/// final prev = setActiveSub(customEffect);
/// try {
///   customEffect.effectFn();
/// } finally {
///   setActiveSub(prev);
/// }
/// ```
ReactiveNode? activeSub;

/// Effect scope that is currently being configured.
///
/// Example:
/// ```dart
/// final scope = getActiveScope();
/// scope?.dispose();
/// ```
EffectScopeReactiveNode? activeScope;

/// Updates either a [ComputedReactiveNode] or [SignalReactiveNode] and returns
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
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
@override
bool updateNode(ReactiveNode node) {
  return switch (node) {
    ComputedReactiveNode() => updateComputed(node),
    SignalReactiveNode() => updateSignal(node),
    _ => updateCustom(node),
  };
}

/// Enqueues an [EffectReactiveNode] chain for execution.
///
/// Parameters:
/// - [e]: Effect node whose dependencies changed
///
/// Example:
/// ```dart
/// final effectNode = CustomEffectNode();
/// notifyEffect(effectNode);
/// if (batchDepth == 0) {
///   flushEffects();
/// }
/// ```
@override
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
@pragma("vm:align-loops")
@pragma('vm:unsafe:no-bounds-checks')
void notifyEffect(ReactiveNode e) {
  EffectBaseReactiveNode? effect = e as EffectBaseReactiveNode;

  // Check if effect implements custom scheduling
  if (effect is EffectScheduler) {
    final scheduler = effect as EffectScheduler;
    if (scheduler.schedule()) {
      // Custom scheduling handled, don't add to default queue
      return;
    }
    // Custom scheduler returned false, continue with default behavior
  }

  var insertIndex = queuedLength;
  var firstInsertedIndex = insertIndex;

  // allow do-while loop
  // ignore: literal_only_boolean_expressions
  do {
    effect!.flags &= ~ReactiveFlags.watching;

    // queued[insertIndex++] = effect;
    _queueSet(insertIndex++, effect as EffectReactiveNode?);
    effect = effect.subs?.sub as EffectBaseReactiveNode?;
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

/// Cleans up dependency links when a node no longer has subscribers.
///
/// Parameters:
/// - [node]: Node that lost its last subscriber
///
/// Example:
/// ```dart
/// final link = dep.subs!; // Link between dep and subscriber
/// if (link.dep.subs == null) {
///   unwatched(link.dep);
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
@override
void unwatched(ReactiveNode node) {
  if (node is EffectBaseReactiveNode) {
    // if (!node.flags.hasAny(ReactiveFlags.mutable)) {
    // ignore: discarded_futures
    node.dispose();
  } else if (node.depsTail != null) {
    node
      ..depsTail = null
      ..flags = (ReactiveFlags.mutable | ReactiveFlags.dirty);
    purgeDeps(node);
  }
}

@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void _queueSet(int index, EffectReactiveNode? e) {
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

/// Returns the [EffectScopeReactiveNode] that is currently open.
///
/// Example:
/// ```dart
/// final scope = getActiveScope();
/// scope?.dispose();
/// ```
EffectScopeReactiveNode? getActiveScope() => activeScope;

/// Sets the ambient [EffectScopeReactiveNode] and returns the previous scope.
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
EffectScopeReactiveNode? setActiveScope([EffectScopeReactiveNode? scope]) {
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
  if (!((--batchDepth) != 0)) {
    flushEffects();
  }
}

/// Returns the current batch depth, where zero means no batching.
///
/// Example:
/// ```dart
/// assert(getBatchDepth() >= 0);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
int getBatchDepth() => batchDepth;

/// Recomputes a [ComputedReactiveNode] and reports whether the pending value
/// changed.
///
/// Parameters:
/// - [computed]: Computed node whose getter should be invoked
///
/// Example:
/// ```dart
/// final computedNode = CustomComputedNode<int>(() => 0);
/// if (updateComputed(computedNode) && computedNode.subs != null) {
///   shallowPropagate(computedNode.subs!);
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
bool updateComputed<T>(ComputedReactiveNode<T> computed) {
  ++cycle;
  computed
    ..depsTail = null
    ..flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
  final prevSub = setActiveSub(computed);

  try {
    final oldValue = computed.pendingValue;
    final newValue = computed.getter();
    final equals = computed.equals == null
        ? oldValue == newValue
        : computed.equals!(newValue as Object, oldValue as Object);
    if (equals) {
      return false;
    }
    computed.pendingValue = newValue;
    return true;
  } finally {
    activeSub = prevSub;
    computed.flags &= ~ReactiveFlags.recursedCheck;
    purgeDeps(computed);
  }
}

/// Updates a [SignalReactiveNode]'s cached value from its pending value.
///
/// Parameters:
/// - [signal]: Signal that should commit its pending value
///
/// Returns true when the cached value actually changed.
///
/// Example:
/// ```dart
/// final signalNode = CustomSignalNode<int>(0);
/// if (updateSignal(signalNode) && signalNode.subs != null) {
///   shallowPropagate(signalNode.subs!);
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
bool updateSignal<T>(SignalReactiveNode<T> signal) {
  signal.flags = ReactiveFlags.mutable;

  return signal.cachedValue != (signal.cachedValue = signal.pendingValue);
}

/// Updates a custom reactive node and returns whether its value changed.
///
/// This function is called by [updateNode] for nodes that are not standard
/// [ComputedReactiveNode] or [SignalReactiveNode] instances. It handles
/// [CustomReactiveNode] instances by calling their [CustomReactiveNode.updateNode]
/// method, which allows custom update logic.
///
/// For non-custom nodes, this function always returns `true`, indicating that
/// the node should be treated as changed.
///
/// Parameters:
/// - [node]: Custom reactive node to update
///
/// Returns: `true` if the node's value changed, `false` otherwise
///
/// Example:
/// ```dart
/// final customNode = CustomWidgetPropsNode<MyWidget>();
/// if (updateCustom(customNode) && customNode.subs != null) {
///   shallowPropagate(customNode.subs!);
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
bool updateCustom<T>(ReactiveNode node) {
  node.flags = ReactiveFlags.mutable;

  if (node is CustomReactiveNode) {
    return node.updateNode();
  } else {
    return true;
  }
}

/// Remove the pending flag from a reactive node
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
bool _removePending(ReactiveNode e, int flags) {
  e.flags = flags & ~ReactiveFlags.pending;
  return false;
}

/// Executes an [EffectReactiveNode] when it is dirty or pending.
///
/// This function checks if the effect node's flags indicate that it needs to
/// be executed (has `dirty` flag or `pending` flag with dirty dependencies).
/// If so, it executes the provided function [fn] in the proper reactive context.
///
/// Parameters:
/// - [e]: Effect node to evaluate
/// - [fn]: The function to execute when the effect needs to run
///
/// Example:
/// ```dart
/// class CustomEffectNode extends EffectReactiveNode {
///   CustomEffectNode() : super(flags: ReactiveFlags.watching);
///
///   @override
///   void runEffect() {
///     defaultRunEffect(this, _effectFn);
///   }
///
///   void _effectFn() {
///     // Effect logic here
///   }
/// }
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void defaultRunEffect(EffectReactiveNode e, void Function() fn) {
  final flags = e.flags;
  if (flags & (ReactiveFlags.dirty) != 0 ||
      (flags & (ReactiveFlags.pending) != 0 && checkDirty(e.deps!, e))) {
    ++cycle;
    e
      ..depsTail = null
      ..flags = ReactiveFlags.watching | ReactiveFlags.recursedCheck;

    // only effect and watcher;
    final prevSub = setActiveSub(e);
    try {
      fn();
    } finally {
      activeSub = prevSub;
      e.flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(e);
    }
  } else {
    e.flags = ReactiveFlags.watching;
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
      effect.runEffect();
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

/// Returns the current value of a computed node, recomputing it when dirty and
/// linking it to the active subscriber.
///
/// Parameters:
/// - [computed]: Node to read and potentially recompute
///
/// Example:
/// ```dart
/// final myComputedNode = CustomComputedNode<int>(() => 0);
/// final value = getComputed(myComputedNode);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T getComputed<T>(ComputedReactiveNode<T> computed) {
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

      JoltDebug.set(computed);
    }
  } else if (flags == (ReactiveFlags.none)) {
    computed.flags = ReactiveFlags.mutable | ReactiveFlags.recursedCheck;
    final prevSub = setActiveSub(computed);
    try {
      computed.pendingValue = computed.getter();
    } finally {
      activeSub = prevSub;
      computed.flags &= ~ReactiveFlags.recursedCheck;
    }

    JoltDebug.set(computed);
  }
  final sub = activeSub;
  if (sub != null) {
    link(computed, sub, cycle);
  }

  JoltDebug.get(computed);

  return computed.pendingValue as T;
}

/// Invalidates a computed node and notifies its subscribers without assigning
/// a new value.
///
/// Parameters:
/// - [computed]: Node to invalidate
///
/// Example:
/// ```dart
/// final cacheBustingComputed = CustomComputedNode<int>(() => 0);
/// notifyComputed(cacheBustingComputed);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void notifyComputed<T>(ComputedReactiveNode<T> computed) {
  updateComputed(computed);

  var subs = computed.subs;

  while (subs != null) {
    subs.sub.flags |= ReactiveFlags.pending;
    shallowPropagate(subs);
    subs = subs.nextSub;
  }

  if (computed.subs != null && batchDepth == 0) {
    flushEffects();
  }

  JoltDebug.notify(computed);
}

/// Assigns a new pending value to a signal and schedules subscribers.
///
/// Parameters:
/// - [signal]: Signal whose value should change
/// - [newValue]: Value to assign
///
/// Example:
/// ```dart
/// final countNode = CustomSignalNode<int>(0);
/// setSignal(countNode, 42);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T setSignal<T>(SignalReactiveNode<T> signal, T newValue) {
  if (signal.pendingValue != (signal.pendingValue = newValue)) {
    signal.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

    final subs = signal.subs;
    if (subs != null) {
      propagate(subs);
      if (batchDepth == 0) {
        flushEffects();
      }
    }

    JoltDebug.set(signal);
  }
  return newValue;
}

/// Returns the current cached value of a signal and links it to the active
/// subscriber.
///
/// Parameters:
/// - [signal]: Signal to read
///
/// Example:
/// ```dart
/// final countNode = CustomSignalNode<int>(0);
/// final value = getSignal(countNode);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T getSignal<T>(SignalReactiveNode<T> signal) {
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

  JoltDebug.get(signal);

  return signal.cachedValue as T;
}

/// Invalidates a signal so that subscribers re-evaluate without changing the
/// stored value.
///
/// Parameters:
/// - [signal]: Signal to invalidate
///
/// Example:
/// ```dart
/// final cacheAwareSignal = CustomSignalNode<int>(0);
/// notifySignal(cacheAwareSignal);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void notifySignal<T>(SignalReactiveNode signal) {
  // Mark as changed even if the underlying reference didn't change (e.g. in-place mutations).
  signal.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

  signal.cachedValue = null;

  final subs = signal.subs;
  if (subs != null) {
    propagate(subs);
    shallowPropagate(subs);
    if (batchDepth == 0) {
      flushEffects();
    }
  }

  JoltDebug.notify(signal);
}

/// Invalidates a custom reactive node so that subscribers re-evaluate without
/// changing the stored value.
///
/// This function marks a custom reactive node as dirty and notifies all its
/// subscribers to re-evaluate. Unlike [notifySignal] and [notifyComputed],
/// this function works with any [ReactiveNode], including [CustomReactiveNode]
/// instances.
///
/// The node is marked as dirty and mutable, and all subscribers are propagated.
/// If not in a batch, effects are flushed immediately.
///
/// Parameters:
/// - [node]: Custom reactive node to invalidate
///
/// Example:
/// ```dart
/// final customNode = CustomWidgetPropsNode<MyWidget>();
/// notifyCustom(customNode); // Triggers subscriber re-evaluation
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void notifyCustom<T>(ReactiveNode node) {
  node.flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

  final subs = node.subs;
  if (subs != null) {
    propagate(subs);
    if (batchDepth == 0) {
      flushEffects();
    }
  }

  JoltDebug.notify(node);
}

@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void getCustom(ReactiveNode node) {
  var sub = activeSub;
  while (sub != null) {
    if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
      link(node, sub, cycle);

      break;
    }
    sub = sub.subs?.sub;
  }

  JoltDebug.get(node);
}

/// Disposes any reactive node and detaches all dependencies/subscribers.
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
  JoltDebug.dispose(e);

  e
    ..depsTail = null
    ..flags = ReactiveFlags.none;
  purgeDeps(e);
  final sub = e.subs;
  if (sub != null) {
    unlink(sub);
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
  final sub = _DummyEffectNode(flags: ReactiveFlags.watching);
  final prevSub = setActiveSub(sub);
  try {
    return fn();
  } finally {
    activeSub = prevSub;
    var link = sub.deps;
    while (link != null) {
      final dep = link.dep;
      link = unlink(link, sub);
      final subs = dep.subs;
      if (subs != null) {
        sub.flags = ReactiveFlags.none;
        propagate(subs);
        shallowPropagate(subs);
      }
    }
    if (batchDepth == 0) {
      flushEffects();
    }
  }
}

/// Interface for readable reactive values.
///
/// Provides read-only access to reactive values with both tracked and
/// untracked access patterns.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// Readable<int> readonly = count.readonly();
/// print(readonly.value); // Tracked access
/// print(readonly.peek); // Untracked access
/// ```
abstract interface class Readable<T> {
  /// Gets the current value and establishes a reactive dependency.
  ///
  /// When accessed within a reactive context (Effect, Computed, etc.),
  /// the context will be notified when this value changes.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubled = Computed(() => count.value * 2);
  /// ```
  T get value;

  /// Gets the current value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity.
  ///
  /// Returns: The current value
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final value = count.peek; // Doesn't create dependency
  /// ```
  T get peek;
}

/// Interface for reactive values that can be manually notified.
///
/// Allows triggering change notifications without modifying the value.
/// Useful for in-place mutations or when you want to force subscribers
/// to re-evaluate.
///
/// Example:
/// ```dart
/// final list = ListSignal([1, 2, 3]);
/// list.value.add(4); // Mutation doesn't auto-notify
/// list.notify(); // Manually trigger notification
/// ```
abstract interface class Notifiable {
  /// Triggers a change notification without modifying the value.
  ///
  /// Notifies all subscribers that they should re-evaluate, even if
  /// the underlying value hasn't changed (e.g., in-place mutations).
  ///
  /// Example:
  /// ```dart
  /// final list = ListSignal([1, 2, 3]);
  /// list.value.add(4);
  /// list.notify(); // Force subscribers to update
  /// ```
  void notify();
}

/// Interface for writable reactive values.
///
/// Extends [Readable] to provide write access, allowing values to be
/// both read and modified reactively.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// count.value = 42; // Can modify
/// print(count.value); // Can read
/// ```
abstract interface class Writable<T> implements Readable<T> {
  /// Sets a new value and notifies subscribers if changed.
  ///
  /// Automatically notifies all subscribers when the value changes.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// count.value = 10; // Notifies subscribers
  /// ```
  set value(T value);
}

/// Base reactive node for computed values.
///
/// Stores the getter used to produce the value along with the pending result
/// collected during recomputation.
///
/// Example:
/// ```dart
/// class CustomComputedNode<T> extends ComputedReactiveNode<T> {
///   CustomComputedNode(super.getter) : super(flags: ReactiveFlags.none);
/// }
/// ```
abstract class ComputedReactiveNode<T> extends ReactiveNode {
  ComputedReactiveNode(
    this.getter, {
    required super.flags,
    this.pendingValue,
    this.equals,
  });
  T? pendingValue;
  final T Function() getter;
  final EqualFn? equals;

  /// {@template jolt_computed_get_peek}
  /// Returns the pending value of the currently executing computed node.
  ///
  /// This static method can only be called from within a computed getter function.
  /// It returns the pending value (the value being computed) of the current computed
  /// node. This is useful for advanced scenarios where you need to access the
  /// previous or current pending value during computation, such as when implementing
  /// custom equality checks or mutations.
  ///
  /// **Important:** This method will throw a [StateError] if called outside of
  /// a computed getter context.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(0);
  /// final computed = Computed(() {
  ///   signal.value;
  ///   final previous = Computed.getPeek<List<int>?>();
  ///   // Use previous value for comparison or mutation
  ///   return List.generate(3, (index) => index);
  /// }, equals: equalList);
  /// ```
  /// {@endtemplate}
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  static T? getPeek<T>() {
    if (activeSub is! ComputedReactiveNode) {
      throw (StateError('Cannot get peek from non-computed node'));
    }
    return (activeSub as ComputedReactiveNode).pendingValue as T?;
  }
}

/// Base reactive node for writable signals.
///
/// Keeps both the pending value (what was recently assigned) and the cached
/// value (what subscribers currently observe).
///
/// Example:
/// ```dart
/// class CustomSignalNode<T> extends SignalReactiveNode<T> {
///   CustomSignalNode(super.initial) : super(flags: ReactiveFlags.mutable);
/// }
/// ```
abstract class SignalReactiveNode<T> extends ReactiveNode {
  SignalReactiveNode({required super.flags, this.pendingValue});

  T? pendingValue;
  late T? cachedValue = pendingValue;
}

/// Base class for custom reactive nodes with custom update logic.
///
/// This class allows you to create reactive nodes that have custom update
/// behavior beyond the standard signal and computed patterns. When a
/// [CustomReactiveNode] is updated via [updateCustom], the system
/// calls [updateNode] to determine if the node's value has actually changed.
///
/// ## Implementing CustomReactiveNode
///
/// Subclasses must implement [updateNode] to define how the node updates
/// and whether its value has changed. The method should:
/// - Update the node's internal state if needed
/// - Return `true` if the value changed (subscribers will be notified)
/// - Return `false` if the value did not change (no notifications)
///
/// Example:
/// ```dart
/// class CustomWidgetPropsNode<T> extends CustomReactiveNode<T> {
///   CustomWidgetPropsNode() : super(flags: ReactiveFlags.mutable);
///
///   bool _dirty = false;
///
///   @override
///   void notify() {
///     _dirty = true;
///     notifyReactiveNode(this);
///   }
///
///   @override
///   bool updateNode() {
///     if (_dirty) {
///       _dirty = false;
///       return true; // Value changed, notify subscribers
///     }
///     return false; // No change
///   }
/// }
/// ```
abstract class CustomReactiveNode<T> extends ReactiveNode {
  CustomReactiveNode({required super.flags});

  /// Updates the node and reports whether its value changed.
  ///
  /// This method is called by [updateCustom] when the reactive system
  /// needs to update this node. Implementations should:
  /// - Update any internal state or cached values
  /// - Return `true` if the node's value has changed (subscribers will be notified)
  /// - Return `false` if the value is unchanged (no notifications will be sent)
  ///
  /// The return value determines whether subscribers are notified of changes.
  /// If `true` is returned, the reactive system will propagate updates to
  /// all subscribers of this node.
  ///
  /// Returns: `true` if the value changed, `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool updateNode() {
  ///   final oldValue = _cachedValue;
  ///   _cachedValue = _computeNewValue();
  ///   return oldValue != _cachedValue;
  /// }
  /// ```
  @protected
  bool updateNode();
}

/// Shared contract for effect-like nodes that can be disposed.
///
/// Example:
/// ```dart
/// void disposeEffect(EffectBaseReactiveNode node) => node.dispose();
/// ```
abstract interface class EffectBaseReactiveNode
    implements ReactiveNode, Disposable {}

class _DummyEffectNode extends ReactiveNode implements EffectReactiveNode {
  _DummyEffectNode({required super.flags});

  // never called
  // coverage:ignore-start
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void dispose() {
    disposeNode(this);
  }

  // never called
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  void runEffect() {
    defaultRunEffect(this, () {});
  }
  // coverage:ignore-end
}

/// Interface for effects that provide custom scheduling behavior.
///
/// Effects implementing this interface can customize how they are scheduled
/// when their dependencies change, instead of being queued for immediate execution.
///
/// Example:
/// ```dart
/// class CustomScheduledEffect extends EffectReactiveNode implements EffectScheduler {
///   @override
///   bool schedule() {
///     // Custom scheduling logic
///     return true; // Custom scheduling handled
///   }
/// }
/// ```
abstract interface class EffectScheduler {
  /// Schedules this effect for execution using a custom scheduling strategy.
  ///
  /// This method is called by the reactive system when the effect's dependencies
  /// change. If this method returns `true`, the effect will not be added to the
  /// default execution queue. If it returns `false`, the default scheduling
  /// behavior will be used.
  ///
  /// Returns: `true` if custom scheduling was handled, `false` to use default scheduling
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool schedule() {
  ///   // Schedule for next frame
  ///   scheduleForNextFrame();
  ///   return true; // Custom scheduling handled
  /// }
  /// ```
  bool schedule();
}

/// Reactive node that runs a side-effect callback when triggered.
///
/// Example:
/// ```dart
/// class CustomEffectNode extends EffectReactiveNode {
///   CustomEffectNode() : super(flags: ReactiveFlags.watching);
///
///   @override
///   @protected
///   void runEffect() {
///     defaultRunEffect(this, _effectFn);
///   }
///
///   void _effectFn() {
///     // Effect logic here
///   }
/// }
/// ```
abstract class EffectReactiveNode extends ReactiveNode
    implements Disposable, EffectBaseReactiveNode {
  EffectReactiveNode({required super.flags});

  /// Executes the effect when it is dirty or pending.
  ///
  /// This method is called by the reactive system to run the effect when its
  /// dependencies change. Implementations should use [defaultRunEffect] to
  /// perform the execution in the proper reactive context.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// @protected
  /// void runEffect() {
  ///   defaultRunEffect(this, _effectFn);
  /// }
  /// ```
  @protected
  void runEffect();
}

/// Reactive node that groups multiple effects for scoped disposal.
///
/// Example:
/// ```dart
/// class CustomEffectScope extends EffectScopeReactiveNode {
///   CustomEffectScope() : super(flags: ReactiveFlags.mutable);
/// }
/// ```
abstract class EffectScopeReactiveNode extends ReactiveNode
    implements Disposable, EffectBaseReactiveNode {
  EffectScopeReactiveNode({required super.flags});
}

typedef EqualFn = bool Function(dynamic value, dynamic previous);
