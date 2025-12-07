part of 'framework.dart';

enum _LifeCycleHookType {
  mounted,
  unmounted,
  didUpdateWidget,
  didChangeDependencies,
  activated,
  deactivated,
}

abstract class _LifeCycleHook extends SetupHook<_LifeCycleHookType> {
  _LifeCycleHook(this.callback);

  final void Function() callback;

  _LifeCycleHookType get hookType;

  @override
  _LifeCycleHookType build() => hookType;
}

class _OnMountedHook extends _LifeCycleHook {
  _OnMountedHook(super.callback);

  @override
  _LifeCycleHookType get hookType => _LifeCycleHookType.mounted;

  @override
  void mount() {
    callback();
  }
}

/// Registers a callback to run when the widget is mounted.
///
/// This is called after the widget is fully initialized and added to the tree.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onMounted(() {
///     print('Widget mounted!');
///   });
///
///   return () => Text('Hello');
/// }
/// ```
void onMounted(void Function() callback) {
  useHook(_OnMountedHook(callback));
}

class _OnUnmountedHook extends _LifeCycleHook {
  _OnUnmountedHook(super.callback);

  @override
  _LifeCycleHookType get hookType => _LifeCycleHookType.unmounted;

  @override
  void unmount() {
    callback();
  }
}

/// Registers a callback to run when the widget is unmounted.
///
/// This is called when the widget is being removed from the tree permanently.
/// Use this for cleanup operations.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onUnmounted(() {
///     print('Cleaning up resources');
///   });
///
///   return () => Text('Hello');
/// }
/// ```
void onUnmounted(void Function() callback) {
  useHook(_OnUnmountedHook(callback));
}

class _OnDidUpdateWidgetHook extends _LifeCycleHook {
  _OnDidUpdateWidgetHook(super.callback);

  @override
  _LifeCycleHookType get hookType => _LifeCycleHookType.didUpdateWidget;

  @override
  void didUpdateWidget() {
    callback();
  }
}

/// Registers a callback to run when the widget is updated with new properties.
///
/// This is called whenever the parent widget rebuilds and provides new
/// properties to this widget.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onDidUpdateWidget(() {
///     print('Widget updated with new props');
///   });
///
///   return () => Text('Hello');
/// }
/// ```
void onDidUpdateWidget(void Function() callback) {
  useHook(_OnDidUpdateWidgetHook(callback));
}

class _OnDidChangeDependenciesHook extends _LifeCycleHook {
  _OnDidChangeDependenciesHook(super.callback);

  @override
  _LifeCycleHookType get hookType => _LifeCycleHookType.didChangeDependencies;

  @override
  void didChangeDependencies() {
    callback();
  }
}

/// Registers a callback to run when the widget's dependencies change.
///
/// This is called when an InheritedWidget that this widget depends on changes.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onDidChangeDependencies(() {
///     print('Dependencies changed');
///   });
///
///   return () => Text('Hello');
/// }
/// ```
void onDidChangeDependencies(void Function() callback) {
  useHook(_OnDidChangeDependenciesHook(callback));
}

class _OnActivatedHook extends _LifeCycleHook {
  _OnActivatedHook(super.callback);

  @override
  _LifeCycleHookType get hookType => _LifeCycleHookType.activated;

  // coverage:ignore-start
  @override
  void activate() {
    callback();
  }
  // coverage:ignore-end
}

/// Registers a callback to run when the widget is reactivated.
///
/// This is called when a deactivated widget is reinserted into the tree.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onActivated(() {
///     print('Widget reactivated');
///   });
///
///   return () => Text('Hello');
/// }
/// ```
void onActivated(void Function() callback) {
  useHook(_OnActivatedHook(callback));
}

class _OnDeactivatedHook extends _LifeCycleHook {
  _OnDeactivatedHook(super.callback);

  @override
  _LifeCycleHookType get hookType => _LifeCycleHookType.deactivated;

  // coverage:ignore-start
  @override
  void deactivate() {
    callback();
  }
  // coverage:ignore-end
}

/// Registers a callback to run when the widget is deactivated.
///
/// This is called when the widget is removed from the tree but may be
/// reinserted later.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onDeactivated(() {
///     print('Widget deactivated');
///   });
///
///   return () => Text('Hello');
/// }
/// ```
void onDeactivated(void Function() callback) {
  useHook(_OnDeactivatedHook(callback));
}

/// Gets the current BuildContext from the SetupWidget.
///
/// This can only be called within the [SetupWidget.setup] function or within
/// hooks that are called from setup.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   final context = useContext();
///   final theme = Theme.of(context);
///
///   return () => Container(color: theme.primaryColor);
/// }
/// ```
BuildContext useContext() {
  final currentContext = JoltSetupContext.current?.context;
  assert(currentContext != null, 'SetupWidgetElement is not exsits');

  return currentContext!;
}

