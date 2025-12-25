import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import 'package:shared_interfaces/shared_interfaces.dart';

part 'widget.dart';
part 'hooks.dart';
part 'stateful_mixin.dart';

/// The core context that manages hooks and reactive state for setup-based widgets.
///
/// This context extends [EffectScopeImpl] to provide automatic cleanup of
/// reactive nodes when the widget is disposed. It manages the complete hook
/// lifecycle including creation, update, and hot reload support.
///
/// ## Design
///
/// [JoltSetupContext] is intentionally decoupled from both [Element] and [State],
/// making it reusable across different widget implementations:
/// - [SetupWidgetElement] uses it for [SetupWidget]
/// - [SetupMixin] uses it for [StatefulWidget]
///
/// While the external API (setup function signature) remains consistent across
/// implementations, the internal build trigger mechanisms differ to leverage
/// the specific advantages of Element ([markNeedsBuild]) vs State ([setState]).
///
/// ## Responsibilities
///
/// - Manages hook registration and lifecycle ([_useHook], [unmountHooks])
/// - Handles hot reload with hook sequence matching ([_reload])
/// - Provides reactive scope for setup functions ([run])
/// - Stores the widget builder and renderer effect
/// - Notifies hooks of lifecycle events ([notifyUpdate], [notifyDependenciesChanged], etc.)
///
/// ## Hot Reload
///
/// During hot reload, hooks are matched by runtime type and position:
/// 1. Matching hooks preserve their state and receive [SetupHook.reassemble]
/// 2. Mismatched hooks are unmounted and replaced with new instances
/// 3. New hooks receive [SetupHook.mount] after setup completes
class JoltSetupContext<T extends Widget> extends EffectScopeImpl {
  JoltSetupContext(this.context, this.propsNode) : super(detach: true);

  final BuildContext context;
  final Props<T> propsNode;

  /// The setup function that returns the widget builder.
  WidgetFunction<T>? setupBuilder;

  /// The effect that triggers widget rebuilds when reactive dependencies change.
  FlutterEffect? renderer;

  /// The list of hooks registered for this widget.
  final List<SetupHook> _hooks = [];

  // coverage:ignore-start
  /// Temporary list used during hot reload to build the new hook sequence.
  final List<SetupHook> _newHooks = [];

  /// Set of hooks that were newly created during hot reload.
  /// These hooks will have their [SetupHook.mount] method called.
  final Set<SetupHook> _newlyCreatedHooks = {};

  /// Current position in the hook sequence during hot reload.
  late int _currentHookIndex = 0;

  /// Whether the widget is currently in hot reload mode.
  late bool _isReassembling = false;
  // coverage:ignore-end

  // coverage:ignore-start
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void _resetHookIndex() {
    assert(() {
      _currentHookIndex = 0;
      _newHooks.clear();
      _newlyCreatedHooks.clear();
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
          hook.reassemble();
        }
      }

      _newlyCreatedHooks.clear();

      return true;
    }());
  }
  // coverage:ignore-end

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

  // coverage:ignore-start
  /// Notifies all hooks that the widget has been activated.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void notifyActivate() {
    for (var hook in _hooks) {
      hook.activate();
    }
  }
  // coverage:ignore-end

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

  @override
  void onDispose() {
    _hooks.clear();

    assert(() {
      _newHooks.clear();
      _newlyCreatedHooks.clear();
      _currentHookIndex = 0;
      return true;
    }());

    renderer?.dispose();
    renderer = null;

    super.onDispose();
  }

  /* -------------------------------- Static -------------------------------- */

  static JoltSetupContext? current;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static JoltSetupContext? setActiveContext([JoltSetupContext? context]) {
    final prev = current;
    current = context;
    return prev;
  }
}

/// A reactive node that tracks widget property changes.
///
/// This node allows reactive code (like [useComputed] or [useEffect]) to depend
/// on widget properties. When the widget is updated with new properties, this
/// node notifies all its subscribers to re-run.
///
/// ## Usage
///
/// The node's [value] returns the current widget instance, providing reactive
/// access to all widget properties.
///
/// ### With SetupWidget
/// ```dart
/// class UserCard extends SetupWidget<UserCard> {
///   final String name;
///   final int age;
///
///   const UserCard({super.key, required this.name, required this.age});
///
///   @override
///   setup(context, props) {
///     // Access props reactively - rebuilds when name changes
///     final displayName = useComputed(() => 'User: ${props().name}');
///
///     return () => Text(displayName.value);
///   }
/// }
/// ```
///
/// ### With SetupMixin
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with SetupMixin<MyWidget> {
///   @override
///   setup(context) {
///     // Access props via mixin's getter
///     final displayName = useComputed(() => 'User: ${props.name}');
///
///     return () => Text(displayName.value);
///   }
/// }
/// ```
///
/// ## Implementation Notes
///
/// - Implements [ReadonlySignal] for compatibility with Jolt's reactive system
/// - Tracks dependencies automatically when accessed in reactive contexts
/// - Disposed when the associated [BuildContext] is unmounted
class Props<T extends Widget> extends ReadonlySignalImpl<T> {
  Props(this._context) : super(null);

  final BuildContext _context;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  T get value {
    getCustom(this);
    return _context.widget as T;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  T get peek => _context.widget as T;

  @override
  bool get isDisposed => !_context.mounted;

  T call() {
    return value;
  }

  @override
  void onDispose() {
    disposeNode(this);
  }
}
