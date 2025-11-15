import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/src/shared.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

/// A widget that uses a composition-based API similar to Vue's Composition API.
///
/// The [setup] function executes only once when the widget is first created,
/// not on every rebuild. This provides better performance and a more predictable
/// execution model compared to React-style hooks.
///
/// Example:
/// ```dart
/// class CounterWidget extends SetupWidget {
///   const CounterWidget({super.key});
///
///   @override
///   WidgetBuilder setup(BuildContext context) {
///     final count = useSignal(0);
///
///     return (context) => Column(
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
abstract class SetupWidget extends Widget {
  /// Creates a SetupWidget.
  const SetupWidget({super.key});

  /// The setup function that runs once when the widget is created.
  ///
  /// This function should return a [WidgetBuilder] that will be called on
  /// each rebuild. Use hooks like [useSignal], [useComputed], etc. to manage
  /// reactive state within this function.
  ///
  /// Parameters:
  /// - [context]: The build context
  ///
  /// Returns: A widget builder function
  SetupFunction setup(BuildContext context);

  @override
  SetupWidgetElement createElement() => SetupWidgetElement(this);
}

/// Extension methods for SetupWidget.
extension SetupWidgetExtension<T extends SetupWidget> on T {
  /// Returns a reactive reference to the widget instance.
  ///
  /// This is the only way to watch for widget parameter changes in SetupWidget,
  /// since the setup function executes only once.
  ///
  /// Returns: A [ReadonlyNode] that tracks widget changes
  ///
  /// Example:
  /// ```dart
  /// class UserCard extends SetupWidget {
  ///   final String name;
  ///
  ///   const UserCard({super.key, required this.name});
  ///
  ///   @override
  ///   WidgetBuilder setup(BuildContext context) {
  ///     final props = useProps();
  ///     return (context) => Text(props.value.name);
  ///   }
  /// }
  /// ```
  ReadonlyNode<T> useProps() => useWidgetProps<T>();
}

