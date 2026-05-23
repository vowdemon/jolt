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

/// Registers [callback] to run after the current setup is mounted.
///
/// Use this for work that should start only after all hooks in the current
/// setup pass have been created and mounted.
///
/// ```dart
/// setup(context, props) {
///   final controller = useScrollController();
///
///   onMounted(() {
///     controller.jumpTo(0);
///   });
///
///   return () => ListView(controller: controller);
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

/// Registers [callback] to run when the current setup unmounts.
///
/// Use this for cleanup that is local to the setup scope.
///
/// ```dart
/// setup(context, props) {
///   final socket = connectSomeSocket();
///
///   onUnmounted(socket.close);
///
///   return () => const SizedBox.shrink();
/// }
/// ```
@defineHook
void onUnmounted(void Function() callback) {
  useHook(_OnUnmountedHook(callback));
}

class _OnDidUpdateWidgetHook<T> extends SetupHook<_LifeCycleHookType> {
  _OnDidUpdateWidgetHook(this.callback);

  final void Function(T, T) callback;

  _LifeCycleHookType get hookType => _LifeCycleHookType.didUpdateWidget;

  @override
  _LifeCycleHookType build() => hookType;

  @override
  void didUpdateWidget(covariant T oldWidget, covariant T newWidget) {
    callback(oldWidget, newWidget);
  }
}

/// Registers [callback] for parent-driven widget updates.
///
/// The callback receives the previous widget instance and the new one. Use
/// this when a setup resource should react to prop updates without being fully
/// recreated.
///
/// ```dart
/// setup(context, props) {
///   final controller = useTextEditingController(text: props().query);
///
///   onDidUpdateWidget<SearchField>((oldWidget, newWidget) {
///     if (oldWidget.query != newWidget.query) {
///       controller.text = newWidget.query;
///     }
///   });
///
///   return () => TextField(controller: controller);
/// }
/// ```
@defineHook
void onDidUpdateWidget<T>(void Function(T oldWidget, T newWidget) callback) {
  useHook(_OnDidUpdateWidgetHook<T>(callback));
}

/// Adds widget-typed update hooks inside [SetupWidget.setup].
extension JoltSetupOnDidUpdateWidget<T extends SetupWidget<T>>
    on SetupWidget<T> {
  /// Registers [callback] for updates to this widget type.
  ///
  /// ```dart
  /// setup(context, props) {
  ///   onDidUpdateWidget((oldWidget, newWidget) {
  ///     debugPrint('${oldWidget.key} -> ${newWidget.key}');
  ///   });
  ///
  ///   return () => const SizedBox.shrink();
  /// }
  /// ```
  @defineHook
  void onDidUpdateWidget(void Function(T, T) callback) {
    useHook(_OnDidUpdateWidgetHook(callback));
  }
}

/// Adds widget-typed update hooks inside [SetupMixin.setup].
extension JoltSetupMixinOnDidUpdateWidget<T extends StatefulWidget>
    on SetupMixin<T> {
  /// Registers [callback] for updates to this widget type.
  ///
  /// ```dart
  /// setup(context) {
  ///   onDidUpdateWidget((oldWidget, newWidget) {
  ///     debugPrint('${oldWidget.key} -> ${newWidget.key}');
  ///   });
  ///
  ///   return () => const SizedBox.shrink();
  /// }
  /// ```
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

/// Registers [callback] for inherited-dependency changes.
///
/// This mirrors Flutter's `didChangeDependencies` lifecycle and is useful when
/// setup code needs to respond to dependency changes outside normal reactive
/// computation.
///
/// ```dart
/// setup(context, props) {
///   onDidChangeDependencies(() {
///     debugPrint('dependencies changed');
///   });
///
///   return () => const SizedBox.shrink();
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

  @override
  void activate() {
    callback();
  }
}

/// Registers [callback] for reactivation after a prior [onDeactivated] event.
///
/// ```dart
/// setup(context, props) {
///   onActivated(() {
///     debugPrint('active again');
///   });
///
///   return () => const SizedBox.shrink();
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

  @override
  void deactivate() {
    callback();
  }
}

/// Registers [callback] for temporary deactivation.
///
/// ```dart
/// setup(context, props) {
///   onDeactivated(() {
///     debugPrint('temporarily removed');
///   });
///
///   return () => const SizedBox.shrink();
/// }
/// ```
@defineHook
void onDeactivated(void Function() callback) {
  useHook(_OnDeactivatedHook(callback));
}

/// The current [BuildContext] for the active setup runtime.
///
/// This is mainly useful inside reusable hooks that need context access
/// without receiving it as an explicit parameter.
///
/// ```dart
/// setup(context, props) {
///   final localizations = MaterialLocalizations.of(useContext());
///   return () => Text(localizations.okButtonLabel);
/// }
/// ```
@defineHook
BuildContext useContext() {
  final currentContext = SetupContext.current?.context;
  assert(currentContext != null, 'SetupWidgetElement is not exists');

  return currentContext!;
}

