import "dart:collection";

import "package:jolt/core.dart";

import "package:jolt/src/jolt/computed.dart";

/// Reactive [Iterable] iteration for types backed by a computed iterable.
///
/// Mix in on [Computed] implementations that expose an [Iterable] through
/// [value]. Reads use [value] and participate in dependency tracking.
mixin IterableSignalMixin<E> implements IterableBase<E> {
  /// The iterable returned by the underlying computed; reads track dependencies.
  Iterable<E> get value;

  /// An iterator over the current [value].
  @override
  Iterator<E> get iterator => value.iterator;

  @override
  String toString() => value.toString();
}

class _IterableSignalImpl<E> extends ComputedImpl<Iterable<E>>
    with IterableMixin<E>, IterableSignalMixin<E>
    implements IterableSignal<E> {
  _IterableSignalImpl(super.getter, {super.debug});
}

/// A computed [Iterable] that updates when its dependencies change.
///
/// Use [IterableSignal] for derived, read-only sequences (filter, map, and
/// similar views). Prefer [ListSignal], [MapSignal], or [SetSignal] when the
/// collection itself must be mutated in place.
///
/// Example:
/// ```dart
/// final numbers = Signal([1, 2, 3, 4, 5]);
/// final evenNumbers = IterableSignal(
///   () => numbers.value.where((n) => n.isEven),
/// );
///
/// Effect(() => print('Even count: ${evenNumbers.length}'));
/// ```
abstract interface class IterableSignal<E>
    implements Computed<Iterable<E>>, IterableMixin<E>, IterableSignalMixin<E> {
  /// Creates a computed iterable from [getter].
  ///
  /// The [getter] callback returns the current iterable and re-runs when
  /// tracked dependencies change.
  ///
  /// Example:
  /// ```dart
  /// final source = Signal([1, 2, 3]);
  /// final doubled = IterableSignal(
  ///   () => source.value.map((x) => x * 2),
  /// );
  /// ```
  factory IterableSignal(Iterable<E> Function() getter,
      {JoltDebugOption? debug}) = _IterableSignalImpl<E>;

  /// Wraps a fixed [iterable] as a computed signal for reactive APIs.
  ///
  /// The [iterable] instance is returned on every read without being copied.
  ///
  /// Example:
  /// ```dart
  /// final items = IterableSignal.value([1, 2, 3]);
  /// Effect(() => print(items.length));
  /// ```
  factory IterableSignal.value(Iterable<E> iterable,
          {JoltDebugOption? debug}) =>
      _IterableSignalImpl(() => iterable, debug: debug);
}
