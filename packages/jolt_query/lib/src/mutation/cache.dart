import 'dart:async';
import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../foundation/notification_orchestrator.dart';
import 'execution.dart';
import 'models.dart';

const ConfigList _mutationSnapshotListConfig = ConfigList(
  isDeepEquals: true,
  cacheHashCode: true,
);

/// Read-only submitted mutation state and committed cache events.
///
/// The cache is owned by its query client. Clearing removes cache entries but
/// does not cancel work; only disposing the client is terminal.
final class MutationCache {
  MutationCache._(this._controller);

  final MutationCacheControllerInternal _controller;

  /// Immutable erased snapshots in submission order.
  IList<MutationSnapshot> get snapshots => _controller.snapshots;

  /// Broadcast committed cache events.
  ///
  /// [clear] leaves this stream open. Client disposal closes it.
  Stream<MutationCacheEvent> get events => _controller.events;

  /// Returns immutable snapshots matching [filter].
  IList<MutationSnapshot> findAll({
    MutationFilter filter = const MutationFilter(),
  }) {
    return IList<MutationSnapshot>.withConfig(
      snapshots.where(filter.matches),
      _mutationSnapshotListConfig,
    );
  }

  /// Removes every cached snapshot without cancelling submitted work.
  void clear() => _controller.clearEntries();
}

/// Internal insertion-ordered mutable store behind [MutationCache].
final class MutationCacheControllerInternal implements Disposable {
  MutationCacheControllerInternal({
    required NotificationOrchestrator notifications,
    required this.callbacks,
    void Function()? onCommittedEvent,
  })  : _notifications = notifications,
        _onCommittedEvent = onCommittedEvent {
    public = MutationCache._(this);
  }

  final NotificationOrchestrator _notifications;
  final void Function()? _onCommittedEvent;
  final LinkedHashMap<int, MutationExecutionBaseInternal> _executions =
      LinkedHashMap<int, MutationExecutionBaseInternal>();
  final StreamController<MutationCacheEvent> _events =
      StreamController<MutationCacheEvent>.broadcast(sync: true);
  final MutationCacheCallbacks callbacks;
  bool _isDisposed = false;

  late final MutationCache public;

  bool get isDisposed => _isDisposed;
  Stream<MutationCacheEvent> get events => _events.stream;
  Iterable<MutationExecutionBaseInternal> get executions => _executions.values;

  IList<MutationSnapshot> get snapshots => IList<MutationSnapshot>.withConfig(
        _executions.values.map((execution) => execution.snapshotInternal),
        _mutationSnapshotListConfig,
      );

  bool containsExecution(MutationExecutionBaseInternal execution) =>
      identical(_executions[execution.id], execution);

  void add(MutationExecutionBaseInternal execution) {
    _checkActive();
    if (_executions.containsKey(execution.id)) {
      throw StateError('Mutation execution ID ${execution.id} already exists.');
    }
    _executions[execution.id] = execution;
    publish(execution, MutationCacheEventKind.added);
  }

  /// Queues outward publication for a state already committed synchronously.
  void publish(
    MutationExecutionBaseInternal execution,
    MutationCacheEventKind kind,
  ) {
    if (_isDisposed) return;
    final wasCached = containsExecution(execution);
    final snapshot = execution.snapshotInternal;
    _notifications.enqueue(() {
      if (_isDisposed) return;
      if (wasCached) {
        _onCommittedEvent?.call();
        _events.add(MutationCacheEvent(kind: kind, snapshot: snapshot));
      }
      execution.notifyListenerInternal();
    });
  }

  MutationExecutionBaseInternal? remove(int id) {
    final execution = _executions.remove(id);
    if (execution == null) return null;
    final snapshot = execution.snapshotInternal;
    execution.onCacheRemovedInternal();
    _notifications.enqueue(() {
      if (_isDisposed) return;
      _onCommittedEvent?.call();
      _events.add(
        MutationCacheEvent(
          kind: MutationCacheEventKind.removed,
          snapshot: snapshot,
        ),
      );
    });
    return execution;
  }

  void clearEntries() {
    _checkActive();
    for (final id in List<int>.of(_executions.keys)) {
      remove(id);
    }
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('MutationCache is disposed.');
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final executions = List<MutationExecutionBaseInternal>.of(
      _executions.values,
    );
    _executions.clear();
    for (final execution in executions) {
      execution.onCacheRemovedInternal();
    }
    unawaited(_events.close());
  }
}