/// The active [SetupContext].
///
/// This is mainly useful for advanced hook implementations and setup-boundary
/// control such as resets.
///
/// ```dart
/// setup(context, props) {
///   final setup = useSetupContext();
///
///   return () => Text('${setup.context.widget.runtimeType}');
/// }
/// ```
@defineHook
SetupContext useSetupContext() {
  final currentContext = SetupContext.current;
  assert(currentContext != null, 'SetupWidgetElement is not exists');

  return currentContext!;
}

// /// Returns a reactive reference to the widget instance.
// ///
// /// See [HookUtils.useWidgetProps] for details.
// final useWidgetProps = HookUtils.useWidgetProps;

/// Registers a custom [SetupHook] with the active setup runtime.
///
/// Use this when a reusable hook needs lifecycle methods that cannot be
/// expressed with the simpler helper hooks.
///
/// ```dart
/// final class CounterHook extends SetupHook<int> {
///   @override
///   int build() => 0;
/// }
///
/// setup(context, props) {
///   final count = useHook(CounterHook());
///   return () => Text('$count');
/// }
/// ```
@defineHook
T useHook<T>(SetupHook<T> hook) => SetupContext.current!._useHook(hook);

/// Base class for custom setup hooks.
///
/// A hook builds a state object once, then receives widget lifecycle callbacks
/// such as [mount], [didUpdateWidget], [didChangeDependencies], [activate],
/// [deactivate], [unmount], and [reassemble].
abstract class SetupHook<T> {
  SetupHook()
      : assert(SetupContext.current != null, 'Setup context is not exists'),
        _context = SetupContext.current!.context;

  late final BuildContext _context;

  /// The [BuildContext] that owns this hook.
  BuildContext get context => _context;

  @protected
  T? rawState;

  /// The current state value of this hook.
  T get state => rawState as T;

  /// Builds the initial state for this hook.
  T build();

  /// Called after [build] when this hook is mounted.
  void mount() {}

  /// Called when this hook is removed from the setup runtime.
  void unmount() {}

  /// Called when the parent widget is updated with a new widget instance.
  void didUpdateWidget(dynamic oldWidget, dynamic newWidget) {}

  /// Called during hot reload when this hook instance is reused.
  void reassemble(SetupHook newHook) {}

  /// Called when inherited dependencies change.
  void didChangeDependencies() {}

  /// Called when the owning widget is reactivated.
  void activate() {}

  /// Called when the owning widget is deactivated.
  void deactivate() {}
}

extension<T> on SetupHook<T> {
  T firstBuild() {
    rawState = build();
    return state;
  }
}

/// A hook that disposes its [Disposable] state on unmount.
class AutoDisposeHook<T extends Disposable> extends SetupHook<T> {
  AutoDisposeHook(this.creator);

  /// Creates the disposable state object for this hook.
  final T Function() creator;

  @override
  T build() => creator();

  @override
  void unmount() {
    state.dispose();
  }
}

/// Memoizes a [Disposable] and disposes it when the hook unmounts.
///
/// ```dart
/// setup(context, props) {
///   final scope = useAutoDispose(() => EffectScope());
///   return () => Text('disposed: ${scope.isDisposed}');
/// }
/// ```
@defineHook
T useAutoDispose<T extends Disposable>(T Function() creator) {
  return useHook(AutoDisposeHook(creator));
}

/// A hook that memoizes a value and optionally disposes it on unmount.
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

/// Memoizes a value for the lifetime of the current hook slot.
///
/// If [disposer] is provided, it runs when the hook unmounts.
///
/// ```dart
/// setup(context, props) {
///   final controller = useMemoized(
///     () => TextEditingController(text: props().title),
///     (controller) => controller.dispose(),
///   );
///
///   return () => TextField(controller: controller);
/// }
/// ```
@defineHook
T useMemoized<T>(T Function() creator, [void Function(T state)? disposer]) {
  return useHook(DisposableHook(creator, disposer));
}

class _UseInheritedHook<T> extends SetupHook<Computed<T>> {
  _UseInheritedHook(this.getter, {this.debug});

  late final Computed<T> _computed;
  late T Function(BuildContext) getter;
  late JoltDebugOption? debug;

  T _getter() {
    return getter(context);
  }

  @override
  Computed<T> build() {
    return _computed = Computed(_getter, debug: debug);
  }

  @override
  void didChangeDependencies() {
    _computed.notify();
  }

