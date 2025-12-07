import 'dart:async';

import 'query.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'query_state.dart';

typedef NowFn = DateTime Function();
typedef OnlineFn = bool Function();

enum QueryNetworkStatus { online, offline }

/// Stores and manages active queries.
class QueryCache {
  final Map<QueryKey, Query<dynamic>> _queries = {};

  Query<T> getOrCreate<T>({
    required QueryOptions<T> options,
    required NowFn now,
    required OnlineFn online,
  }) {
    final existing = _queries[options.queryKey];
    if (existing != null) {
      final typed = existing as Query<T>;
      typed.updateOptions(options);
      return typed;
    }
    final query = Query<T>(options: options, now: now, online: online);
    _queries[options.queryKey] = query;
    return query;
  }

  Query<dynamic>? get(QueryKey key) => _queries[key];

  void remove(QueryKey key) {
    _queries.remove(key)?.dispose();
  }

  void clear() {
    for (final entry in _queries.values) {
      entry.dispose();
    }
    _queries.clear();
  }

  Iterable<Query<dynamic>> get all => _queries.values;
}

/// Primary entry point for managing and consuming queries.
class QueryClient {
  QueryClient({
    QueryCache? cache,
    Duration? defaultStaleTime,
    Duration? defaultGcTime,
    NowFn? now,
    QueryNetworkStatus networkStatus = QueryNetworkStatus.online,
  })  : cache = cache ?? QueryCache(),
        defaultStaleTime = defaultStaleTime ?? Duration.zero,
        defaultGcTime = defaultGcTime ?? const Duration(minutes: 5),
        _now = now ?? DateTime.now,
        _networkStatus = networkStatus;

  final QueryCache cache;
  final Duration defaultStaleTime;
  final Duration defaultGcTime;
  final NowFn _now;
  QueryNetworkStatus _networkStatus;

  NowFn get now => _now;
  QueryNetworkStatus get networkStatus => _networkStatus;
  bool get isOnline => _networkStatus == QueryNetworkStatus.online;

  /// Toggle network availability; resumes paused queries when going online.
  void setNetworkStatus(QueryNetworkStatus status) {
    if (_networkStatus == status) return;
    _networkStatus = status;
    if (status == QueryNetworkStatus.online) {
      for (final query in cache.all) {
        query.resumeIfPaused();
      }
    }
  }

  void setOnline(bool online) =>
      setNetworkStatus(online ? QueryNetworkStatus.online : QueryNetworkStatus.offline);

  Query<T> ensureQuery<T>(QueryOptions<T> rawOptions) {
    final options = rawOptions.withDefaults(
      defaultStaleTime: defaultStaleTime,
      defaultGcTime: defaultGcTime,
    );

    return cache.getOrCreate<T>(
        options: options, now: _now, online: () => _networkStatus == QueryNetworkStatus.online);
  }

  Future<T> fetchQuery<T>(QueryOptions<T> options, {bool force = false}) async {
    final query = ensureQuery(options);
    final value = await query.fetch(force: force);
    return value;
  }

  Future<void> prefetchQuery<T>(QueryOptions<T> options) async {
    await fetchQuery(options);
  }

  T? getQueryData<T>(QueryKey key) {
    final query = cache.get(key) as Query<T>?;
    return query?.snapshot.data;
  }

  void setQueryData<T>(QueryKey key, T data,
      {Duration? staleTime, Duration? gcTime}) {
    final options = QueryOptions<T>(
      queryKey: key,
      queryFn: () async => data,
      staleTime: staleTime ?? defaultStaleTime,
      gcTime: gcTime ?? defaultGcTime,
      initialData: data,
    );
    final query = ensureQuery(options);
    query.setData(data);
  }

  void invalidateQueries(QueryKey? key, {bool refetch = false}) {
    for (final query in cache.all) {
      final targetKey = query.options.queryKey;
      final matches = key == null || key == targetKey || key.isParentOf(targetKey);
      if (matches) {
        query.invalidate();
        if (refetch && query.options.enabled) {
          unawaited(query.fetch());
        }
      }
    }
  }

  void removeQueries(QueryKey? key) {
    if (key == null) {
      cache.clear();
      return;
    }
    cache.remove(key);
  }
}
