import 'dart:async';

import 'package:jolt/jolt.dart' show Effect, Readable, Signal, batch, untracked;
import 'package:meta/meta.dart' show internal;
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../foundation/query_failure.dart';
import '../foundation/query_runtime.dart';
import '../foundation/query_value.dart';
import '../keys/query_key.dart';
import 'cache.dart';
import 'cache_models.dart';
import 'client.dart';
import 'observer_result.dart';
import 'policies.dart';
import 'recipe.dart';
import 'state.dart';

/// Package seam for specialized observers that share the ordinary lifecycle
/// but need a different fetch executor.
@internal
typedef QueryObserverFetchDelegateInternal<TView> = Future<Object?> Function(
  QueryEntryInternal entry,
  ResolvedQueryTarget<TView> target, {
  required bool cancelRefetch,
});

/// Single-query observation methods for [QueryClient].
extension QueryClientObserverMethods on QueryClient {
  /// Observes one fixed target until the returned observer is disposed.
  QueryObserver<TView> observeQuery<TView>(QueryTarget<TView> target) {
    checkActiveInternal();
    final observer = QueryObserver<TView>._fixed(this, target);
    return ownDisposableInternal(observer);
  }

  /// Reactively switches to the target returned by [target].
  ///
  /// Signal reads performed by [target] are tracked by an observer-owned
  /// effect. Switching preserves the previous selected presentation for a new
  /// target's placeholder resolver.
  QueryObserver<TView> watchQuery<TView>(
    QueryTarget<TView> Function() target,
  ) {
    checkActiveInternal();
    final observer = QueryObserver<TView>._watched(this, target);
    return ownDisposableInternal(observer);
  }

  /// Package seam for specialized recipes that already own a resolved target.
  @internal
  QueryObserver<TView> observeResolvedQueryInternal<TView>(
    ResolvedQueryTarget<TView> target, {
    bool Function()? activityOverride,
    QueryObserverFetchDelegateInternal<TView>? fetchDelegate,
  }) {
    checkActiveInternal();
    final observer = QueryObserver<TView>._resolved(
      this,
      target,
      activityOverride: activityOverride,
      fetchDelegate: fetchDelegate,
    );
    return ownDisposableInternal(observer);
  }
}

