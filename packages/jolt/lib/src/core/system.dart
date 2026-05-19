import 'package:jolt/core.dart';

/// Base node in the reactive dependency graph.
///
/// A reactive node can depend on other nodes through [deps] and can be observed
/// by other nodes through [subs]. Subclasses define how values are updated,
/// cached, or disposed.
abstract class ReactiveNode {
  /// Creates a node with the supplied link state and [flags].
  ///
  /// The optional [deps] and [depsTail] values seed this node's dependency
  /// chain, while [subs] and [subsTail] seed its subscriber chain.
  ReactiveNode({
    required this.flags,
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
  });

  /// First dependency link in the chain.
  Link? deps;

  /// Last dependency link in the chain.
  Link? depsTail;

  /// First subscriber link in the chain.
  Link? subs;

  /// Last subscriber link in the chain.
  Link? subsTail;

  /// Reactive flags for this node.
  int flags;

  /// Called when this node no longer has subscribers.
  ///
  /// Implementations release dependency links or dispose resources that are
  /// only needed while the node is observed.
  void unwatched();

  /// Recomputes or refreshes this node when it is dirty.
  ///
  /// Returns `true` when the observable value changed and shallow propagation
  /// to subscribers may be required.
  bool update();
}

/// Dependency edge between two [ReactiveNode]s.
///
/// Each link connects a dependency node to a subscriber node and participates
/// in doubly linked lists on both sides of the graph.
class Link {
  /// Creates a dependency edge from [dep] to [sub].
  ///
  /// The optional neighboring links splice this edge into the subscriber and
  /// dependency chains on both nodes.
  Link({
    required this.version,
    required ReactiveNode dep,
    required ReactiveNode sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  })  : _dep = WeakReference(dep),
        _sub = WeakReference(sub);

  /// Version number for this link.
  int version;

  final WeakReference<ReactiveNode> _dep;

  final WeakReference<ReactiveNode> _sub;

  /// The dependency node, if it has not been collected.
  ReactiveNode? get dep => _dep.target;

  /// The subscriber node, if it has not been collected.
  ReactiveNode? get sub => _sub.target;

  /// Previous subscriber link.
  Link? prevSub;

  /// Next subscriber link.
  Link? nextSub;

  /// Previous dependency link.
  Link? prevDep;

  /// Next dependency link.
  Link? nextDep;
}

/// Stack node used for iterative graph traversals.
///
/// This lightweight frame type lets the core walk dependency chains without
/// recursive calls.
class Stack<T> {
  /// Creates a stack node that stores [value] and points to [prev].
  Stack({required this.value, this.prev});

  /// The value stored in this stack node.
  T value;

  /// The previous node in the stack.
  Stack<T>? prev;
}

/// Bit flags that describe a [ReactiveNode]'s reactive state.
abstract final class ReactiveFlags {
  /// No flags set - node is inactive.
  static const none = 0;

  /// Node can have dependencies and be updated.
  static const mutable = 1 << 0;

  /// Node is being watched by effects.
  static const watching = 1 << 1;

  /// Node is being checked for recursion.
  static const recursedCheck = 1 << 2;

  /// Node is in recursive update.
  static const recursed = 1 << 3;

  /// Node needs to be updated.
  static const dirty = 1 << 4;

  /// Node is pending update.
  static const pending = 1 << 5;

  /// Node owns at least one child effect or effect scope.
  ///
  /// This bit is used by the Jolt layer to preserve nested effect cleanup
  /// ordering. Core propagation checks mask specific bits, so this flag can
  /// travel alongside the core flags without changing propagation decisions.
  static const hasChildEffect = 1 << 6;
}