/// Gets the current JoltSetupContext.
///
/// This provides access to the underlying setup context, which manages hooks
/// and reactive effects for the widget. This is primarily used for advanced
/// use cases.
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   final setupContext = useSetupContext();
///
///   // Register cleanup when the scope is disposed
///   onScopeDispose(() => print('Scope disposed'));
///
///   return () => Text('Hello');
/// }
/// ```
JoltSetupContext useSetupContext() {
  final currentContext = JoltSetupContext.current;
  assert(currentContext != null, 'SetupWidgetElement is not exsits');

  return currentContext!;
}

// /// Returns a reactive reference to the widget instance.
// ///
// /// See [HookUtils.useWidgetProps] for details.
// final useWidgetProps = HookUtils.useWidgetProps;

/// Creates a hook that persists across rebuilds and hot reloads.
///
/// Hooks are matched during hot reload by their runtime type and position in
/// the sequence. If the hook sequence changes:
/// - Matching hooks are reused and [SetupHook.reassemble] is called
/// - Mismatched hooks trigger unmount of all subsequent hooks
/// - New hooks are created and [SetupHook.mount] is called
///
/// Example:
/// ```dart
/// class CounterHook extends SetupHook<int> {
///   @override
///   int build() => 0;
///
///   @override
///   void mount() {
///     print('Hook mounted');
///   }
///
///   @override
///   void unmount() {
///     print('Hook unmounted');
///   }
/// }
///
/// // In setup:
/// final counter = useHook(CounterHook());
/// ```
T useHook<T>(SetupHook<T> hook) => JoltSetupContext.current!._useHook(hook);

/// Base class for all setup hooks.
///
/// Hooks provide a way to encapsulate reusable stateful logic in SetupWidget.
/// Each hook has a lifecycle that mirrors the widget lifecycle.
///
/// ## Lifecycle Methods
///
/// - [build]: Called once to create the initial state (on first use)
/// - [mount]: Called after the hook is created and added to the widget
/// - [unmount]: Called when the hook is being removed (on dispose or hot reload mismatch)
/// - [didUpdateWidget]: Called when the widget is updated with new properties
/// - [didChangeDependencies]: Called when the widget's dependencies change
/// - [activate]: Called when the widget is reactivated (e.g., after being in a navigator stack)
/// - [deactivate]: Called when the widget is deactivated
/// - [reassemble]: Called during hot reload when the hook is reused
///
/// ## Hot Reload Behavior
///
/// During hot reload, hooks are matched by their runtime type and position:
/// - If the hook type at position N matches, the hook is reused and [reassemble] is called
/// - If there's a type mismatch, this and all subsequent hooks are unmounted
/// - New or replacement hooks have [mount] called
///
/// Example:
/// ```dart
/// class TimerHook extends SetupHook<Timer> {
///   @override
///   Timer build() => Timer.periodic(Duration(seconds: 1), (_) {});
///
///   @override
///   void mount() {
///     print('Timer started');
///   }
///
///   @override
///   void unmount() {
///     state.cancel();
///     print('Timer cancelled');
///   }
///
///   @override
///   void reassemble() {
///     print('Hot reload - timer preserved');
///   }
/// }
/// ```
abstract class SetupHook<T> {
  SetupHook()
      : assert(JoltSetupContext.current != null, 'Setup context is not exists'),
        _context = JoltSetupContext.current!.context;

  late final BuildContext _context;

  /// The BuildContext of the widget that owns this hook.
  BuildContext get context => _context;

  T? _state;

  /// The current state value of this hook.
  T get state => _state as T;

  /// Builds the initial state for this hook.
  ///
  /// Called once when the hook is first created. The returned value becomes
  /// the [state] of this hook.
  T build();

  // coverage:ignore-start

  /// Called after the hook is created and added to the widget.
  ///
  /// This is called after [build] for new hooks, or after hot reload for
  /// hooks that were newly created due to type mismatches.
  ///
  /// Use this to set up resources, subscriptions, or perform initialization.
  void mount() {}

  /// Called when the hook is being removed.
  ///
  /// This happens when:
  /// - The widget is being disposed
  /// - During hot reload when there's a type mismatch
  ///
  /// Use this to clean up resources, cancel subscriptions, etc.
  void unmount() {}

  /// Called when the parent widget is updated with new properties.
  void didUpdateWidget() {}

  /// Called during hot reload when this hook is reused.
  ///
  /// This is called instead of [mount] for hooks that matched during
  /// hot reload sequence matching.
  void reassemble() {}

  /// Called when the widget's InheritedWidget dependencies change.
  void didChangeDependencies() {}

  /// Called when the widget is reactivated.
  void activate() {}

  /// Called when the widget is deactivated.
  void deactivate() {}
  // coverage:ignore-end
}

extension<T> on SetupHook<T> {
  T firstBuild() {
    _state = build();
    return state;
  }
}

/// Creates a stream hook from a reactive node.
// Stream<T> useJoltStream<T>(ReadonlyNode<T> node, {JoltDebugFn? onDebug}) {
//   return useHook(AutoDisposeHook(() => node.stream));
// }