class SetupWidgetElement<T extends SetupWidget> extends ComponentElement
    with JoltCommonEffectBuilder {
  SetupWidgetElement(SetupWidget super.widget);

  late final JoltSetupContext setupContext = JoltSetupContext(this);

  @override
  SetupWidget get widget => super.widget as SetupWidget;

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
      setupContext._onMountedCallbacks.clear();
      setupContext._onUpdatedCallbacks.clear();
      setupContext._onChangedDependenciesCallbacks.clear();
      setupContext._onUnmountedCallbacks.clear();
      setupContext.renderer?.dispose();

      // 重新执行 setup
      setupContext.run(() {
        setupContext._resetHookIndex();
        setupContext.widget.value = widget;
        setupContext.setupBuilder = widget.setup(this);
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
    setupContext.widget.value = widget;
    setupContext.run(() {
      setupContext._resetHookIndex();
      setupContext.setupBuilder = widget.setup(this);
      setupContext.renderer =
          Effect(joltBuildTriggerEffect, immediately: false);
      for (var callback in setupContext._onMountedCallbacks) {
        callback();
      }
    });
  }

  @override
  void unmount() {
    for (var callback in setupContext._onUnmountedCallbacks) {
      callback();
    }

    super.unmount();

    setupContext.dispose();
  }

  @override
  void update(SetupWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    setupContext.widget.value = newWidget;
    for (var callback in setupContext._onUpdatedCallbacks) {
      callback();
    }

    rebuild(force: true);
  }

  @override
  void didChangeDependencies() {
    for (var callback in setupContext._onChangedDependenciesCallbacks) {
      callback();
    }
    super.didChangeDependencies();
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

    return trackWithEffect(
        () => setupContext.setupBuilder!(this), setupContext.renderer!);
  }
}

/// Utility functions for SetupWidget hooks and lifecycle management.
abstract final class HookUtils {
  /// Registers a callback to be called when the widget is mounted.
  ///
  /// The callback is called once after the first build completes.
  ///
  /// Parameters:
  /// - [callback]: The function to call when the widget is mounted
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   onMounted(() {
  ///     print('Widget mounted');
  ///   });
  ///   return (context) => Text('Hello');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onMounted(void Function() callback) {
    final context = useSetupContext();

    context._onMountedCallbacks.add(callback);
  }

  /// Registers a callback to be called when the widget is unmounted.
  ///
  /// The callback is called when the widget is removed from the widget tree.
  ///
  /// Parameters:
  /// - [callback]: The function to call when the widget is unmounted
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   final timer = useSignal<Timer?>(null);
  ///
  ///   onMounted(() {
  ///     timer.value = Timer.periodic(Duration(seconds: 1), (_) {});
  ///   });
  ///
  ///   onUnmounted(() {
  ///     timer.value?.cancel();
  ///   });
  ///
  ///   return (context) => Text('Timer');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onUnmounted(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onUnmountedCallbacks.add(callback);
  }

  /// Registers a callback to be called when the widget is updated.
  ///
  /// The callback is called when the widget receives a new configuration
  /// (new widget instance with the same runtimeType).
  ///
  /// Parameters:
  /// - [callback]: The function to call when the widget is updated
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   onUpdated(() {
  ///     print('Widget updated');
  ///   });
  ///   return (context) => Text('Hello');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onUpdated(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onUpdatedCallbacks.add(callback);
  }

  /// Registers a callback to be called when widget dependencies change.
  ///
  /// The callback is called when [InheritedWidget] dependencies change.
  ///
  /// Parameters:
  /// - [callback]: The function to call when dependencies change
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   onChangedDependencies(() {
  ///     print('Dependencies changed');
  ///   });
  ///   return (context) => Text('Hello');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onChangedDependencies(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onChangedDependenciesCallbacks.add(callback);
  }

  /// Gets the current BuildContext from the SetupWidget.
  ///
  /// Returns: The BuildContext of the current SetupWidget
  ///
  /// Throws: An assertion error if called outside of a SetupWidget
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   final ctx = useContext();
  ///   return (context) => Text('Context: $ctx');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static BuildContext useContext() {
    final currentContext = JoltSetupContext.current?.context;
    assert(currentContext != null, 'SetupWidgetElement is not exsits');

    return currentContext!;
  }

  /// Gets the current JoltSetupContext.
  ///
  /// Returns: The JoltSetupContext of the current SetupWidget
  ///
  /// Throws: An assertion error if called outside of a SetupWidget
  ///
  /// This is typically used internally by other hooks and utilities.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static JoltSetupContext useSetupContext() {
    final currentContext = JoltSetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exsits');

    return currentContext!;
  }

  /// Returns a reactive reference to the widget instance.
  ///
  /// This is the only way to watch for widget parameter changes in SetupWidget,
  /// since the setup function executes only once.
  ///
  /// Returns: A [ReadonlyNode] that tracks widget changes
  ///
  /// Example:
  /// ```dart
  /// class UserCard extends SetupWidget {
  ///   final String name;
  ///
  ///   const UserCard({super.key, required this.name});
  ///
  ///   @override
  ///   WidgetBuilder setup(BuildContext context) {
  ///     final props = useWidgetProps<UserCard>();
  ///     return (context) => Text(props.value.name);
  ///   }
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static ReadonlyNode<T> useWidgetProps<T extends SetupWidget>() {
    final widget = useSetupContext().widget;

    return use(() => Computed(() => widget.value as T));
  }

  /// Creates a hook that persists across rebuilds and hot reloads.
  ///
  /// Hooks are stored by type and position in the setup function. During hot
  /// reload, hooks are matched by type and position to preserve state.
  ///
  /// Parameters:
  /// - [hook]: A function that creates the hook value
  ///
  /// Returns: The hook value (reused if already exists)
  ///
  /// Throws: An assertion error if called outside of a SetupWidget
  ///
  /// This is the underlying mechanism used by all `use*` hooks.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static T use<T>(T Function() hook) {
    assert(JoltSetupContext.current != null,
        'Hook.use must be called within a SetupWidget');

    return JoltSetupContext.current!._useHook(hook);
  }
}

/// Registers a callback to be called when the widget is mounted.
///
/// See [HookUtils.onMounted] for details.
final onMounted = HookUtils.onMounted;

/// Registers a callback to be called when the widget is unmounted.
///
/// See [HookUtils.onUnmounted] for details.
final onUnmounted = HookUtils.onUnmounted;

/// Registers a callback to be called when the widget is updated.
///
/// See [HookUtils.onUpdated] for details.
final onUpdated = HookUtils.onUpdated;

/// Registers a callback to be called when widget dependencies change.
///
/// See [HookUtils.onChangedDependencies] for details.
final onChangedDependencies = HookUtils.onChangedDependencies;