  @override
  void reassemble(covariant _UseInheritedHook<T> newHook) {
    if (debug != newHook.debug) {
      debug = newHook.debug;
      JoltDevTools.setDebug(
          (_computed as ComputedImpl<T>).raw, newHook.debug?.onDebug);
    }
    getter = newHook.getter;
    _computed.notify();
  }
}

/// Reactively reads an inherited value during `setup`.
///
/// The returned [Computed] is invalidated when inherited dependencies change.
///
/// ```dart
/// setup(context, props) {
///   final theme = useInherited((context) => Theme.of(context));
///
///   return () => Text(
///     'Hello',
///     style: theme.value.textTheme.bodyLarge,
///   );
/// }
/// ```
@defineHook
Computed<T> useInherited<T>(T Function(BuildContext) getter,
    {JoltDebugOption? debug}) {
  return useHook(_UseInheritedHook<T>(getter, debug: debug));
}

/// Setup reset hook factory methods.
final class JoltSetupHookResetCreator {
  /// Creates the reset hook namespace.
  const JoltSetupHookResetCreator._();

  /// Returns a callback that schedules a full setup reset.
  @defineHook
  @experimental
  void Function() call() {
    final currentContext = SetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    return currentContext!._resetSetupFn;
  }

  /// Resets the current setup when any watched [Listenable] notifies.
  @defineHook
  @experimental
  void listen(Iterable<Listenable> Function() watcher) {
    final currentContext = SetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    useHook(_ResetSetupOnListenableHook(
      watcher,
      currentContext!._resetSetupFn,
    ));
  }

  /// Resets the current setup when any watched [Readable] changes.
  @defineHook
  @experimental
  void watch(Iterable<Readable> Function() watchFn) {
    final currentContext = SetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    final resetSetup = currentContext!._resetSetupFn;
    useHook(_ResetSetupWatchHook(watchFn, resetSetup));
  }

  /// Resets the current setup when [selector] changes value.
  @defineHook
  @experimental
  void select<T>(T Function() selector) {
    final currentContext = SetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exists');

    final resetSetup = currentContext!._resetSetupFn;
    useHook(_ResetSetupSelectHook(selector, resetSetup));
  }
}

/// Experimental API that tears down the current setup boundary and reruns `setup`.
///
/// Prefer ordinary reactive updates unless the initialization boundary itself
/// must be recreated.
///
/// ```dart
/// setup(context, props) {
///   final reset = useSetupReset();
///
///   return () => FilledButton(
///     onPressed: reset,
///     child: const Text('Reset setup'),
///   );
/// }
/// ```
@experimental
final useSetupReset = JoltSetupHookResetCreator._();

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
      rawState = newList;
      for (final listenable in newList) {
        listenable.addListener(_listener);
      }
    }
    watcher = newHook.watcher;
    resetSetup = newHook.resetSetup;
  }
}

class _ResetSetupWatchHook extends SetupHook<PostFrameEffect> {
  _ResetSetupWatchHook(this.watchFn, this.resetSetup);

  late Iterable<Readable> Function() watchFn;
  late void Function() resetSetup;

  void _watcher() {
    for (final readable in watchFn()) {
      readable.value;
    }
  }

  @override
  PostFrameEffect build() {
    return PostFrameEffect(() {
      _watcher();
      resetSetup();
    }, lazy: true);
  }

  @override
  void mount() {
    (state as EffectImpl).track(_watcher, false);
  }

  @override
  void unmount() {
    state.dispose();
  }

  @override
  void reassemble(covariant _ResetSetupWatchHook newHook) {
    watchFn = newHook.watchFn;
    resetSetup = newHook.resetSetup;
    (state as EffectImpl).track(_watcher, true);
  }
}

class _ResetSetupSelectHook<T> extends SetupHook<PostFrameEffect> {
  _ResetSetupSelectHook(this.selector, this.resetSetup);

  late T Function() selector;
  late void Function() resetSetup;
  T? _prevValue;
  bool _hasPrevValue = false;

  void _select() {
    final currentValue = selector();
    if (_hasPrevValue && currentValue != _prevValue) {
      resetSetup();
    }
    _prevValue = currentValue;
    _hasPrevValue = true;
  }

  @override
  PostFrameEffect build() {
    return PostFrameEffect(_select, lazy: true);
  }

  @override
  void mount() {
    // Initialize prevValue on first mount
    _prevValue = selector();
    _hasPrevValue = true;
    // Track dependencies for reactive updates
    (state as EffectImpl).track(_select, false);
  }

  @override
  void unmount() {
    state.dispose();
  }

  @override
  void reassemble(covariant _ResetSetupSelectHook<T> newHook) {
    selector = newHook.selector;
    resetSetup = newHook.resetSetup;
    _prevValue = untracked(selector);
    _hasPrevValue = true;
    (state as EffectImpl).track(_select, true);
  }
}
