import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';

import '../setup/framework.dart';
import 'annotation.dart';

/// Automatic keep-alive hook factory methods.
class JoltSetupHookAutomaticKeepAliveCreator {
  const JoltSetupHookAutomaticKeepAliveCreator._();

  /// Sets a fixed keep-alive policy for the current setup scope.
  @defineHook
  void call(bool wantKeepAlive) {
    return useHook(
        _AutomaticKeepAliveClientHook(wantKeepAlive: Readonly(wantKeepAlive)));
  }

  /// Sets a reactive keep-alive policy for the current setup scope.
  @defineHook
  void value(Readable<bool> wantKeepAlive) {
    return useHook(_AutomaticKeepAliveClientHook(wantKeepAlive: wantKeepAlive));
  }
}

/// Controls whether the current subtree should stay alive when off-screen.
///
/// Call `useAutomaticKeepAlive(true)` for a fixed keep-alive policy, or
/// `useAutomaticKeepAlive.value(readable)` when the policy should react to
/// state changes.
///
/// ```dart
/// setup(context, props) {
///   useAutomaticKeepAlive(true);
///
///   return () => const ExpensiveEditor();
/// }
/// ```
final useAutomaticKeepAlive = JoltSetupHookAutomaticKeepAliveCreator._();

class _AutomaticKeepAliveClientHook extends SetupHook<void> {
  _AutomaticKeepAliveClientHook({required Readable<bool> wantKeepAlive})
      : _wantKeepAlive = wantKeepAlive;

  final Readable<bool> _wantKeepAlive;
  PostFrameEffect? _effect;
  KeepAliveHandle? _keepAliveHandle;

  void _ensureKeepAlive() {
    assert(_keepAliveHandle == null);
    _keepAliveHandle = KeepAliveHandle();
    KeepAliveNotification(_keepAliveHandle!).dispatch(context);
  }

  void _releaseKeepAlive() {
    _keepAliveHandle!.dispose();
    _keepAliveHandle = null;
  }

  bool _isActive = false;

  void updateKeepAlive() {
    if (_wantKeepAlive.peek) {
      if (_keepAliveHandle == null) {
        _ensureKeepAlive();
      }
    } else {
      if (_keepAliveHandle != null) {
        _releaseKeepAlive();
      }
    }
  }

  @override
  @protected
  void mount() {
    _isActive = true;
    _effect = PostFrameEffect(() {
      _wantKeepAlive.value;
      if (_isActive) {
        updateKeepAlive();
      }
    });
  }

  @override
  @protected
  void unmount() {
    _effect?.dispose();
    _effect = null;
  }

  @override
  @protected
  void deactivate() {
    if (_keepAliveHandle != null) {
      _releaseKeepAlive();
    }
    _isActive = false;
  }

  @override
  @protected
  void activate() {
    _isActive = true;
    updateKeepAlive();
  }

  @override
  @protected
  void build() {}
}
