import "package:shared_interfaces/shared_interfaces.dart";

import "package:jolt/core.dart";

export './impl/effect.dart' show onEffectCleanup;

/// A reactive side effect that re-runs when its tracked dependencies change.
///
/// Nested effects created inside an effect are not automatically disposed when
/// the parent effect is disposed. The caller is responsible for managing the
/// lifecycle of nested effects.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// final effect = Effect(() {
///   print('Count: ${count.value}');
/// });
///
/// count.value = 1;
/// effect.dispose();
/// ```
/// {@category React To State Changes}
abstract class Effect implements DisposableNode {
  /// Creates an effect from [fn].
  ///
  /// The [fn] callback tracks the reactive values it reads. When [lazy] is
  /// `false`, this effect runs immediately and then re-runs after tracked
  /// dependencies change. Set [detach] to keep this effect out of the current
  /// [EffectScope].
  factory Effect(
    void Function() fn, {
    bool lazy,
    bool detach,
    JoltDebugOption? debug,
  }) = EffectImpl;

  /// Creates an effect that does not run until [run] is called.
  ///
  /// The [fn] callback starts tracking dependencies on the first manual run.
  /// Set [detach] to keep this effect out of the current [EffectScope].
  factory Effect.lazy(void Function() fn,
      {bool detach, JoltDebugOption? debug}) = EffectImpl.lazy;

  /// Manually runs the effect function.
  ///
  /// This marks the effect dirty and executes it with dependency tracking.
  /// Calling [run] after disposal fails in debug builds.
  void run();

  /// Registers a cleanup callback for this effect.
  ///
  /// The [fn] callback runs before this effect re-runs and when this effect
  /// disposes.
  void onCleanup(Disposer fn);

  @override
  bool get isDisposed;
}
