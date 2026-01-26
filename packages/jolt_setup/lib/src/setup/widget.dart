part of 'framework.dart';

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
/// ## Example
///
/// ```dart
/// class CounterWidget extends SetupWidget<CounterWidget> {
///   const CounterWidget({super.key});
///
///   @override
///   setup(context, props) {
///     // Setup runs once - create reactive state
///     final count = useSignal(0);
///
///     // Return builder function - runs on each rebuild
///     return () => Column(
///       children: [
///         Text('Count: ${count.value}'),
///         ElevatedButton(
///           onPressed: () => count.value++,
///           child: const Text('Increment'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Parameters and Props
///
/// For widgets with parameters, use the `props` parameter to access them reactively:
///
/// ```dart
/// class UserCard extends SetupWidget<UserCard> {
///   final String name;
///   final int age;
///
///   const UserCard({super.key, required this.name, required this.age});
///
///   @override
///   setup(context, props) {
///     // Access props reactively - triggers rebuild when they change
///     final greeting = useComputed(() => 'Hello, ${props().name}!');
///
///     return () => Column(
///       children: [
///         Text(greeting.value),
///         Text('Age: ${props().age}'),
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
  /// This function should return a [WidgetFunction] that will be called on
  /// each rebuild. Use hooks like [useSignal], [useComputed], etc. to manage
  /// reactive state within this function.
  ///
  /// Hooks are cached and reused across hot reloads based on their runtime type
  /// and position in the sequence. If the hook sequence changes during hot reload,
  /// mismatched hooks will be unmounted and recreated.
  ///
  /// ## Parameters
  ///
  /// - **context**: The standard Flutter [BuildContext] for accessing inherited widgets
  /// - **props**: A [Props] that provides reactive access to widget properties
  ///
  /// ## Returns
  ///
  /// A [WidgetFunction] that builds the widget tree. This builder runs on each
  /// reactive rebuild when tracked dependencies change.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// setup(context, props) {
  ///   // Access reactive props
  ///   final title = useComputed(() => props().title);
  ///
  ///   // Create local reactive state
  ///   final count = useSignal(0);
  ///
  ///   // Return builder function
  ///   return () => Column(
  ///     children: [
  ///       Text(title.value),
  ///       Text('Count: ${count.value}'),
  ///     ],
  ///   );
  /// }
  /// ```
  WidgetFunction<T> setup(BuildContext context, Props<T> props);

  @override
  SetupWidgetElement<T> createElement() => SetupWidgetElement<T>(this);
}

/// The [Element] that manages the lifecycle of a [SetupWidget].
///
/// This element orchestrates the complete lifecycle of setup-based widgets,
/// leveraging [JoltSetupContext] for hook management while implementing
/// Element-specific build triggering mechanisms.
///
/// ## Responsibilities
///
/// - **Setup Execution**: Runs the widget's [setup] function once during first build
/// - **Hook Management**: Delegates hook lifecycle to [JoltSetupContext]
/// - **Build Triggering**: Uses [markNeedsBuild] for efficient rebuilds
/// - **Hot Reload**: Preserves hook state across code changes
/// - **Props Tracking**: Uses [Props] for reactive property tracking
///
/// ## Lifecycle Flow
///
/// 1. **Creation** ([createElement])
///    - Element is created and attached to the tree
///
/// 2. **First Build** ([performRebuild])
///    - Setup function runs with [BuildContext] and [Props]
///    - Hooks are registered and mounted
///    - Renderer effect is created
///
/// 3. **Updates** ([update])
///    - Props node notifies subscribers
///    - Hooks receive [SetupHook.didUpdateWidget]
///    - Rebuild is triggered if reactive dependencies changed
///
/// 4. **Disposal** ([unmount])
///    - Hooks are unmounted in reverse order
///    - Props node is disposed
///    - Setup context is disposed
///
/// ## Hot Reload
///
/// During hot reload ([reassemble]):
/// 1. Existing hooks are matched by type and position
/// 2. Matched hooks preserve state and receive [SetupHook.reassemble]
/// 3. Mismatched hooks are unmounted and replaced
///
/// ## Implementation Notes
///
/// - Mixes in [JoltCommonEffectBuilder] for [joltBuildTriggerEffect]
/// - Uses [Props] for reactive property tracking
/// - Leverages Element's [markNeedsBuild] for performance
class SetupWidgetElement<T extends SetupWidget<T>> extends ComponentElement {
  SetupWidgetElement(SetupWidget<T> super.widget);

