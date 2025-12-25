import "dart:collection";
import "dart:math" show Random;

import "package:jolt/core.dart";

import "package:jolt/src/jolt/base.dart";
import "package:jolt/src/jolt/signal.dart";

/// A mixin that provides reactive list functionality.
///
/// This mixin implements all List operations while maintaining reactivity.
/// Any modification to the list will automatically notify subscribers.
mixin ListSignalMixin<E>
    implements ListBase<E>, Readable<List<E>>, IMutableCollection, Notifiable {
  @override
  int get length => value.length;

  @override
  List<R> cast<R>() => value.cast<R>();

  @override
  E get first => value.first;

  @override
  E get last => value.last;

  @override
  E get single => value.single;

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  Iterable<E> where(bool Function(E element) test) => value.where(test);

  @override
  Iterable<T> whereType<T>() => value.whereType<T>();

  @override
  bool any(bool Function(E element) test) => value.any(test);

  @override
  bool every(bool Function(E element) test) => value.every(test);

  @override
  bool contains(Object? element) => value.contains(element);

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.firstWhere(test, orElse: orElse);

  @override
  int indexOf(Object? element, [int start = 0]) =>
      value.indexOf(element as E, start);

  @override
  int indexWhere(bool Function(E element) test, [int start = 0]) =>
      value.indexWhere(test, start);

  @override
  int lastIndexOf(Object? element, [int? start]) =>
      value.lastIndexOf(element as E, start);

  @override
  int lastIndexWhere(bool Function(E element) test, [int? start]) =>
      value.lastIndexWhere(test, start);

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.lastWhere(test, orElse: orElse);

  @override
  R fold<R>(R initialValue, R Function(R previousValue, E element) combine) =>
      value.fold<R>(initialValue, combine);

  @override
  Iterable<E> followedBy(Iterable<E> other) => value.followedBy(other);

  @override
  Iterable<E> getRange(int start, int end) => value.getRange(start, end);

  @override
  Map<int, E> asMap() => value.asMap();

  @override
  Iterable<R> expand<R>(Iterable<R> Function(E element) toElements) =>
      value.expand<R>(toElements);

  @override
  Iterable<E> get reversed => value.reversed;

  @override
  List<E> sublist(int start, [int? end]) => value.sublist(start, end);

  @override
  E elementAt(int index) => value.elementAt(index);

  @override
  void forEach(void Function(E element) action) {
    value.forEach(action);
  }

  @override
  String join([String separator = ""]) => value.join(separator);

  @override
  Iterable<T> map<T>(T Function(E element) f) => value.map<T>(f);

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      value.singleWhere(test, orElse: orElse);

  @override
  E reduce(E Function(E value, E element) combine) => value.reduce(combine);

  @override
  Iterable<E> skip(int count) => value.skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E value) test) => value.skipWhile(test);

  @override
  Iterable<E> take(int count) => value.take(count);

  @override
  Iterable<E> takeWhile(bool Function(E value) test) => value.takeWhile(test);

  @override
  List<E> toList({bool growable = true}) => value.toList(growable: growable);

  @override
  Set<E> toSet() => value.toSet();

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  List<E> operator +(List<E> other) => value + other;

  @override
  E operator [](int index) => value[index];

  @override
  void operator []=(int index, E value) {
    final oldValue = peek[index];
    peek[index] = value;
    if (oldValue != value) {
      notify();
    }
  }

  @override
  void add(E value) {
    peek.add(value);
    notify();
  }

  @override
  void addAll(Iterable<E> iterable) {
    peek.addAll(iterable);
    notify();
  }

  @override
  void clear() {
    if (peek.isNotEmpty) {
      peek.clear();
      notify();
    }
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    bool needNotify = false;
    E value = fill as E;
    RangeError.checkValidRange(start, end, peek.length);
    for (int i = start; i < end; i++) {
      if (!needNotify && peek[i] != value) {
        needNotify = true;
      }
      peek[i] = value;
    }
    if (needNotify) {
      notify();
    }
  }

  @override
  void insert(int index, E element) {
    peek.insert(index, element);
    notify();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    peek.insertAll(index, iterable);
    notify();
  }

  @override
  bool remove(Object? value) {
    return _checkLength(() => peek.remove(value));
  }

  @override
  E removeAt(int index) {
    return _checkLength(() => peek.removeAt(index));
  }

  @override
  E removeLast() {
    return _checkLength(() => peek.removeLast());
  }

  @override
  void removeRange(int start, int end) {
    _checkLength(() => peek.removeRange(start, end));
  }

  @override
  void removeWhere(bool Function(E element) test) {
    _checkLength(() => peek.removeWhere(test));
  }

  @override
  void replaceRange(int start, int end, Iterable<E> replacements) {
    final oldLength = end - start;

    final iter = replacements.iterator;

    bool needNotify = false;
    int i = 0;

    while (i < oldLength && iter.moveNext()) {
      if (peek[start + i] != iter.current) {
        needNotify = true;
        break;
      }
      i++;
    }

    if (!needNotify && i < oldLength) {
      needNotify = true;
    }

    if (!needNotify && iter.moveNext()) {
      needNotify = true;
    }

    peek.replaceRange(start, end, replacements);

    if (needNotify) notify();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    _checkLength(() => peek.retainWhere(test));
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    final iter = iterable.iterator;
    bool needNotify = false;

    int i = index;

    // First pass: compare
    while (iter.moveNext()) {
      if (!needNotify && peek[i] != iter.current) {
        needNotify = true;
        // DO NOT break, we must continue consuming iterator for alignment
      }
      i++;
    }

    // Second pass: perform mutation
    peek.setAll(index, iterable);

    if (needNotify) notify();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    final iter = iterable.iterator;
    bool changed = false;

    for (int i = 0; i < skipCount; i++) {
      if (!iter.moveNext()) {
        break;
      }
    }

    for (int i = start; i < end; i++) {
      if (!iter.moveNext()) break;

      if (!changed && peek[i] != iter.current) {
        changed = true;
      }
    }

    peek.setRange(start, end, iterable, skipCount);

    if (changed) notify();
  }

  @override
  void shuffle([Random? random]) {
    if (peek.isNotEmpty) {
      peek.shuffle(random);
      notify();
    }
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    if (peek.isNotEmpty) {
      peek.sort(compare);
      notify();
    }
  }

  @override
  set first(E val) {
    final oldValue = peek.first;
    if (oldValue != val) {
      peek.first = val;
      notify();
    }
  }

  @override
  set last(E val) {
    final oldValue = peek.last;
    if (oldValue != val) {
      peek.last = val;
      notify();
    }
  }

  @override
  set length(int value) {
    if (peek.length != value) {
      peek.length = value;
      notify();
    }
  }

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  T _checkLength<T>(T Function() fn) {
    final originLength = peek.length;
    final result = fn();
    if (originLength != peek.length) {
      notify();
    }
    return result;
  }
}

