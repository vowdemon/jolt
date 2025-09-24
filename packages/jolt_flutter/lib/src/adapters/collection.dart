import 'package:jolt/jolt.dart' as jolt;

import '../mixins/value_notifier.dart';
import 'signal.dart';

/// A reactive signal that wraps a List and tracks mutations.
///
/// [ListSignal] provides reactive capabilities for List operations, automatically
/// notifying listeners when items are added, removed, or modified. It integrates
/// with Flutter's ValueNotifier system for seamless widget integration.
///
/// ## Parameters
///
/// - [value]: The initial List value
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final todos = ListSignal<String>(['Buy milk', 'Walk dog']);
///
/// JoltBuilder(
///   builder: (context) => ListView.builder(
///     itemCount: todos.value.length,
///     itemBuilder: (context, index) => Text(todos.value[index]),
///   ),
/// )
///
/// // Add item - will trigger reactive rebuild
/// todos.add('Finish project');
/// ```
class ListSignal<E> extends jolt.ListSignal<E>
    with JoltValueNotifier<List<E>>
    implements Signal<List<E>> {
  ListSignal(super.value, {super.autoDispose});
}

/// A reactive signal that wraps a Map and tracks mutations.
///
/// [MapSignal] provides reactive capabilities for Map operations, automatically
/// notifying listeners when key-value pairs are added, removed, or modified.
/// It integrates with Flutter's ValueNotifier system for seamless widget integration.
///
/// ## Parameters
///
/// - [value]: The initial Map value
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final userSettings = MapSignal<String, bool>({
///   'notifications': true,
///   'darkMode': false,
/// });
///
/// JoltBuilder(
///   builder: (context) => Column(
///     children: userSettings.value.entries.map((entry) =>
///       SwitchListTile(
///         title: Text(entry.key),
///         value: entry.value,
///         onChanged: (value) => userSettings[entry.key] = value,
///       ),
///     ).toList(),
///   ),
/// )
/// ```
class MapSignal<K, V> extends jolt.MapSignal<K, V>
    with JoltValueNotifier<Map<K, V>>
    implements Signal<Map<K, V>> {
  MapSignal(super.value, {super.autoDispose});
}

/// A reactive signal that wraps a Set and tracks mutations.
///
/// [SetSignal] provides reactive capabilities for Set operations, automatically
/// notifying listeners when items are added or removed. It integrates with
/// Flutter's ValueNotifier system for seamless widget integration.
///
/// ## Parameters
///
/// - [value]: The initial Set value
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final selectedTags = SetSignal<String>({'flutter', 'dart'});
///
/// JoltBuilder(
///   builder: (context) => Wrap(
///     children: availableTags.map((tag) =>
///       FilterChip(
///         label: Text(tag),
///         selected: selectedTags.value.contains(tag),
///         onSelected: (selected) {
///           if (selected) {
///             selectedTags.add(tag);
///           } else {
///             selectedTags.remove(tag);
///           }
///         },
///       ),
///     ).toList(),
///   ),
/// )
/// ```
class SetSignal<E> extends jolt.SetSignal<E>
    with JoltValueNotifier<Set<E>>
    implements Signal<Set<E>> {
  SetSignal(super.value, {super.autoDispose});
}

/// A computed signal that provides reactive access to Iterable data.
///
/// [IterableSignal] creates a computed signal that derives its value from a
/// getter function. Unlike collection signals, it doesn't track mutations
/// but recalculates when its dependencies change.
///
/// ## Parameters
///
/// - [getter]: Function that returns an Iterable
/// - [autoDispose]: Whether to automatically dispose when no longer referenced
///
/// ## Example
///
/// ```dart
/// final numbers = Signal([1, 2, 3, 4, 5]);
/// final evenNumbers = IterableSignal(() => numbers.value.where((n) => n.isEven));
///
/// JoltBuilder(
///   builder: (context) => Text('Even: ${evenNumbers.value.join(', ')}'),
/// )
///
/// numbers.add(6); // evenNumbers automatically updates to include 6
/// ```
class IterableSignal<E> extends jolt.IterableSignal<E> {
  IterableSignal(super.getter, {super.autoDispose});

  /// Creates an IterableSignal from a static Iterable value.
  ///
  /// This factory constructor provides a convenient way to create an IterableSignal
  /// from a pre-existing Iterable without needing to wrap it in a function.
  ///
  /// ## Parameters
  ///
  /// - [iterable]: The Iterable to wrap
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  ///
  /// ## Returns
  ///
  /// An [IterableSignal] that provides the static Iterable value
  ///
  /// ## Example
  ///
  /// ```dart
  /// final staticList = IterableSignal.value([1, 2, 3, 4, 5]);
  ///
  /// JoltBuilder(
  ///   builder: (context) => Text('Count: ${staticList.value.length}'),
  /// )
  /// ```
  factory IterableSignal.value(Iterable<E> iterable,
      {bool autoDispose = false}) {
    return IterableSignal(() => iterable, autoDispose: autoDispose);
  }
}
