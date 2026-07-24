import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    show IList;
import 'package:jolt/jolt.dart' show Effect, Readable, Signal, untracked;
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../keys/query_key.dart';
import 'client.dart';
import 'observer.dart';
import 'observer_result.dart';
import 'recipe.dart';

/// Combines ordered erased query results into one application value.
typedef QueriesCombiner<R> = R Function(
  IList<ErasedQueryObserverResult> results,
);

/// Dynamic and combined multiple-query observation methods for [QueryClient].
///
/// These methods intentionally erase heterogeneous result types. For a fixed
/// statically heterogeneous group, prefer separate typed observers composed in
/// a Dart record, for example `(users: usersObserver, count: countObserver)`.
extension QueryClientQueriesObserverMethods on QueryClient {
  /// Observes a fixed ordered list of heterogeneous targets.
  QueriesObserver<IList<ErasedQueryObserverResult>> observeQueries(
    Iterable<AnyQueryTarget> targets,
  ) {
    return observeCombinedQueries(targets, (results) => results);
  }

  /// Reactively observes the ordered heterogeneous targets returned by
  /// [targets]. Added targets attach, removed targets dispose, and reordering is
  /// reflected in the result.
  QueriesObserver<IList<ErasedQueryObserverResult>> watchQueries(
    Iterable<AnyQueryTarget> Function() targets,
  ) {
    return watchCombinedQueries(targets, (results) => results);
  }

  /// Observes fixed heterogeneous targets and derives one combined value.
  QueriesObserver<R> observeCombinedQueries<R>(
    Iterable<AnyQueryTarget> targets,
    QueriesCombiner<R> combine,
  ) {
    checkActiveInternal();
    final observer = QueriesObserver<R>._fixed(this, targets, combine);
    return ownDisposableInternal(observer);
  }

  /// Reactively observes heterogeneous targets and derives one combined value.
  QueriesObserver<R> watchCombinedQueries<R>(
    Iterable<AnyQueryTarget> Function() targets,
    QueriesCombiner<R> combine,
  ) {
    checkActiveInternal();
    final observer = QueriesObserver<R>._watched(this, targets, combine);
    return ownDisposableInternal(observer);
  }
}

/// A reactive ordered multi-query or combined presentation.
final class QueriesObserver<R> implements Readable<R>, Disposable {
  QueriesObserver._(this._client, this._combine)
      : _value = Signal<R>.lazy(),
        _structureVersion = Signal<int>(0);

  factory QueriesObserver._fixed(
    QueryClient client,
    Iterable<AnyQueryTarget> targets,
    QueriesCombiner<R> combine,
  ) {
    final observer = QueriesObserver<R>._(client, combine);
    try {
      observer
        .._reconcileTargets(targets)
        .._startResultEffect();
      return observer;
    } on Object {
      observer.dispose();
      rethrow;
    }
  }

  factory QueriesObserver._watched(
    QueryClient client,
    Iterable<AnyQueryTarget> Function() targets,
    QueriesCombiner<R> combine,
  ) {
    final observer = QueriesObserver<R>._(client, combine);
    try {
      observer._targetEffect = Effect(
        () => observer._reconcileTargets(targets()),
        detach: true,
      );
      observer._startResultEffect();
      return observer;
    } on Object {
      observer.dispose();
      rethrow;
    }
  }

  final QueryClient _client;
  final QueriesCombiner<R> _combine;
  final Signal<R> _value;
  final Signal<int> _structureVersion;
  List<_ErasedQuerySlot> _slots = <_ErasedQuerySlot>[];
  Effect? _targetEffect;
  Effect? _resultEffect;
  bool _hasValue = false;
  bool _isDisposed = false;

  /// Whether this observer and all of its child observers are disposed.
  bool get isDisposed => _isDisposed;

  /// The current result without reactive tracking.
  R get snapshot => _value.peek;

  @override
  R get peek => _value.peek;

  @override
  R get value => _value.value;

  void _startResultEffect() {
    _resultEffect = Effect(_recompute, detach: true);
  }

