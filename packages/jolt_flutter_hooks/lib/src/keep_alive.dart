import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';

void useAutomaticKeepAlive(ReadonlyNode<bool> wantKeepAlive) {
  return useHook(_AutomaticKeepAliveClientHook(wantKeepAlive: wantKeepAlive));
}

class _AutomaticKeepAliveClientHook extends SetupHook<void> {
  _AutomaticKeepAliveClientHook({required ReadonlyNode<bool> wantKeepAlive})
      : _wantKeepAlive = wantKeepAlive;

  final ReadonlyNode<bool> _wantKeepAlive;
  FlutterEffect? _effect;
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
    _effect = FlutterEffect(() {
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

  // coverage:ignore-start
  @override
  @protected
  void activate() {
    _isActive = true;
    updateKeepAlive();
  }
  // coverage:ignore-end

  @override
  @protected
  void build() {}
}
