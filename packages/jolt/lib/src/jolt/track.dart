import "package:jolt/core.dart";

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
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T untracked<T>(T Function() fn) {
  final prevSub = setActiveSub(null);
  try {
    return fn();
  } finally {
    setActiveSub(prevSub);
  }
}

/// Executes a function and notifies all dependencies of changes.
///
/// This function creates a temporary reactive context, executes the function,
/// and then notifies all dependencies that were accessed during execution.
/// This is useful for triggering updates without actually changing values.
///
/// Parameters:
/// - [fn]: Function to execute
///
/// Returns: The result of the function execution
///
/// Example:
/// ```dart
/// notifyAll(() {
///   // Access signals to trigger their subscribers
///   final value = signal.value;
/// });
/// ```
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T triggerTracked<T>(T Function() fn) => trigger(fn);