  void _reconcileTargets(Iterable<AnyQueryTarget> targets) {
    if (_isDisposed) return;
    _client.checkActiveInternal();
    final requested = List<AnyQueryTarget>.of(targets, growable: false);
    final remaining = <(QueryClient, QueryKey), ListQueue<_ErasedQuerySlot>>{};
    for (final slot in _slots) {
      (remaining[(slot.client, slot.key)] ??= ListQueue<_ErasedQuerySlot>())
          .add(slot);
    }
    final next = <_ErasedQuerySlot>[];
    final created = <_ErasedQuerySlot>[];

    try {
      for (final target in requested) {
        final matches = remaining[(_client, target.key)];
        final previous =
            matches == null || matches.isEmpty ? null : matches.removeFirst();
        if (previous == null) {
          final slot = _createSlot(target);
          created.add(slot);
          next.add(slot);
        } else if (identical(previous.source, target)) {
          next.add(previous);
        } else if (previous.update(target)) {
          next.add(previous);
        } else {
          final slot = _createSlot(target);
          created.add(slot);
          next.add(slot);
          previous.dispose();
        }
      }
    } on Object {
      for (final slot in created) {
        slot.dispose();
      }
      rethrow;
    }
    for (final slots in remaining.values) {
      for (final removed in slots) {
        removed.dispose();
      }
    }
    _slots = next;
    _structureVersion.value = _structureVersion.peek + 1;
  }

  _ErasedQuerySlot _createSlot(AnyQueryTarget source) {
    return source.resolved.accept(
      _CreateErasedQuerySlot(_client, source),
    );
  }

  void _recompute() {
    _structureVersion.value;
    final results = IList<ErasedQueryObserverResult>(
      _slots.map((slot) => slot.read()),
    );
    final next = untracked(() => _combine(results));
    if (_hasValue && _value.peek == next) return;
    _hasValue = true;
    _value.value = next;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _targetEffect?.dispose();
    _targetEffect = null;
    _resultEffect?.dispose();
    _resultEffect = null;
    final slots = _slots;
    _slots = <_ErasedQuerySlot>[];
    for (final slot in slots) {
      slot.dispose();
    }
    _structureVersion.dispose();
    _value.dispose();
    _client.releaseDisposableInternal(this);
  }
}

abstract interface class _ErasedQuerySlot implements Disposable {
  QueryClient get client;
  AnyQueryTarget get source;
  QueryKey get key;

  bool update(AnyQueryTarget target);
  ErasedQueryObserverResult read();

  @override
  void dispose();
}

final class _TypedErasedQuerySlot<T> implements _ErasedQuerySlot {
  _TypedErasedQuerySlot({
    required this.client,
    required this.source,
    required this.observer,
  }) : key = source.key;

  @override
  final QueryClient client;
  @override
  AnyQueryTarget source;
  final QueryObserver<T> observer;
  @override
  final QueryKey key;
  QueryObserverResult<T>? _lastTyped;
  ErasedQueryObserverResult? _lastErased;

  @override
  bool update(AnyQueryTarget target) {
    if (target.key != key) return false;
    return target.resolved.accept(
      _UpdateErasedQuerySlot<T>(this, target),
    );
  }

  @override
  ErasedQueryObserverResult read() {
    final typed = observer.value;
    if (!identical(typed, _lastTyped)) {
      _lastTyped = typed;
      _lastErased = ErasedQueryObserverResult.from(typed);
    }
    return _lastErased!;
  }

  @override
  void dispose() => observer.dispose();
}

final class _UpdateErasedQuerySlot<T>
    implements ResolvedQueryTargetVisitor<bool> {
  const _UpdateErasedQuerySlot(this.slot, this.source);

  final _TypedErasedQuerySlot<T> slot;
  final AnyQueryTarget source;

  @override
  bool visit<TView>(ResolvedQueryTarget<TView> target) {
    final typedTarget = target;
    if (typedTarget is! ResolvedQueryTarget<T>) return false;
    slot
      ..source = source
      ..observer.updateResolvedTargetInternal(
        typedTarget as ResolvedQueryTarget<T>,
      );
    return true;
  }
}

final class _CreateErasedQuerySlot
    implements ResolvedQueryTargetVisitor<_ErasedQuerySlot> {
  const _CreateErasedQuerySlot(this.client, this.source);

  final QueryClient client;
  final AnyQueryTarget source;

  @override
  _ErasedQuerySlot visit<TView>(ResolvedQueryTarget<TView> target) {
    return _TypedErasedQuerySlot<TView>(
      client: client,
      source: source,
      observer: client.observeResolvedQueryInternal(target),
    );
  }
}
