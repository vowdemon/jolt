import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

/// A [Hook] that wraps a Jolt [Readable] and disposes it on unmount.
///
/// Use this through the public `use*` helpers rather than constructing it
/// directly unless you are extending the hook system.
class JoltHook<T, S extends Readable<T>> extends Hook<S> {
  /// Creates a hook that builds [jolt] once per hook slot.
  const JoltHook(this.jolt, {super.keys});

  /// Builds the reactive value for this hook slot.
  final S Function() jolt;

  @override
  JoltHookState<T, S> createState() => JoltHookState();
}

/// The [HookState] for [JoltHook].
class JoltHookState<T, S extends Readable<T>>
    extends HookState<S, JoltHook<T, S>> {
  late final _instance = hook.jolt();

  @override
  void dispose() {
    if (_instance case Disposable disposable) {
      disposable.dispose();
    }
  }

  @override
  S build(BuildContext context) => _instance;

  // coverage:ignore-start
  @override
  Object? get debugValue => _instance.value;

  @override
  String get debugLabel => 'use${hook.jolt.runtimeType}';
  // coverage:ignore-end
}

/// A [Hook] that wraps a Jolt effect node and disposes it on unmount.
class JoltEffectHook<S extends Object> extends Hook<S> {
  /// Creates a hook that builds [joltEffect] once per hook slot.
  const JoltEffectHook(this.joltEffect, {super.keys})
      : assert(joltEffect is Effect Function() ||
            joltEffect is FlutterEffect Function() ||
            joltEffect is Watcher Function() ||
            joltEffect is EffectScope Function());

  /// Builds the effect node for this hook slot.
  final S Function() joltEffect;

  @override
  JoltEffectHookState<S> createState() => JoltEffectHookState();
}

/// The [HookState] for [JoltEffectHook].
class JoltEffectHookState<S extends Object>
    extends HookState<S, JoltEffectHook<S>> {
  late final _instance = hook.joltEffect();

  @override
  void dispose() {
    if (_instance is DisposableNode) {
      (_instance as DisposableNode).dispose();
    }
  }

  @override
  S build(BuildContext context) => _instance;

  // coverage:ignore-start
  @override
  bool get debugSkipValue => true;

  @override
  String get debugLabel => 'use${hook.joltEffect.runtimeType}';
  // coverage:ignore-end
}

/// A [Hook] that rebuilds a widget when reactive dependencies change.
class JoltWidgetHook<T extends Widget> extends Hook<T> {
  /// Creates a hook that tracks dependencies accessed by [builder].
  const JoltWidgetHook(this.builder, {super.keys, this.debug});

  /// Builds the widget for the current hook slot.
  final T Function() builder;

  /// Optional debug options for the internal [FlutterEffect].
  final JoltDebugOption? debug;

  @override
  JoltWidgetHookState<T> createState() => JoltWidgetHookState();
}

/// The [HookState] for [JoltWidgetHook].
class JoltWidgetHookState<T extends Widget>
    extends HookState<T, JoltWidgetHook<T>> {
  FlutterEffect? _effect;

  @override
  void dispose() {
    _effect?.dispose();
    _effect = null;
  }

  @override
  void initHook() {
    _effect = FlutterEffect(_markNeedsBuild, lazy: true, debug: hook.debug);
  }

  void _markNeedsBuild() {
    final element = context as Element;
    if (element.dirty) return;
    element.markNeedsBuild();
  }

  @override
  T build(BuildContext context) {
    final prevSub = setActiveSub((_effect as EffectImpl).raw);
    try {
      return hook.builder();
    } finally {
      setActiveSub(prevSub);
    }
  }

  // coverage:ignore-start
  @override
  bool get debugSkipValue => true;

  @override
  String get debugLabel => 'useJoltWidget';
  // coverage:ignore-end
}

/// A [Hook] that wraps a cancellable [Until] future.
class JoltUntilHook<T> extends Hook<Until<T>> {
  /// Creates a hook that builds [until] once per hook slot.
  const JoltUntilHook(this.until, {super.keys});

  /// Builds the [Until] instance for this hook slot.
  final Until<T> Function() until;

  @override
  JoltUntilHookState<T> createState() => JoltUntilHookState();
}

/// The [HookState] for [JoltUntilHook].
class JoltUntilHookState<T> extends HookState<Until<T>, JoltUntilHook<T>> {
  late final Until<T> _until = hook.until();

  @override
  void dispose() {
    _until.cancel();
  }

  @override
  Until<T> build(BuildContext context) => _until;

  // coverage:ignore-start
  @override
  bool get debugSkipValue => true;

  @override
  String get debugLabel => 'useUntil';
  // coverage:ignore-end
}
