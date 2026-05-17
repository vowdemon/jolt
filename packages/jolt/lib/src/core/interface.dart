import 'package:jolt/core.dart';
import 'package:meta/meta.dart';

export 'package:jolt/src/core/system.dart' show ReactiveNode, ReactiveFlags;

abstract interface class Readable<T> {
  /// Gets the current value and establishes a reactive dependency.
  ///
  /// When accessed within a reactive context (Effect, Computed, etc.),
  /// the context will be notified when this value changes.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubled = Computed(() => count.value * 2);
  /// ```
  T get value;

  /// Gets the current value without establishing a reactive dependency.
  ///
  /// Use this when you need to read the value without triggering reactivity.
  ///
  /// Returns: The current value
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final value = count.peek; // Doesn't create dependency
  /// ```
  T get peek;
}

/// Interface for reactive values that can be manually notified.
///
/// Allows triggering change notifications without modifying the value.
/// Useful for in-place mutations or when you want to force subscribers
/// to re-evaluate.
///
/// Example:
/// ```dart
/// final list = ListSignal([1, 2, 3]);
/// list.value.add(4); // Mutation doesn't auto-notify
/// list.notify(); // Manually trigger notification
/// ```
abstract interface class Notifiable {
  /// Triggers a change notification without modifying the value.
  ///
  /// Notifies all subscribers that they should re-evaluate. The behavior
  /// depends on the [force] parameter and the specific implementation:
  ///
  /// - When [force] is `true` (force update), subscribers are notified
  ///   regardless of whether the value changed.
  /// - When [force] is `false` (soft update), subscribers are only notified
  ///   if the value actually changed during recomputation.
  ///
  /// This is useful for scenarios like in-place mutations where the value
  /// reference doesn't change but the content does.
  ///
  /// Parameters:
  /// - [force]: If `true`, forces notification even if the value hasn't changed.
  ///   Defaults to `true`; pass `false` explicitly for a soft update.
  ///
  /// Example:
  /// ```dart
  /// final list = ListSignal([1, 2, 3]);
  /// list.value.add(4); // Mutation doesn't auto-notify
  /// list.notify(); // Force subscribers to update
  ///
  /// final computed = Computed(() => expensiveCalculation());
  /// computed.notify(); // Force update: always notifies subscribers
  /// computed.notify(false); // Soft update: only notifies if value changed
  /// ```
  void notify([bool force = true]);
}

/// Interface for writable reactive values.
///
/// Extends [Readable] to provide write access, allowing values to be
/// both read and modified reactively.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// count.value = 42; // Can modify
/// print(count.value); // Can read
/// ```
abstract interface class Writable<T> implements Readable<T> {
  /// Sets a new value and notifies subscribers if changed.
  ///
  /// Automatically notifies all subscribers when the value changes.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// count.value = 10; // Notifies subscribers
  /// ```
  set value(T value);
}

abstract interface class DisposableNode implements Disposable {
  /// Whether this node has been disposed.
  bool get isDisposed;

  /// Disposes this node and cleans up resources.
  ///
  /// Marks the node as disposed; it is no longer reactive and will not
  /// participate in updates or propagation. Invokes [onDispose] for custom
  /// cleanup and notifies the finalizer system for chained disposers.
  ///
  /// Example:
  /// ```dart
  /// final node = MyDisposableNode();
  /// node.dispose(); // Cleanup happens automatically
  /// ```
  @mustCallSuper
  @override
  void dispose();
}

abstract class CustomReactiveNode<T> implements ReactiveNode {
  bool update();
}

typedef EqualFn = bool Function(dynamic value, dynamic previous);
