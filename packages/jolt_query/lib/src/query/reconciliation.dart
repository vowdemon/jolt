import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// A diagnostic emitted when default reconciliation cannot safely infer change.
final class DataReconciliationDiagnostic {
  /// Creates a reconciliation diagnostic.
  const DataReconciliationDiagnostic({
    required this.message,
    required this.value,
  });

  /// A human-readable explanation of the risky input.
  final String message;

  /// The value whose reuse caused the diagnostic.
  final Object value;
}

/// Receives optional reconciliation diagnostics.
typedef DataReconciliationDiagnosticSink = void Function(
  DataReconciliationDiagnostic diagnostic,
);

/// The erased package boundary retained by resolved query plans.
abstract base class DataReconcilerBase {
  /// Creates an erased reconciler boundary.
  const DataReconcilerBase();

  /// Reconciles values whose raw type is owned by the implementation.
  Object? reconcileObject(Object? previous, Object? next);
}

/// Reconciles a newly fetched value with the previously committed value.
///
/// A reconciler must return a value assignable to [T]. Custom implementations
/// can extend this base class, or callers can use [DataReconciler.custom].
abstract base class DataReconciler<T> extends DataReconcilerBase {
  /// Creates a subclassable typed reconciler.
  const DataReconciler();

  /// Uses identity, immutable-collection, and JSON-compatible sharing rules.
  factory DataReconciler.standard({
    DataReconciliationDiagnosticSink? diagnostics,
  }) = _StandardDataReconciler<T>;

  /// Preserves only an identical previous value.
  const factory DataReconciler.identity() = _IdentityDataReconciler<T>;

  /// Uses [reconcile] as the complete application-defined policy.
  factory DataReconciler.custom(T Function(T previous, T next) reconcile) =
      _CallbackDataReconciler<T>;

  /// Reconciles [next] against [previous].
  T reconcile(T previous, T next);

  @override
  Object? reconcileObject(Object? previous, Object? next) {
    return reconcile(previous as T, next as T);
  }
}

final class _IdentityDataReconciler<T> extends DataReconciler<T> {
  const _IdentityDataReconciler();

  @override
  T reconcile(T previous, T next) =>
      identical(previous, next) ? previous : next;
}

final class _CallbackDataReconciler<T> extends DataReconciler<T> {
  const _CallbackDataReconciler(this.callback);

  final T Function(T previous, T next) callback;

  @override
  T reconcile(T previous, T next) => callback(previous, next);
}

final class _StandardDataReconciler<T> extends DataReconciler<T> {
  const _StandardDataReconciler({this.diagnostics});

  final DataReconciliationDiagnosticSink? diagnostics;

  @override
  T reconcile(T previous, T next) {
    if (identical(previous, next)) {
      if (next is List<Object?> || next is Map<Object?, Object?>) {
        diagnostics?.call(
          DataReconciliationDiagnostic(
            message: 'The same mutable List or Map instance was returned. '
                'In-place changes cannot be structurally reconciled.',
            value: next as Object,
          ),
        );
      }
      return previous;
    }

    if (_equalImmutableCollection(previous, next)) return previous;
    if (!_isJsonCompatible(previous) || !_isJsonCompatible(next)) return next;

    final shared = _shareJson(previous, next);
    return shared is T ? shared : next;
  }
}

bool _equalImmutableCollection(Object? previous, Object? next) {
  if (previous is IList<Object?> && next is IList<Object?>) {
    return previous == next;
  }
  if (previous is IMap<Object?, Object?> && next is IMap<Object?, Object?>) {
    return previous == next;
  }
  if (previous is ISet<Object?> && next is ISet<Object?>) {
    return previous == next;
  }
  return false;
}

bool _isJsonCompatible(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return true;
  }
  if (value is List<Object?>) {
    return value.every(_isJsonCompatible);
  }
  if (value is Map<Object?, Object?>) {
    return value.entries.every(
      (entry) => entry.key is String && _isJsonCompatible(entry.value),
    );
  }
  return false;
}

