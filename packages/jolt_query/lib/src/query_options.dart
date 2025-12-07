import 'package:meta/meta.dart';

import 'query_key.dart';

/// Signature for a query fetch function.
typedef QueryFn<T> = Future<T> Function();

/// Options controlling how a query behaves.
@immutable
class QueryOptions<T> {
  const QueryOptions({
    required this.queryKey,
    required this.queryFn,
    this.staleTime,
    this.gcTime,
    this.enabled = true,
    this.initialData,
    this.placeholderData,
  });

  /// Unique key for the query.
  final QueryKey queryKey;

  /// Async function that returns the data for the query.
  final QueryFn<T> queryFn;

  /// Duration before data is considered stale.
  ///
  /// When null, the client's default is used.
  final Duration? staleTime;

  /// How long the query should stay in the cache after it becomes unused.
  ///
  /// When null, the client's default is used。
  final Duration? gcTime;

  /// Whether the query is allowed to run.
  final bool enabled;

  /// Optional initial data.
  final T? initialData;

  final T? placeholderData;

  QueryOptions<T> withDefaults({
    required Duration defaultStaleTime,
    required Duration defaultGcTime,
  }) {
    return QueryOptions<T>(
      queryKey: queryKey,
      queryFn: queryFn,
      staleTime: staleTime ?? defaultStaleTime,
      gcTime: gcTime ?? defaultGcTime,
      enabled: enabled,
      initialData: initialData,
      placeholderData: placeholderData,
    );
  }

  QueryOptions<T> copyWith({
    QueryFn<T>? queryFn,
    Duration? staleTime,
    Duration? gcTime,
    bool? enabled,
    T? initialData,
    bool setInitialData = false,
    T? placeholderData,
    bool setPlaceholderData = false,
  }) {
    return QueryOptions<T>(
      queryKey: queryKey,
      queryFn: queryFn ?? this.queryFn,
      staleTime: staleTime ?? this.staleTime,
      gcTime: gcTime ?? this.gcTime,
      enabled: enabled ?? this.enabled,
      initialData: setInitialData ? initialData : this.initialData,
      placeholderData:
          setPlaceholderData ? placeholderData : this.placeholderData,
    );
  }
}
