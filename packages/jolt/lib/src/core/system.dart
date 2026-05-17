import 'package:jolt/core.dart';

/// Base class for all reactive nodes in the dependency graph.
///
/// ReactiveNode represents a node in the reactive dependency graph that can
/// have dependencies (values it reads from) and subscribers (effects that
/// depend on it). This is the foundation of Jolt's reactive system.
///
/// Example:
/// ```dart
/// final node = ReactiveNode(flags: ReactiveFlags.mutable);
/// node.flags |= ReactiveFlags.dirty;
/// ```
abstract class ReactiveNode {
  /// Creates a reactive node with the given configuration.
  ///
  /// Parameters:
  /// - [deps]: First dependency link
  /// - [depsTail]: Last dependency link
  /// - [subs]: First subscriber link
  /// - [subsTail]: Last subscriber link
  /// - [flags]: Reactive flags for this node
  ///
  /// Example:
  /// ```dart
  /// final node = ReactiveNode(flags: ReactiveFlags.mutable);
  /// ```
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

  void unwatched();
}

/// Link between reactive nodes in the dependency graph.
///
/// Link represents a connection between a dependency node and a subscriber node
/// in the reactive graph. It maintains bidirectional links for efficient
/// traversal and cleanup.
///
/// Example:
/// ```dart
/// final depNode = ReactiveNode(flags: ReactiveFlags.mutable);
/// final subNode = ReactiveNode(flags: ReactiveFlags.watching);
/// final link = Link(version: cycle, dep: depNode, sub: subNode);
/// depNode.subs = link;
/// ```
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
  ///
  /// Example:
  /// ```dart
  /// final depNode = ReactiveNode(flags: ReactiveFlags.mutable);
  /// final subNode = ReactiveNode(flags: ReactiveFlags.watching);
  /// final link = Link(version: 1, dep: depNode, sub: subNode);
  /// ```
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

/// Stack data structure for managing recursive operations.
///
/// Stack is used internally by the reactive system to manage recursive
/// traversal of the dependency graph during updates.
///
/// Example:
/// ```dart
/// final link = Link(version: 0, dep: ReactiveNode(flags: 0), sub: ReactiveNode(flags: 0));
/// var stack = Stack(value: link);
/// stack = Stack(value: link.nextSub, prev: stack);
/// ```
class Stack<T> {
  /// Creates a stack node with the given value and previous node.
  ///
  /// Parameters:
  /// - [value]: The value stored in this stack node
  /// - [prev]: The previous node in the stack
  ///
  /// Example:
  /// ```dart
  /// final node = Stack(value: 1);
  /// ```
  Stack({required this.value, this.prev});

  /// The value stored in this stack node.
  T value;

  /// The previous node in the stack.
  Stack<T>? prev;
}

/// Flags for tracking reactive node state.
///
/// These flags are used internally by the reactive system to track the
/// state and lifecycle of reactive nodes during dependency tracking
/// and update propagation.
///
/// Example:
/// ```dart
/// final node = ReactiveNode(flags: ReactiveFlags.mutable);
/// node.flags |= ReactiveFlags.pending;
/// ```
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
///
/// Example:
/// ```dart
/// final depNode = CustomSignalNode<int>(0);
/// final effectNode = CustomEffectNode();
/// link(depNode, effectNode, cycle);
/// ```
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
}

/// Unlinks a dependency from a subscriber.
///
/// Parameters:
/// - [link]: The link to unlink
/// - [sub]: Optional subscriber node
///
/// Returns: The next dependency link, or null if none
///
/// Example:
/// ```dart
/// final link = dep.subs!;
/// final next = unlink(link);
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
Link? unlink(Link link, [ReactiveNode? sub]) {
  sub ??= link.sub;

  final dep = link.dep;
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
/// Parameters:
/// - [theLink]: The link to start propagation from
///
/// Example:
/// ```dart
/// final signalNode = CustomSignalNode<int>(0);
/// propagate(signalNode.subs!, false);
/// ```
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

/// Checks if a node is dirty and needs updating.
///
/// Parameters:
/// - [theLink]: The link to check
/// - [sub]: The subscriber node
///
/// Returns: true if the node is dirty and needs updating
///
/// Example:
/// ```dart
/// final effectNode = CustomEffectNode();
/// final dirty = checkDirty(effectNode.deps!, effectNode);
/// ```

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
      if (updateNode(dep)) {
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
        if (updateNode(sub)) {
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

/// Shallow propagates changes without deep recursion.
///
/// Parameters:
/// - [theLink]: The link to start shallow propagation from
///
/// Example:
/// ```dart
/// final signalNode = CustomSignalNode<int>(0);
/// shallowPropagate(signalNode.subs!);
/// ```
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

/// Checks if a link is still valid for a subscriber.
///
/// Parameters:
/// - [checkLink]: The link to check
/// - [sub]: The subscriber node
///
/// Returns: true if the link is still valid
///
/// Example:
/// ```dart
/// final effectNode = CustomEffectNode();
/// final link = effectNode.depsTail!;
/// final stillValid = isValidLink(link, effectNode);
/// ```
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