/// A typed reactive presentation of one shared query-cache entry.
///
/// [value] tracks the complete immutable result. The individual getters track
/// only the fields needed to compute that getter. [snapshot] and [peek] are
/// untracked synchronous reads.
final class QueryObserver<TView>
    implements
        Readable<QueryObserverResult<TView>>,
        Disposable,
        QueryEntryListenerInternal {
  QueryObserver._(
    this._client, {
    bool Function()? activityOverride,
    QueryObserverFetchDelegateInternal<TView>? fetchDelegate,
  })  : _fetchDelegate = fetchDelegate,
        _current = QueryObserverResult<TView>(
          key: QueryKey(const <Object?>[]),
          data: QueryValue<TView>.absent(),
          status: QueryStatus.pending,
          fetchStatus: FetchStatus.idle,
          isEnabled: false,
        ),
        _versions = List<Signal<int>>.generate(
          _ObserverField.values.length,
          (_) => Signal<int>(0),
          growable: false,
        ),
        _activityOverride = activityOverride;

  factory QueryObserver._fixed(
    QueryClient client,
    QueryTarget<TView> target,
  ) {
    final observer = QueryObserver<TView>._(client);
    observer
      .._switchTarget(target)
      .._startEnvironmentEffects();
    return observer;
  }

  factory QueryObserver._watched(
    QueryClient client,
    QueryTarget<TView> Function() target,
  ) {
    final observer = QueryObserver<TView>._(client);
    observer._targetEffect = Effect(
      () => observer._switchTarget(target()),
      detach: true,
    );
    observer._startEnvironmentEffects();
    return observer;
  }

  factory QueryObserver._resolved(
    QueryClient client,
    ResolvedQueryTarget<TView> target, {
    bool Function()? activityOverride,
    QueryObserverFetchDelegateInternal<TView>? fetchDelegate,
  }) {
    final observer = QueryObserver<TView>._(
      client,
      activityOverride: activityOverride,
      fetchDelegate: fetchDelegate,
    );
    observer
      .._installResolvedTarget(target)
      .._startEnvironmentEffects();
    return observer;
  }

  final QueryClient _client;
  final List<Signal<int>> _versions;
  final bool Function()? _activityOverride;
  final QueryObserverFetchDelegateInternal<TView>? _fetchDelegate;

  QueryObserverResult<TView> _current;
  ResolvedQueryTarget<TView>? _target;
  QueryEntryInternal? _entry;
  late _EffectiveObserverSettings<TView> _settings;

  Effect? _targetEffect;
  Effect? _focusEffect;
  Effect? _onlineEffect;
  QueryScheduledHandle? _pollingHandle;
  int _pollingGeneration = 0;
  QueryScheduledHandle? _staleHandle;
  int _staleGeneration = 0;
  bool _lastFocused = true;
  bool _lastOnline = true;
  bool _isDisposed = false;
  int _completionSequenceAtMount = 0;
  bool _hasAttachedTarget = false;

  QueryValue<TView> _previousPresentation = QueryValue<TView>.absent();
  bool _lastRawWasPresent = false;

  bool _hasSelectionMemo = false;
  Object? _selectionRaw;
  QueryValue<TView> _selectionData = QueryValue<TView>.absent();
  QueryFailure? _selectionFailure;
  DateTime? _selectionFailureAt;

  bool _hasPlaceholderMemo = false;
  QueryValue<TView> _placeholderInput = QueryValue<TView>.absent();
  QueryValue<TView> _placeholderData = QueryValue<TView>.absent();
  QueryFailure? _placeholderFailure;
  DateTime? _placeholderFailureAt;

  /// Whether this observer has released all owned resources.
  bool get isDisposed => _isDisposed;

  /// Package seam exposing the currently attached raw cache entry.
  @internal
  QueryEntryInternal get entryInternal {
    _checkActive();
    return _entry!;
  }

  /// Package seam exposing the currently resolved presentation target.
  @internal
  ResolvedQueryTarget<TView> get targetInternal {
    _checkActive();
    return _target!;
  }

  /// Package seam for synchronously refreshing after specialized operations.
  @internal
  void refreshInternal() {
    _checkActive();
    _refresh();
  }

  /// Package seam for specialized observers to apply a new resolved target.
  ///
  /// Updating the same structural key changes presentation and observer
  /// settings without treating the target as newly mounted.
  @internal
  void updateResolvedTargetInternal(ResolvedQueryTarget<TView> target) {
    _checkActive();
    _installResolvedTarget(target);
  }

  /// The current complete result without reactive tracking.
  QueryObserverResult<TView> get snapshot => _current;

  @override
  QueryObserverResult<TView> get peek => _current;

  @override
  QueryObserverResult<TView> get value {
    _track(_ObserverField.whole);
    return _current;
  }

  /// The currently observed structural key.
  QueryKey get key {
    _track(_ObserverField.key);
    return _current.key;
  }

  /// Selected data with explicit absence and present-null semantics.
  QueryValue<TView> get data {
    _track(_ObserverField.data);
    return _current.data;
  }

  /// The canonical selected presentation state.
  QueryStatus get status {
    _track(_ObserverField.status);
    return _current.status;
  }

  /// The orthogonal transport state.
  FetchStatus get fetchStatus {
    _track(_ObserverField.fetchStatus);
    return _current.fetchStatus;
  }

  /// The active pause reason, if any.
  PauseReason? get pauseReason {
    _track(_ObserverField.pauseReason);
    return _current.pauseReason;
  }

  /// The latest terminal cache or observer-local presentation failure.
  QueryFailure? get failure {
    _track(_ObserverField.failure);
    return _current.failure;
  }

  /// The latest retryable transport failure.
  QueryFailure? get transientFailure {
    _track(_ObserverField.transientFailure);
    return _current.transientFailure;
  }

  /// The number of failed transport attempts in the current operation.
  int get failureCount {
    _track(_ObserverField.failureCount);
    return _current.failureCount;
  }

  /// The raw cache data's latest accepted update time.
  DateTime? get dataUpdatedAt {
    _track(_ObserverField.dataUpdatedAt);
    return _current.dataUpdatedAt;
  }

  /// The latest terminal or observer-local failure time.
  DateTime? get failureUpdatedAt {
    _track(_ObserverField.failureUpdatedAt);
    return _current.failureUpdatedAt;
  }

  /// Whether the underlying entry is invalidated.
  bool get isInvalidated {
    _track(_ObserverField.isInvalidated);
    return _current.isInvalidated;
  }

  /// Whether data is stale under this observer's freshness policy.
  bool get isStale {
    _track(_ObserverField.isStale);
    return _current.isStale;
  }

  /// Whether the visible value came from observer-local placeholder logic.
  bool get isPlaceholderData {
    _track(_ObserverField.isPlaceholderData);
    return _current.isPlaceholderData;
  }

  /// Whether the entry has completed an accepted query operation.
  bool get isFetched {
    _track(_ObserverField.isFetched);
    return _current.isFetched;
  }

  /// Whether an operation completed after this target was attached.
  bool get isFetchedAfterMount {
    _track(_ObserverField.isFetchedAfterMount);
    return _current.isFetchedAfterMount;
  }

  /// Whether this observer currently participates in automatic query work.
  bool get isEnabled {
    _track(_ObserverField.isEnabled);
    return _current.isEnabled;
  }

  /// Whether the selected presentation has no accepted value yet.
  bool get isPending {
    _track(_ObserverField.status);
    return _current.isPending;
  }

  /// Whether the selected presentation is successful.
  bool get isSuccess {
    _track(_ObserverField.status);
    return _current.isSuccess;
  }

  /// Whether the selected presentation has a terminal failure.
  bool get isError {
    _track(_ObserverField.status);
    return _current.isError;
  }

  /// Whether transport or retry-delay work is active.
  bool get isFetching {
    _track(_ObserverField.fetchStatus);
    return _current.isFetching;
  }

  /// Whether query work is waiting behind an eligibility gate.
  bool get isPaused {
    _track(_ObserverField.fetchStatus);
    return _current.isPaused;
  }

  /// Whether an absent initial value is currently loading.
  bool get isLoading {
    _track(_ObserverField.status);
    _track(_ObserverField.fetchStatus);
    return _current.isLoading;
  }

  /// Alias for [isLoading].
  bool get isInitialLoading => isLoading;

  /// Whether retained selected data is being refreshed.
  bool get isRefetching {
    _track(_ObserverField.status);
    _track(_ObserverField.fetchStatus);
    return _current.isRefetching;
  }

  /// Whether initial loading failed without retained selected data.
  bool get isLoadingError {
    _track(_ObserverField.status);
    _track(_ObserverField.data);
    return _current.isLoadingError;
  }

  /// Whether a refresh failed while selected data remains visible.
  bool get isRefetchError {
    _track(_ObserverField.status);
    _track(_ObserverField.data);
    return _current.isRefetchError;
  }

  /// Refetches the current target even when automatic activation is disabled.
  ///
  /// With [cancelRefetch], an active retained-data refetch is replaced. An
  /// active initial load is always joined so all observers retain single-flight
  /// behavior. Failures are represented in the returned result.
  Future<QueryObserverResult<TView>> refetch({
    bool cancelRefetch = true,
  }) async {
    _checkActive();
    final entry = _entry!;
    final target = _target!;
    try {
      await _fetchEntry(
        entry,
        target,
        cancelRefetch: cancelRefetch,
      );
    } on Object {
      // Query failures are committed to the entry and returned as state.
    }
    if (!_isDisposed && identical(_entry, entry)) _refresh();
    return _current;
  }

  @override
  @internal
  bool get isQueryEntryActiveInternal =>
      !_isDisposed && (_activityOverride?.call() ?? _settings.enabled);

  @override
  @internal
  bool get blocksQueryRefetchInternal => _settings.staleTime.isImmutable;

  @override
  @internal
  bool isQueryEntryStaleInternal(QueryEntryInternal entry) {
    if (!isQueryEntryActiveInternal) return false;
    return _client.isQueryEntryStaleInternal(entry, _settings.staleTime);
  }

  @override
  @internal
  void onQueryEntryChangedInternal(
    QueryEntryInternal entry,
    QueryCacheEventKind kind,
  ) {
    if (_isDisposed || !identical(entry, _entry)) return;
    _refresh();
  }

  @override
  @internal
  void onQueryEntryRemovedInternal(QueryEntryInternal entry) {
    if (_isDisposed || !identical(entry, _entry)) return;
    _entry = null;
    final target = _target;
    if (target == null || _client.isDisposed) return;
    _attach(target);
  }

  void _switchTarget(QueryTarget<TView> target) {
    if (_isDisposed) return;
    _client.checkActiveInternal();
    _installResolvedTarget(target.resolved);
  }

  void _installResolvedTarget(ResolvedQueryTarget<TView> resolved) {
    if (_isDisposed) return;
    _client.checkActiveInternal();
    final previousEntry = _entry;
    if (previousEntry != null && previousEntry.key == resolved.plan.key) {
      final wasEntryActive = previousEntry.isActive;
      final wasEnabled = _settings.enabled;
      final nextSettings =
          _EffectiveObserverSettings.resolve(_client, resolved);
      final reconfigurePolling =
          !_settings.hasSamePollingScheduleAs(nextSettings);
      _target = resolved;
      if (!_client.updateQueryObserverTargetInternal(previousEntry, resolved)) {
        _entry = null;
        _settings = nextSettings;
        _attach(resolved);
        return;
      }
      _settings = nextSettings;
      _client.refreshQueryObserverActivityInternal(
        previousEntry,
        wasActive: wasEntryActive,
      );
      _resetPresentationMemos();
      _activateIfNeeded(previousEntry, wasEnabled: wasEnabled);
      final resultChanged = _refresh();
      if (reconfigurePolling && !resultChanged) _configurePolling();
      return;
    }

    if (previousEntry != null) {
      _client.detachQueryObserverInternal(previousEntry, this);
    }
    _target = resolved;
    _settings = _EffectiveObserverSettings.resolve(_client, resolved);
    _attach(
      resolved,
      applyMountPolicy: !_hasAttachedTarget,
    );
  }

  void _attach(
    ResolvedQueryTarget<TView> target, {
    bool applyMountPolicy = true,
  }) {
    _resetPresentationMemos();
    final entry = _client.attachQueryObserverInternal(target, this);
    _entry = entry;
    _completionSequenceAtMount = entry.visibleCompletionSequence;
    _hasAttachedTarget = true;
    if (applyMountPolicy) {
      _mountIfNeeded(entry);
    } else {
      _fetchOnTargetChangeIfNeeded(entry);
    }
    _refresh();
  }

  void _resetPresentationMemos() {
    _hasSelectionMemo = false;
    _selectionRaw = null;
    _selectionData = QueryValue<TView>.absent();
    _selectionFailure = null;
    _selectionFailureAt = null;
    _lastRawWasPresent = false;
    _resetPlaceholderMemo(_previousPresentation);
  }

  void _resetPlaceholderMemo(QueryValue<TView> previous) {
    _hasPlaceholderMemo = false;
    _placeholderInput = previous;
    _placeholderData = QueryValue<TView>.absent();
    _placeholderFailure = null;
    _placeholderFailureAt = null;
  }

  void _mountIfNeeded(QueryEntryInternal entry) {
    if (!_settings.enabled || entry.operation != null) return;
    if (entry.data.isAbsent) {
      if (entry.status == QueryStatus.error && !_settings.retryOnMount) {
        return;
      }
      _startAutomaticFetch(entry);
      return;
    }
    if (_settings.staleTime.isImmutable) return;
    if (_matchesRefetchPolicy(_settings.refetchOnMount, entry)) {
      _startAutomaticFetch(entry);
    }
  }

  void _activateIfNeeded(
    QueryEntryInternal entry, {
    required bool wasEnabled,
  }) {
    if (wasEnabled || !_settings.enabled || entry.operation != null) return;
    if (entry.data.isAbsent) {
      _startAutomaticFetch(entry);
      return;
    }
    if (_settings.staleTime.isImmutable) return;
    if (_client.isQueryEntryStaleInternal(entry, _settings.staleTime)) {
      _startAutomaticFetch(entry);
    }
  }

  void _fetchOnTargetChangeIfNeeded(QueryEntryInternal entry) {
    if (!_settings.enabled || entry.operation != null) return;
    if (_client.isQueryEntryStaleInternal(entry, _settings.staleTime)) {
      _startAutomaticFetch(entry);
    }
  }

  bool _matchesRefetchPolicy(
    RefetchPolicy policy,
    QueryEntryInternal entry,
  ) {
    return switch (policy) {
      RefetchPolicy.never => false,
      RefetchPolicy.stale => _client.isQueryEntryStaleInternal(
          entry,
          _settings.staleTime,
        ),
      RefetchPolicy.always => true,
    };
  }

  void _startAutomaticFetch(QueryEntryInternal entry) {
    if (_isDisposed || entry.operation != null) return;
    final future = _fetchEntry(
      entry,
      _target!,
      cancelRefetch: false,
    );
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
  }

  Future<Object?> _fetchEntry(
    QueryEntryInternal entry,
    ResolvedQueryTarget<TView> target, {
    required bool cancelRefetch,
  }) {
    final delegate = _fetchDelegate;
    if (delegate != null) {
      return delegate(
        entry,
        target,
        cancelRefetch: cancelRefetch,
      );
    }
    return _client.refetchQueryEntryInternal(
      entry,
      target.plan,
      cancelRefetch: cancelRefetch,
    );
  }

  void _startEnvironmentEffects() {
    _lastFocused = _client.focusManager.peek;
    _focusEffect = Effect(
      () {
        final focused = _client.focusManager.value;
        final reconnected = !_lastFocused && focused;
        _lastFocused = focused;
        if (reconnected) _onFocus();
        _refresh();
      },
      detach: true,
    );

    _lastOnline = _client.onlineManager.peek;
    _onlineEffect = Effect(
      () {
        final online = _client.onlineManager.value;
        final reconnected = !_lastOnline && online;
        _lastOnline = online;
        if (reconnected) _onReconnect();
        _refresh();
      },
      detach: true,
    );
  }

  void _onFocus() {
    if (_isDisposed || !_settings.enabled) return;
    final entry = _entry;
    final target = _target;
    if (entry == null || target == null || entry.operation != null) return;
    if (_settings.staleTime.isImmutable) return;
    if (_matchesRefetchPolicy(_settings.refetchOnFocus, entry)) {
      _startAutomaticFetch(entry);
    }
  }

  void _onReconnect() {
    if (_isDisposed || !_settings.enabled) return;
    final entry = _entry;
    final target = _target;
    if (entry == null || target == null || entry.operation != null) return;
    if (_settings.staleTime.isImmutable) return;
    if (_matchesRefetchPolicy(_settings.refetchOnReconnect, entry)) {
      _startAutomaticFetch(entry);
    }
  }

  void _configurePolling() {
    _pollingGeneration += 1;
    _pollingHandle?.cancel();
    _pollingHandle = null;
    _scheduleNextPoll(_pollingGeneration);
  }

  void _scheduleNextPoll(int generation) {
    if (_isDisposed ||
        generation != _pollingGeneration ||
        _pollingHandle != null ||
        !isQueryEntryActiveInternal ||
        _settings.staleTime.isImmutable) {
      return;
    }
    final interval = _resolvePollingInterval();
    if (interval == null) return;
    _schedulePollHandle(generation, interval);
  }

  Duration? _resolvePollingInterval() {
    final resolver = _settings.pollingIntervalResolver;
    final interval = resolver == null
        ? _settings.pollingInterval
        : untracked(() => resolver(_current));
    if (interval != null && interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'pollingIntervalResolver',
        'A polling interval must be positive.',
      );
    }
    return interval;
  }

  void _schedulePollHandle(int generation, Duration interval) {
    if (_isDisposed ||
        generation != _pollingGeneration ||
        _pollingHandle != null) {
      return;
    }
    _pollingHandle = _client.timersInternal.schedule(interval, () {
      if (_isDisposed || generation != _pollingGeneration) return;
      _pollingHandle = null;
      if (!isQueryEntryActiveInternal || _settings.staleTime.isImmutable) {
        return;
      }

      if (!_settings.pollInBackground && !_client.focusManager.peek) {
        _schedulePollHandle(generation, interval);
        return;
      }
      final entry = _entry;
      if (entry == null) return;
      if (entry.operation != null) {
        _schedulePollHandle(generation, interval);
        return;
      }
      final nextInterval = _resolvePollingInterval();
      if (nextInterval == null) return;
      if (_isDisposed ||
          generation != _pollingGeneration ||
          !identical(entry, _entry) ||
          !isQueryEntryActiveInternal ||
          _settings.staleTime.isImmutable) {
        return;
      }
      if (!_settings.pollInBackground && !_client.focusManager.peek) {
        _schedulePollHandle(generation, nextInterval);
        return;
      }
      if (entry.operation != null) {
        _schedulePollHandle(generation, nextInterval);
        return;
      }
      _startAutomaticFetch(entry);
      _schedulePollHandle(generation, nextInterval);
    });
  }

  bool _refresh() {
    if (_isDisposed) return false;
    final target = _target;
    final entry = _entry;
    if (target == null || entry == null) return false;

    final presentation = _resolvePresentation(target, entry);
    final status = presentation.failure != null
        ? QueryStatus.error
        : presentation.isPlaceholder && entry.status == QueryStatus.pending
            ? QueryStatus.success
            : entry.status;
    final stale = isQueryEntryActiveInternal &&
        _client.isQueryEntryStaleInternal(
          entry,
          _settings.staleTime,
        );
    final next = QueryObserverResult<TView>(
      key: entry.key,
      data: presentation.data,
      status: status,
      fetchStatus: entry.fetchStatus,
      pauseReason: entry.pauseReason,
      failure: presentation.failure ?? entry.failure,
      transientFailure: entry.transientFailure,
      failureCount: entry.failureCount,
      dataUpdatedAt: entry.dataUpdatedAt,
      failureUpdatedAt: presentation.failureUpdatedAt ?? entry.failureUpdatedAt,
      isInvalidated: entry.isInvalidated,
      isStale: stale,
      isPlaceholderData: presentation.isPlaceholder,
      isFetched: _entryUpdateCount(entry) > 0,
      isFetchedAfterMount: _entryUpdateCount(entry) > 0 &&
          entry.visibleCompletionSequence > _completionSequenceAtMount,
      isEnabled: isQueryEntryActiveInternal,
    );
    final resultChanged = _commit(next);
    if (resultChanged) _configurePolling();
    _client.queryCacheControllerInternal
        .refreshObserverFreshnessInternal(entry);
    _configureStaleTimer(entry, isStale: stale);
    return resultChanged;
  }

  void _configureStaleTimer(
    QueryEntryInternal entry, {
    required bool isStale,
  }) {
    _staleGeneration += 1;
    _staleHandle?.cancel();
    _staleHandle = null;
    if (_isDisposed || isStale || entry.data.isAbsent || entry.isInvalidated) {
      return;
    }
    final updatedAt = entry.dataUpdatedAt;
    if (updatedAt == null) return;
    final remaining = _settings.staleTime.timeUntilStaleInternal(
      StaleState(
        now: _client.runtime.clock.wallNow(),
        updatedAt: updatedAt,
        isInvalidated: entry.isInvalidated,
      ),
    );
    if (remaining == null || remaining <= Duration.zero) return;
    final generation = _staleGeneration;
    _staleHandle = _client.timersInternal.schedule(remaining, () {
      if (_isDisposed || generation != _staleGeneration) return;
      _staleHandle = null;
      _refresh();
    });
  }

  _ObserverPresentation<TView> _resolvePresentation(
    ResolvedQueryTarget<TView> target,
    QueryEntryInternal entry,
  ) {
    final raw = entry.data;
    if (raw case QueryPresent<Object?>(:final value)) {
      _lastRawWasPresent = true;
      if (!_hasSelectionMemo || !identical(value, _selectionRaw)) {
        _hasSelectionMemo = true;
        _selectionRaw = value;
        _selectionFailure = null;
        _selectionFailureAt = null;
        try {
          var selected = target.select(value);
          final previous = _previousPresentation;
          if (previous case QueryPresent<TView>(:final value)) {
            if (_settings.areEqual(value, selected)) selected = value;
          }
          _selectionData = QueryValue<TView>.present(selected);
          _previousPresentation = _selectionData;
        } catch (error, stackTrace) {
          _selectionFailure = QueryFailure(error, stackTrace);
          _selectionFailureAt = _client.runtime.clock.wallNow();
          _selectionData = _previousPresentation;
        }
      }
      return _ObserverPresentation<TView>(
        data: _selectionData,
        failure: _selectionFailure,
        failureUpdatedAt: _selectionFailureAt,
      );
    }

    if (_lastRawWasPresent) {
      _lastRawWasPresent = false;
      _resetPlaceholderMemo(_previousPresentation);
    }
    if (!_hasPlaceholderMemo) {
      _hasPlaceholderMemo = true;
      try {
        _placeholderData = target.resolvePlaceholder(_placeholderInput);
        if (_placeholderData.isPresent) {
          _previousPresentation = _placeholderData;
        }
      } catch (error, stackTrace) {
        _placeholderFailure = QueryFailure(error, stackTrace);
        _placeholderFailureAt = _client.runtime.clock.wallNow();
        _placeholderData = _previousPresentation;
      }
    }
    return _ObserverPresentation<TView>(
      data: _placeholderData,
      failure: _placeholderFailure,
      failureUpdatedAt: _placeholderFailureAt,
      isPlaceholder: _placeholderData.isPresent,
    );
  }

  bool _commit(QueryObserverResult<TView> next) {
    final previous = _current;
    final changes = <_ObserverField>[];
    if (previous.key != next.key) changes.add(_ObserverField.key);
    if (!_sameData(previous.data, next.data)) changes.add(_ObserverField.data);
    if (previous.status != next.status) changes.add(_ObserverField.status);
    if (previous.fetchStatus != next.fetchStatus) {
      changes.add(_ObserverField.fetchStatus);
    }
    if (previous.pauseReason != next.pauseReason) {
      changes.add(_ObserverField.pauseReason);
    }
    if (!identical(previous.failure, next.failure)) {
      changes.add(_ObserverField.failure);
    }
    if (!identical(previous.transientFailure, next.transientFailure)) {
      changes.add(_ObserverField.transientFailure);
    }
    if (previous.failureCount != next.failureCount) {
      changes.add(_ObserverField.failureCount);
    }
    if (previous.dataUpdatedAt != next.dataUpdatedAt) {
      changes.add(_ObserverField.dataUpdatedAt);
    }
    if (previous.failureUpdatedAt != next.failureUpdatedAt) {
      changes.add(_ObserverField.failureUpdatedAt);
    }
    if (previous.isInvalidated != next.isInvalidated) {
      changes.add(_ObserverField.isInvalidated);
    }
    if (previous.isStale != next.isStale) {
      changes.add(_ObserverField.isStale);
    }
    if (previous.isPlaceholderData != next.isPlaceholderData) {
      changes.add(_ObserverField.isPlaceholderData);
    }
    if (previous.isFetched != next.isFetched) {
      changes.add(_ObserverField.isFetched);
    }
    if (previous.isFetchedAfterMount != next.isFetchedAfterMount) {
      changes.add(_ObserverField.isFetchedAfterMount);
    }
    if (previous.isEnabled != next.isEnabled) {
      changes.add(_ObserverField.isEnabled);
    }
    if (changes.isEmpty) return false;
    _current = next;
    batch<void>(() {
      for (final field in changes) {
        _bump(field);
      }
      _bump(_ObserverField.whole);
    });
    return true;
  }

  int _entryUpdateCount(QueryEntryInternal entry) {
    return entry.dataUpdateCount + entry.failureUpdateCount;
  }

  bool _sameData(QueryValue<TView> previous, QueryValue<TView> next) {
    return switch ((previous, next)) {
      (QueryAbsent<TView>(), QueryAbsent<TView>()) => true,
      (
        QueryPresent<TView>(value: final previousValue),
        QueryPresent<TView>(value: final nextValue),
      ) =>
        identical(previousValue, nextValue),
      _ => false,
    };
  }

  void _track(_ObserverField field) {
    _versions[field.index].value;
  }

  void _bump(_ObserverField field) {
    final version = _versions[field.index];
    version.value = version.peek + 1;
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('QueryObserver is disposed.');
    _client.checkActiveInternal();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _pollingGeneration += 1;
    _pollingHandle?.cancel();
    _pollingHandle = null;
    _staleGeneration += 1;
    _staleHandle?.cancel();
    _staleHandle = null;
    _targetEffect?.dispose();
    _targetEffect = null;
    _focusEffect?.dispose();
    _focusEffect = null;
    _onlineEffect?.dispose();
    _onlineEffect = null;
    final entry = _entry;
    _entry = null;
    if (entry != null) {
      _client.detachQueryObserverInternal(entry, this);
    }
    _client.releaseDisposableInternal(this);
    for (final version in _versions) {
      version.dispose();
    }
  }
}