  /// The reactive node that tracks widget property changes.
  late final _propsNode = _PropsImpl<T>(this);

  /// The setup context that manages hooks and reactive state.
  late final JoltSetupContext<T> setupContext = JoltSetupContext(
    this,
    _propsNode,
    resetSetupFn: _doResetSetup,
  );

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  T get widget => super.widget as T;

  bool _isFirstBuild = true;

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
      setupContext.run(() {
        setupContext._resetHookIndex();
        setupContext.setupBuilder = widget.setup(this, _propsNode);
        setupContext._cleanupUnusedHooks();
      });

      setupContext._isReassembling = false;
      return true;
    }());
  }
  // coverage:ignore-end

  @override
  void performRebuild() {
    if (!_isFirstBuild) {
      super.performRebuild();
    } else {
      // First build: initialize setup
      setupContext.run(() {
        setupContext.setupBuilder = widget.setup(this, _propsNode);
        setupContext.renderer = FlutterEffect.lazy(markNeedsBuild,
            debug: JoltDebugOption.type("SetupRenderer<$T>"));

        for (var hook in setupContext._hooks) {
          hook.mount();
        }
      });
      _isFirstBuild = false;
      super.performRebuild();
    }
  }

  @override
  void unmount() {
    setupContext.unmountHooks();
    super.unmount();
    _propsNode.dispose();
    setupContext.dispose();
  }

  @override
  void update(SetupWidget newWidget) {
    final oldWidget = widget;
    super.update(newWidget);
    assert(widget == newWidget);
    setupContext.notifyUpdate(oldWidget, newWidget);
    rebuild(force: true);
  }

  @override
  void didChangeDependencies() {
    setupContext.notifyDependenciesChanged();
    super.didChangeDependencies();
  }

  // coverage:ignore-start
  @override
  void activate() {
    super.activate();
    setupContext.notifyActivate();
  }
  // coverage:ignore-end

  @override
  void deactivate() {
    setupContext.notifyDeactivate();
    super.deactivate();
  }

  /// Resets and re-runs the setup function at runtime.
  ///
  /// This method provides a runtime hot-reload mechanism that:
  /// 1. Unmounts all existing hooks in reverse order
  /// 2. Disposes the current renderer effect
  /// 3. Cleans up all EffectScope cleanup functions
  /// 4. Clears all hook state
  /// 5. Re-runs the setup function to create new hooks
  /// 6. Recreates the renderer effect
  /// 7. Mounts all new hooks
  ///
  /// This is similar to hot reload but can be triggered programmatically
  /// at runtime, allowing for dynamic reconfiguration of the widget's setup.
  ///
  /// ## Example
  ///
  /// ```dart
  /// setup(context, props) {
  ///   final count = useSignal(0);
  ///
  ///   // Somewhere in your code, reset the entire setup
  ///   // This will unmount all hooks, clean up effects, and re-run setup
  ///   (context as Element).setupContext.setupContext();
  ///
  ///   return () => Text('Count: ${count.value}');
  /// }
  /// ```
  void resetSetup() {
    setupContext.scheduleResetSetup();
  }

  void _doResetSetup() {
    // 1. Unmount all existing hooks in reverse order
    setupContext.unmountHooks();

    // 2. Dispose the current renderer
    setupContext.renderer?.dispose();
    setupContext.renderer = null;

    // 3. Clean up all EffectScope cleanup functions registered during setup
    setupContext.cleanup();

    // 4. Clear all hooks
    setupContext._hooks.clear();

    assert(() {
      setupContext._newHooks.clear();
      setupContext._newlyCreatedHooks.clear();
      setupContext._newHookConfigs.clear();
      setupContext._currentHookIndex = 0;
      setupContext._isReassembling = false;
      return true;
    }());

    // 5. Re-run setup function to create new hooks
    setupContext.run(() {
      setupContext.setupBuilder = widget.setup(this, _propsNode);

      // 6. Recreate the renderer effect
      setupContext.renderer = FlutterEffect.lazy(
        markNeedsBuild,
        debug: JoltDebugOption.type("SetupRenderer<$T>"),
      );

      // 7. Mount all new hooks
      for (var hook in setupContext._hooks) {
        hook.mount();
      }
    });

    // 8. Trigger a rebuild to apply the changes
    markNeedsBuild();
  }

  @override
  Widget build() {
    // coverage:ignore-start
    assert(() {
      if (setupContext._isReassembling) {
        _reload();
      }
      return true;
    }());
    // coverage:ignore-end

    return setupContext.run(() => trackWithEffect(
        () => setupContext.setupBuilder!(), setupContext.renderer!));
  }
}

