import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/src/shared.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

part 'hooks.dart';

/// A widget that uses a composition-based API similar to Vue's Composition API.
///
/// The [setup] function executes only once when the widget is first created,
/// not on every rebuild. This provides better performance and a more predictable
/// execution model compared to React-style hooks.
///
/// ## Hot Reload Behavior
///
/// During hot reload, hooks are matched in order by their runtime type:
/// - If types match in sequence, existing hooks are reused and [SetupHook.reassemble] is called
/// - If a type mismatch occurs, all subsequent hooks are unmounted in reverse order
/// - New or replacement hooks will have [SetupHook.mount] called
///
/// This ensures hooks maintain correct state during development while
/// adapting to code changes.
///
/// Example:
/// ```dart
/// class CounterWidget extends SetupWidget {
///   const CounterWidget({super.key});
///
///   @override
///   setup(context, props) {
///     final count = useSignal(0);
///
///     return () => Column(
///       children: [
///         Text('Count: ${count.value}'),
///         ElevatedButton(
///           onPressed: () => count.value++,
///           child: Text('Increment'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
abstract class SetupWidget<T extends SetupWidget<T>> extends Widget {
  /// Creates a SetupWidget.
  const SetupWidget({super.key});

  /// The setup function that runs once when the widget is created.
  ///
  /// This function should return a [SetupFunction] that will be called on
  /// each rebuild. Use hooks like [useSignal], [useComputed], etc. to manage
  /// reactive state within this function.
  ///
  /// Hooks are cached and reused across hot reloads based on their runtime type
  /// and position in the sequence. If the hook sequence changes during hot reload,
  /// mismatched hooks will be unmounted and recreated.
  ///
  /// Parameters:
  /// - [context]: The setup build context providing access to widget props
  /// - [props]: A reactive node that tracks widget property changes
  ///
  /// Returns: A widget builder function that runs on each reactive rebuild
  SetupFunction<T> setup(
      SetupBuildContext<T> context, PropsReadonlyNode<T> props);

  @override
  SetupWidgetElement<T> createElement() => SetupWidgetElement<T>(this);
}

/// The build context for SetupWidget that provides access to widget properties.
///
/// This interface extends [BuildContext] and adds a reactive [props] getter
/// that allows tracking widget property changes within the reactive system.
abstract interface class SetupBuildContext<T extends SetupWidget<T>>
    implements BuildContext {
  /// The current widget instance.
  ///
  /// Accessing this property within a reactive context (like [useComputed] or
  /// [useEffect]) will establish a dependency on widget updates.
  T get props;
}

/// The Element that manages the lifecycle of a SetupWidget.
///
/// This element is responsible for:
/// - Running the setup function once on creation
/// - Managing hook lifecycle (mount, unmount, reassemble)
/// - Handling hot reload with hook sequence matching
/// - Propagating widget updates to hooks
/// - Managing the reactive effect that triggers rebuilds
class SetupWidgetElement<T extends SetupWidget<T>> extends ComponentElement
    with JoltCommonEffectBuilder
    implements SetupBuildContext<T> {
  SetupWidgetElement(SetupWidget<T> super.widget);

  /// The setup context that manages hooks and reactive state.
  late final JoltSetupContext<T> setupContext = JoltSetupContext(this);

  @override
  T get widget => super.widget as T;

  /// The reactive node that tracks widget property changes.
  late final _propsNode = PropsReadonlyNode<T>(this);

  @override
  T get props => _propsNode.value;

  // coverage:ignore-start
  @override
  void reassemble() {
    super.reassemble();
    assert(() {
      setupContext._isReassembling = true;
      return true;
    }());
  }

  void _reload() {
    assert(() {
      setupContext.renderer?.dispose();

      setupContext._hooks.clear();

      setupContext.run(() {
        setupContext._resetHookIndex();

        setupContext.setupBuilder = widget.setup(this, _propsNode);
        setupContext.renderer =
            Effect(joltBuildTriggerEffect, immediately: false);

        setupContext._cleanupUnusedHooks();
      });

      setupContext._isReassembling = false;
      return true;
    }());
  }
  // coverage:ignore-end

  bool _isFirstBuild = true;
  @override
  void performRebuild() {
    if (!_isFirstBuild) {
      super.performRebuild();
    } else {
      _firstBuild();
      _isFirstBuild = false;
      super.performRebuild();
    }
  }

  void _firstBuild() {
    setupContext.run(() {
      setupContext._resetHookIndex();
      setupContext.setupBuilder = widget.setup(this, _propsNode);
      setupContext.renderer =
          Effect(joltBuildTriggerEffect, immediately: false);
      for (var hook in setupContext._hooks) {
        hook.mount();
      }
    });
  }

  @override
  void unmount() {
    for (var hook in setupContext._hooks.reversed) {
      hook.unmount();
    }

    super.unmount();

    _propsNode.dispose();
    setupContext.dispose();
  }

  @override
  void update(SetupWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _propsNode.notify();
    for (var hook in setupContext._hooks) {
      hook.didUpdateWidget();
    }

    rebuild(force: true);
  }

  @override
  void didChangeDependencies() {
    for (var hook in setupContext._hooks) {
      hook.didChangeDependencies();
    }

    super.didChangeDependencies();
  }

  // coverage:ignore-start
  @override
  void activate() {
    super.activate();
    for (var hook in setupContext._hooks) {
      hook.activated();
    }
  }
  // coverage:ignore-end

  @override
  void deactivate() {
    for (var hook in setupContext._hooks.reversed) {
      hook.deactivated();
    }

    super.deactivate();
  }

  @override
  Widget build() {
    // coverage:ignore-start
    assert(() {
      if (setupContext._isReassembling) {
        _reload();
        setupContext._isReassembling = false;
      }
      return true;
    }());
    // coverage:ignore-end

    return setupContext.run(() => trackWithEffect(
        () => setupContext.setupBuilder!(), setupContext.renderer!));
  }
}

