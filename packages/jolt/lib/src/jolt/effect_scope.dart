import 'package:jolt/core.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

export './impl/effect_scope.dart' show onScopeDispose;

/// A disposal boundary that groups effects, signals, and scope cleanups.
///
/// Use [EffectScope] to bind related reactive work to a single lifecycle and
/// dispose everything together.
///
/// Example:
/// ```dart
/// EffectScope scope = EffectScope()
///   ..run(() {
///     final signal = Signal(0);
///     Effect(() => print(signal.value));
///   });
/// scope.dispose(); // Disposes all effects in scope
/// ```
abstract class EffectScope implements DisposableNode {
  /// Creates an effect scope.
  ///
  /// The [detach] flag keeps this scope out of the current parent scope so
  /// parent disposal does not dispose it automatically.
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope(detach: true);
  /// ```
  factory EffectScope({
    bool detach,
    JoltDebugOption? debug,
  }) = EffectScopeImpl;

  /// Runs [fn] with this scope set as the active scope.
  ///
  /// The [fn] callback can create effects, signals, and cleanups that should
  /// belong to this scope.
  ///
  /// Example:
  /// ```dart
  /// final result = scope.run(() => 42);
  /// ```
  T run<T>(T Function() fn);

  @override
  bool get isDisposed;

  /// Registers a cleanup function to run when this scope disposes.
  ///
  /// The [fn] callback should release resources owned by this scope.
  ///
  /// Example:
  /// ```dart
  /// scope.onCleanup(() => subscription.cancel());
  /// ```
  void onCleanup(Disposer fn);
}
