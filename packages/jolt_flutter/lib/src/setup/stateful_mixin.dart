part of 'framework.dart';

/// A mixin that brings setup-based composition API to [StatefulWidget].
///
/// This mixin allows you to use Jolt's reactive setup pattern with traditional
/// [StatefulWidget], providing a bridge between Flutter's standard widget system
/// and Jolt's composition API.
///
/// ## Usage
///
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final String title;
///   final int initialCount;
///
///   const MyWidget({super.key, required this.title, required this.initialCount});
///
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> with SetupMixin<MyWidget> {
///   @override
///   setup(context) {
///     // Access widget properties via props getter
///     final count = useSignal(props.initialCount);
///
///     // Use any Jolt hooks
///     useEffect(() {
///       print('Title: ${props.title}');
///     }, [props.title]);
///
///     return () => Column(
///       children: [
///         Text(props.title),
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
///
/// ## Features
///
/// - **Props Access**: Use the [props] getter to access widget properties reactively
/// - **Hooks Support**: All Jolt hooks ([useSignal], [useComputed], [useEffect], etc.)
/// - **Lifecycle Integration**: Automatically integrates with Flutter's State lifecycle
/// - **Hot Reload**: Full hot reload support with hook state preservation
///
/// ## Lifecycle
///
/// The mixin automatically handles:
/// - Setup function runs on first build (after [initState], before first [build])
/// - Props updates trigger [JoltSetupContext.notifyUpdate]
/// - Dependencies changes trigger [JoltSetupContext.notifyDependenciesChanged]
/// - Cleanup on [dispose]
///
/// ## When to Use
///
/// Use [SetupMixin] when:
/// - You need [StatefulWidget] features (like [State.mounted])
/// - Integrating with existing StatefulWidget code
/// - You prefer State's lifecycle methods
///
/// Use [SetupWidget] when:
/// - Building new components from scratch
/// - You want the simplest API
/// - Element's lifecycle is sufficient
mixin SetupMixin<T extends StatefulWidget> on State<T> {
  late final PropsReadonlyNode<T> _propsNode = PropsReadonlyNode<T>(context);
  late final JoltSetupContext<T> setupContext =
      JoltSetupContext<T>(context, _propsNode);

  bool _isFirstBuild = true;

  /// Provides direct access to the widget properties.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T get props => _propsNode.value;

  /// The setup function that runs once when the widget is created.
  ///
  /// This function is called during the first [build] (after [initState] but
  /// before the first frame is rendered). It executes only once during the
  /// widget's lifetime.
  ///
  /// Use this function to:
  /// - Initialize reactive state with hooks ([useSignal], [useComputed], etc.)
  /// - Set up side effects with [useEffect]
  /// - Access widget properties via the [props] getter
  /// - Create the widget builder function
  ///
  /// ## Parameters
  ///
  /// - [context]: The [BuildContext] for this State. Note that you can access
  ///   widget properties via the [props] getter instead of [context.widget]
  ///
  /// ## Returns
  ///
  /// A [WidgetFunction] that will be called on each rebuild triggered by
  /// reactive dependencies. The builder should be a pure function that returns
  /// a [Widget] based on the current reactive state.
  ///
  /// ## Example
  ///
  /// ```dart
  /// @override
  /// setup(context) {
  ///   final count = useSignal(0);
  ///   final doubled = useComputed(() => count.value * 2);
  ///
  ///   useEffect(() {
  ///     print('Count changed: ${count.value}');
  ///   }, [count.value]);
  ///
  ///   // Return the builder function
  ///   return () => Text('Count: ${count.value}, Doubled: ${doubled.value}');
  /// }
  /// ```
  ///
  /// ## Accessing InheritedWidgets
  ///
  /// Unlike [initState], the setup function can safely access [InheritedWidget]s:
  /// ```dart
  /// @override
  /// setup(context) {
  ///   final theme = Theme.of(context);
  ///   final count = useSignal(0);
  ///
  ///   return () => Text(
  ///     'Count: ${count.value}',
  ///     style: theme.textTheme.bodyLarge,
  ///   );
  /// }
  /// ```
  WidgetFunction<T> setup(BuildContext context);

  /* --------------------------- Lifecycle hooks --------------------------- */

  // coverage:ignore-start
  @override
  @mustCallSuper
  void reassemble() {
    super.reassemble();
    assert(() {
      setupContext._isReassembling = true;
      return true;
    }());
  }
  // coverage:ignore-end

  @override
  @mustCallSuper
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    setupContext.notifyUpdate();
  }

  @override
  @mustCallSuper
  void didChangeDependencies() {
    setupContext.notifyDependenciesChanged();
    super.didChangeDependencies();
  }

  // coverage:ignore-start
  @override
  @mustCallSuper
  void activate() {
    super.activate();
    setupContext.notifyActivated();
  }
  // coverage:ignore-end

  @override
  @mustCallSuper
  void deactivate() {
    setupContext.notifyDeactivated();
    super.deactivate();
  }

  @override
  @mustCallSuper
  void dispose() {
    setupContext.unmountHooks();
    _propsNode.dispose();
    setupContext.dispose();
    super.dispose();
  }

  /* ------------------------------ Build flow ----------------------------- */

  bool _isScheduled = false;

  void _triggerRebuild() {
    final element = context as ComponentElement;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      if (_isScheduled) return;
      _isScheduled = true;
      SchedulerBinding.instance.endOfFrame.then((_) {
        _isScheduled = false;
        if (element.dirty || !mounted) return;
        element.markNeedsBuild();
      });
    } else {
      if (element.dirty) return;
      element.markNeedsBuild();
    }
  }

  // coverage:ignore-start
  void _reload() {
    assert(() {
      setupContext._hooks.clear();

      setupContext.run(() {
        setupContext._resetHookIndex();
        setupContext.setupBuilder = setup(context);
        setupContext._cleanupUnusedHooks();
      });

      setupContext._isReassembling = false;
      return true;
    }());
  }
  // coverage:ignore-end

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    if (_isFirstBuild) {
      // Initialize setup on first build rather than initState.
      // Although initState runs before build, Flutter doesn't allow accessing
      // InheritedWidgets in initState (throws assertion error). Since setup
      // may need to access InheritedWidgets (e.g., Theme.of(context)),
      // we must initialize here.
      setupContext.run(() {
        setupContext.setupBuilder = setup(context);
        setupContext.renderer = Effect.lazy(_triggerRebuild);

        for (var hook in setupContext._hooks) {
          hook.mount();
        }
      });
      _isFirstBuild = false;
    }

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
