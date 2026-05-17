import 'package:jolt/core.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

export './impl/effect_scope.dart' show onScopeDispose;

/// Interface for effect scopes that manage the lifecycle of effects.
///
/// EffectScope allows you to group related effects together and dispose
/// them all at once. It's useful for component-based architectures.
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
  /// Creates a new effect scope.
  ///
  /// Parameters:
  /// - [detach]: Whether to detach this scope from its parent scope
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope(detach: true);
  /// ```
  factory EffectScope({
    bool detach,
    JoltDebugOption? debug,
  }) = EffectScopeImpl;

  /// Runs a function within this scope's context.
  ///
  /// Parameters:
  /// - [fn]: Function to execute within the scope
  ///
  /// Returns: The result of the function execution
  ///
  /// Example:
  /// ```dart
  /// final result = scope.run(() => 42);
  /// ```
  T run<T>(T Function() fn);

  @override
  bool get isDisposed;

  void onCleanup(Disposer fn);
}
