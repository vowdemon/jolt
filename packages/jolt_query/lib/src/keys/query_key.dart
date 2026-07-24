import 'package:fast_immutable_collections/fast_immutable_collections.dart';

const ConfigList _keyListConfig = ConfigList(
  isDeepEquals: true,
  cacheHashCode: true,
);
const ConfigMap _keyMapConfig = ConfigMap(
  isDeepEquals: true,
  sort: true,
  cacheHashCode: true,
);

/// A non-generic, immutable structural query cache key.
final class QueryKey {
  /// Normalizes and defensively copies [parts].
  factory QueryKey(List<Object?> parts) =>
      QueryKey._normalized(_normalizeParts(parts));

  QueryKey._normalized(this.parts) : _hashCode = parts.hashCode;

  /// The normalized top-level key parts.
  final IList<Object?> parts;

  final int _hashCode;

  /// Whether this key begins with all structural [prefix] parts.
  bool startsWith(QueryKey prefix) => _startsWith(parts, prefix.parts);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QueryKey && parts == other.parts;

  @override
  int get hashCode => _hashCode;

  @override
  String toString() => 'QueryKey(${parts.unlockView})';
}

/// A structural mutation key used for defaults, filtering, and observation.
///
/// Equal mutation keys do not imply deduplication or serialized execution.
final class MutationKey {
  /// Normalizes and defensively copies [parts].
  factory MutationKey(List<Object?> parts) =>
      MutationKey._normalized(_normalizeParts(parts));

  MutationKey._normalized(this.parts) : _hashCode = parts.hashCode;

  /// The normalized top-level key parts.
  final IList<Object?> parts;

  final int _hashCode;

  /// Whether this key begins with all structural [prefix] parts.
  bool startsWith(MutationKey prefix) => _startsWith(parts, prefix.parts);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MutationKey && parts == other.parts;

  @override
  int get hashCode => _hashCode;

  @override
  String toString() => 'MutationKey(${parts.unlockView})';
}

IList<Object?> _normalizeParts(Iterable<Object?> parts) =>
    IList<Object?>.withConfig(
      parts.map<Object?>(_normalizeValue),
      _keyListConfig,
    );

Object? _normalizeValue(Object? value) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'key', 'Numbers must be finite.');
    }
    if (value == 0 || value.truncateToDouble() == value) {
      return value.toInt();
    }
    return value;
  }
  if (value is List<Object?>) {
    return IList<Object?>.withConfig(
      value.map<Object?>(_normalizeValue),
      _keyListConfig,
    );
  }
  if (value is IList<Object?>) {
    return IList<Object?>.withConfig(
      value.map<Object?>(_normalizeValue),
      _keyListConfig,
    );
  }
  if (value is Map<Object?, Object?>) {
    return _normalizeMap(value.entries);
  }
  if (value is IMap<Object?, Object?>) {
    return _normalizeMap(value.entries);
  }
  throw ArgumentError.value(
    value,
    'key',
    'Unsupported structural key value of type ${value.runtimeType}.',
  );
}

IMap<String, Object?> _normalizeMap(
  Iterable<MapEntry<Object?, Object?>> entries,
) {
  final normalized = <String, Object?>{};
  for (final entry in entries) {
    final key = entry.key;
    if (key is! String) {
      throw ArgumentError.value(
        entries,
        'key',
        'Structural maps must contain only String keys.',
      );
    }
    normalized[key] = _normalizeValue(entry.value);
  }
  return IMap<String, Object?>.withConfig(normalized, _keyMapConfig);
}

bool _startsWith(IList<Object?> value, IList<Object?> prefix) {
  if (prefix.length > value.length) return false;
  for (var index = 0; index < prefix.length; index += 1) {
    if (!_partiallyMatches(value[index], prefix[index])) return false;
  }
  return true;
}

bool _partiallyMatches(Object? value, Object? pattern) {
  if (value == pattern) return true;

  if (value is IList<Object?> && pattern is IList<Object?>) {
    if (pattern.length > value.length) return false;
    for (var index = 0; index < pattern.length; index += 1) {
      if (!_partiallyMatches(value[index], pattern[index])) return false;
    }
    return true;
  }

  if (value is IMap<String, Object?> && pattern is IMap<String, Object?>) {
    for (final entry in pattern.entries) {
      if (!value.containsKey(entry.key) ||
          !_partiallyMatches(value[entry.key], entry.value)) {
        return false;
      }
    }
    return true;
  }

  return false;
}
