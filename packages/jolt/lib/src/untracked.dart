import 'effect.dart';
import 'reactive.dart';

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
T _untracked<T, P>(
  P? Function(P?) setPrev,
  T Function() fn,
) {
  final prev = setPrev(null);
  try {
    return fn();
  } finally {
    setPrev(prev);
  }
}

/// Executes a function without tracking reactive dependencies.
///
/// When called within a reactive context (like an Effect or Computed),
/// any reactive values accessed inside the untracked function will not
/// be tracked as dependencies. This is useful for accessing values that
/// should not trigger re-runs.
///
/// Parameters:
/// - [fn]: Function to execute without dependency tracking
///
/// Returns: The result of the function execution
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// final name = Signal('Alice');
///
/// final computed = Computed(() {
///   final currentCount = count.value; // Tracked dependency
///   final currentName = untracked(() => name.value); // Not tracked
///   return 'Count: $currentCount, Name: $currentName';
/// });
///
/// count.value = 1; // Triggers recomputation
/// name.value = 'Bob'; // Does NOT trigger recomputation
/// ```
T untracked<T>(T Function() fn) =>
    _untracked(globalReactiveSystem.setCurrentSub, fn);

/// Executes a function without tracking effect scope dependencies.
///
/// Similar to [untracked], but specifically for effect scope contexts.
/// This is used internally and typically not needed in application code.
///
/// Parameters:
/// - [fn]: Function to execute without scope tracking
///
/// Returns: The result of the function execution
///
/// Example:
/// ```dart
/// final effect = untrackedEffect(() => Effect(() {
///   // This effect won't be tracked by parent scope
///   print('Hello');
/// }));
/// ```
T untrackedEffect<T extends JEffectNode>(T Function() fn) =>
    _untracked(globalReactiveSystem.setCurrentScope, fn);