/// A hook implementation that manages disposable Jolt reactive nodes.
///
/// This hook automatically disposes the reactive node when the widget is unmounted
/// or when the hook is removed during hot reload.
///
/// This is used internally by all Jolt hook functions (useSignal, useComputed, etc.)
/// to ensure proper lifecycle management.
class AutoDisposeHook<T extends Disposable> extends SetupHook<T> {
  AutoDisposeHook(this.creator);

  /// Function that creates the reactive node.
  final T Function() creator;

  @override
  T build() => creator();

  @override
  void unmount() {
    state.dispose();
  }
}

/// Creates a hook that automatically disposes a disposable resource.
///
/// This is a convenience function for creating hooks that manage Jolt reactive
/// nodes (Signal, Computed, Effect, etc.). The resource will be automatically
/// disposed when the widget is unmounted or during hot reload.
///
/// Example:
/// ```dart
/// setup(context, props) {
///   final signal = useAutoDispose(() => Signal(0));
///   final computed = useAutoDispose(() => Computed(() => signal.value * 2));
///
///   return () => Text('${computed.value}');
/// }
/// ```
T useAutoDispose<T extends Disposable>(T Function() creator) {
  return useHook(AutoDisposeHook(creator));
}

/// A hook that memoizes a value and optionally calls a disposer on unmount.
class DisposableHook<T> extends SetupHook<T> {
  final T Function() creator;
  final void Function(T state)? disposer;

  DisposableHook(this.creator, [this.disposer]);

  @override
  T build() => creator();

  @override
  void unmount() {
    disposer?.call(state);
  }
}

/// Memoizes a value and optionally calls a disposer when unmounted.
///
/// Similar to [useMemoized], but allows you to provide a custom disposer function
/// that will be called when the widget is unmounted or during hot reload.
///
/// Example:
/// ```dart
/// setup(context, props) {
///   final controller = useMemoized(
///     () => TextEditingController(text: 'Hello'),
///     () => controller.dispose(),
///   );
///
///   return () => TextField(controller: controller);
/// }
/// ```
T useMemoized<T>(T Function() creator, [void Function(T state)? disposer]) {
  return useHook(DisposableHook(creator, disposer));
}

/// A hook that provides reactive access to an [InheritedWidget].
///
/// This hook ensures that when the [InheritedWidget] changes, the widget
/// will rebuild automatically. Use this in [setup] instead of directly
/// calling methods like [Theme.of] to ensure your widget responds to changes.
///
/// ## Why use this?
///
/// When you access an [InheritedWidget] directly in [setup] (e.g., `Theme.of(context)`),
/// the value is captured once and won't update when the inherited widget changes.
/// This hook creates a reactive signal that updates when dependencies change.
///
/// ## Example
///
/// ```dart
/// @override
/// setup(context, props) {
///   // ✅ Correct: Use useInherited to get reactive access
///   final theme = useInherited((context) => Theme.of(context));
///
///   // Now calling theme() returns the latest Theme
///   return () => Text(
///     'Hello',
///     style: theme().textTheme.bodyLarge,
///   );
/// }
/// ```
///
/// ## Comparison
///
/// ```dart
/// // ❌ Wrong: Theme won't update when it changes
/// @override
/// setup(context, props) {
///   final theme = Theme.of(context);
///   return () => Text('Hello', style: theme.textTheme.bodyLarge);
/// }
///
/// // ✅ Correct: Theme updates reactively
/// @override
/// setup(context, props) {
///   final theme = useInherited((context) => Theme.of(context));
///   return () => Text('Hello', style: theme().textTheme.bodyLarge);
/// }
///
/// // ✅ Also correct: Access in builder function
/// @override
/// setup(context, props) {
///   return () {
///     final theme = Theme.of(context);
///     return Text('Hello', style: theme.textTheme.bodyLarge);
///   };
/// }
/// ```
class _UseInheritedHook<T> extends SetupHook<Computed<T>> {
  _UseInheritedHook(this.getter);

  late final Computed<T> _computed;
  final T Function(BuildContext) getter;

  @override
  Computed<T> build() {
    return _computed = Computed(() => getter(context));
  }

  @override
  void didChangeDependencies() {
    _computed.notify();
  }
}

/// Reactively tracks an [InheritedWidget] inside `setup`.
///
/// Provide a `getter` such as `(context) => Theme.of(context)`. The hook calls it
/// with the current [BuildContext], and the returned [Computed] keeps widgets in
/// sync by updating whenever the inherited widget changes.
///
/// Example:
///
/// ```
/// final theme = useInherited((context) => Theme.of(context));
/// return () => Text('Hello', style: theme().textTheme.bodyLarge);
/// ```
///
/// Returns a computed signal that stays in sync with the inherited widget.
Computed<T> useInherited<T>(T Function(BuildContext) getter) {
  return useHook(_UseInheritedHook<T>(getter));
}
