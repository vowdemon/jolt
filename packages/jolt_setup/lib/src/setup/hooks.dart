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
@defineHook
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
@defineHook
void onUnmounted(void Function() callback) {
  useHook(_OnUnmountedHook(callback));
}

/// Hook that registers a callback for widget updates.
///
/// This hook is called when the widget is updated with new properties,
/// providing access to both the old and new widget instances.
class _OnDidUpdateWidgetHook<T> extends SetupHook<_LifeCycleHookType> {
  _OnDidUpdateWidgetHook(this.callback);

  /// Callback function that receives old and new widget instances.
  final void Function(T, T) callback;

  _LifeCycleHookType get hookType => _LifeCycleHookType.didUpdateWidget;

  @override
  _LifeCycleHookType build() => hookType;

  @override
  void didUpdateWidget(covariant T oldWidget, covariant T newWidget) {
    callback(oldWidget, newWidget);
  }
}

/// Registers a callback to run when the widget is updated with new properties.
///
/// This is called whenever the parent widget rebuilds and provides new
/// properties to this widget. The callback receives both the old and new
/// widget instances for comparison.
///
/// Parameters:
/// - [callback]: Function that receives (oldWidget, newWidget) when updated
///
/// Example:
/// ```dart
/// @override
/// setup(context, props) {
///   onDidUpdateWidgetAt<MyWidget>((oldWidget, newWidget) {
///     if (oldWidget.title != newWidget.title) {
///       print('Title changed from ${oldWidget.title} to ${newWidget.title}');
///     }
///   });
///
///   return () => Text('Hello');
/// }
/// ```
@defineHook
void onDidUpdateWidgetAt<T>(void Function(T, T) callback) {
  useHook(_OnDidUpdateWidgetHook(callback));
}

/// Extension for registering widget update callbacks on SetupWidget.
///
/// This extension provides a convenient way to register update callbacks
/// directly on SetupWidget instances. The widget type is automatically
/// inferred from the SetupWidget type parameter.
///
/// Example:
/// ```dart
/// class MyWidget extends SetupWidget<MyWidget> {
///   final String title;
///
///   const MyWidget({super.key, required this.title});
///
///   @override
///   setup(context, props) {
///     onDidUpdateWidget((oldWidget, newWidget) {
///       print('Updated: ${oldWidget.title} -> ${newWidget.title}');
///     });
///
///     return () => Text(props().title);
///   }
/// }
/// ```
extension JoltSetupOnDidUpdateWidget<T extends SetupWidget<T>>
    on SetupWidget<T> {
  /// Registers a callback for widget updates.
  ///
  /// Parameters:
  /// - [callback]: Function that receives (oldWidget, newWidget) when updated
  @defineHook
  void onDidUpdateWidget(void Function(T, T) callback) {
    useHook(_OnDidUpdateWidgetHook(callback));
  }
}

