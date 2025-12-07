/// Base class for all query keys.
///
/// A [QueryKey] is compared by its runtime type and the values returned
/// from [props]. This lets you create strongly‑typed keys by simply
/// extending the class and defining the pieces of data that should
/// participate in equality. Different subclasses are **not** equal even if
/// their [props] match, which avoids accidental collisions when you model
/// distinct resource types.
abstract class QueryKey {
  /// Creates a new query key.
  const QueryKey();

  /// Values that determine equality for this key.
  ///
  /// Subclasses should override and return any fields that uniquely
  /// identify the query.
  List<Object?> get props;

  /// Determines whether [other] should be treated as a descendant of this key
  /// when进行级联失效等操作。
  ///
  /// 默认实现：任何 `QueryKey` 都视为子级（即最宽松匹配）。
  /// 可以在子类中重写以实现树形/分组失效逻辑。
  bool isParentOf(QueryKey other) => true;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return _listEquals(props, (other as QueryKey).props);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[runtimeType, ...props]);

  @override
  String toString() => '$runtimeType(${props.join(', ')})';
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