/// Registers [dep] as a dependency of [sub] for [version].
///
/// Existing links are reused when possible, and stale collected links are
/// removed while the subscriber and dependency chains are rewired.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void link(ReactiveNode dep, ReactiveNode sub, int version) {
  var prevDep = sub.depsTail;
  while (prevDep != null && prevDep.dep == null) {
    final prev = prevDep.prevDep;
    unlink(prevDep, sub);
    prevDep = prev;
  }
  if (prevDep != null && identical(prevDep.dep, dep)) {
    return;
  }
  var nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
  while (nextDep != null && nextDep.dep == null) {
    nextDep = unlink(nextDep, sub);
  }
  if (nextDep != null && identical(nextDep.dep, dep)) {
    nextDep.version = version;
    sub.depsTail = nextDep;
    return;
  }
  var prevSub = dep.subsTail;
  while (prevSub != null && prevSub.sub == null) {
    unlink(prevSub);
    prevSub = dep.subsTail;
  }
  if (prevSub != null &&
      prevSub.version == version &&
      identical(prevSub.sub, sub)) {
    return;
  }
  final newLink = sub.depsTail = dep.subsTail = Link(
    version: version,
    dep: dep,
    sub: sub,
    prevDep: prevDep,
    nextDep: nextDep,
    prevSub: prevSub,
    nextSub: null,
  );
  if (nextDep != null) {
    nextDep.prevDep = newLink;
  }
  if (prevDep != null) {
    prevDep.nextDep = newLink;
  } else {
    sub.deps = newLink;
  }
  if (prevSub != null) {
    prevSub.nextSub = newLink;
  } else {
    dep.subs = newLink;
  }
  assert(() {
    JoltDevTools.notifyLinkUpdate('link', dep, sub);
    return true;
  }());
}

/// Removes [link] from the dependency graph.
///
/// Returns the next dependency link for [sub]. When [sub] is omitted, this uses
/// the subscriber stored on [link].
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
Link? unlink(Link link, [ReactiveNode? sub]) {
  sub ??= link.sub;

  final dep = link.dep;
  assert(() {
    JoltDevTools.notifyLinkUpdate('unlink', dep, sub);
    return true;
  }());
  final Link(:prevDep, :nextDep, :nextSub, :prevSub) = link;
  if (nextDep != null) {
    nextDep.prevDep = prevDep;
  } else if (sub != null) {
    sub.depsTail = prevDep;
  }
  if (prevDep != null) {
    prevDep.nextDep = nextDep;
  } else if (sub != null) {
    sub.deps = nextDep;
  }
  if (nextSub != null) {
    nextSub.prevSub = prevSub;
  } else if (dep != null) {
    dep.subsTail = prevSub;
  }
  if (prevSub != null) {
    prevSub.nextSub = nextSub;
  } else if (dep != null && (dep.subs = nextSub) == null) {
    dep.unwatched();
  }

  return nextDep;
}

/// Propagates changes through the reactive graph.
///
/// Walks subscriber links starting at [theLink] and marks affected nodes
/// pending. When [innerWrite] is true, writes are treated as occurring
/// during an effect run and subscribers may receive [ReactiveFlags.recursed].
void propagate(Link theLink, bool innerWrite) {
  Link? link = theLink;

  var next = link.nextSub;
  Stack<Link?>? stack;

  top:
  do {
    final sub = link!.sub;
    if (sub == null) {
      final stale = link;
      unlink(stale);
      if ((link = next) != null) {
        next = link!.nextSub;
        continue;
      }
      while (stack != null) {
        link = stack.value;
        stack = stack.prev;
        if (link != null) {
          next = link.nextSub;
          continue top;
        }
      }
      break;
    }
    var flags = sub.flags;

    if (flags &
            (ReactiveFlags.recursedCheck |
                ReactiveFlags.recursed |
                ReactiveFlags.dirty |
                ReactiveFlags.pending) ==
        0) {
      sub.flags = flags | ReactiveFlags.pending;
      if (innerWrite) {
        sub.flags |= ReactiveFlags.recursed;
      }
    } else if (flags & (ReactiveFlags.recursedCheck | ReactiveFlags.recursed) ==
        0) {
      flags = ReactiveFlags.none;
    } else if (flags & (ReactiveFlags.recursedCheck) == 0) {
      sub.flags = (flags & ~ReactiveFlags.recursed) | (ReactiveFlags.pending);
    } else if (flags & (ReactiveFlags.dirty | ReactiveFlags.pending) == 0 &&
        isValidLink(link, sub)) {
      sub.flags = flags | (ReactiveFlags.recursed | ReactiveFlags.pending);

      flags &= ReactiveFlags.mutable;
    } else {
      flags = ReactiveFlags.none;
    }

    if (flags & (ReactiveFlags.watching) != 0) {
      (sub as EffectNode).notifyEffect();
    }

    if (flags & (ReactiveFlags.mutable) != 0) {
      final subSubs = sub.subs;
      if (subSubs != null) {
        final nextSub = (link = subSubs).nextSub;
        if (nextSub != null) {
          stack = Stack(value: next, prev: stack);
          next = nextSub;
        }
        continue;
      }
    }

    if ((link = next) != null) {
      next = link!.nextSub;
      continue;
    }

    while (stack != null) {
      link = stack.value;
      stack = stack.prev;
      if (link != null) {
        next = link.nextSub;
        continue top;
      }
    }

    break;
  } while (true);
}

