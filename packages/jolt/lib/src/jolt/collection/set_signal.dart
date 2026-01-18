import "dart:collection";

import "package:jolt/core.dart";

import "package:jolt/src/jolt/base.dart";
import "package:jolt/src/jolt/signal.dart";

/// A mixin that provides reactive set functionality.
///
/// This mixin implements all Set operations while maintaining reactivity.
/// Any modification to the set will automatically notify subscribers.
/// All mutating operations trigger change notifications.
mixin SetSignalMixin<E>
    implements SetBase<E>, Readable<Set<E>>, IMutableCollection, Notifiable {
  /// Returns true if the set contains the given element.
  ///
  /// This is a non-mutating query operation.
  @override
  bool contains(Object? element) => value.contains(element);

  /// Returns a view of this set as having [R] elements.
  ///
  /// This is a non-mutating operation that returns a new view of the set.
  @override
  Set<R> cast<R>() => value.cast<R>();

  /// Applies the given function to each element in the set.
  ///
  /// This is a non-mutating iteration operation.
  @override
  void forEach(void Function(E element) action) {
    value.forEach(action);
  }

  /// Whether this set is empty.
  @override
  bool get isEmpty => value.isEmpty;

  /// Whether this set is not empty.
  @override
  bool get isNotEmpty => value.isNotEmpty;

  /// Removes the given element from the set.
  ///
  /// Returns true if the element was removed, false if it wasn't present.
  /// Only notifies subscribers if the element was actually removed.
  @override
  bool remove(Object? element) {
    final result = value.remove(element);
    if (result) {
      notify(true);
    }
    return result;
  }

  /// The number of elements in this set.
  @override
  int get length => value.length;

  /// Returns a new set containing all elements in this set and [other].
  ///
  /// This is a non-mutating operation that creates a new set.
  @override
  Set<E> union(Set<E> other) => value.union(other);

  /// Returns a new set containing elements present in both this set and [other].
  ///
  /// This is a non-mutating operation that creates a new set.
  @override
  Set<E> intersection(Set<Object?> other) => value.intersection(other);

  /// Returns true if any element satisfies the given test.
  ///
  /// This is a non-mutating query operation.
  @override
  bool any(bool Function(E element) test) => value.any(test);

  /// Returns true if this set contains all elements in [other].
  ///
  /// This is a non-mutating query operation.
  @override
  bool containsAll(Iterable<Object?> other) => value.containsAll(other);

  /// Returns a new set with elements in this set that are not in [other].
  ///
  /// This is a non-mutating operation that creates a new set.
  @override
  Set<E> difference(Set<Object?> other) => value.difference(other);

  /// Returns the element at the given index.
  ///
  /// Since sets are unordered, the index is based on iteration order.
  @override
  E elementAt(int index) => value.elementAt(index);

  /// Expands each element into zero or more elements.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<R> expand<R>(Iterable<R> Function(E element) f) => value.expand(f);

  /// Returns true if every element satisfies the given test.
  ///
  /// This is a non-mutating query operation.
  @override
  bool every(bool Function(E element) test) => value.every(test);

  /// Returns the first element that satisfies the given test.
  ///
  /// This is a non-mutating query operation.
  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  /// Reduces the set to a single value by iteratively combining elements.
  ///
  /// This is a non-mutating operation.
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      value.fold(initialValue, combine);

  /// Returns an iterable of this set followed by [other].
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  /// Joins all elements into a string separated by [separator].
  ///
  /// This is a non-mutating operation.
  @override
  String join([String separator = ""]) => value.join(separator);

  /// Returns the last element that satisfies the given test.
  ///
  /// This is a non-mutating query operation.
  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  /// Returns the element equal to [element], if present.
  ///
  /// This is a non-mutating query operation specific to sets.
  @override
  E? lookup(Object? element) => value.lookup(element);

  /// The first element of the set.
  @override
  E get first => value.first;

  /// The last element of the set.
  @override
  E get last => value.last;

  /// The single element of the set.
  ///
  /// Throws if the set is empty or has more than one element.
  @override
  E get single => value.single;

  /// Returns an iterator over the elements of this set.
  @override
  Iterator<E> get iterator => value.iterator;

  /// Returns an iterable with elements transformed by the given function.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<T> map<T>(T Function(E element) f) => value.map(f);

  /// Returns a new set containing the same elements as this set.
  ///
  /// This is a non-mutating operation that creates a new set.
  @override
  Set<E> toSet() => value.toSet();

  /// Reduces the set to a single value using the given combine function.
  ///
  /// This is a non-mutating operation.
  @override
  E reduce(E Function(E value, E element) combine) => value.reduce(combine);

  /// Returns an iterable that skips the first [n] elements.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<E> skip(int n) => value.skip(n);

  /// Returns an iterable that skips elements while [test] returns true.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<E> skipWhile(bool Function(E element) test) => value.skipWhile(test);

  /// Returns an iterable with at most [count] elements.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<E> take(int count) => value.take(count);

  /// Returns an iterable that takes elements while [test] returns true.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<E> takeWhile(bool Function(E element) test) => value.takeWhile(test);

  /// Returns a list containing the elements of this set.
  ///
  /// This is a non-mutating operation that creates a new list.
  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  /// Returns an iterable containing only elements of type [T].
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<T> whereType<T>() => value.whereType<T>();

  /// Returns the single element that satisfies the given test.
  ///
  /// This is a non-mutating query operation.
  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.singleWhere(test, orElse: orElse);

  /// Returns an iterable containing elements that satisfy the given test.
  ///
  /// This is a non-mutating operation that returns an iterable.
  @override
  Iterable<E> where(bool Function(E element) test) => value.where(test);

  /// Adds the given element to this set.
  ///
  /// Returns true if the element was added, false if it was already present.
  /// Only notifies subscribers if the element was actually added.
  @override
  bool add(E element) {
    final result = peek.add(element);
    if (result) {
      notify(true);
    }
    return result;
  }

  /// Adds all elements from the given iterable to this set.
  ///
  /// Elements already present in the set are not added again.
  /// Notifies subscribers if any elements were added.
  @override
  void addAll(Iterable<E> other) {
    _checkLength(() => peek.addAll(other));
  }

  /// Removes all elements from the set.
  ///
  /// Notifies subscribers of the change.
  @override
  void clear() {
    _checkLength(() => peek.clear());
  }

  /// Removes all elements that satisfy the given test.
  ///
  /// Notifies subscribers after removal.
  @override
  void removeWhere(bool Function(E element) test) {
    _checkLength(() => peek.removeWhere(test));
  }

  /// Removes all elements in [other] from this set.
  ///
  /// Notifies subscribers after removal.
  @override
  void removeAll(Iterable<Object?> other) {
    _checkLength(() => peek.removeAll(other));
  }

  /// Removes all elements that do not satisfy the given test.
  ///
  /// Notifies subscribers after removal.
  @override
  void retainWhere(bool Function(E element) test) {
    _checkLength(() => peek.retainWhere(test));
  }

  /// Removes all elements not in [other] from this set.
  ///
  /// Notifies subscribers after removal.
  @override
  void retainAll(Iterable<Object?> other) {
    _checkLength(() => peek.retainAll(other));
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  T _checkLength<T>(T Function() fn) {
    final originLength = peek.length;
    final result = fn();
    if (originLength != peek.length) {
      notify(true);
    }
    return result;
  }
}

/// Implementation of [SetSignal] that automatically notifies subscribers when modified.
///
/// This is the concrete implementation of the [SetSignal] interface. SetSignal
/// extends Signal to provide full Set functionality while maintaining reactivity.
/// All set operations (add, remove, clear, etc.) will trigger notifications
/// to subscribers.
///
/// See [SetSignal] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final tags = SetSignal<String>({'dart', 'flutter'});
///
/// Effect(() => print('Tags: ${tags.join(', ')} (${tags.length} total)'));
/// // Prints: "Tags: dart, flutter (2 total)"
///
/// tags.add('reactive');
/// // Prints: "Tags: dart, flutter, reactive (3 total)"
///
/// tags.add('dart'); // No change since 'dart' already exists
/// // No notification triggered
///
/// tags.remove('flutter');
/// // Prints: "Tags: dart, reactive (2 total)"
///
/// tags.addAll(['web', 'mobile']);
/// // Prints: "Tags: dart, reactive, web, mobile (4 total)"
///
/// tags.clear();
/// // Prints: "Tags:  (0 total)"
/// ```
class SetSignalImpl<E> extends SignalImpl<Set<E>>
    with SetSignalMixin<E>
    implements SetSignal<E> {
  /// Creates a reactive set signal with the given initial set.
  ///
  /// Parameters:
  /// - [value]: Initial set content, defaults to empty set if null
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final emptySet = SetSignal<String>(null); // Creates empty set
  /// final tags = SetSignal({'dart', 'flutter'});
  /// final autoSet = SetSignal({'tag1', 'tag2'});
  /// ```
  SetSignalImpl(Set<E>? value, {super.debug}) : super(value ?? {});
}

/// Interface for reactive set signals.
///
/// SetSignal extends Signal to provide full Set functionality while
/// maintaining reactivity. All set operations (add, remove, clear, etc.)
/// will trigger notifications to subscribers.
///
/// Example:
/// ```dart
/// SetSignal<String> tags = SetSignal({'dart', 'flutter'});
///
/// Effect(() => print('Tags: ${tags.join(', ')}'));
/// tags.add('reactive'); // Triggers effect
/// ```
abstract interface class SetSignal<E>
    implements Signal<Set<E>>, SetSignalMixin<E> {
  /// Creates a reactive set signal with the given initial set.
  ///
  /// Parameters:
  /// - [value]: Initial set content, defaults to empty set if null
  /// - [debug]: Optional debug options
  ///
  /// Example:
  /// ```dart
  /// final emptySet = SetSignal<String>(null); // Creates empty set
  /// final tags = SetSignal({'dart', 'flutter'});
  /// ```
  factory SetSignal(Set<E>? value, {JoltDebugOption? debug}) = SetSignalImpl<E>;
}
