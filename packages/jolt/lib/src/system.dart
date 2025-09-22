import 'utils.dart';

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
  /// No flags set
  static const none = 0;

  /// Node can have dependencies
  static const mutable = 1 << 0;

  /// Node is being watched by effects
  static const watching = 1 << 1;

  /// Node is being checked for recursion
  static const recursedCheck = 1 << 2;

  /// Node is in recursive update
  static const recursed = 1 << 3;

  /// Node needs to be updated
  static const dirty = 1 << 4;

  /// Node is pending update
  static const pending = 1 << 5;
}

/// Abstract reactive system for managing dependency tracking
abstract class ReactiveSystem {
  int currentVersion = 0;

  /// Update a reactive node and return true if changed
  bool update(ReactiveNode sub);

  /// Notify a subscriber that it needs to update
  void notify(ReactiveNode sub);

  /// Handle when a node is no longer being watched
  void unwatched(ReactiveNode sub);

  /// Link a dependency to a subscriber in the reactive graph
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void link(ReactiveNode dep, ReactiveNode sub) {
    final prevDep = sub.depsTail;
    if (prevDep != null && prevDep.dep == dep) {
      return;
    }
    final nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
    if (nextDep != null && nextDep.dep == dep) {
      nextDep.version = currentVersion;
      sub.depsTail = nextDep;
      return;
    }
    final prevSub = dep.subsTail;
    if (prevSub != null &&
        prevSub.version == currentVersion &&
        prevSub.sub == sub) {
      return;
    }
    final newLink = sub.depsTail = dep.subsTail = Link(
      version: currentVersion,
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

      if (flags.notHasAny(
        ReactiveFlags.recursedCheck |
            ReactiveFlags.recursed |
            ReactiveFlags.dirty |
            ReactiveFlags.pending,
      )) {
        sub.flags = flags | ReactiveFlags.pending;
      } else if (flags.notHasAny(
        ReactiveFlags.recursedCheck | ReactiveFlags.recursed,
      )) {
        flags = ReactiveFlags.none;
      } else if (flags.notHasAny(ReactiveFlags.recursedCheck)) {
        sub.flags = (flags & ~(ReactiveFlags.recursed)) | ReactiveFlags.pending;
      } else if (flags.notHasAny(ReactiveFlags.dirty | ReactiveFlags.pending) &&
          isValidLink(link, sub)) {
        sub.flags = flags | ReactiveFlags.recursed | ReactiveFlags.pending;
        flags &= ReactiveFlags.mutable;
      } else {
        flags = ReactiveFlags.none;
      }

      if (flags.hasAny(ReactiveFlags.watching)) {
        notify(sub);
      }

      if (flags.hasAny(ReactiveFlags.mutable)) {
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

  /// Start tracking dependencies for a subscriber
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void startTracking(ReactiveNode sub) {
    ++currentVersion;
    sub.depsTail = null;
    sub.flags = (sub.flags &
            ~(ReactiveFlags.recursed |
                ReactiveFlags.dirty |
                ReactiveFlags.pending)) |
        ReactiveFlags.recursedCheck;
  }

  /// End tracking dependencies and clean up unused links
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void endTracking(ReactiveNode sub) {
    final depsTail = sub.depsTail;
    var toRemove = depsTail != null ? depsTail.nextDep : sub.deps;
    while (toRemove != null) {
      toRemove = unlink(toRemove, sub);
    }
    sub.flags &= ~ReactiveFlags.recursedCheck;
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

      if (sub.flags.hasAny(ReactiveFlags.dirty)) {
        dirty = true;
      } else if (flags.hasAll(ReactiveFlags.mutable | ReactiveFlags.dirty)) {
        if (update(dep)) {
          final subs = dep.subs!;
          if (subs.nextSub != null) {
            shallowPropagate(subs);
          }
          dirty = true;
        }
      } else if (flags.hasAll(ReactiveFlags.mutable | ReactiveFlags.pending)) {
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
          sub.flags &= ~(ReactiveFlags.pending);
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
      if (flags.hasAny(ReactiveFlags.pending) &&
          flags.notHasAny(ReactiveFlags.dirty)) {
        sub.flags = flags | ReactiveFlags.dirty;
        if (flags.hasAny(ReactiveFlags.watching)) {
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
