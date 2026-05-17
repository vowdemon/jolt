import "package:shared_interfaces/shared_interfaces.dart";

import "package:jolt/core.dart";

export './impl/effect.dart' show onEffectCleanup;

/// Interface for reactive effects that run when dependencies change.
///
/// Effects are side-effect functions that run in response to reactive state
/// changes. They automatically track their dependencies and re-run when
/// any dependency changes.
///
/// Nested effects created inside an effect are not automatically disposed when
/// the parent effect is disposed. The caller is responsible for managing the
/// lifecycle of nested effects.
///
/// Example:
/// ```dart
/// Effect effect = Effect(() {
///   print('Count: ${count.value}');
/// });
/// effect.run(); // Manually trigger
/// effect.dispose(); // Stop the effect
/// ```
abstract class Effect implements DisposableNode {
  /// {@macro jolt_effect_impl}
  factory Effect(
    void Function() fn, {
    bool lazy,
    bool detach,
    JoltDebugOption? debug,
  }) = EffectImpl;

  /// {@macro jolt_effect_impl.lazy}
  factory Effect.lazy(void Function() fn,
      {bool detach, JoltDebugOption? debug}) = EffectImpl.lazy;

  /// Manually runs the effect function.
  ///
  /// This establishes the effect as the current reactive context,
  /// allowing it to track dependencies accessed during execution.
  ///
  /// Example:
  /// ```dart
  /// effect.run(); // Triggers the effect
  /// ```
  void run();

  /// Registers a cleanup function to be called when the effect is disposed or re-run.
  ///
  /// Parameters:
  /// - [fn]: The cleanup function to register
  ///
  /// Example:
  /// ```dart
  /// effect.onCleanup(() => subscription.cancel());
  /// ```
  void onCleanup(Disposer fn);

  @override
  bool get isDisposed;
}
