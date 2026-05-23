import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import 'observer.dart';
import 'shared.dart';

/// Creates the writable reactive value that backs a [Surge].
typedef SurgeStateCreator<T> = Writable<T> Function(T state);

Signal<T> _defaultSignalCreator<T>(T state) => Signal(state);

/// A reactive state container inspired by the Cubit pattern.
///
/// Subclasses expose imperative methods that call [emit] to publish new state.
/// The current value is available through [state] and can be observed through
/// [stream] or Jolt effects.
///
/// ```dart
/// class CounterSurge extends Surge<int> {
///   CounterSurge() : super(0);
///
///   void increment() => emit(state + 1);
/// }
/// ```
abstract class Surge<State> implements ChainedDisposable {
  /// Creates a surge with [initialState].
  ///
  /// Pass [creator] to customize the backing [Writable], such as a
  /// [WritableComputed] instead of the default [Signal].
  Surge(State initialState, {SurgeStateCreator<State>? creator})
      : _state = (creator ?? _defaultSignalCreator)(initialState) {
    SurgeObserver.observer?.onCreate(this);
  }

  /// The writable reactive value that stores this surge's state.
  final Writable<State> _state;

  bool _isDisposed = false;

  /// The current state value.
  ///
  /// Reading this inside reactive code tracks the surge as a dependency.
  State get state => _state.value;

  /// The backing writable reactive value.
  Writable<State> get raw => _state;

  /// A broadcast stream of state values.
  Stream<State> get stream => _state.stream;

  /// Whether this surge has been disposed.
  bool get isDisposed => _isDisposed;

  /// Disposes this surge and its backing reactive value.
  ///
  /// After disposal, [emit] throws an assertion error.
  @override
  void dispose() {
    if (_isDisposed) return;
    onDispose();
    try {
      (_state as dynamic).dispose();
    } catch (_) {}

    _isDisposed = true;
  }

  /// Publishes [state] when it differs from the current value.
  ///
  /// [onChange] runs before the value is updated. Throws if this surge has been
  /// disposed.
  void emit(State state) {
    assert(!_isDisposed, 'JoltSurge is disposed');
    if (_isDisposed) return;

    if (state == _state.peek) return;
    onChange(Change(currentState: _state.peek, nextState: state));
    _state.set(state);
  }

  /// Called before [emit] applies a new state.
  ///
  /// The default implementation notifies [SurgeObserver.observer].
  void onChange(Change<State> change) {
    SurgeObserver.observer?.onChange(this, change);
  }

  /// Called when this surge is disposed.
  ///
  /// The default implementation notifies [SurgeObserver.observer].
  @override
  void onDispose() {
    SurgeObserver.observer?.onDispose(this);
  }
}