Object? _shareJson(Object? previous, Object? next) {
  if (identical(previous, next)) return previous;

  if (previous == null || next == null) return next;
  if (previous is bool || previous is num || previous is String) {
    return previous.runtimeType == next.runtimeType && previous == next
        ? previous
        : next;
  }

  if (previous is List<Object?> && next is List<Object?>) {
    if (previous.length != next.length) {
      return _shareChangedList(previous, next);
    }

    var allPrevious = true;
    final values = List<Object?>.filled(next.length, null);
    for (var index = 0; index < next.length; index += 1) {
      final value = _shareJson(previous[index], next[index]);
      values[index] = value;
      allPrevious = allPrevious && identical(value, previous[index]);
    }
    if (allPrevious) return previous;
    return _copyListWithSharedValues(next, values);
  }

  if (previous is Map<Object?, Object?> && next is Map<Object?, Object?>) {
    if (previous.keys.any((key) => key is! String) ||
        next.keys.any((key) => key is! String) ||
        previous.length != next.length ||
        next.keys.any((key) => !previous.containsKey(key))) {
      return next;
    }

    var allPrevious = true;
    final values = <String, Object?>{};
    for (final key in next.keys.cast<String>()) {
      final value = _shareJson(previous[key], next[key]);
      values[key] = value;
      allPrevious = allPrevious && identical(value, previous[key]);
    }
    if (allPrevious) return previous;
    return _copyMapWithSharedValues(next, values);
  }

  return next;
}

Object _shareChangedList(List<Object?> previous, List<Object?> next) {
  final values = List<Object?>.of(next);
  final sharedLength =
      previous.length < next.length ? previous.length : next.length;
  for (var index = 0; index < sharedLength; index += 1) {
    values[index] = _shareJson(previous[index], next[index]);
  }
  return _copyListWithSharedValues(next, values);
}

Object _copyListWithSharedValues(
  List<Object?> next,
  List<Object?> values,
) {
  try {
    // `toList` retains the receiver's reified element type even though this
    // package boundary views it as `List<Object?>`.
    final copy = next.toList(growable: true);
    for (var index = 0; index < values.length; index += 1) {
      copy[index] = values[index];
    }
    return copy;
  } on Object {
    // Custom collection implementations can reject copying or assignment.
    return next;
  }
}

Object _copyMapWithSharedValues(
  Map<Object?, Object?> next,
  Map<String, Object?> values,
) {
  if (values.runtimeType == next.runtimeType) return values;

  final objectCopy = <Object?, Object?>{...values};
  if (objectCopy.runtimeType == next.runtimeType) return objectCopy;

  final dynamicCopy = <dynamic, dynamic>{...values};
  if (dynamicCopy.runtimeType == next.runtimeType) return dynamicCopy;

  final stringDynamicCopy = <String, dynamic>{...values};
  if (stringDynamicCopy.runtimeType == next.runtimeType) {
    return stringDynamicCopy;
  }

  // Dart exposes reified Map type arguments for checks but cannot bind them to
  // new generic constructor arguments. For a narrower Map<String, V>, reuse
  // the freshly fetched shell and replace only values its own setter accepts.
  // This retains the declared runtime type while still sharing equal branches.
  final replaced = <MapEntry<String, Object?>>[];
  try {
    for (final entry in values.entries) {
      final current = next[entry.key];
      if (identical(current, entry.value)) continue;
      replaced.add(MapEntry<String, Object?>(entry.key, current));
      next[entry.key] = entry.value;
    }
    return next;
  } on Object {
    for (final entry in replaced.reversed) {
      try {
        next[entry.key] = entry.value;
      } on Object {
        // A custom Map may reject rollback too. Preserve reconciliation's
        // non-throwing fallback and leave the caller-provided value in place.
      }
    }
    return next;
  }
}
