import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:jolt/jolt.dart';

/// A Flutter hook that wraps Jolt reactive values.
///
/// This hook provides integration between Jolt's reactive system and Flutter's
/// hook system, ensuring proper lifecycle management and automatic disposal.
///
/// Type parameters:
/// - [T]: The type of the reactive value
/// - [S]: The specific reactive value type (extends [JReadonlyValue<T>])
class JoltHook<T, S extends JReadonlyValue<T>> extends Hook<S> {
  /// Creates a Jolt hook with the given reactive value.
  ///
  /// Parameters:
  /// - [jolt]: The reactive value to wrap
  /// - [keys]: Optional keys for hook memoization
  const JoltHook(this.jolt, {super.keys});

  /// The reactive value wrapped by this hook.
  final S jolt;

  @override
  JoltHookState<T, S> createState() => JoltHookState();
}

/// The state class for [JoltHook].
///
/// Manages the lifecycle of the wrapped reactive value, ensuring proper
/// disposal when the hook is removed from the widget tree.
class JoltHookState<T, S extends JReadonlyValue<T>>
    extends HookState<S, JoltHook<T, S>> {
  late final _instance = hook.jolt;

  @override
  void dispose() {
    _instance.dispose();
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

/// A Flutter hook that wraps Jolt effect nodes.
///
/// This hook provides integration between Jolt's effect system and Flutter's
/// hook system, ensuring proper lifecycle management for effects, watchers,
/// and effect scopes.
///
/// Type parameters:
/// - [T]: The type parameter for the effect
/// - [S]: The specific effect node type (extends [EffectBaseNode])
class JoltEffectHook<S extends EffectBaseNode> extends Hook<S> {
  /// Creates a Jolt effect hook with the given effect node.
  ///
  /// Parameters:
  /// - [joltEffect]: The effect node to wrap
  /// - [keys]: Optional keys for hook memoization
  const JoltEffectHook(this.joltEffect, {super.keys});

  /// The effect node wrapped by this hook.
  final S joltEffect;

  @override
  JoltEffectHookState<S> createState() => JoltEffectHookState();
}

/// The state class for [JoltEffectHook].
///
/// Manages the lifecycle of the wrapped effect node, ensuring proper
/// disposal when the hook is removed from the widget tree.
class JoltEffectHookState<S extends EffectBaseNode>
    extends HookState<S, JoltEffectHook<S>> {
  late final _instance = hook.joltEffect;

  @override
  void dispose() {
    _instance.dispose();
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

/// A Flutter hook that wraps Jolt effect nodes.
///
/// This hook provides integration between Jolt's effect system and Flutter's
/// hook system, ensuring proper lifecycle management for effects, watchers,
/// and effect scopes.
///
/// Type parameters:
/// - [T]: The type parameter for the effect
/// - [S]: The specific effect node type (extends [EffectBaseNode])
class JoltWidgetHook<T extends Widget> extends Hook<T> {
  /// Creates a Jolt effect hook with the given effect node.
  ///
  /// Parameters:
  /// - [joltEffect]: The effect node to wrap
  /// - [keys]: Optional keys for hook memoization
  const JoltWidgetHook(this.builder, {super.keys});

  /// The effect node wrapped by this hook.
  final T Function() builder;

  @override
  JoltWidgetHookState<T> createState() => JoltWidgetHookState();
}

/// The state class for [JoltWidgetHook].
///
/// Manages the lifecycle of the wrapped effect node, ensuring proper
/// disposal when the hook is removed from the widget tree.
class JoltWidgetHookState<T extends Widget>
    extends HookState<T, JoltWidgetHook<T>> {
  Effect? _effect;
  T? _lastBuiltWidget;

  @override
  void dispose() {
    _effect?.dispose();
    _effect = null;
    _lastBuiltWidget = null;
  }

  @override
  void initHook() {
    _effect = Effect(_effectFn, immediately: false);
  }

  void _effectFn() {
    setState(() {
      _lastBuiltWidget = hook.builder();
    });
  }

  @override
  T build(BuildContext context) {
    if (_lastBuiltWidget == null) {
      _effect!.run();
    }
    return _lastBuiltWidget!;
  }

  // coverage:ignore-start
  @override
  bool get debugSkipValue => true;

  @override
  String get debugLabel => 'useJoltWidget';
  // coverage:ignore-end
}
