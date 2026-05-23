import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:meta/meta.dart';

import '../hooks/hooks.dart';

part 'widget.dart';
part 'hooks.dart';
part 'stateful_mixin.dart';

/// The runtime context that owns a setup widget's hooks and reactive scope.
///
/// [SetupContext] stores the current [BuildContext], reactive [Props], the
/// builder returned from `setup`, and the hooks registered during that run.
/// It also drives hot-reload hook reconciliation and setup-level resets.
///
/// Most applications interact with this type indirectly through [useContext],
/// [useSetupContext], [SetupWidgetElement], or [SetupMixin]. It becomes useful
/// directly when writing custom hooks, debugging setup lifecycles, or
/// implementing advanced reset behavior.
class SetupContext<T extends Widget> extends EffectScopeImpl {
  /// Creates a setup runtime for [context] and [propsNode].
  SetupContext(
    this.context,
    this.propsNode, {
    required void Function() resetSetupFn,
  })  : _resetSetupFn = resetSetupFn,
        super(detach: true, debug: JoltDebugOption.type('SetupContext<$T>'));

  /// The build context that owns this setup runtime.
  final BuildContext context;

  /// Reactive access to the current widget instance.
  final Props<T> propsNode;

  /// Callback function to reset and re-run the setup function.
  final void Function() _resetSetupFn;

  /// Whether resetSetup has been scheduled for the current frame.
  bool _isResetSetupScheduled = false;

  /// The most recent builder returned from `setup`.
  WidgetFunction<T>? setupBuilder;

  /// The effect that schedules rebuilds for the current setup builder.
  FlutterEffect? renderer;

  /// The list of hooks registered for this widget.
  final List<SetupHook> _hooks = [];

  /// Temporary list used during hot reload to build the new hook sequence.
  late final List<SetupHook> _newHooks = [];

  /// Set of hooks that were newly created during hot reload.
  /// These hooks will have their [SetupHook.mount] method called.
  late final Set<SetupHook> _newlyCreatedHooks = {};

  /// Maps reused hooks to their new configurations during hot reload.
  late final Map<SetupHook, SetupHook> _newHookConfigs = {};

  /// Current position in the hook sequence during hot reload.
  late int _currentHookIndex = 0;

  /// Whether the widget is currently in hot reload mode.
  late bool _isReassembling = false;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void _resetHookIndex() {
    assert(() {
      _currentHookIndex = 0;
      _newHooks.clear();
      _newlyCreatedHooks.clear();
      _newHookConfigs.clear();
      return true;
    }());
  }

  /// Registers and manages a hook in the setup context.
  ///
  /// During normal operation, hooks are simply added to the list and initialized.
  ///
  /// During hot reload, hooks are matched sequentially by their runtime type:
  /// - If the current hook type matches the old hook at the same position,
  ///   the old hook is reused and its state is preserved
  /// - If a type mismatch occurs, all remaining old hooks from that position
  ///   onwards are unmounted in reverse order
  /// - New hooks are created and marked for mounting
  ///
  /// This ensures that hook state is preserved when possible while safely
  /// handling changes to the hook sequence during development.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  U _useHook<U>(SetupHook<U> hook) {
    U? hookState;
    SetupHook<U>? existingHook;

    assert(() {
      if (_isReassembling && _currentHookIndex < _hooks.length) {
        final oldHook = _hooks[_currentHookIndex];

        if (oldHook.runtimeType == hook.runtimeType) {
          existingHook = oldHook as SetupHook<U>;
          hookState = existingHook!.state;
          _newHooks.add(existingHook!);
          _newHookConfigs[existingHook!] = hook;
          _currentHookIndex++;
          return true;
        } else {
          for (int i = _hooks.length - 1; i >= _currentHookIndex; i--) {
            _hooks[i].unmount();
          }
          _hooks.removeRange(_currentHookIndex, _hooks.length);
        }
      }

      hookState = hook.firstBuild();
      _newHooks.add(hook);
      _newlyCreatedHooks.add(hook);
      _currentHookIndex++;
      return true;
    }());

    final result = hookState ?? hook.firstBuild();
    final hookToAdd = existingHook ?? hook;

    if (!_isReassembling) {
      _hooks.add(hookToAdd);
    }