/// The setup context that manages hooks and reactive state for a SetupWidget.
///
/// This context extends [EffectScopeImpl] to provide automatic cleanup of
/// reactive nodes when the widget is disposed. It also manages the hook
/// lifecycle including hot reload support.
class JoltSetupContext<T extends SetupWidget<T>> extends EffectScopeImpl {
  JoltSetupContext(this.element) : super(detach: true);

  final SetupWidgetElement element;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  SetupBuildContext<T> get context => element as SetupBuildContext<T>;

  /// The setup function that returns the widget builder.
  SetupFunction<T>? setupBuilder;

  /// The effect that triggers widget rebuilds when reactive dependencies change.
  Effect? renderer;

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

/// A convenience widget that uses a builder function for setup.
///
/// This is the simplest way to use SetupWidget without creating a custom class.
/// Use this for quick prototyping or simple components.
///
/// For complex widgets with properties, it's recommended to create a proper
/// SetupWidget subclass instead.
///
/// Example:
/// ```dart
/// SetupBuilder(
///   setup: (context) {
///     final count = useSignal(0);
///
///     return () => Column(
///       children: [
///         Text('Count: ${count.value}'),
///         ElevatedButton(
///           onPressed: () => count.value++,
///           child: Text('Increment'),
///         ),
///       ],
///     );
///   },
/// )
/// ```
class SetupBuilder extends SetupWidget<SetupBuilder> {
  /// Creates a SetupBuilder.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [setup]: The setup function that returns a widget builder
  const SetupBuilder({
    super.key,
    required SetupFunctionBuilder<SetupBuilder> setup,
  }) : _setup = setup;

  final SetupFunctionBuilder<SetupBuilder> _setup;

  @override
  setup(context, props) => _setup(context);
}

/// A function type that creates a setup function from a BuildContext.
///
/// This is used by [SetupBuilder] to provide the setup function in a more
/// convenient inline format.
///
/// Parameters:
/// - [context]: The setup build context
///
/// Returns: A [SetupFunction] that builds the widget on each reactive update
typedef SetupFunctionBuilder<T extends SetupWidget<T>> = SetupFunction<T>
    Function(SetupBuildContext<T> context);

/// A function type that builds a widget.
///
/// This is the return type of the [SetupWidget.setup] method. The returned
/// builder function is called on each rebuild triggered by reactive dependencies,
/// while the setup function itself runs only once during widget creation.
///
/// The function takes no parameters and returns a Widget. All reactive state
/// should be captured from the setup closure.
typedef SetupFunction<T> = Widget Function();

/// A reactive node that tracks widget property changes.
///
/// This node allows reactive code (like [useComputed] or [useEffect]) to depend
/// on widget properties. When the widget is updated with new properties, this
/// node notifies all its subscribers to re-run.
///
/// The node's value is the current widget instance, so you can access any
/// property of the widget reactively.
///
/// Example:
/// ```dart
/// class UserCard extends SetupWidget<UserCard> {
///   final String name;
///   final int age;
///
///   const UserCard({super.key, required this.name, required this.age});
///
///   @override
///   setup(context, props) {
///     // React to name changes
///     final displayName = useComputed(() => 'User: ${props.value.name}');
///
///     return () => Text(displayName.value);
///   }
/// }
/// ```
class PropsReadonlyNode<T extends SetupWidget<T>> extends ReactiveNode
    implements ReadonlyNode<T> {
  PropsReadonlyNode(this._context) : super(flags: ReactiveFlags.mutable);

  final BuildContext _context;

  @override
  T get() {
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(this, sub, cycle);

        break;
      }
      sub = sub.subs?.sub;
    }

    return _context.widget as T;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T call() => get();

  @override
  void notify() {
    notifySignal(this);
  }

  @override
  T get peek => _context.widget as T;

  @override
  T get value => get();

  @override
  FutureOr<void> dispose() {
    disposeNode(this);
  }

  @override
  bool get isDisposed => !_context.mounted;

  // coverage:ignore-start
  @override
  void onDispose() {}
  // coverage:ignore-end
}
