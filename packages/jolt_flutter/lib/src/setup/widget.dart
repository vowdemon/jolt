import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/src/shared.dart';

part 'hooks.dart';

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
abstract class SetupWidget<T extends SetupWidget<T>> extends Widget {
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
  SetupFunction<T> setup(
      SetupBuildContext<T> context, PropsReadonlyNode<T> props);

  @override
  SetupWidgetElement<T> createElement() => SetupWidgetElement<T>(this);
}

/// Extension methods for SetupWidget.
// extension SetupWidgetExtension<T extends SetupWidget<T>> on T {
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
// ///     final props = useProps();
// ///     return (context) => Text(props.value.name);
// ///   }
// /// }
// /// ```
// @pragma('vm:prefer-inline')
// @pragma('wasm:prefer-inline')
// @pragma('dart2js:prefer-inline')
// PropsReadonlyNode<T> useProps() =>
//     (useContext() as SetupBuildContext<T>).props as PropsReadonlyNode<T>;

// T get props => useProps().value;
// }

abstract interface class SetupBuildContext<T extends SetupWidget<T>>
    implements BuildContext {
  T get props;
}

class SetupWidgetElement<T extends SetupWidget<T>> extends ComponentElement
    with JoltCommonEffectBuilder
    implements SetupBuildContext<T> {
  SetupWidgetElement(SetupWidget<T> super.widget);

  late final JoltSetupContext<T> setupContext = JoltSetupContext(this);

  @override
  T get widget => super.widget as T;

  late final _propsNode = PropsReadonlyNode<T>(this);

  @override
  T get props => _propsNode.value;

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
      setupContext._onActivatedCallbacks.clear();
      setupContext._onDeactivatedCallbacks.clear();
      setupContext.renderer?.dispose();

      // 清空 _hooks 列表，准备按新的调用顺序重新构建
      setupContext._hooks.clear();

      // 重新执行 setup
      setupContext.run(() {
        setupContext._resetHookIndex();

        setupContext.setupBuilder = widget.setup(this, _propsNode);
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
    setupContext.run(() {
      setupContext._resetHookIndex();
      setupContext.setupBuilder = widget.setup(this, _propsNode);
      setupContext.renderer =
          Effect(joltBuildTriggerEffect, immediately: false);
      for (var hook in setupContext._hooks) {
        hook.mount();
      }
      for (var callback in setupContext._onMountedCallbacks) {
        callback();
      }
    });
  }

  @override
  void unmount() {
    for (var hook in setupContext._hooks.reversed) {
      hook.unmount();
    }
    for (var callback in setupContext._onUnmountedCallbacks) {
      callback();
    }

    super.unmount();

    _propsNode.dispose();
    setupContext.dispose();
  }

  @override
  void update(SetupWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _propsNode.notify();
    for (var hook in setupContext._hooks) {
      hook.update();
    }
    for (var callback in setupContext._onUpdatedCallbacks) {
      callback();
    }

    rebuild(force: true);
  }

  @override
  void didChangeDependencies() {
    for (var hook in setupContext._hooks) {
      hook.dependenciesChange();
    }
    for (var callback in setupContext._onChangedDependenciesCallbacks) {
      callback();
    }

    super.didChangeDependencies();
  }

  @override
  void activate() {
    super.activate();
    for (var hook in setupContext._hooks) {
      hook.activated();
    }
    for (var callback in setupContext._onActivatedCallbacks) {
      callback();
    }
  }

  @override
  void deactivate() {
    for (var hook in setupContext._hooks.reversed) {
      hook.deactivated();
    }
    for (var callback in setupContext._onDeactivatedCallbacks) {
      callback();
    }
    super.deactivate();
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

    return setupContext.run(() => trackWithEffect(
        () => setupContext.setupBuilder!(), setupContext.renderer!));
  }
}

class JoltSetupContext<T extends SetupWidget<T>> extends EffectScopeImpl {
  JoltSetupContext(this.element) : super(detach: true);

  final SetupWidgetElement element;

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  SetupBuildContext<T> get context => element as SetupBuildContext<T>;

  SetupFunction<T>? setupBuilder;
  Effect? renderer;

  final List<SetupHook> _hooks = [];

  final List<void Function()> _onMountedCallbacks = [];
  final List<void Function()> _onUnmountedCallbacks = [];
  final List<void Function()> _onUpdatedCallbacks = [];
  final List<void Function()> _onChangedDependenciesCallbacks = [];
  final List<void Function()> _onActivatedCallbacks = [];
  final List<void Function()> _onDeactivatedCallbacks = [];

  late final Map<Type, List<SetupHook>> _hookCacheByType = {};
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
  U _useHook<U>(SetupHook<U> hook) {
    final hookType = U;
    U? hookState;
    SetupHook<U>? existingHook;

    assert(() {
      final typeIndex = _typeIndexCounters[hookType] ?? 0;
      _typeIndexCounters[hookType] = typeIndex + 1;
      _newTypeUsageCounts[hookType] = typeIndex + 1;

      final typeCache = _hookCacheByType[hookType];
      if (typeCache != null && typeIndex < typeCache.length) {
        // 重用已存在的 hook（按类型和索引匹配）
        existingHook = typeCache[typeIndex] as SetupHook<U>;
        hookState = existingHook!.state;
        return true;
      }

      // 创建新的 hook
      hookState = hook.initState();
      _hookCacheByType.putIfAbsent(hookType, () => []).add(hook);
      _hooks.add(hook);
      return true;
    }());

    final result = hookState ?? hook.initState();
    final hookToAdd = existingHook ?? hook;

    if (!kDebugMode) {
      _hooks.add(hookToAdd);
    }

    return result;
  }

  void _cleanupUnusedHooks() {
    assert(() {
      if (!_isReassembling) return true;
      final unusedHooks = <SetupHook>[];

      // 按类型序列清理未使用的 hooks
      _hookCacheByType.forEach((type, hooks) {
        final newCount = _newTypeUsageCounts[type] ?? 0;
        final oldCount = hooks.length;

        if (newCount < oldCount) {
          unusedHooks.addAll(hooks.sublist(newCount, oldCount));
          hooks.removeRange(newCount, oldCount);
        }
      });

      _hookCacheByType.removeWhere((type, hooks) {
        if (!_newTypeUsageCounts.containsKey(type)) {
          unusedHooks.addAll(hooks);
          return true;
        }
        return false;
      });

      // 按定义顺序的逆序清理（与 unmount 保持一致）
      for (var hook in unusedHooks.reversed) {
        hook.unmount();
      }

      // 从 _hooks 列表中移除未使用的 hooks（保持顺序）
      final unusedHooksSet = unusedHooks.toSet();
      _hooks.removeWhere((hook) => unusedHooksSet.contains(hook));

      // 通知所有保留的 hooks 重新组装（按定义顺序）
      for (var hooks in _hookCacheByType.values) {
        for (var hook in hooks) {
          hook.reassemble();
        }
      }

      return true;
    }());
  }
  // coverage:ignore-end

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  @override
  U run<U>(U Function() fn) {
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
    _onActivatedCallbacks.clear();
    _onDeactivatedCallbacks.clear();
    _hooks.clear();

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
class SetupBuilder extends SetupWidget<SetupBuilder> {
  /// Creates a SetupBuilder.
  ///
  /// Parameters:
  /// - [key]: The widget key
  /// - [setup]: The setup function that returns a widget builder
  const SetupBuilder({
    super.key,
    required SetupFunctionBuilder<SetupBuilder> setup,
  }) : _setup = setup;

  final SetupFunctionBuilder<SetupBuilder> _setup;

  @override
  setup(context, props) => _setup(context);
}

/// A function type that creates a setup function from a BuildContext.
///
/// This is used by [SetupBuilder] to provide the setup function.
typedef SetupFunctionBuilder<T extends SetupWidget<T>> = SetupFunction<T>
    Function(SetupBuildContext<T> context);

/// A function type that builds a widget from a BuildContext.
///
/// This is the return type of the [SetupWidget.setup] method. The returned
/// builder function is called on each rebuild, while the setup function
/// itself runs only once.
typedef SetupFunction<T> = Widget Function();

class PropsReadonlyNode<T extends SetupWidget<T>> extends ReactiveNode
    implements ReadonlyNode<T> {
  PropsReadonlyNode(this._context) : super(flags: ReactiveFlags.mutable);

  final BuildContext _context;

  @override
  T get() {
    var sub = activeSub;
    while (sub != null) {
      if (sub.flags & (ReactiveFlags.mutable | ReactiveFlags.watching) != 0) {
        link(this, sub, cycle);

        break;
      }
      sub = sub.subs?.sub;
    }

    return _context.widget as T;
  }

  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  @pragma('dart2js:prefer-inline')
  T call() => get();

  @override
  void notify() {
    notifySignal(this);
  }

  @override
  T get peek => _context.widget as T;

  @override
  T get value => get();

  @override
  FutureOr<void> dispose() {
    disposeNode(this);
  }

  @override
  bool get isDisposed => !_context.mounted;

  // coverage:ignore-start
  @override
  void onDispose() {}
  // coverage:ignore-end
}
