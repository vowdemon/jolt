/// An explicit cached-value presence marker.
sealed class QueryValue<T> {
  const QueryValue._();

  /// Creates an absent value.
  const factory QueryValue.absent() = QueryAbsent<T>;

  /// Creates a present value, including a present `null` when [T] is nullable.
  const factory QueryValue.present(T value) = QueryPresent<T>;

  /// Whether a value is present.
  bool get isPresent;

  /// Whether no value is present.
  bool get isAbsent => !isPresent;

  /// Returns the contained value, or `null` for absence.
  ///
  /// Use [isPresent] when `null` is itself a valid value.
  T? get valueOrNull;

  /// Returns the contained value or throws when this value is absent.
  T requireValue();
}

/// An explicitly absent query value.
final class QueryAbsent<T> extends QueryValue<T> {
  /// Creates an absent query value.
  const QueryAbsent() : super._();

  @override
  bool get isPresent => false;

  @override
  T? get valueOrNull => null;

  @override
  T requireValue() => throw StateError('Query value is absent.');

  @override
  bool operator ==(Object other) => other is QueryAbsent<T>;

  @override
  int get hashCode => Object.hash(QueryAbsent, T);

  @override
  String toString() => 'QueryAbsent<$T>()';
}

/// An explicitly present query value.
final class QueryPresent<T> extends QueryValue<T> {
  /// Creates a present query value.
  const QueryPresent(this.value) : super._();

  /// The present value.
  final T value;

  @override
  bool get isPresent => true;

  @override
  T? get valueOrNull => value;

  @override
  T requireValue() => value;

  @override
  bool operator ==(Object other) =>
      other is QueryPresent<T> && other.value == value;

  @override
  int get hashCode => Object.hash(QueryPresent, T, value);

  @override
  String toString() => 'QueryPresent<$T>($value)';
}