final class _EffectiveObserverSettings<T> {
  const _EffectiveObserverSettings({
    required this.enabled,
    required this.staleTime,
    required this.refetchOnMount,
    required this.refetchOnFocus,
    required this.refetchOnReconnect,
    required this.retryOnMount,
    required this.pollingInterval,
    required this.pollingIntervalResolver,
    required this.pollInBackground,
    required this.equality,
  });

  factory _EffectiveObserverSettings.resolve(
    QueryClient client,
    ResolvedQueryTarget<T> target,
  ) {
    final observer = client.resolveQueryObserverSettingsInternal(target);
    return _EffectiveObserverSettings<T>(
      enabled: observer.enabled!,
      staleTime: observer.staleTime!,
      refetchOnMount: observer.refetchOnMount!,
      refetchOnFocus: observer.refetchOnFocus!,
      refetchOnReconnect: observer.refetchOnReconnect!,
      retryOnMount: observer.retryOnMount!,
      pollingInterval:
          observer.pollingEnabled == false ? null : observer.pollingInterval,
      pollingIntervalResolver: observer.pollingEnabled == false
          ? null
          : observer.pollingIntervalResolver,
      pollInBackground: observer.pollInBackground!,
      equality: observer,
    );
  }

  final bool enabled;
  final StalePolicy staleTime;
  final RefetchPolicy refetchOnMount;
  final RefetchPolicy refetchOnFocus;
  final RefetchPolicy refetchOnReconnect;
  final bool retryOnMount;
  final Duration? pollingInterval;
  final QueryPollingIntervalResolver<T>? pollingIntervalResolver;
  final bool pollInBackground;
  final ResolvedObserverSettings<T> equality;

  bool areEqual(T previous, T next) => equality.areEqual(previous, next);

  bool hasSamePollingScheduleAs(_EffectiveObserverSettings<T> other) {
    return enabled == other.enabled &&
        staleTime.isImmutable == other.staleTime.isImmutable &&
        pollingInterval == other.pollingInterval &&
        identical(pollingIntervalResolver, other.pollingIntervalResolver) &&
        pollInBackground == other.pollInBackground;
  }
}

final class _ObserverPresentation<T> {
  const _ObserverPresentation({
    required this.data,
    this.failure,
    this.failureUpdatedAt,
    this.isPlaceholder = false,
  });

  final QueryValue<T> data;
  final QueryFailure? failure;
  final DateTime? failureUpdatedAt;
  final bool isPlaceholder;
}

enum _ObserverField {
  whole,
  key,
  data,
  status,
  fetchStatus,
  pauseReason,
  failure,
  transientFailure,
  failureCount,
  dataUpdatedAt,
  failureUpdatedAt,
  isInvalidated,
  isStale,
  isPlaceholderData,
  isFetched,
  isFetchedAfterMount,
  isEnabled,
}