/// Whether [sub] has a dirty dependency reachable from [theLink].
///
/// Mutable pending dependencies are recomputed as needed while traversing the
/// graph. Returns `true` when [sub] should rerun or recompute.

bool checkDirty(Link theLink, ReactiveNode sub) {
  Link? link = theLink;
  Stack<(Link, ReactiveNode)>? stack;
  var checkDepth = 0;
  var dirty = false;

  top:
  // allow do-while loop
  // ignore: literal_only_boolean_expressions
  do {
    final dep = link!.dep;
    if (dep == null) {
      link = unlink(link, sub);
      if (link != null) {
        continue;
      }
      break;
    }
    final flags = dep.flags;

    if (sub.flags & (ReactiveFlags.dirty) == (ReactiveFlags.dirty)) {
      dirty = true;
    } else if (flags & (ReactiveFlags.mutable | ReactiveFlags.dirty) ==
        (ReactiveFlags.mutable | ReactiveFlags.dirty)) {
      final subs = dep.subs!;
      if (dep.update()) {
        if (subs.nextSub != null) {
          shallowPropagate(subs);
        }
        dirty = true;
      }
    } else if (flags & (ReactiveFlags.mutable | ReactiveFlags.pending) ==
        (ReactiveFlags.mutable | ReactiveFlags.pending)) {
      stack = Stack(value: (link, sub), prev: stack);
      link = dep.deps;
      sub = dep;
      ++checkDepth;
      continue;
    }

    if (!dirty) {
      final nextDep = link.nextDep;
      if (nextDep != null) {
        link = nextDep;
        continue;
      }
    }

    while (checkDepth-- != 0) {
      final frame = stack!.value;
      link = frame.$1;
      final parentSub = frame.$2;
      stack = stack.prev;
      if (dirty) {
        final subs = sub.subs;
        if (sub.update()) {
          assert(subs != null);
          if (subs!.nextSub != null) {
            shallowPropagate(subs);
          }
          sub = parentSub;
          continue;
        }
        dirty = false;
      } else {
        sub.flags &= ~ReactiveFlags.pending;
      }
      sub = parentSub;
      final nextDep = link.nextDep;
      if (nextDep != null) {
        link = nextDep;
        continue top;
      }
    }

    return dirty && sub.flags != ReactiveFlags.none;
  } while (true);

  return dirty && sub.flags != ReactiveFlags.none;
}

/// Marks direct subscribers reachable from [theLink] dirty.
///
/// This does not recurse into deeper subscriber chains. It is typically used
/// after a value has already been recomputed.
void shallowPropagate(Link theLink) {
  Link? link = theLink;
  do {
    final sub = link!.sub;
    if (sub == null) {
      final stale = link;
      link = link.nextSub;
      unlink(stale);
      continue;
    }
    final flags = sub.flags;
    if (flags & (ReactiveFlags.pending | ReactiveFlags.dirty) ==
        (ReactiveFlags.pending)) {
      sub.flags = flags | (ReactiveFlags.dirty);
      if (flags & (ReactiveFlags.watching | ReactiveFlags.recursedCheck) ==
          ReactiveFlags.watching) {
        (sub as EffectNode).notifyEffect();
      }
    }
  } while ((link = link?.nextSub) != null);
}

/// Whether [checkLink] is still present in [sub]'s dependency chain.
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
bool isValidLink(Link checkLink, ReactiveNode sub) {
  var link = sub.depsTail;

  while (link != null) {
    if (link == checkLink) {
      return true;
    }
    link = link.prevDep;
  }
  return false;
}
