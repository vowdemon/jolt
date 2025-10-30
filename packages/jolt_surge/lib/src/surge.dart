import 'package:jolt/jolt.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'observer.dart';
import 'shared.dart';

abstract class Surge<State> implements Disposable {
  Surge(State initialState) : _state = Signal(initialState) {
    SurgeObserver.observer?.onCreate(this);
  }

  final Signal<State> _state;
  bool _isDisposed = false;

  State get state => _state.value;
  Signal<State> get raw => _state;
  Stream<State> get stream => _state.stream;
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    SurgeObserver.observer?.onDispose(this);
  }

  void emit(State state) {
    assert(!_isDisposed, 'JoltSurge is disposed');

    if (state == _state.peek) return;
    onChange(Change(currentState: _state.peek, nextState: state));
    _state.set(state);
  }

  void onChange(Change<State> change) {
    SurgeObserver.observer?.onChange(this, change);
  }
}
