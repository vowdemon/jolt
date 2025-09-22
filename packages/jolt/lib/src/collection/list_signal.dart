import 'dart:collection';
import 'dart:math' show Random;

import '../base.dart';
import '../signal.dart';

/// A mixin that provides reactive list functionality.
///
/// This mixin implements all List operations while maintaining reactivity.
/// Any modification to the list will automatically notify subscribers.
mixin ListSignalMixin<E>
    implements ListBase<E>, JReadonlyValue<List<E>>, IMutableCollection {
  @override
  int get length => value.length;

  @override
  List<R> cast<R>() {
    return value.cast<R>();
  }

  @override
  E get first => value.first;

  @override
  E get last => value.last;

  @override
  E get single => value.single;

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  Iterable<E> where(bool Function(E element) test) {
    return value.where(test);
  }

  @override
  Iterable<T> whereType<T>() {
    return value.whereType<T>();
  }

  @override
  bool any(bool Function(E element) test) {
    return value.any(test);
  }

  @override
  bool every(bool Function(E element) test) {
    return value.every(test);
  }

  @override
  bool contains(Object? element) {
    return value.contains(element);
  }

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) {
    return value.firstWhere(test, orElse: orElse);
  }

  @override
  int indexOf(Object? element, [int start = 0]) {
    return value.indexOf(element as E, start);
  }

  @override
  int indexWhere(bool Function(E element) test, [int start = 0]) {
    return value.indexWhere(test, start);
  }

  @override
  int lastIndexOf(Object? element, [int? start]) {
    return value.lastIndexOf(element as E, start);
  }

  @override
  int lastIndexWhere(bool Function(E element) test, [int? start]) {
    return value.lastIndexWhere(test, start);
  }

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) {
    return value.lastWhere(test, orElse: orElse);
  }

  @override
  R fold<R>(R initialValue, R Function(R previousValue, E element) combine) {
    return value.fold<R>(initialValue, combine);
  }

  @override
  Iterable<E> followedBy(Iterable<E> other) {
    return value.followedBy(other);
  }

  @override
  Iterable<E> getRange(int start, int end) {
    return value.getRange(start, end);
  }

  @override
  Map<int, E> asMap() {
    return value.asMap();
  }

  @override
  Iterable<R> expand<R>(Iterable<R> Function(E element) toElements) {
    return value.expand<R>(toElements);
  }

  @override
  Iterable<E> get reversed => value.reversed;

  @override
  List<E> sublist(int start, [int? end]) {
    return value.sublist(start, end);
  }

  @override
  E elementAt(int index) {
    return value.elementAt(index);
  }

  @override
  void forEach(void Function(E element) action) {
    value.forEach(action);
  }

  @override
  String join([String separator = ""]) {
    return value.join(separator);
  }

  @override
  Iterable<T> map<T>(T Function(E element) f) {
    return value.map<T>(f);
  }

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) {
    return value.singleWhere(test, orElse: orElse);
  }

  @override
  E reduce(E Function(E value, E element) combine) {
    return value.reduce(combine);
  }

  @override
  Iterable<E> skip(int count) {
    return value.skip(count);
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) {
    return value.skipWhile(test);
  }

  @override
  Iterable<E> take(int count) {
    return value.take(count);
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) {
    return value.takeWhile(test);
  }

  @override
  List<E> toList({bool growable = true}) {
    return value.toList(growable: growable);
  }

  @override
  Set<E> toSet() {
    return value.toSet();
  }

  @override
  bool get isEmpty => value.isEmpty;

  @override
  bool get isNotEmpty => value.isNotEmpty;

  @override
  set first(E val) {
    peek.first = val;
    notify();
  }

  @override
  set last(E val) {
    peek.last = val;
    notify();
  }

  @override
  set length(int value) {
    peek.length = value;
    notify();
  }

  @override
  List<E> operator +(List<E> other) {
    return value + other;
  }

  @override
  E operator [](int index) => value[index];

  @override
  void operator []=(int index, E value) {
    peek[index] = value;
    notify();
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
    peek.clear();
    notify();
  }

  @override
  void fillRange(int start, int end, [E? fillValue]) {
    peek.fillRange(start, end, fillValue);
    notify();
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
    final result = peek.remove(value);
    notify();
    return result;
  }

  @override
  E removeAt(int index) {
    final result = peek.removeAt(index);
    notify();
    return result;
  }

  @override
  E removeLast() {
    final result = peek.removeLast();
    notify();
    return result;
  }

  @override
  void removeRange(int start, int end) {
    peek.removeRange(start, end);
    notify();
  }

  @override
  void removeWhere(bool Function(E element) test) {
    peek.removeWhere(test);
    notify();
  }

  @override
  void replaceRange(int start, int end, Iterable<E> replacements) {
    peek.replaceRange(start, end, replacements);
    notify();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    peek.retainWhere(test);
    notify();
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    peek.setAll(index, iterable);
    notify();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    peek.setRange(start, end, iterable, skipCount);
    notify();
  }

  @override
  void shuffle([Random? random]) {
    peek.shuffle(random);
    notify();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    peek.sort(compare);
    notify();
  }
}

/// A reactive list that automatically notifies subscribers when modified.
///
/// ListSignal extends Signal to provide full List functionality while
/// maintaining reactivity. All list operations (add, remove, etc.) will
/// trigger notifications to subscribers.
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
class ListSignal<E> extends Signal<List<E>> with ListSignalMixin<E> {
  /// Creates a reactive list signal with the given initial list.
  ///
  /// Parameters:
  /// - [value]: Initial list content, defaults to empty list if null
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  ///
  /// Example:
  /// ```dart
  /// final emptyList = ListSignal<String>(null); // Creates empty list
  /// final numbers = ListSignal([1, 2, 3]);
  /// final autoList = ListSignal(['a', 'b'], autoDispose: true);
  /// ```
  ListSignal(List<E>? value, {super.autoDispose}) : super(value ?? []);
}
