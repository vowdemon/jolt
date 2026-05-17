import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/core/reactive.dart';
import 'package:jolt/src/core/system.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposer;

class SignalNode<T> extends ReactiveNode {
  SignalNode(this.value)
      : pendingValue = value,
        super(flags: ReactiveFlags.mutable);

  T? value;
  T? pendingValue;

  T peek() => pendingValue as T;

  T get() {
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

  T set(T value) {
    if (pendingValue != (pendingValue = value)) {
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

      if (subs != null) {
        propagate(subs!, runDepth > 0);
        if (batchDepth == 0) {
          flushEffects();
        }
      }
    }
    return value;
  }

  bool update() {
    flags &= ReactiveFlags.mutable;

    final oldValue = value;
    return oldValue != (value = pendingValue);
  }

  void notify() {
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

  void dispose() {
    this
      ..depsTail = null
      ..flags = ReactiveFlags.none;

    purgeDeps(this);
    final sub = subs;
    if (sub != null) {
      unlink(sub);
    }
  }

  bool get isDisposed => flags == ReactiveFlags.none;

  @override
  void unwatched() {}
}

class ComputedNode<T> extends ReactiveNode {
  ComputedNode(this.getter, {this.equals}) : super(flags: ReactiveFlags.none);

  final T Function() getter;
  final bool Function(T current, T? previous)? equals;

  T? value;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  T peek() => untracked(get);

  T get() {
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
      } finally {
        activeSub = prevSub;
        flags &= ~ReactiveFlags.recursedCheck;
      }
    }
    final sub = activeSub;
    if (sub != null) {
      link(this, sub, cycle);
    }

    return value as T;
  }

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

      return isNotEqual;
    } finally {
      activeSub = prevSub;
      flags &= ~ReactiveFlags.recursedCheck;
      purgeDeps(this);
    }
  }

  void notify([bool force = true]) {
    final updated = update();

    if (!force && !updated) return;

    var subs = this.subs;

    while (subs != null) {
      subs.sub.flags |= ReactiveFlags.pending;
      shallowPropagate(subs);
      subs = subs.nextSub;
    }

    if (this.subs != null && batchDepth == 0) {
      flushEffects();
    }
  }

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
  }

  @override
  void unwatched() {
    if (depsTail != null) {
      flags = ReactiveFlags.mutable | ReactiveFlags.dirty;
      disposeDepsInReverse(this);
    }
  }
}

mixin CleanableNode {
  final Set<Disposer> _cleanups = {};
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

  void onCleanup(Disposer cleanup) {
    _cleanups.add(cleanup);
  }
}

abstract class BaseEffectNode extends ReactiveNode with CleanableNode {
  BaseEffectNode({required super.flags});

  void dispose() {
    flags = ReactiveFlags.none;
    disposeDepsInReverse(this);

    var sub = subs;
    if (sub != null) {
      unlink(sub);
    }
    cleanup();
    untracked(() => JFinalizer.disposeObject(this));
  }
}

class EffectScopeNode extends BaseEffectNode {
  EffectScopeNode({bool detach = false}) : super(flags: ReactiveFlags.mutable) {
    if (!detach) {
      final prevSub = getActiveSub();
      if (prevSub != null) {
        link(this, prevSub, 0);
        prevSub.flags |= ReactiveFlags.hasChildEffect;
      }
    }
  }

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

  bool get isDisposed => flags == ReactiveFlags.none;

  bool update() {
    flags = ReactiveFlags.mutable;
    return true;
  }

  @override
  void unwatched() {
    dispose();
  }
}

class EffectNode extends BaseEffectNode {
  EffectNode(this.fn, {bool lazy = false, bool detach = false})
      : super(flags: ReactiveFlags.watching | ReactiveFlags.recursedCheck) {
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
          JoltDebug.effect(this);
          return true;
        }());
      }
    }
    setActiveSub(prevSub);
    flags &= ~ReactiveFlags.recursedCheck;
  }

  final void Function() fn;

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
        activeSub = prevSub;
        this.flags &= ~ReactiveFlags.recursedCheck;
        purgeDeps(this);
      }
    } else if (deps != null) {
      this.flags =
          ReactiveFlags.watching | (flags & ReactiveFlags.hasChildEffect);
    }
  }

  bool get isDisposed => flags == ReactiveFlags.none;

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

  @override
  void unwatched() {
    dispose();
  }
}
