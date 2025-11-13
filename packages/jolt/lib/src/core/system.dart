part of './reactive.dart';

/// Base class for all reactive nodes in the dependency graph.
///
/// ReactiveNode represents a node in the reactive dependency graph that can
/// have dependencies (values it reads from) and subscribers (effects that
/// depend on it). This is the foundation of Jolt's reactive system.
class ReactiveNode {
  /// Creates a reactive node with the given configuration.
  ///
  /// Parameters:
  /// - [deps]: First dependency link
  /// - [depsTail]: Last dependency link
  /// - [subs]: First subscriber link
  /// - [subsTail]: Last subscriber link
  /// - [flags]: Reactive flags for this node
  ReactiveNode({
    this.deps,
    this.depsTail,
    this.subs,
    this.subsTail,
    required this.flags,
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
}

/// Link between reactive nodes in the dependency graph.
///
/// Link represents a connection between a dependency node and a subscriber node
/// in the reactive graph. It maintains bidirectional links for efficient
/// traversal and cleanup.
class Link {
  /// Creates a link between dependency and subscriber nodes.
  ///
  /// Parameters:
  /// - [version]: Version number for this link
  /// - [dep]: The dependency node
  /// - [sub]: The subscriber node
  /// - [prevSub]: Previous subscriber link
  /// - [nextSub]: Next subscriber link
  /// - [prevDep]: Previous dependency link
  /// - [nextDep]: Next dependency link
  Link({
    required this.version,
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  });

  /// Version number for this link.
  int version;

  /// The dependency node.
  ReactiveNode dep;

  /// The subscriber node.
  ReactiveNode sub;

  /// Previous subscriber link.
  Link? prevSub;

  /// Next subscriber link.
  Link? nextSub;

  /// Previous dependency link.
  Link? prevDep;

  /// Next dependency link.
  Link? nextDep;
}

/// Stack data structure for managing recursive operations.
///
/// Stack is used protectedly by the reactive system to manage recursive
/// traversal of the dependency graph during updates.
class Stack<T> {
  /// Creates a stack node with the given value and previous node.
  ///
  /// Parameters:
  /// - [value]: The value stored in this stack node
  /// - [prev]: The previous node in the stack
  Stack({required this.value, this.prev});

  /// The value stored in this stack node.
  T value;

  /// The previous node in the stack.
  Stack<T>? prev;
}

/// Flags for tracking reactive node state.
///
/// These flags are used protectedly by the reactive system to track the
/// state and lifecycle of reactive nodes during dependency tracking
/// and update propagation.
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
}

/// Abstract reactive system for managing dependency tracking.
///
/// ReactiveSystem defines the core interface for managing reactive dependencies,
/// updates, and notifications in the reactive graph.

// /// Updates a reactive node and returns true if changed.
// ///
// /// Parameters:
// /// - [sub]: The reactive node to update
// ///
// /// Returns: true if the node's value changed, false otherwise
// bool update(ReactiveNode sub);

// /// Notifies a subscriber that it needs to update.
// ///
// /// Parameters:
// /// - [sub]: The subscriber node to notify
// void notify(ReactiveNode sub);

// /// Handles when a node is no longer being watched.
// ///
// /// Parameters:
// /// - [sub]: The node that is no longer being watched
// void unwatched(ReactiveNode sub);

/// Links a dependency to a subscriber in the reactive graph.
///
/// Parameters:
/// - [dep]: The dependency node
/// - [sub]: The subscriber node
/// - [version]: Version number for the link
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

  JoltDebug.linked(dep);
}

/// Unlinks a dependency from a subscriber.
///
/// Parameters:
/// - [link]: The link to unlink
/// - [sub]: Optional subscriber node
///
/// Returns: The next dependency link, or null if none
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

  JoltDebug.unlinked(dep);
  return nextDep;
}

/// Propagates changes through the reactive graph.
///
/// Parameters:
/// - [theLink]: The link to start propagation from

void propagate(Link theLink) {
  Link? link = theLink;
  Link? next = link.nextSub;
  Stack<Link?>? stack;

  top:
  do {
    final sub = link!.sub;
    int flags = sub.flags;

    if (flags &
            (ReactiveFlags.recursedCheck |
                ReactiveFlags.recursed |
                ReactiveFlags.dirty |
                ReactiveFlags.pending) ==
        0) {
      sub.flags = flags | ReactiveFlags.pending;
    } else if (flags & (ReactiveFlags.recursedCheck | ReactiveFlags.recursed) ==
        0) {
      flags = (ReactiveFlags.none);
    } else if (flags & (ReactiveFlags.recursedCheck) == 0) {
      sub.flags = (flags & ~(ReactiveFlags.recursed)) | (ReactiveFlags.pending);
    } else if (flags & (ReactiveFlags.dirty | ReactiveFlags.pending) == 0 &&
        isValidLink(link, sub)) {
      sub.flags = flags | (ReactiveFlags.recursed | ReactiveFlags.pending);
      flags &= (ReactiveFlags.mutable);
    } else {
      flags = (ReactiveFlags.none);
    }

    if (flags & (ReactiveFlags.watching) != 0) {
      notifyEffect(sub);
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

/// Checks if a node is dirty and needs updating.
///
/// Parameters:
/// - [theLink]: The link to check
/// - [sub]: The subscriber node
///
/// Returns: true if the node is dirty and needs updating

bool checkDirty(Link theLink, ReactiveNode sub) {
  Link? link = theLink;
  Stack<Link?>? stack;
  int checkDepth = 0;
  bool dirty = false;

  top:
  do {
    final dep = link!.dep;
    final flags = dep.flags;

    if (sub.flags & (ReactiveFlags.dirty) == (ReactiveFlags.dirty)) {
      dirty = true;
    } else if (flags & (ReactiveFlags.mutable | ReactiveFlags.dirty) ==
        (ReactiveFlags.mutable | ReactiveFlags.dirty)) {
      if (updateNode(dep)) {
        final subs = dep.subs!;
        if (subs.nextSub != null) {
          shallowPropagate(subs);
        }
        dirty = true;
      }
    } else if (flags & (ReactiveFlags.mutable | ReactiveFlags.pending) ==
        (ReactiveFlags.mutable | ReactiveFlags.pending)) {
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
        if (updateNode(sub)) {
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

/// Shallow propagates changes without deep recursion.
///
/// Parameters:
/// - [theLink]: The link to start shallow propagation from

void shallowPropagate(Link theLink) {
  Link? link = theLink;
  do {
    final sub = link!.sub;
    final flags = sub.flags;
    if (flags & (ReactiveFlags.pending | ReactiveFlags.dirty) ==
        (ReactiveFlags.pending)) {
      sub.flags = flags | (ReactiveFlags.dirty);
      if (flags & (ReactiveFlags.watching | ReactiveFlags.recursedCheck) ==
          ReactiveFlags.watching) {
        notifyEffect(sub);
      }
    }
  } while ((link = link.nextSub) != null);
}

/// Checks if a link is still valid for a subscriber.
///
/// Parameters:
/// - [checkLink]: The link to check
/// - [sub]: The subscriber node
///
/// Returns: true if the link is still valid
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
