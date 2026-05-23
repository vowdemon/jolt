import "dart:collection";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

/// In-place [Map] mutations for a [Signal] holding a [Map].
///
/// Read operations delegate to [value] and track dependencies. Mutations update
/// the backing map through [peek] and call [notify] when entries change.
/// See [MapSignal] for the public writable map signal type.
mixin MapSignalMixin<K, V>
    implements MapBase<K, V>, Readable<Map<K, V>>, Notifiable {
  /// Looks up the value for [key] in the current map.
  ///
  /// Reads through [value], so reactive consumers track this access.
  @override
  V? operator [](Object? key) => value[key];

  /// Returns a view of this map as having [RK] keys and [RV] instances.
  ///
  /// This is a non-mutating operation that returns a new view of the map.
  @override
  Map<RK, RV> cast<RK, RV>() => value.cast<RK, RV>();

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

  /// The number of key-value pairs in the map.
  @override
  int get length => value.length;

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

  /// Sets the value associated with the given key.
  ///
  /// Updates the map with the key-value pair and notifies all subscribers.
  /// This operation triggers reactive updates.
  @override
  void operator []=(K key, V value) {
    final needNotify = !peek.containsKey(key) || peek[key] != value;
    peek[key] = value;
    if (needNotify) {
      notify();
    }
  }

  /// Adds all key-value pairs from the given map to this map.
  ///
  /// All entries from [other] are added to this map, overwriting any
  /// existing entries with the same keys. Notifies subscribers after update.
  @override
  void addAll(Map<K, V> other) {
    bool needNotify = false;
    other.forEach((key, value) {
      if (!needNotify && (!peek.containsKey(key) || peek[key] != value)) {
        needNotify = true;
      }
      peek[key] = value;
    });

    if (needNotify) {
      notify();
    }
  }

  /// Adds all entries from the given iterable to this map.
  ///
  /// Each entry in [newEntries] is added to this map, overwriting any
  /// existing entries with the same keys. Notifies subscribers after update.
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    bool needNotify = false;
    for (var entry in newEntries) {
      if (!needNotify &&
          (!peek.containsKey(entry.key) || peek[entry.key] != entry.value)) {
        needNotify = true;
      }
      peek[entry.key] = entry.value;
    }

    if (needNotify) {
      notify();
    }
  }

  /// Removes all entries from the map.
  ///
  /// Clears all key-value pairs and notifies subscribers of the change.
  @override
  void clear() {
    if (peek.isEmpty) {
      return;
    } else {
      peek.clear();
      notify();
    }
  }

  /// Look up the value of [key], or add a new entry if it isn't there.
  ///
  /// If [key] is present, returns its value. Otherwise, calls [ifAbsent]
  /// to get a new value, adds the key-value pair, and returns the new value.
  /// Notifies subscribers if a new entry is added.
  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (peek.containsKey(key)) {
      return peek[key] as V;
    }
    final result = peek[key] = ifAbsent();
    notify();
    return result;
  }

  /// Removes the entry for the given key and returns its value.
  ///
  /// Returns the value associated with [key], or null if [key] is not present.
  /// Notifies subscribers if an entry was removed.
  @override
  V? remove(Object? key) {
    if (peek.containsKey(key)) {
      final v = peek.remove(key);
      notify();
      return v;
    } else {
      return peek.remove(key);
    }
  }

  /// Updates the value for the given key.
  ///
  /// If [key] is present, updates its value by calling [update] with the
  /// current value. If [key] is not present and [ifAbsent] is provided,
  /// adds the key with the value returned by [ifAbsent].
  /// Notifies subscribers after the update.
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    if (peek.containsKey(key)) {
      final oldValue = peek[key];
      final newValue = peek[key] = update(oldValue as V);
      if (oldValue != newValue) {
        notify();
      }
      return newValue;
    }
    if (ifAbsent != null) {
      final result = peek[key] = ifAbsent();
      notify();
      return result;
    }
    throw ArgumentError.value(key, "key", "Key not in map.");
  }

  /// Updates all values in the map.
  ///
  /// Calls [update] for each key-value pair and updates the value with
  /// the returned result. Notifies subscribers after all updates.
  @override
  void updateAll(V Function(K key, V value) update) {
    bool needNotify = false;
    for (var key in peek.keys) {
      final oldValue = peek[key];
      final newValue = peek[key] = update(key, oldValue as V);
      if (!needNotify && oldValue != newValue) {
        needNotify = true;
      }
    }
    if (needNotify) {
      notify();
    }
  }

  /// Removes all entries that satisfy the given test.
  ///
  /// Calls [test] for each key-value pair and removes entries where
  /// [test] returns true. Notifies subscribers after removal.
  @override
  void removeWhere(bool Function(K key, V value) test) {
    var keysToRemove = <K>[];
    for (var key in keys) {
      if (test(key, peek[key] as V)) keysToRemove.add(key);
    }
    for (var key in keysToRemove) {
      peek.remove(key);
    }
    if (keysToRemove.isNotEmpty) {
      notify();
    }
  }
}

class _MapSignalImpl<K, V> extends SignalImpl<Map<K, V>>
    with MapSignalMixin<K, V>
    implements MapSignal<K, V> {
  _MapSignalImpl(Map<K, V>? value, {super.debug}) : super(value ?? {});
}

/// A [Signal] that behaves like a mutable [Map] and notifies on in-place edits.
///
/// Use [MapSignal] when subscribers should react to `[]=`, [Map.addAll], and
/// other map mutations without replacing the whole [Signal.value]. For a
/// derived, read-only view, use [IterableSignal] or [Computed] instead.
///
/// Example:
/// ```dart
/// final user = MapSignal({'name': 'Alice', 'age': 30});
///
/// Effect(() => print('User: ${user['name']}'));
/// user['name'] = 'Bob';
/// ```
abstract interface class MapSignal<K, V>
    implements Signal<Map<K, V>>, MapSignalMixin<K, V> {
  /// Creates a map signal with optional initial entries.
  ///
  /// The optional [value] supplies the initial entries. Pass `null` to start
  /// with an empty map.
  ///
  /// Example:
  /// ```dart
  /// final user = MapSignal({'name': 'Alice'});
  /// final empty = MapSignal<String, int>(null);
  /// ```
  factory MapSignal(Map<K, V>? value, {JoltDebugOption? debug}) =
      _MapSignalImpl<K, V>;
}