/// Implementation of [ListSignal] that automatically notifies subscribers when modified.
///
/// This is the concrete implementation of the [ListSignal] interface. ListSignal
/// extends Signal to provide full List functionality while maintaining reactivity.
/// All list operations (add, remove, etc.) will trigger notifications to subscribers.
///
/// See [ListSignal] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final items = ListSignal(['apple', 'banana']);
///
/// Effect(() => print('Items: ${items.join(', ')}'));
/// // Prints: "Items: apple, banana"
///
/// items.add('cherry');
/// // Prints: "Items: apple, banana, cherry"
///
/// items[0] = 'orange';
/// // Prints: "Items: orange, banana, cherry"
///
/// items.removeAt(1);
/// // Prints: "Items: orange, cherry"
/// ```
class ListSignalImpl<E> extends SignalImpl<List<E>>
    with ListSignalMixin<E>
    implements ListSignal<E> {
  /// Creates a reactive list signal with the given initial list.
  ///
  /// Parameters:
  /// - [value]: Initial list content, defaults to empty list if null
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final emptyList = ListSignal<String>(null); // Creates empty list
  /// final numbers = ListSignal([1, 2, 3]);
  /// final autoList = ListSignal(['a', 'b']);
  /// ```
  ListSignalImpl(List<E>? value, {super.onDebug}) : super(value ?? []);
}

/// Interface for reactive list signals.
///
/// ListSignal extends Signal to provide full List functionality while
/// maintaining reactivity. All list operations (add, remove, etc.) will
/// trigger notifications to subscribers.
///
/// Example:
/// ```dart
/// ListSignal<String> items = ListSignal(['apple', 'banana']);
///
/// Effect(() => print('Items: ${items.join(', ')}'));
/// items.add('cherry'); // Triggers effect
/// ```
abstract interface class ListSignal<E>
    implements Signal<List<E>>, ListSignalMixin<E> {
  /// Creates a reactive list signal with the given initial list.
  ///
  /// Parameters:
  /// - [value]: Initial list content, defaults to empty list if null
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final emptyList = ListSignal<String>(null); // Creates empty list
  /// final numbers = ListSignal([1, 2, 3]);
  /// final autoList = ListSignal(['a', 'b']);
  /// ```
  factory ListSignal(List<E>? value, {JoltDebugFn? onDebug}) =
      ListSignalImpl<E>;
}
