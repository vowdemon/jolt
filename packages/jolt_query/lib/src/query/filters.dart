import 'cache_models.dart';
import 'state.dart';
import '../keys/query_key.dart';

/// Which observer-activity partition a query filter accepts.
enum QueryActivity {
  /// Accept both active and inactive entries.
  all,

  /// Accept entries with at least one enabled attached observer.
  active,

  /// Accept entries without an enabled observer.
  ///
  /// Entries observed exclusively by disabled observers are inactive.
  inactive,
}

/// Which observer-aware freshness partition a query filter accepts.
enum QueryFreshness {
  /// Accept both fresh and stale entries.
  all,

  /// Accept entries that are currently fresh.
  fresh,

  /// Accept entries that are currently stale.
  stale,
}

/// An erased, read-only structural query-cache filter.
final class QueryFilter {
  /// Creates a query filter.
  const QueryFilter({
    this.key,
    this.exact = false,
    this.activity = QueryActivity.all,
    this.freshness = QueryFreshness.all,
    this.status,
    this.fetchStatus,
    this.predicate,
  });

  /// An optional exact or prefix structural key constraint.
  final QueryKey? key;

  /// Whether [key] must match exactly instead of by structural prefix.
  final bool exact;

  /// The accepted observer-activity partition.
  final QueryActivity activity;

  /// The accepted observer-aware freshness partition.
  final QueryFreshness freshness;

  /// An optional canonical data-state constraint.
  final QueryStatus? status;

  /// An optional operation-state constraint.
  final FetchStatus? fetchStatus;

  /// An optional final read-only predicate.
  final bool Function(QueryCacheSnapshot snapshot)? predicate;

  /// Whether [snapshot] satisfies every configured constraint.
  bool matches(QueryCacheSnapshot snapshot) {
    final filterKey = key;
    if (filterKey != null) {
      final keyMatches = exact
          ? snapshot.key == filterKey
          : snapshot.key.startsWith(filterKey);
      if (!keyMatches) return false;
    }

    switch (activity) {
      case QueryActivity.all:
        break;
      case QueryActivity.active:
        if (!snapshot.isActive) return false;
      case QueryActivity.inactive:
        if (snapshot.isActive) return false;
    }

    switch (freshness) {
      case QueryFreshness.all:
        break;
      case QueryFreshness.fresh:
        if (snapshot.isStale) return false;
      case QueryFreshness.stale:
        if (!snapshot.isStale) return false;
    }

    final requiredStatus = status;
    if (requiredStatus != null && snapshot.status != requiredStatus) {
      return false;
    }
    final requiredFetchStatus = fetchStatus;
    if (requiredFetchStatus != null &&
        snapshot.fetchStatus != requiredFetchStatus) {
      return false;
    }
    final finalPredicate = predicate;
    return finalPredicate == null || finalPredicate(snapshot);
  }

  /// Adds a caller-owned data-type assertion for typed bulk data operations.
  TypedQueryFilter<T> typed<T>() => TypedQueryFilter<T>.from(this);
}

/// A query filter carrying the caller's assertion that every match stores [T].
///
/// The generic is intentionally a type witness. Structural query keys remain
/// caller-owned declarations of cache shape, so no runtime type registry is
/// introduced.
final class TypedQueryFilter<T> {
  /// Creates a typed query filter directly.
  factory TypedQueryFilter({
    QueryKey? key,
    bool exact = false,
    QueryActivity activity = QueryActivity.all,
    QueryFreshness freshness = QueryFreshness.all,
    QueryStatus? status,
    FetchStatus? fetchStatus,
    bool Function(QueryCacheSnapshot snapshot)? predicate,
  }) =>
      TypedQueryFilter<T>.from(
        QueryFilter(
          key: key,
          exact: exact,
          activity: activity,
          freshness: freshness,
          status: status,
          fetchStatus: fetchStatus,
          predicate: predicate,
        ),
      );

  /// Adds a typed witness to an existing erased filter.
  const TypedQueryFilter.from(this.untyped);

  /// The same matching rules without the typed assertion.
  final QueryFilter untyped;

  /// The structural key constraint.
  QueryKey? get key => untyped.key;

  /// Whether key matching is exact.
  bool get exact => untyped.exact;

  /// The observer-activity constraint.
  QueryActivity get activity => untyped.activity;

  /// The freshness constraint.
  QueryFreshness get freshness => untyped.freshness;

  /// The canonical data-state constraint.
  QueryStatus? get status => untyped.status;

  /// The operation-state constraint.
  FetchStatus? get fetchStatus => untyped.fetchStatus;

  /// The final read-only predicate.
  bool Function(QueryCacheSnapshot snapshot)? get predicate =>
      untyped.predicate;

  /// Whether [snapshot] satisfies every configured constraint.
  bool matches(QueryCacheSnapshot snapshot) => untyped.matches(snapshot);
}
