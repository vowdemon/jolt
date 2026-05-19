import 'package:jolt/jolt.dart';
import 'package:jolt/core.dart';
import 'package:meta/meta.dart';

export 'package:jolt/src/core/system.dart' show ReactiveNode, ReactiveFlags;

/// A read-only container for a value of type [T].
///
/// [Readable] is the shared read surface for [Signal], [Computed], [Readonly],
/// and other adapters. An implementation may be reactive or not; the interface
/// only describes how to read the current contents, not how updates propagate.
///
/// Use [value] for the usual read path and [peek] when a read must not observe
/// changes. On reactive sources, [value] can register dependencies in effects
/// and computed values, while [peek] always reads without tracking.
///
/// Example:
/// ```dart
/// void log<T>(Readable<T> source) {
///   print(source.peek);
///   print(source.value);
/// }
/// ```
abstract interface class Readable<T> {
  /// Returns the current value using this source's normal read semantics.
  ///
  /// Reactive implementations notify the active subscriber when read inside
  /// an effect or computed value. Non-reactive implementations simply return
  /// the stored value.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final doubled = Computed(() => count.value * 2);
  /// ```
  T get value;

  /// Returns the current value without subscribing to later updates.
  ///
  /// On reactive sources, use this to avoid establishing a dependency. On fixed
  /// containers such as [Readonly], [peek] and [value] return the same result.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final snapshot = count.peek;
  /// ```
  T get peek;
}

/// A reactive value that can trigger notifications without replacing its contents.
///
/// Example:
/// ```dart
/// final list = ListSignal([1, 2, 3]);
/// list.value.add(4); // Mutation doesn't auto-notify
/// list.notify(); // Manually trigger notification
/// ```
abstract interface class Notifiable {
  /// Triggers a change notification without modifying this value.
  ///
  /// Use this after in-place mutations or when subscribers should re-evaluate
  /// even though the stored reference did not change.
  void notify();
}

/// A read/write container for a value of type [T].
///
/// Extends [Readable] with a [value] setter. Reactive implementations such as
/// [Signal] notify subscribers when the assigned value changes.
///
/// Example:
/// ```dart
/// final count = Signal(0);
/// count.value = 42;
/// print(count.value);
/// ```
abstract interface class Writable<T> implements Readable<T> {
  /// Sets a new value and notifies subscribers if changed.
  ///
  /// The assigned [value] becomes this container's current contents. Reactive
  /// implementations notify subscribers when the new value is observed as
  /// different from the previous one.
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// count.value = 10; // Notifies subscribers
  /// ```
  set value(T value);
}

/// A reactive graph node that can be disposed and detached from the system.
///
/// Disposing marks the node inactive, unlinks dependencies and subscribers, and
/// runs any registered cleanup. Implementations are used by effects, scopes,
/// and custom nodes built on the core graph.
abstract interface class DisposableNode implements Disposable {
  /// Whether this node has been disposed.
  bool get isDisposed;

  /// Disposes this node and cleans up resources.
  ///
  /// Marks the node as disposed; it is no longer reactive and will not
  /// participate in updates or propagation. Implementations may also detach
  /// dependencies, subscribers, and registered cleanup.
  @mustCallSuper
  @override
  void dispose();
}

/// Compares a computed result with its previous value for equality.
///
/// Return `true` when the values should be treated as equal so downstream
/// nodes can skip notification. The [value] argument is the newly computed
/// value. The [previous] argument is the cached value from the prior run, or
/// `null` on the first run.
///
/// Example:
/// ```dart
/// final len = Computed(
///   () => items.value.length,
///   equals: (value, previous) => value == previous,
/// );
/// ```
typedef ComputedEqualsFn = bool Function(dynamic value, dynamic previous);
