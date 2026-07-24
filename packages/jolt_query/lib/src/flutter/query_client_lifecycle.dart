import 'package:flutter/widgets.dart';
import 'package:shared_interfaces/shared_interfaces.dart' show Disposable;

import '../query/client.dart';

/// Explicit Flutter application-lifecycle binding for one [QueryClient].
///
/// The client owns this handle after [bindFlutterLifecycle] returns. Calling
/// [dispose] early unregisters it without disposing the client or Flutter
/// binding. Disposing the client also disposes this handle.
final class FlutterLifecycleBinding
    with WidgetsBindingObserver
    implements Disposable {
  FlutterLifecycleBinding._(this._client, this._binding) {
    _binding.addObserver(this);
    final initialState = _binding.lifecycleState;
    if (initialState != null) _apply(initialState);
  }

  final QueryClient _client;
  final WidgetsBinding _binding;
  bool _isDisposed = false;

  /// Whether this handle has stopped observing Flutter lifecycle changes.
  bool get isDisposed => _isDisposed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed || _client.isDisposed) return;
    _apply(state);
  }

  void _apply(AppLifecycleState state) {
    _client.focusManager.isFocused = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _binding.removeObserver(this);
    _client.releaseDisposableInternal(this);
  }
}

/// Flutter lifecycle integration methods for [QueryClient].
extension QueryClientFlutterLifecycleMethods on QueryClient {
  /// Mirrors Flutter application focus into [QueryClient.focusManager].
  ///
  /// Only [AppLifecycleState.resumed] is considered focused. This binding does
  /// not infer connectivity or modify [QueryClient.onlineManager].
  FlutterLifecycleBinding bindFlutterLifecycle({
    WidgetsBinding? binding,
  }) {
    checkActiveInternal();
    return ownDisposableInternal(
      FlutterLifecycleBinding._(this, binding ?? WidgetsBinding.instance),
    );
  }
}