/// Gets the current BuildContext from the SetupWidget.
///
/// See [HookUtils.useContext] for details.
final useContext = HookUtils.useContext;

/// Gets the current JoltSetupContext.
///
/// See [HookUtils.useSetupContext] for details.
final useSetupContext = HookUtils.useSetupContext;

/// Returns a reactive reference to the widget instance.
///
/// See [HookUtils.useWidgetProps] for details.
final useWidgetProps = HookUtils.useWidgetProps;

/// Creates a hook that persists across rebuilds and hot reloads.
///
/// See [HookUtils.use] for details.
final useHook = HookUtils.use;

class JoltSetupContext extends EffectScopeImpl {
  JoltSetupContext(this.element)
      : widget = Signal(element.widget),
        super(detach: true);

  final SetupWidgetElement element;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  BuildContext get context => element as BuildContext;

  final Signal<SetupWidget> widget;
  WidgetBuilder? setupBuilder;
  Effect? renderer;

  final List<void Function()> _onMountedCallbacks = [];
  final List<void Function()> _onUnmountedCallbacks = [];
  final List<void Function()> _onUpdatedCallbacks = [];
  final List<void Function()> _onChangedDependenciesCallbacks = [];

  late final Map<Type, List<Object>> _hookCacheByType = {};
  late final Map<Type, int> _typeIndexCounters = {};
  late final Map<Type, int> _newTypeUsageCounts = {};
  late bool _isReassembling = false;

  // coverage:ignore-start
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  void _resetHookIndex() {
    assert(() {
      _typeIndexCounters.clear();
      _newTypeUsageCounts.clear();
      return true;
    }());
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T _useHook<T>(T Function() hook) {
    final hookType = T;
    T? hookState;
    assert(() {
      final typeIndex = _typeIndexCounters[hookType] ?? 0;
      _typeIndexCounters[hookType] = typeIndex + 1;

      _newTypeUsageCounts[hookType] = typeIndex + 1;

      final typeCache = _hookCacheByType[hookType];
      if (typeCache != null && typeIndex < typeCache.length) {
        hookState = typeCache[typeIndex] as T;
        return true;
      }

      _hookCacheByType
          .putIfAbsent(hookType, () => [])
          .add((hookState = hook()) as Object);

      return true;
    }());

    final result = hookState ?? hook();
    if (result is Disposable) {
      onCleanUp(result.dispose);
    }

    return result;
  }

  void _cleanupUnusedHooks() {
    assert(() {
      if (!_isReassembling) return true;

      _hookCacheByType.forEach((type, hooks) {
        final newCount = _newTypeUsageCounts[type] ?? 0;
        final oldCount = hooks.length;

        if (newCount < oldCount) {
          hooks.removeRange(newCount, oldCount);
        }
      });

      _hookCacheByType.removeWhere((type, hooks) {
        return !_newTypeUsageCounts.containsKey(type);
      });

      return true;
    }());
  }
  // coverage:ignore-end

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  T run<T>(T Function() fn) {
    final prevContext = setActiveContext(this);
    try {
      return super.run(fn);
    } finally {
      setActiveContext(prevContext);
    }
  }

  @override
  void onDispose() {
    _onMountedCallbacks.clear();
    _onUnmountedCallbacks.clear();
    _onUpdatedCallbacks.clear();
    _onChangedDependenciesCallbacks.clear();

    assert(() {
      _hookCacheByType.clear();
      _typeIndexCounters.clear();
      _newTypeUsageCounts.clear();
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
///
/// Example:
/// ```dart
/// SetupBuilder(
///   setup: (context) {
///     final count = useSignal(0);
///
///     return (context) => Column(
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
class SetupBuilder extends SetupWidget {
  /// Creates a SetupBuilder.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [setup]: The setup function that returns a widget builder
  const SetupBuilder({
    super.key,
    required SetupFunctionBuilder setup,
  }) : _setup = setup;

  final SetupFunctionBuilder _setup;

  @override
  SetupFunction setup(BuildContext context) => _setup(context);
}

/// A function type that creates a setup function from a BuildContext.
///
/// This is used by [SetupBuilder] to provide the setup function.
typedef SetupFunctionBuilder = SetupFunction Function(BuildContext context);

/// A function type that builds a widget from a BuildContext.
///
/// This is the return type of the [SetupWidget.setup] method. The returned
/// builder function is called on each rebuild, while the setup function
/// itself runs only once.
typedef SetupFunction = WidgetBuilder;
