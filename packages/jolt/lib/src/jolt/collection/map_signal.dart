import "dart:collection";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

/// A mixin that provides reactive map functionality.
///
/// This mixin implements all Map operations while maintaining reactivity.
/// Any modification to the map will automatically notify subscribers.
/// All mutating operations trigger change notifications.
mixin MapSignalMixin<K, V>
    implements MapBase<K, V>, Readonly<Map<K, V>>, IMutableCollection {
  /// Gets the value associated with the given key.
  ///
  /// Returns the value for the given key, or null if the key is not present.
  /// This operation does not trigger reactivity when used for reading.
  @override
  V? operator [](Object? key) => value[key];

  /// Sets the value associated with the given key.
  ///
  /// Updates the map with the key-value pair and notifies all subscribers.
  /// This operation triggers reactive updates.
  @override
  void operator []=(K key, V value) {
    this.value[key] = value;
    notify();
  }

  /// Adds all key-value pairs from the given map to this map.
  ///
  /// All entries from [other] are added to this map, overwriting any
  /// existing entries with the same keys. Notifies subscribers after update.
  @override
  void addAll(Map<K, V> other) {
    value.addAll(other);
    notify();
  }

  /// Adds all entries from the given iterable to this map.
  ///
  /// Each entry in [newEntries] is added to this map, overwriting any
  /// existing entries with the same keys. Notifies subscribers after update.
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    value.addEntries(newEntries);
    notify();
  }

  /// Returns a view of this map as having [RK] keys and [RV] instances.
  ///
  /// This is a non-mutating operation that returns a new view of the map.
  @override
  Map<RK, RV> cast<RK, RV>() => value.cast<RK, RV>();

  /// Removes all entries from the map.
  ///
  /// Clears all key-value pairs and notifies subscribers of the change.
  @override
  void clear() {
    value.clear();
    notify();
  }

  /// Returns true if this map contains the given key.
  ///
  /// This is a non-mutating query operation.
  @override
  bool containsKey(Object? key) => value.containsKey(key);

  /// Returns true if this map contains the given value.
  ///
  /// This is a non-mutating query operation that searches through all values.
  @override
  bool containsValue(Object? targetValue) => value.containsValue(targetValue);

  /// Applies the given function to each key-value pair in the map.
  ///
  /// This is a non-mutating iteration operation.
  @override
  void forEach(void Function(K key, V value) action) {
    value.forEach(action);
  }

  /// Whether this map is empty.
  @override
  bool get isEmpty => value.isEmpty;

  /// Whether this map is not empty.
  @override
  bool get isNotEmpty => value.isNotEmpty;

  /// The keys of this map.
  ///
  /// Returns an iterable of all keys in the map.
  @override
  Iterable<K> get keys => value.keys;

  /// Look up the value of [key], or add a new entry if it isn't there.
  ///
  /// If [key] is present, returns its value. Otherwise, calls [ifAbsent]
  /// to get a new value, adds the key-value pair, and returns the new value.
  /// Notifies subscribers if a new entry is added.
  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final v = value.putIfAbsent(key, ifAbsent);
    notify();
    return v;
  }

  /// Removes the entry for the given key and returns its value.
  ///
  /// Returns the value associated with [key], or null if [key] is not present.
  /// Notifies subscribers if an entry was removed.
  @override
  V? remove(Object? key) {
    final v = value.remove(key);
    notify();
    return v;
  }

  /// The number of key-value pairs in the map.
  @override
  int get length => value.length;

  /// Updates the value for the given key.
  ///
  /// If [key] is present, updates its value by calling [update] with the
  /// current value. If [key] is not present and [ifAbsent] is provided,
  /// adds the key with the value returned by [ifAbsent].
  /// Notifies subscribers after the update.
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final v = value.update(key, update, ifAbsent: ifAbsent);
    notify();
    return v;
  }

  /// Updates all values in the map.
  ///
  /// Calls [update] for each key-value pair and updates the value with
  /// the returned result. Notifies subscribers after all updates.
  @override
  void updateAll(V Function(K key, V value) update) {
    value.updateAll(update);
    notify();
  }

  /// Removes all entries that satisfy the given test.
  ///
  /// Calls [test] for each key-value pair and removes entries where
  /// [test] returns true. Notifies subscribers after removal.
  @override
  void removeWhere(bool Function(K key, V value) test) {
    value.removeWhere(test);
    notify();
  }

  /// The values of this map.
  ///
  /// Returns an iterable of all values in the map.
  @override
  Iterable<V> get values => value.values;

  /// Returns a new map where each entry is transformed by the given function.
  ///
  /// This is a non-mutating operation that creates a new map.
  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) =>
      value.map(convert);

  /// The map entries of this map.
  ///
  /// Returns an iterable of all key-value pairs as MapEntry objects.
  @override
  Iterable<MapEntry<K, V>> get entries => value.entries;
}

/// Implementation of [MapSignal] that automatically notifies subscribers when modified.
///
/// This is the concrete implementation of the [MapSignal] interface. MapSignal
/// extends Signal to provide full Map functionality while maintaining reactivity.
/// All map operations (put, remove, clear, etc.) will trigger notifications
/// to subscribers.
///
/// See [MapSignal] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final userMap = MapSignal<String, dynamic>({'name': 'Alice', 'age': 30});
///
/// Effect(() => print('User: ${userMap['name']}, Age: ${userMap['age']}'));
/// // Prints: "User: Alice, Age: 30"
///
/// userMap['name'] = 'Bob';
/// // Prints: "User: Bob, Age: 30"
///
/// userMap['city'] = 'New York';
/// // Prints: "User: Bob, Age: 30" (if city is not used in effect)
///
/// userMap.addAll({'age': 25, 'country': 'USA'});
/// // Prints: "User: Bob, Age: 25"
///
/// userMap.clear();
/// // Prints: "User: null, Age: null"
/// ```
class MapSignalImpl<K, V> extends SignalImpl<Map<K, V>>
    with MapSignalMixin<K, V>
    implements MapSignal<K, V> {
  /// Creates a reactive map signal with the given initial map.
  ///
  /// Parameters:
  /// - [value]: Initial map content, defaults to empty map if null
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final emptyMap = MapSignal<String, int>(null); // Creates empty map
  /// final userMap = MapSignal({'name': 'Alice', 'age': 30});
  /// final autoMap = MapSignal({'key': 'value'});
  /// ```
  MapSignalImpl(Map<K, V>? value, {super.onDebug}) : super(value ?? {});
}

/// Interface for reactive map signals.
///
/// MapSignal extends Signal to provide full Map functionality while
/// maintaining reactivity. All map operations (put, remove, clear, etc.)
/// will trigger notifications to subscribers.
///
/// Example:
/// ```dart
/// MapSignal<String, dynamic> userMap = MapSignal({'name': 'Alice', 'age': 30});
///
/// Effect(() => print('User: ${userMap['name']}'));
/// userMap['name'] = 'Bob'; // Triggers effect
/// ```
abstract interface class MapSignal<K, V>
    implements Signal<Map<K, V>>, MapSignalMixin<K, V> {
  /// Creates a reactive map signal with the given initial map.
  ///
  /// Parameters:
  /// - [value]: Initial map content, defaults to empty map if null
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final emptyMap = MapSignal<String, int>(null); // Creates empty map
  /// final userMap = MapSignal({'name': 'Alice', 'age': 30});
  /// ```
  factory MapSignal(Map<K, V>? value, {JoltDebugFn? onDebug}) =
      MapSignalImpl<K, V>;
}
