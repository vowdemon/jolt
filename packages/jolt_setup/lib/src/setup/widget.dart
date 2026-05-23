part of 'framework.dart';

/// A widget whose setup logic runs once and returns a builder.
///
/// [SetupWidget] separates one-time initialization from repeated rendering.
/// Override [setup] to create signals, effects, controllers, and lifecycle
/// hooks. `setup` runs when the element is first created, and then again only
/// if the setup boundary is explicitly reset. The returned [WidgetFunction]
/// participates in normal reactive rebuilds.
///
/// Use [Props] inside [setup] when derived state should react to updated widget
/// fields. Read inherited widgets either in [setup] through [useInherited] or
/// in the returned builder when a plain Flutter dependency is enough.
///
/// ```dart
/// class CounterCard extends SetupWidget<CounterCard> {
///   const CounterCard({
///     super.key,
///     required this.title,
///     required this.initialValue,
///   });
///
///   final String title;
///   final int initialValue;
///
///   @override
///   WidgetFunction<CounterCard> setup(
///     BuildContext context,
///     Props<CounterCard> props,
///   ) {
///     final count = useSignal(props().initialValue);
///     final label = useComputed(() => '${props().title}: ${count.value}');
///
///     return () => Text(label.value);
///   }
/// }
/// ```
abstract class SetupWidget<T extends SetupWidget<T>> extends Widget {
  /// Creates a setup-based widget.
  const SetupWidget({super.key});

  /// Runs once to register hooks and returns the widget builder.
  ///
  /// Use [context] for inherited widgets and [props] for reactive access to
  /// the current widget instance. The returned builder is called on each
  /// reactive rebuild, so it should render from state created during this
  /// setup pass instead of allocating new long-lived resources.
  WidgetFunction<T> setup(BuildContext context, Props<T> props);

  @override
  SetupWidgetElement<T> createElement() => SetupWidgetElement<T>(this);
}

/// The element that owns a [SetupWidget]'s setup runtime.
///
/// [SetupWidgetElement] executes [SetupWidget.setup], mounts hooks, forwards
/// widget lifecycle events into [SetupContext], and rebuilds when the tracked
/// renderer effect is notified.
///
/// Most applications use [SetupWidget] directly and never construct this type
/// manually. It is public so advanced integrations can inspect the setup
/// runtime or trigger a setup reset from element-level code.
class SetupWidgetElement<T extends SetupWidget<T>> extends ComponentElement {
  SetupWidgetElement(SetupWidget<T> super.widget);

  /// The reactive node that tracks widget property changes.
  late final _propsNode = _PropsImpl<T>(this);

  /// The setup context that manages hooks and reactive state.
  late final SetupContext<T> setupContext = SetupContext(
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

  @override
  void performRebuild() {
    if (!_isFirstBuild) {
      super.performRebuild();
    } else {
      // First build: initialize setup
      setupContext.run(() {
        setupContext.setupBuilder = widget.setup(this, _propsNode);
        setupContext.renderer = PostFrameEffect(
          markNeedsBuild,
          lazy: true,
          debug: JoltDebugOption.type("SetupRenderer<$T>"),
        );

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

  @override
  void activate() {
    super.activate();
    setupContext.notifyActivate();
  }

  @override
  void deactivate() {
    setupContext.notifyDeactivate();
    super.deactivate();
  }

  /// Schedules a full rerun of the current `setup`.
  ///
  /// The reset happens at frame end and coalesces repeated calls in the same
  /// frame. It recreates the hook sequence instead of performing a normal
  /// widget rebuild, so it should be reserved for cases where the setup
  /// boundary itself must be rebuilt.
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
      setupContext.setupBuilder = widget.setup(this, _propsNode);

      // 6. Recreate the renderer effect
      setupContext.renderer = PostFrameEffect(
        markNeedsBuild,
        lazy: true,
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

/// A setup-based widget built directly from a callback.
///
/// Use [SetupBuilder] when you want setup semantics without defining a custom
/// [SetupWidget] subclass. It is a good fit for local composition, small
/// reactive leaf widgets, and prototypes that do not need a dedicated widget
/// type.
///
/// ```dart
/// SetupBuilder(
///   setup: (context) {
///     final count = useSignal(0);
///     useEffect(() {
///       debugPrint('count = ${count.value}');
///     });
///
///     return () => Text('Count: ${count.value}');
///   },
/// )
/// ```
class SetupBuilder extends SetupWidget<SetupBuilder> {
  /// Creates a builder-backed setup widget.
  ///
  /// The [setup] callback runs once for this widget identity and must return
  /// the builder used for later reactive rebuilds.
  const SetupBuilder({
    super.key,
    required WidgetFunction<SetupBuilder> Function(BuildContext) setup,
  }) : _setup = setup;

  final WidgetFunction<SetupBuilder> Function(BuildContext) _setup;

  @override
  setup(context, props) => _setup(context);
}

/// A widget builder returned from `setup`.
///
/// The builder closes over state created during setup and is called whenever
/// tracked reactive dependencies schedule a rebuild.
typedef WidgetFunction<T> = Widget Function();
