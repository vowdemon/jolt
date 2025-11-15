import 'package:flutter/widgets.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/src/shared.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

abstract class SetupWidget extends Widget {
  const SetupWidget({super.key});

  SetupFunction setup(BuildContext context);

  @override
  SetupWidgetElement createElement() => SetupWidgetElement(this);
}

extension SetupWidgetExtension<T extends SetupWidget> on T {
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

abstract final class HookUtils {
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onMounted(void Function() callback) {
    final context = useSetupContext();

    context._onMountedCallbacks.add(callback);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onUnmounted(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onUnmountedCallbacks.add(callback);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onUpdated(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onUpdatedCallbacks.add(callback);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static void onChangedDependencies(void Function() callback) {
    final currentContext = useSetupContext();

    currentContext._onChangedDependenciesCallbacks.add(callback);
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static BuildContext useContext() {
    final currentContext = JoltSetupContext.current?.context;
    assert(currentContext != null, 'SetupWidgetElement is not exsits');

    return currentContext!;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static JoltSetupContext useSetupContext() {
    final currentContext = JoltSetupContext.current;
    assert(currentContext != null, 'SetupWidgetElement is not exsits');

    return currentContext!;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static ReadonlyNode<T> useWidgetProps<T extends SetupWidget>() {
    final widget = useSetupContext().widget;

    return use(() => Computed(() => widget.value as T));
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  static T use<T>(T Function() hook) {
    assert(JoltSetupContext.current != null,
        'Hook.use must be called within a SetupWidget');

    return JoltSetupContext.current!._useHook(hook);
  }
}

final onMounted = HookUtils.onMounted;
final onUnmounted = HookUtils.onUnmounted;
final onUpdated = HookUtils.onUpdated;
final onChangedDependencies = HookUtils.onChangedDependencies;
final useContext = HookUtils.useContext;
final useSetupContext = HookUtils.useSetupContext;
final useWidgetProps = HookUtils.useWidgetProps;
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

class SetupBuilder extends SetupWidget {
  const SetupBuilder({
    super.key,
    required SetupFunctionBuilder setup,
  }) : _setup = setup;

  final SetupFunctionBuilder _setup;

  @override
  SetupFunction setup(BuildContext context) => _setup(context);
}

typedef SetupFunctionBuilder = SetupFunction Function(BuildContext context);
typedef SetupFunction = WidgetBuilder;
