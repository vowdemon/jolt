import 'dart:async';

import 'package:jolt/jolt.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'query_key.dart';
import 'query_options.dart';
import 'query_state.dart';

typedef _NowFn = DateTime Function();
typedef _OnlineFn = bool Function();

/// Internal representation of a cached query.
class Query<T> implements Disposable {
  Query({
    required QueryOptions<T> options,
    required _NowFn now,
    required _OnlineFn online,
  })  : _options = options,
        _now = now,
        _online = online,
        _state = Signal<QueryState<T>>(QueryState.idle(initial: options.initialData)) {
    _initializeData();
  }

  final _NowFn _now;
  final _OnlineFn _online;
  QueryOptions<T> _options;
  final Signal<QueryState<T>> _state;
  Future<T>? _ongoingFetch;
  DateTime? _staleUntil;
  Timer? _gcTimer;
  Completer<T>? _pausedCompleter;
  int _observers = 0;
  bool _observedOnce = false;

  QueryOptions<T> get options => _options;

  ReadonlySignal<QueryState<T>> get state => _state;

  QueryState<T> get snapshot => _state.peek;

  bool get isFetching => snapshot.isFetching;

  bool get isStale => _isStale();

  bool get isActive => _observers > 0;

  bool _isStale() {
    if (_staleUntil == null) return true;
    return _now().isAfter(_staleUntil!);
  }

  void _markFresh() {
    final staleTime = _options.staleTime ?? Duration.zero;
    _staleUntil = _now().add(staleTime);
  }

  void _initializeData() {
    if (_options.initialData != null) {
      _markFresh();
      _state.value = _state.peek.copyWith(
        status: QueryStatus.success,
        setData: true,
        data: _options.initialData,
        isStale: _isStale(),
        dataUpdatedAt: _now(),
        fetchCount: 0,
        isPlaceholderData: false,
        isEnabled: _options.enabled,
        fetchState: QueryFetchState.idle,
      );
      return;
    }

    if (_options.placeholderData != null) {
      _state.value = _state.peek.copyWith(
        status: QueryStatus.success,
        setData: true,
        data: _options.placeholderData,
        isPlaceholderData: true,
        fetchState: QueryFetchState.idle,
        isStale: true,
        fetchCount: 0,
        isEnabled: _options.enabled,
      );
      return;
    }

    _state.value = _state.peek.copyWith(isEnabled: _options.enabled);
  }

  void updateOptions(QueryOptions<T> next) {
    _options = next;
    if (next.staleTime != null && !_isStale()) {
      _markFresh();
    }
    _state.value = _state.peek.copyWith(isEnabled: next.enabled);
  }

  Future<T> fetch({bool force = false}) {
    if (!_options.enabled && !force) {
      return Future.error(StateError('Query ${_options.queryKey} is disabled'));
    }

    if (!_online()) {
      _state.value = _state.peek.copyWith(
        fetchState: QueryFetchState.paused,
      );
      _pausedCompleter ??= Completer<T>();
      return _pausedCompleter!.future;
    }

    if (!force && !isStale && snapshot.isSuccess) {
      return Future.value(snapshot.data as T);
    }

    if (_ongoingFetch != null) return _ongoingFetch!;

    _ongoingFetch = _runFetch();
    return _ongoingFetch!;
  }

  Future<T> _runFetch() async {
    _state.value = _state.peek.copyWith(fetchState: QueryFetchState.pending);
    final previous = snapshot.data;
    _state.value = QueryState<T>(
      status: QueryStatus.loading,
      data: previous,
      error: null,
      stackTrace: null,
      fetchState: QueryFetchState.pending,
      isStale: true,
      isPlaceholderData: snapshot.isPlaceholderData,
      fetchCount: snapshot.fetchCount,
      fetchedAfterMount:
          snapshot.fetchedAfterMount || (_observedOnce && snapshot.hasData),
      isEnabled: _options.enabled,
      dataUpdatedAt: snapshot.dataUpdatedAt,
    );

    try {
      final value = await _options.queryFn();
      _markFresh();
      final nextState = QueryState<T>(
        status: QueryStatus.success,
        data: value,
        error: null,
        stackTrace: null,
        fetchState: QueryFetchState.idle,
        isStale: _isStale(),
        isPlaceholderData: false,
        fetchCount: snapshot.fetchCount + 1,
        fetchedAfterMount: _observedOnce || snapshot.fetchedAfterMount,
        isEnabled: _options.enabled,
        dataUpdatedAt: _now(),
      );
      _state.value = nextState;
      return value;
    } catch (err, stack) {
      final nextState = QueryState<T>(
        status: QueryStatus.error,
        data: previous,
        error: err,
        stackTrace: stack,
        fetchState: QueryFetchState.idle,
        isStale: true,
        isPlaceholderData: snapshot.isPlaceholderData,
        fetchCount: snapshot.fetchCount,
        fetchedAfterMount:
            snapshot.fetchedAfterMount || (_observedOnce && snapshot.hasData),
        isEnabled: _options.enabled,
        dataUpdatedAt: snapshot.dataUpdatedAt,
      );
      _state.value = nextState;
      rethrow;
    } finally {
      _ongoingFetch = null;
    }
  }

  void setData(T data, {bool markFresh = true}) {
    if (markFresh) {
      _markFresh();
    }
    _state.value = QueryState<T>(
      status: QueryStatus.success,
      data: data,
      error: null,
      stackTrace: null,
      fetchState: QueryFetchState.idle,
      isStale: _isStale(),
      isPlaceholderData: false,
      fetchCount: snapshot.fetchCount,
      fetchedAfterMount: snapshot.fetchedAfterMount,
      isEnabled: _options.enabled,
      dataUpdatedAt: _now(),
    );
  }

  void invalidate() {
    _staleUntil = _now().subtract(const Duration(seconds: 1));
    _state.value = _state.peek.copyWith(isStale: true);
  }

  void scheduleGc(Duration cacheTime, void Function() onGc) {
    _gcTimer?.cancel();
    _gcTimer = Timer(cacheTime, onGc);
  }

  void addObserver() {
    _observers++;
    _observedOnce = true;
    _gcTimer?.cancel();
    _gcTimer = null;
    if (isStale && _options.enabled) {
      unawaited(fetch());
    }
  }

  void removeObserver() {
    _observers = (_observers - 1).clamp(0, _observers);
    if (_observers == 0) {
      final gc = _options.gcTime ?? const Duration(minutes: 5);
      if (gc <= Duration.zero) {
        dispose();
      } else {
        scheduleGc(gc, () => dispose());
      }
    }
  }

  void resumeIfPaused() {
    if (_pausedCompleter == null) return;
    if (!_online()) return;
    final completer = _pausedCompleter!;
    _pausedCompleter = null;
    fetch().then(completer.complete).catchError(completer.completeError);
  }

  @override
  void dispose() {
    _gcTimer?.cancel();
    _gcTimer = null;
    _pausedCompleter?.completeError(StateError('Query disposed'));
    _pausedCompleter = null;
    _state.dispose();
  }
}

abstract class QueryHandle {
  QueryKey get queryKey;
  void invalidate();
  bool get isStale;
}
