import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

/// Implementation of [EffectScope] for managing the lifecycle of effects and other reactive nodes.
///
/// This is the concrete implementation of the [EffectScope] interface. EffectScope
/// allows you to group related effects together and dispose them all at once.
/// It's useful for component-based architectures where you want to clean up
/// all effects when a component is destroyed.
///
/// See [EffectScope] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final scope = EffectScope()
///   ..run(() {
///     final signal = Signal(0);
///     Effect(() => print('Value: ${signal.value}'));
///
///     // Both signal and effect will be disposed when scope is disposed
///   });
///
/// // Later, dispose all effects in the scope
/// scope.dispose();
/// ```
class EffectScopeImpl implements EffectScope {
  final EffectScopeNode raw;

  /// Creates a new effect scope.
  ///
  /// Parameters:
  /// - [detach]: Whether to detach this scope from its parent scope. If true,
  ///   the scope will not be automatically disposed when its parent is disposed.
  ///   Defaults to false.
  /// - [debug]: Optional debug options
  ///
  /// The scope is automatically linked to its parent scope (if any) unless
  /// [detach] is true. Use [run] to execute code within the scope context.
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope()
  ///   ..run(() {
  ///     final signal = Signal(0);
  ///     Effect(() => print(signal.value));
  ///
  ///     // Register cleanup function
  ///     onScopeDispose(() => print('Scope disposed'));
  ///   });
  /// ```
  EffectScopeImpl({bool detach = false, JoltDebugOption? debug})
      : raw = EffectScopeNode(detach: detach, debug: debug);

  /// Runs a function within this scope's context.
  ///
  /// Parameters:
  /// - [fn]: Function to execute within the scope
  ///
  /// Returns: The result of the function execution
  ///
  /// Example:
  /// ```dart
  /// final scope = EffectScope();
  ///
  /// final result = scope.run(() {
  ///   final signal = Signal(42);
  ///   return signal.value;
  /// });
  /// ```
  @override
  T run<T>(T Function() fn) => raw.run(fn);

  @override
  void dispose() => raw.dispose();

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  void onCleanup(Disposer fn) => raw.onCleanup(fn);
}

/// Registers a cleanup function to be executed when the current effect scope is disposed.
///
/// Parameters:
/// - [fn]: The cleanup function to register
/// - [owner]: Optional effect scope owner. If not provided, automatically detects
///   the current active effect scope from the reactive context.
///
/// This function can only be called within an effect scope context. The cleanup
/// function will be executed when the effect scope is disposed.
///
/// Example:
/// ```dart
/// final scope = EffectScope()
///   ..run(() {
///     final subscription = someStream.listen((data) {});
///     onScopeDispose(() => subscription.cancel());
///   });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
void onScopeDispose(Disposer fn, {EffectScope? owner}) {
  final e = owner ?? getActiveScope();

  assert(e is EffectScope || e is EffectScopeNode,
      "Cannot add cleanup on a non-effect scope");
  if (e is EffectScopeNode) {
    e.onCleanup(fn);
  } else if (e is EffectScope) {
    e.onCleanup(fn);
  }
}