    return result;
  }

  /// Cleans up unused hooks after hot reload completes.
  ///
  /// This method:
  /// 1. Unmounts any remaining old hooks that weren't matched
  /// 2. Replaces the hook list with the new sequence
  /// 3. Calls [SetupHook.mount] on newly created hooks
  /// 4. Calls [SetupHook.reassemble] on reused hooks
  void _cleanupUnusedHooks() {
    assert(() {
      if (!_isReassembling) return true;

      if (_currentHookIndex < _hooks.length) {
        for (int i = _hooks.length - 1; i >= _currentHookIndex; i--) {
          _hooks[i].unmount();
        }
        _hooks.removeRange(_currentHookIndex, _hooks.length);
      }

      _hooks.clear();
      _hooks.addAll(_newHooks);
      _newHooks.clear();

      for (var hook in _hooks) {
        if (_newlyCreatedHooks.contains(hook)) {
          hook.mount();
        } else {
          final newHook = _newHookConfigs[hook];
          assert(newHook != null, 'Reused hook must have a new configuration');
          hook.reassemble(newHook!);
        }
      }

      _newlyCreatedHooks.clear();
      _newHookConfigs.clear();

      return true;
    }());
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  U run<U>(U Function() fn) {
    final prevContext = setActiveContext(this);
    try {
      return super.run(fn);
    } finally {
      setActiveContext(prevContext);
    }
  }

  /* -------------------------- Lifecycle Hooks -------------------------- */

  /// Notifies props node and all hooks that the widget has been updated.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notifyUpdate<U extends Object>(U oldWidget, U newWidget) {
    propsNode.notify();
    for (var hook in _hooks) {
      hook.didUpdateWidget(oldWidget, newWidget);
    }
  }

  /// Notifies all hooks that dependencies have changed.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notifyDependenciesChanged() {
    for (var hook in _hooks) {
      hook.didChangeDependencies();
    }
  }

  /// Notifies all hooks that the widget has been activated.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notifyActivate() {
    for (var hook in _hooks) {
      hook.activate();
    }
  }

  /// Notifies all hooks that the widget has been deactivated.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notifyDeactivate() {
    for (var hook in _hooks.reversed) {
      hook.deactivate();
    }
  }

  /// Unmounts all hooks in reverse order.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void unmountHooks() {
    for (var hook in _hooks.reversed) {
      hook.unmount();
    }
  }

  /// Schedules a setup reset at the end of the current frame.
  ///
  /// Multiple calls in the same frame coalesce into one reset. When the
  /// callback runs, the current hooks and renderer are torn down and `setup`
  /// runs again to produce a fresh hook sequence.
  void scheduleResetSetup() {
    // If already scheduled for this frame, skip
    if (_isResetSetupScheduled) {
      return;
    }

    // Mark as scheduled
    _isResetSetupScheduled = true;

    // Schedule for end of frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isResetSetupScheduled = false;
      if (!isDisposed) {
        _resetSetupFn();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _hooks.clear();

    assert(() {
      _newHooks.clear();
      _newlyCreatedHooks.clear();
      _newHookConfigs.clear();
      _currentHookIndex = 0;
      return true;
    }());

    renderer?.dispose();
    renderer = null;
    _isResetSetupScheduled = false;
  }

  /* -------------------------------- Static -------------------------------- */

  /// The setup runtime that is currently executing hook code.
  static SetupContext? current;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')

  /// Makes [context] current and returns the previous active runtime.
  static SetupContext? setActiveContext([SetupContext? context]) {
    final prev = current;
    current = context;
    return prev;
  }
}

class _PropsImpl<T extends Widget> extends ReactiveNode
    implements Props<T>, Readonly<T> {
  _PropsImpl(this._context) : super(flags: ReactiveFlags.mutable);

  final BuildContext _context;

  @override
  bool get isDisposed => flags == ReactiveFlags.none;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  T get value {
    if (isDisposed) return peek;
    var sub = getActiveSub();
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(this, sub, getCycle());

        break;
      }
      sub = sub.subs?.sub;
    }

    return _context.widget as T;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  T get peek => _context.widget as T;

  @override
  T call() {
    return value;
  }

  @override
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

  @override
  void notify() {
    flags = ReactiveFlags.mutable | ReactiveFlags.dirty;

    if (subs != null) {
      propagate(subs!, getRunDepth() > 0);
      shallowPropagate(subs!);
      if (getBatchDepth() == 0) {
        flushEffects();
      }
    }
  }

  @override
  bool update() => true;

  @override
  void unwatched() {}

  @override
  set value(T value) {
    throw UnsupportedError('Props is a readonly signal');
  }
}

/// Reactive access to a widget instance inside `setup`.
///
/// Reading [value] or calling [call] inside reactive code tracks the current
/// widget as a dependency, so computed values and effects are refreshed when
/// the parent rebuilds with a new widget instance.
///
/// This is the object passed as `props` to [SetupWidget.setup]. It lets setup
/// code derive reactive state from widget fields without manually wiring update
/// callbacks.
abstract class Props<T extends Widget> implements Signal<T> {
  /// Returns the current widget instance and tracks it as a dependency.
  T call();
}
