import 'dart:async';

/// The exception thrown by [QueryCancellationToken.throwIfCancelled].
final class QueryCancelledException implements Exception {
  /// Creates a cancellation exception with an optional [reason].
  const QueryCancelledException([this.reason]);

  /// The caller-supplied cancellation reason.
  final Object? reason;

  @override
  String toString() => reason == null
      ? 'QueryCancelledException'
      : 'QueryCancelledException: $reason';
}

/// A cooperatively consumed query cancellation token.
final class QueryCancellationToken {
  QueryCancellationToken._(this._state);

  final _CancellationState _state;

  /// Whether cancellation has been requested.
  ///
  /// Reading this property marks the token as consumed by the query function.
  bool get isCancelled {
    _state.isConsumed = true;
    return _state.isCancelled;
  }

  /// The cancellation reason, or `null` when absent.
  ///
  /// Reading this property marks the token as consumed.
  Object? get reason {
    _state.isConsumed = true;
    return _state.reason;
  }

  /// Completes with the cancellation reason when cancellation is requested.
  ///
  /// Reading this property marks the token as consumed.
  Future<Object?> get whenCancelled {
    _state.isConsumed = true;
    return _state.completer.future;
  }

  /// Whether user code has consumed a cancellation capability.
  bool get wasConsumed => _state.isConsumed;

  /// Adds a synchronous cancellation listener and returns a removal callback.
  ///
  /// The listener runs in the Zone in which it was registered. Registering a
  /// listener marks the token as consumed.
  void Function() addListener(void Function(Object? reason) listener) {
    _state.isConsumed = true;
    return _state.addListener(listener);
  }

  /// Throws [QueryCancelledException] when cancellation was requested.
  void throwIfCancelled() {
    _state.isConsumed = true;
    if (_state.isCancelled) {
      throw QueryCancelledException(_state.reason);
    }
  }
}

/// Owns and triggers a [QueryCancellationToken].
final class QueryCancellationController {
  /// Creates an uncancelled controller.
  QueryCancellationController() : _state = _CancellationState() {
    token = QueryCancellationToken._(_state);
  }

  final _CancellationState _state;

  /// The token passed to query functions.
  late final QueryCancellationToken token;

  /// Whether cancellation has been requested, without consuming the token.
  bool get isCancelled => _state.isCancelled;

  /// The cancellation reason, without consuming the token.
  Object? get reason => _state.reason;

  /// Whether query code consumed the token.
  bool get wasConsumed => _state.isConsumed;

  /// Adds an owner-side listener without marking the user token as consumed.
  void Function() addListener(void Function(Object? reason) listener) =>
      _state.addListener(listener);

  /// Requests cancellation once and notifies all current listeners.
  bool cancel([Object? reason]) {
    if (_state.isCancelled) return false;
    _state
      ..isCancelled = true
      ..reason = reason;
    _state.completer.complete(reason);
    final listeners = List<_CancellationListener>.of(_state.listeners);
    _state.listeners.clear();
    for (final registration in listeners) {
      registration.zone.runGuarded(
        () => registration.listener(reason),
      );
    }
    return true;
  }
}

final class _CancellationState {
  _CancellationState();

  final Completer<Object?> completer = Completer<Object?>.sync();
  final List<_CancellationListener> listeners = <_CancellationListener>[];
  bool isCancelled = false;
  bool isConsumed = false;
  Object? reason;

  void Function() addListener(void Function(Object? reason) listener) {
    final registration = _CancellationListener(Zone.current, listener);
    if (isCancelled) {
      registration.zone.runGuarded(() => listener(reason));
      return () {};
    }
    listeners.add(registration);
    return () => listeners.remove(registration);
  }
}

final class _CancellationListener {
  const _CancellationListener(this.zone, this.listener);

  final Zone zone;
  final void Function(Object? reason) listener;
}