/// A convenience widget that uses a builder function for setup.
///
/// [SetupBuilder] provides the simplest way to use Jolt's setup API without
/// creating a custom widget class. It's ideal for quick prototyping, simple
/// components, or inline reactive widgets.
///
/// ## When to Use
///
/// **Use SetupBuilder when:**
/// - Prototyping or experimenting with reactive state
/// - Creating simple, self-contained components
/// - You don't need custom widget properties
/// - The component logic is straightforward
///
/// **Use SetupWidget subclass when:**
/// - You need custom properties (title, count, callback, etc.)
/// - Building reusable components with clear APIs
/// - The component is complex or will be used in multiple places
/// - You want better IDE support and type checking for properties
///
/// ## Example
///
/// ```dart
/// // Simple counter - no custom properties needed
/// SetupBuilder(
///   setup: (context) {
///     final count = useSignal(0);
///
///     useEffect(() {
///       print('Count changed: ${count.value}');
///     }, [count.value]);
///
///     return () => Column(
///       children: [
///         Text('Count: ${count.value}'),
///         ElevatedButton(
///           onPressed: () => count.value++,
///           child: const Text('Increment'),
///         ),
///       ],
///     );
///   },
/// )
/// ```
///
/// ## Comparison with SetupWidget
///
/// ```dart
/// // SetupBuilder: For simple widgets without custom properties
/// SetupBuilder(
///   setup: (context) {
///     final count = useSignal(0);
///     return () => Text('Count: ${count.value}');
///   },
/// )
///
/// // SetupWidget: For reusable widgets with custom properties
/// class Counter extends SetupWidget<Counter> {
///   final int initialValue;
///   final String label;
///
///   const Counter({
///     super.key,
///     required this.initialValue,
///     required this.label,
///   });
///
///   @override
///   setup(context, props) {
///     // Access reactive props through props parameter
///     final count = useSignal(props().initialValue);
///
///     // React to prop changes
///     final displayText = useComputed(() =>
///       '${props().label}: ${count.value}'
///     );
///
///     return () => Text(displayText.value);
///   }
/// }
/// ```
class SetupBuilder extends SetupWidget<SetupBuilder> {
  /// Creates a SetupBuilder.
  ///
  /// ## Parameters
  ///
  /// - **key**: Optional widget key for controlling widget identity
  /// - **setup**: A function that receives [BuildContext] and returns a [WidgetFunction]
  ///
  /// The setup function is called once during widget creation and should return
  /// a builder function that constructs the widget tree on each rebuild.
  const SetupBuilder({
    super.key,
    required WidgetFunction<SetupBuilder> Function(BuildContext) setup,
  }) : _setup = setup;

  final WidgetFunction<SetupBuilder> Function(BuildContext) _setup;

  @override
  setup(context, props) => _setup(context);
}

/// A function type that builds a widget without parameters.
typedef WidgetFunction<T> = Widget Function();
