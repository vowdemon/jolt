import 'dart:collection';

import '../base.dart';
import '../computed.dart';

/// A mixin that provides reactive iterable functionality.
///
/// This mixin implements the basic IterableBase interface while maintaining
/// reactivity for iterable operations. It serves as a foundation for reactive
/// iterable implementations.
mixin IterableSignalMixin<E> implements IterableBase<E>, IMutableCollection {
  /// The current iterable value.
  Iterable<E> get value;

  /// Returns an iterator over the elements of this iterable.
  ///
  /// The iterator is obtained from the current value, providing reactive
  /// access to the iterable's elements.
  @override
  Iterator<E> get iterator => value.iterator;
}

/// A reactive iterable that computes its value from a getter function.
///
/// IterableSignal extends Computed to provide reactive iterable functionality.
/// The iterable is computed on-demand and cached until dependencies change,
/// making it efficient for expensive iterable operations.
///
/// Example:
/// ```dart
/// final numbers = Signal([1, 2, 3, 4, 5]);
///
/// // Create reactive iterable that filters even numbers
/// final evenNumbers = IterableSignal(() =>
///   numbers.value.where((n) => n.isEven)
/// );
///
/// // Use like any iterable
/// print('Even numbers: ${evenNumbers.toList()}'); // [2, 4]
///
/// // React to changes
/// Effect(() {
///   print('Count of even numbers: ${evenNumbers.length}');
/// });
///
/// numbers.value = [1, 2, 3, 4, 5, 6]; // Triggers effect: "Count of even numbers: 3"
/// ```
class IterableSignal<E> extends Computed<Iterable<E>>
    with IterableMixin<E>, IterableSignalMixin<E> {
  /// Creates a reactive iterable with the given getter function.
  ///
  /// Parameters:
  /// - [getter]: Function that computes the iterable value
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  ///
  /// Example:
  /// ```dart
  /// final source = Signal([1, 2, 3]);
  /// final doubled = IterableSignal(() => source.value.map((x) => x * 2));
  /// ```
  IterableSignal(super.getter, {super.autoDispose});

  /// Creates a reactive iterable from a static iterable value.
  ///
  /// Parameters:
  /// - [iterable]: The static iterable to wrap
  /// - [autoDispose]: Whether to automatically dispose when no longer referenced
  ///
  /// Returns: An IterableSignal that always returns the given iterable
  ///
  /// This factory is useful when you need to convert a static iterable
  /// into a reactive one for compatibility with reactive APIs.
  ///
  /// Example:
  /// ```dart
  /// final staticList = [1, 2, 3];
  /// final reactiveIterable = IterableSignal.value(staticList);
  ///
  /// // Now can be used in reactive contexts
  /// Effect(() {
  ///   print('Items: ${reactiveIterable.toList()}');
  /// });
  /// ```
  factory IterableSignal.value(Iterable<E> iterable,
      {bool autoDispose = false}) {
    return IterableSignal(() => iterable, autoDispose: autoDispose);
  }
}
