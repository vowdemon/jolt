import 'debug.dart';

/// Base class for all reactive nodes in the dependency graph
class ReactiveNode {
  /// Create a reactive node
  ReactiveNode({
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
    required this.flags,
  });
  Link? deps;
  Link? depsTail;
  Link? subs;
  Link? subsTail;
  int flags;
}

/// Link between reactive nodes in the dependency graph
class Link {
  /// Create a link between nodes
  Link({
    required this.version,
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  });

  int version;
  ReactiveNode dep;
  ReactiveNode sub;
  Link? prevSub;
  Link? nextSub;
  Link? prevDep;
  Link? nextDep;
}

/// Stack data structure for managing recursive operations
class Stack<T> {
  /// Create a stack node
  Stack({required this.value, this.prev});

  T value;
  Stack<T>? prev;
}

/// Effect execution flags
class EffectFlags {
  static const queued = 1 << 6;
}

/// Flags for tracking reactive node state
class ReactiveFlags {
  /// 0. No flags set
  static const none = 0;

  /// 1. Node can have dependencies
  static const mutable = 1 << 0;

  /// 2. Node is being watched by effects
  static const watching = 1 << 1;

  /// 4. Node is being checked for recursion
  static const recursedCheck = 1 << 2;

  /// 8. Node is in recursive update
  static const recursed = 1 << 3;

  /// 16. Node needs to be updated
  static const dirty = 1 << 4;

  /// 32. Node is pending update
  static const pending = 1 << 5;
}

/// Abstract reactive system for managing dependency tracking
abstract class ReactiveSystem {
  /// Update a reactive node and return true if changed
  bool update(ReactiveNode sub);

  /// Notify a subscriber that it needs to update
  void notify(ReactiveNode sub);

  /// Handle when a node is no longer being watched33
  void unwatched(ReactiveNode sub);

  /// Link a dependency to a subscriber in the reactive graph
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void link(ReactiveNode dep, ReactiveNode sub, int version) {
    final prevDep = sub.depsTail;
    if (prevDep != null && identical(prevDep.dep, dep)) {
      return;
    }
    final nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
    if (nextDep != null && identical(nextDep.dep, dep)) {
      nextDep.version = version;
      sub.depsTail = nextDep;
      return;
    }
    final prevSub = dep.subsTail;
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
      getJoltDebugFn(dep)?.call(DebugNodeOperationType.linked, dep);
      return true;
    }());
  }

  /// Unlink a dependency from a subscriber
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  Link? unlink(Link link, [ReactiveNode? sub]) {
    sub ??= link.sub;

    final dep = link.dep;
    final prevDep = link.prevDep;
    final nextDep = link.nextDep;
    final nextSub = link.nextSub;
    final prevSub = link.prevSub;
    if (nextDep != null) {
      nextDep.prevDep = prevDep;
    } else {
      sub.depsTail = prevDep;
    }
    if (prevDep != null) {
      prevDep.nextDep = nextDep;
    } else {
      sub.deps = nextDep;
    }
    if (nextSub != null) {
      nextSub.prevSub = prevSub;
    } else {
      dep.subsTail = prevSub;
    }
    if (prevSub != null) {
      prevSub.nextSub = nextSub;
    } else if ((dep.subs = nextSub) == null) {
      unwatched(dep);
    }

    assert(() {
      getJoltDebugFn(dep)?.call(DebugNodeOperationType.unlinked, dep);
      return true;
    }());
    return nextDep;
  }

  /// Propagate changes through the reactive graph
  void propagate(Link theLink) {
    Link? link = theLink;
    Link? next = link.nextSub;
    Stack<Link?>? stack;

    top:
    do {
      final sub = link!.sub;
      int flags = sub.flags;

      if (flags &
              60 /** ReactiveFlags.recursedCheck | ReactiveFlags.recursed | ReactiveFlags.dirty | ReactiveFlags.pending */ ==
          0) {
        sub.flags = flags | 32 /* ReactiveFlags.pending */;
      } else if (flags &
              12 /** ReactiveFlags.recursedCheck | ReactiveFlags.recursed */ ==
          0) {
        flags = 0 /* ReactiveFlags.none */;
      } else if (flags & 4 /** ReactiveFlags.recursedCheck */ == 0) {
        sub.flags = (flags & ~(8 /* ReactiveFlags.recursed */)) |
            32 /* ReactiveFlags.pending */;
      } else if (flags &
                  48 /** ReactiveFlags.dirty | ReactiveFlags.pending */ ==
              0 &&
          isValidLink(link, sub)) {
        sub.flags =
            flags | 40 /* ReactiveFlags.recursed | ReactiveFlags.pending */;
        flags &= 1 /* ReactiveFlags.mutable */;
      } else {
        flags = 0 /* ReactiveFlags.none */;
      }

      if (flags & 2 /** ReactiveFlags.watching */ != 0) {
        notify(sub);
      }

      if (flags & 1 /** ReactiveFlags.mutable */ != 0) {
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

  /// Check if a node is dirty and needs updating
  bool checkDirty(Link theLink, ReactiveNode sub) {
    Link? link = theLink;
    Stack<Link?>? stack;
    int checkDepth = 0;
    bool dirty = false;

    top:
    do {
      final dep = link!.dep;
      final flags = dep.flags;

      if (sub.flags & 16 /** ReactiveFlags.dirty */ == 16) {
        dirty = true;
      } else if (flags &
              17 /** ReactiveFlags.mutable | ReactiveFlags.dirty */ ==
          17) {
        if (update(dep)) {
          final subs = dep.subs!;
          if (subs.nextSub != null) {
            shallowPropagate(subs);
          }
          dirty = true;
        }
      } else if (flags &
              33 /** ReactiveFlags.mutable | ReactiveFlags.pending */ ==
          33) {
        if (link.nextSub != null || link.prevSub != null) {
          stack = Stack(value: link, prev: stack);
        }
        link = dep.deps!;
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
        final firstSub = sub.subs!;
        final hasMultipleSubs = firstSub.nextSub != null;
        if (hasMultipleSubs) {
          link = stack!.value;
          stack = stack.prev;
        } else {
          link = firstSub;
        }
        if (dirty) {
          if (update(sub)) {
            if (hasMultipleSubs) {
              shallowPropagate(firstSub);
            }
            sub = link!.sub;
            continue;
          }
          dirty = false;
        } else {
          sub.flags &= ~32 /* ReactiveFlags.pending */;
        }
        sub = link!.sub;
        final nextDep = link.nextDep;
        if (nextDep != null) {
          link = nextDep;
          continue top;
        }
      }

      return dirty;
    } while (true);
  }

  /// Shallow propagate changes without deep recursion
  void shallowPropagate(Link theLink) {
    Link? link = theLink;
    do {
      final sub = link!.sub;
      final flags = sub.flags;
      if (flags & 48 /** ReactiveFlags.pending | ReactiveFlags.dirty */ ==
          32 /** ReactiveFlags.pending */) {
        sub.flags = flags | 16 /* ReactiveFlags.dirty */;
        if (flags & 2 /** ReactiveFlags.watching */ != 0) {
          notify(sub);
        }
      }
    } while ((link = link.nextSub) != null);
  }

  /// Check if a link is still valid for a subscriber
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  bool isValidLink(Link checkLink, ReactiveNode sub) {
    Link? link = sub.depsTail;

    while (link != null) {
      if (link == checkLink) {
        return true;
      }
      link = link.prevDep;
    }
    return false;
  }
}
