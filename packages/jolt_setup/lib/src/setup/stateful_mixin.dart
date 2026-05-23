part of 'framework.dart';

/// A mixin that adds the setup runtime to a [StatefulWidget] [State].
///
/// Use this when you want hook-based setup logic but still need a custom
/// [State] subclass. The `setup` function runs once for the current state
/// object, while the returned builder participates in normal Flutter rebuilds.
///
/// This is the bridge API for existing `StatefulWidget` codebases. It keeps
/// Flutter's [State] lifecycle and instance methods available while giving the
/// state object access to Jolt hooks such as [useSignal], [useComputed],
/// [useEffect], and the setup lifecycle callbacks.
///
/// ```dart
/// class SearchBox extends StatefulWidget {
///   const SearchBox({super.key, required this.initialText});
///
///   final String initialText;
///
///   @override
///   State<SearchBox> createState() => _SearchBoxState();
/// }
///
/// class _SearchBoxState extends State<SearchBox> with SetupMixin<SearchBox> {
///   @override
///   WidgetFunction<SearchBox> setup(BuildContext context) {
///     final controller =
///         useTextEditingController(text: props.initialText);
///
///     return () => TextField(controller: controller);
///   }
/// }
/// ```
mixin SetupMixin<T extends StatefulWidget> on State<T> {
  late final Props<T> _propsNode = _PropsImpl<T>(context);
  late final SetupContext<T> setupContext = SetupContext<T>(
    context,
    _propsNode,
    resetSetupFn: _doResetSetup,
  );

  bool _isFirstBuild = true;

  /// The current widget instance for this state object.
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T get props => _propsNode.value;

  /// Runs once to register hooks and returns the widget builder.
  ///
  /// Use [context] to read inherited widgets during setup and [props] to read
  /// the current widget instance. The returned [WidgetFunction] should render
  /// from reactive state created during this call rather than allocating new
  /// long-lived resources on every rebuild.
  WidgetFunction<T> setup(BuildContext context);

  /* --------------------------- Lifecycle hooks --------------------------- */

  @override
  @mustCallSuper
  void reassemble() {
    super.reassemble();
    assert(() {
      setupContext._isReassembling = true;
      return true;
    }());
  }

  @override
  @mustCallSuper
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    setupContext.notifyUpdate(oldWidget, widget);
  }

  @override
  @mustCallSuper
  void didChangeDependencies() {
    setupContext.notifyDependenciesChanged();
    super.didChangeDependencies();
  }

  @override
  @mustCallSuper
  void activate() {
    super.activate();
    setupContext.notifyActivate();
  }

  @override
  @mustCallSuper
  void deactivate() {
    setupContext.notifyDeactivate();
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

  /// Schedules a full rerun of the current `setup`.
  ///
  /// The reset happens at frame end and coalesces multiple calls in the same
  /// frame. It tears down the current hooks and renderer, then runs `setup`
  /// again to rebuild the setup boundary from scratch.
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
    setupContext.raw.cleanup();

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
      setupContext.setupBuilder = setup(context);

      // 6. Recreate the renderer effect
      setupContext.renderer = PostFrameEffect(
        (context as Element).markNeedsBuild,
        lazy: true,
        debug: JoltDebugOption.type("SetupRenderer<$T>"),
      );

      // 7. Mount all new hooks
      for (var hook in setupContext._hooks) {
        hook.mount();
      }
    });

    // 8. Trigger a rebuild to apply the changes
    (context as Element).markNeedsBuild();
  }

  /* ------------------------------ Build flow ----------------------------- */

  void _reload() {
    assert(() {
      setupContext.run(() {
        setupContext._resetHookIndex();
        setupContext.setupBuilder = setup(context);
        setupContext._cleanupUnusedHooks();
      });

      setupContext._isReassembling = false;
      return true;
    }());
  }

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
        setupContext.renderer = PostFrameEffect(
          (context as Element).markNeedsBuild,
          lazy: true,
          debug: JoltDebugOption.type("SetupRenderer<$T>"),
        );

        for (var hook in setupContext._hooks) {
          hook.mount();
        }
      });
      _isFirstBuild = false;
    }

    assert(() {
      if (setupContext._isReassembling) {
        _reload();
      }
      return true;
    }());

    return setupContext.run(() => (setupContext.renderer! as EffectImpl)
        .track(() => setupContext.setupBuilder!()));
  }
}
