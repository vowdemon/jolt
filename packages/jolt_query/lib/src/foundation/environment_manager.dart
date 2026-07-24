import 'dart:async';

import 'package:jolt/jolt.dart' show Readable, Signal;
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

/// The client-owned, stable application focus state.
final class FocusManager implements Readable<bool>, Disposable {
  /// Creates a focused manager by default.
  FocusManager({bool initiallyFocused = true})
      : _delegate = _BooleanEnvironmentManager(initiallyFocused);

  final _BooleanEnvironmentManager _delegate;

  /// Whether the application is currently focused.
  bool get isFocused => _delegate.peek;

  /// Directly updates focus state.
  set isFocused(bool value) => _delegate.setValue(value);

  /// Replaces the event source while leaving ownership of [source] to caller.
  void setEventSource(Stream<bool>? source) => _delegate.setEventSource(source);

  @override
  bool get peek => _delegate.peek;

  @override
  bool get value => _delegate.value;

  @override
  void dispose() => _delegate.dispose();
}

/// The client-owned, stable network reachability state.
final class OnlineManager implements Readable<bool>, Disposable {
  /// Creates an online manager by default.
  OnlineManager({bool initiallyOnline = true})
      : _delegate = _BooleanEnvironmentManager(initiallyOnline);

  final _BooleanEnvironmentManager _delegate;

  /// Whether the application is currently online.
  bool get isOnline => _delegate.peek;

  /// Directly updates online state.
  set isOnline(bool value) => _delegate.setValue(value);

  /// Replaces the event source while leaving ownership of [source] to caller.
  void setEventSource(Stream<bool>? source) => _delegate.setEventSource(source);

  @override
  bool get peek => _delegate.peek;

  @override
  bool get value => _delegate.value;

  @override
  void dispose() => _delegate.dispose();
}

final class _BooleanEnvironmentManager {
  _BooleanEnvironmentManager(bool initialValue)
      : _signal = Signal(initialValue);

  final Signal<bool> _signal;
  StreamSubscription<bool>? _subscription;
  int _sourceGeneration = 0;
  bool _isDisposed = false;

  bool get peek => _signal.peek;
  bool get value => _signal.value;

  void setValue(bool value) {
    if (_isDisposed) return;
    _signal.value = value;
  }

  void setEventSource(Stream<bool>? source) {
    if (_isDisposed) {
      throw StateError('Environment manager is disposed.');
    }
    _sourceGeneration += 1;
    final generation = _sourceGeneration;
    final previous = _subscription;
    _subscription = null;
    if (previous != null) unawaited(previous.cancel());
    if (source == null) return;

    final registrationZone = Zone.current;
    late final StreamSubscription<bool> subscription;
    subscription = source.listen(
      setValue,
      onError: (Object error, StackTrace stackTrace) {
        registrationZone.handleUncaughtError(error, stackTrace);
      },
      onDone: () {
        if (!_isDisposed && generation == _sourceGeneration) {
          _subscription = null;
        }
      },
    );
    if (_isDisposed || generation != _sourceGeneration) {
      unawaited(subscription.cancel());
    } else {
      _subscription = subscription;
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _sourceGeneration += 1;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _signal.dispose();
  }
}