/// Extension for registering widget update callbacks on SetupMixin.
///
/// This extension provides a convenient way to register update callbacks
/// directly on SetupMixin instances. The widget type is automatically
/// inferred from the StatefulWidget type parameter.
///
/// Example:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final String title;
///
///   const MyWidget({super.key, required this.title});
///
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> with SetupMixin<MyWidget> {
///   @override
///   setup(context) {
///     onDidUpdateWidget((oldWidget, newWidget) {
///       print('Updated: ${oldWidget.title} -> ${newWidget.title}');
///     });
///
///     return () => Text(widget.title);
///   }
/// }
/// ```
extension JoltSetupMixinOnDidUpdateWidget<T extends StatefulWidget>
    on SetupMixin<T> {
  /// Registers a callback for widget updates.
  ///
  /// Parameters:
  /// - [callback]: Function that receives (oldWidget, newWidget) when updated
  @defineHook
  void onDidUpdateWidget(void Function(T, T) callback) {
    useHook(_OnDidUpdateWidgetHook(callback));
  }
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
@defineHook
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
@defineHook
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
@defineHook
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
@defineHook
BuildContext useContext() {
  final currentContext = JoltSetupContext.current?.context;
  assert(currentContext != null, 'SetupWidgetElement is not exists');

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
@defineHook
JoltSetupContext useSetupContext() {
  final currentContext = JoltSetupContext.current;
  assert(currentContext != null, 'SetupWidgetElement is not exists');

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
@defineHook
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

  @protected
  T? rawState;

  /// The current state value of this hook.
  T get state => rawState as T;

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
  void didUpdateWidget(dynamic oldWidget, dynamic newWidget) {}

  /// Called during hot reload when this hook is reused.
  ///
  /// This is called instead of [mount] for hooks that matched during
  /// hot reload sequence matching.
  ///
  /// The [newHook] parameter contains the new hook instance with updated
  /// configuration from the hot-reloaded code. You can compare it with
  /// the current hook configuration and update state if needed.
  ///
  /// Example:
  /// ```dart
  /// class TimerHook extends SetupHook<Timer> {
  ///   TimerHook(this.duration);
  ///   final Duration duration;
  ///
  ///   @override
  ///   Timer build() => Timer.periodic(duration, (_) {});
  ///
  ///   @override
  ///   void reassemble(covariant TimerHook newHook) {
  ///     if (newHook.duration != duration) {
  ///       state.cancel();
  ///       _state = Timer.periodic(newHook.duration, (_) {});
  ///     }
  ///   }
  ///
  ///   @override
  ///   void unmount() => state.cancel();
  /// }
  /// ```
  void reassemble(SetupHook newHook) {}

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
    rawState = build();
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
@defineHook
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
@defineHook
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
@defineHook
Computed<T> useInherited<T>(T Function(BuildContext) getter) {
  return useHook(_UseInheritedHook<T>(getter));
}

/// {@template jolt_reset_hook_creator}
/// Helper class for creating reset setup hooks in SetupWidget.
///
/// This class provides methods to reset and re-run the setup function
/// programmatically, similar to hot reload but triggered at runtime.
/// Use [useReset] to access these methods.
/// {@endtemplate}
final class JoltResetHookCreator {
  /// Helper class for creating reset setup hooks in SetupWidget.
  const JoltResetHookCreator._();

  /// Gets a reference to the resetSetup function.
  ///
  /// This hook returns a function that can be called to reset and re-run
  /// the setup function at runtime, similar to hot reload but triggered
  /// programmatically.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   final reset = useReset();
  ///
  ///   // Later, call reset to reset the entire setup
  ///   onMounted(() {
  ///     if (shouldReset) {
  ///       reset();
  ///     }
  ///   });
  ///
  ///   return () => Text('Hello');
  /// }
  /// ```
  @defineHook
  void Function() call() {
    final currentContext = JoltSetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    return currentContext!._resetSetupFn;
  }

  /// Listens to Listenables and calls resetSetup when they notify.
  ///
  /// This hook subscribes to one or more Listenables and automatically calls
  /// resetSetup whenever any of them notifies. This is useful for resetting
  /// the setup when external state changes.
  ///
  /// Parameters:
  /// - [watcher]: A function that returns an iterable of Listenables to subscribe to
  ///
  /// Example:
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   final notifier = ValueNotifier(0);
  ///
  ///   // Reset setup whenever notifier changes
  ///   useReset.listen(() => [notifier]);
  ///
  ///   return () => Text('Count: ${notifier.value}');
  /// }
  /// ```
  @defineHook
  void listen(Iterable<Listenable> Function() watcher) {
    final currentContext = JoltSetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    useHook(_ResetSetupOnListenableHook(
      watcher,
      currentContext!._resetSetupFn,
    ));
  }

  /// Watches reactive signals and calls resetSetup when they change.
  ///
  /// This hook uses an Effect to watch reactive signals. Whenever any
  /// signal accessed within the watch function changes, resetSetup is called.
  ///
  /// Parameters:
  /// - [watchFn]: A function that returns an iterable of Readable signals to watch.
  ///   The effect will track all signals in the returned iterable.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///   final name = useSignal('Alice');
  ///
  ///   // Reset setup whenever count or name changes
  ///   useReset.watch(() => [count, name]);
  ///
  ///   return () => Text('${name.value}: ${count.value}');
  /// }
  /// ```
  @defineHook
  void watch(Iterable<Readable> Function() watchFn) {
    final currentContext = JoltSetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    final resetSetup = currentContext!._resetSetupFn;
    useHook(_ResetSetupWatchHook(watchFn, resetSetup));
  }

  /// Selects a value from reactive state and resets setup when it changes.
  ///
  /// This hook uses an Effect to track a selector function. Whenever the
  /// selected value changes (compared using `!=`), resetSetup is called.
  /// This is useful when you only want to reset when a derived value changes,
  /// not when individual signals change.
  ///
  /// Parameters:
  /// - [selector]: A function that selects a value from reactive state.
  ///   The effect will track all signals accessed within this function.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///   final name = useSignal('Alice');
  ///
  ///   // Reset setup only when the combined string changes
  ///   useReset.select(() => '${name.value}: ${count.value}');
  ///
  ///   return () => Text('${name.value}: ${count.value}');
  /// }
  /// ```
  @defineHook
  void select<T>(T Function() selector) {
    final currentContext = JoltSetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    final resetSetup = currentContext!._resetSetupFn;
    useHook(_ResetSetupSelectHook(selector, resetSetup));
  }
}

/// {@macro jolt_reset_hook_creator}
final useReset = JoltResetHookCreator._();

/// Hook that listens to a Listenable and calls resetSetup when it notifies.
class _ResetSetupOnListenableHook extends SetupHook<Iterable<Listenable>> {
  _ResetSetupOnListenableHook(this.watcher, this.resetSetup);

  late Iterable<Listenable> Function() watcher;
  late void Function() resetSetup;

  void _listener() {
    resetSetup();
  }

  @override
  Iterable<Listenable> build() {
    final listenables = watcher();
    for (final listenable in listenables) {
      listenable.addListener(_listener);
    }
    return listenables;
  }

  @override
  void unmount() {
    for (final listenable in state) {
      listenable.removeListener(_listener);
    }
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _ResetSetupOnListenableHook newHook) {
    final oldList = state.toList();
    final newList = newHook.watcher().toList();

    bool hasNewListenable = oldList.length != newList.length;
    if (!hasNewListenable) {
      for (int i = 0; i < oldList.length; i++) {
        if (oldList[i] != newList[i]) {
          hasNewListenable = true;
          break;
        }
      }
    }

    if (hasNewListenable) {
      for (final listenable in state) {
        listenable.removeListener(_listener);
      }
      watcher = newHook.watcher;
      for (final listenable in newList) {
        listenable.addListener(_listener);
      }
    }
    resetSetup = newHook.resetSetup;
  }
  // coverage:ignore-end
}

/// Hook that watches reactive signals and calls resetSetup when they change.
class _ResetSetupWatchHook extends SetupHook<FlutterEffect> {
  _ResetSetupWatchHook(this.watchFn, this.resetSetup);

  late Iterable<Readable> Function() watchFn;
  late void Function() resetSetup;

  void _watcher() {
    for (final readable in watchFn()) {
      readable.value;
    }
  }

  @override
  FlutterEffect build() {
    return FlutterEffect(() {
      _watcher();
      resetSetup();
    }, lazy: true);
  }

  @override
  void mount() {
    trackWithEffect(_watcher, state, false);
  }

  @override
  void unmount() {
    state.dispose();
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _ResetSetupWatchHook newHook) {
    if (watchFn != newHook.watchFn) {
      trackWithEffect(_watcher, state, true);
      watchFn = newHook.watchFn;
    }
    resetSetup = newHook.resetSetup;
  }
  // coverage:ignore-end
}

/// Hook that selects a value and calls resetSetup when it changes.
class _ResetSetupSelectHook<T> extends SetupHook<FlutterEffect> {
  _ResetSetupSelectHook(this.selector, this.resetSetup);

  late T Function() selector;
  late void Function() resetSetup;
  T? _prevValue;

  void _select() {
    final currentValue = selector();
    if (_prevValue != null && currentValue != _prevValue) {
      resetSetup();
    }
    _prevValue = currentValue;
  }

  @override
  FlutterEffect build() {
    return FlutterEffect(_select, lazy: true);
  }

  @override
  void mount() {
    // Initialize prevValue on first mount
    _prevValue = selector();
    // Track dependencies for reactive updates
    trackWithEffect(_select, state, false);
  }

  @override
  void unmount() {
    state.dispose();
  }

  // coverage:ignore-start
  @override
  void reassemble(covariant _ResetSetupSelectHook<T> newHook) {
    if (selector != newHook.selector) {
      _prevValue = newHook.selector();
    }
    selector = newHook.selector;
    resetSetup = newHook.resetSetup;
  }
  // coverage:ignore-end
}
