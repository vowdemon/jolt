part of 'widget.dart';

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

  /// Registers a callback to be called when the widget is activated.
  ///
  /// The callback is called when the widget is re-inserted into the widget tree
  /// after being deactivated (e.g., when navigating back to a route).
  ///
  /// Parameters:
  /// - [callback]: The function to call when the widget is activated
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   onActivated(() {
  ///     print('Widget activated');
  ///   });
  ///   return (context) => Text('Hello');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onActivated(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onActivatedCallbacks.add(callback);
  }

  /// Registers a callback to be called when the widget is deactivated.
  ///
  /// The callback is called when the widget is removed from the widget tree
  /// but not yet unmounted (e.g., when navigating away from a route).
  ///
  /// Parameters:
  /// - [callback]: The function to call when the widget is deactivated
  ///
  /// Example:
  /// ```dart
  /// setup: (context) {
  ///   onDeactivated(() {
  ///     print('Widget deactivated');
  ///   });
  ///   return (context) => Text('Hello');
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onDeactivated(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onDeactivatedCallbacks.add(callback);
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

  // /// Returns a reactive reference to the widget instance.
  // ///
  // /// This is the only way to watch for widget parameter changes in SetupWidget,
  // /// since the setup function executes only once.
  // ///
  // /// Returns: A [ReadonlyNode] that tracks widget changes
  // ///
  // /// Example:
  // /// ```dart
  // /// class UserCard extends SetupWidget {
  // ///   final String name;
  // ///
  // ///   const UserCard({super.key, required this.name});
  // ///
  // ///   @override
  // ///   WidgetBuilder setup(BuildContext context) {
  // ///     final props = useWidgetProps<UserCard>();
  // ///     return (context) => Text(props.value.name);
  // ///   }
  // /// }
  // /// ```
  // @pragma('vm:prefer-inline')
  // @pragma('wasm:prefer-inline')
  // @pragma('dart2js:prefer-inline')
  // static ReadonlyNode<T> useWidgetProps<T extends SetupWidget<T>>() {
  //   return (useContext() as SetupWidgetElement<T>)._propsNode;
  // }

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
  static T use<T>(SetupHook<T> hook) {
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

/// Registers a callback to be called when the widget is activated.
///
/// See [HookUtils.onActivated] for details.
final onActivated = HookUtils.onActivated;

/// Registers a callback to be called when the widget is deactivated.
///
/// See [HookUtils.onDeactivated] for details.
final onDeactivated = HookUtils.onDeactivated;

/// Gets the current BuildContext from the SetupWidget.
///
/// See [HookUtils.useContext] for details.
final useContext = HookUtils.useContext;

/// Gets the current JoltSetupContext.
///
/// See [HookUtils.useSetupContext] for details.
final useSetupContext = HookUtils.useSetupContext;

// /// Returns a reactive reference to the widget instance.
// ///
// /// See [HookUtils.useWidgetProps] for details.
// final useWidgetProps = HookUtils.useWidgetProps;

/// Creates a hook that persists across rebuilds and hot reloads.
///
/// See [HookUtils.use] for details.
T useHook<T>(SetupHook<T> hook) => HookUtils.use(hook);

abstract class SetupHook<T> {
  SetupHook()
      : assert(JoltSetupContext.current != null,
            'SetupWidgetElement is not exists'),
        _context = JoltSetupContext.current!.context;

  late final BuildContext _context;
  BuildContext get context => _context;

  T? _state;
  T get state => _state as T;
  T createState();

  void mount() {}

  void unmount() {}

  void update() {}

  void reassemble() {}

  void dependenciesChange() {}

  void activated() {}

  void deactivated() {}

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @internal
  T initState() {
    _state ??= createState();
    return state;
  }
}

class MemoizedSetupHook<T> extends SetupHook<T> {
  MemoizedSetupHook(this.creator);

  final T Function() creator;

  @override
  T createState() => creator();
}

T useMemoized<T>(T Function() creator) {
  return useHook(MemoizedSetupHook(creator));
}
