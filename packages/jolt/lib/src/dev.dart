import 'jolt/computed.dart';
import 'jolt/effect.dart';
import 'jolt/observer.dart';
import 'jolt/signal.dart';

class DebugJoltObserver implements IJoltObserver {
  DebugJoltObserver();

  final Set<WeakReference<Signal>> _signals = {};
  final Set<WeakReference<Computed>> _computeds = {};
  final Set<WeakReference<Effect>> _effects = {};
  final Set<WeakReference<EffectScope>> _effectScopes = {};
  final Set<WeakReference<Watcher>> _watchers = {};

  @override
  void onComputedCreated(Computed source) {
    print('Computed created: ${source.value}');
    _computeds.add(WeakReference(source));
  }

  @override
  void onComputedUpdated(Computed source, Object? newValue, Object? oldValue) {
    print('Computed updated: $oldValue -> $newValue');
  }

  @override
  void onComputedNotified(Computed source) {
    print('Computed notified: ${source.value}');
  }

  @override
  void onComputedDisposed(Computed source) {
    print('Computed disposed: ${source.value}');
    _computeds.removeWhere((e) => e.target == source);
  }

  @override
  void onEffectCreated(Effect source) {
    print('Effect created: ${source.runtimeType}');
    _effects.add(WeakReference(source));
  }

  @override
  void onEffectTriggered(Effect source) {
    print('Effect triggered: ${source.runtimeType}');
  }

  @override
  void onEffectDisposed(Effect source) {
    print('Effect disposed: ${source.runtimeType}');
    _effects.removeWhere((e) => e.target == source);
  }

  @override
  void onEffectScopeCreated(EffectScope source) {
    print('Effect scope created: ${source.runtimeType}');
  }

  @override
  void onEffectScopeDisposed(EffectScope source) {
    print('Effect scope disposed: ${source.runtimeType}');
  }

  @override
  void onSignalCreated(Signal source) {
    print('Signal created: ${source.value}');
    _signals.add(WeakReference(source));
  }

  @override
  void onSignalUpdated(Signal source, Object? newValue, Object? oldValue) {
    print('Signal updated: $oldValue -> $newValue');
  }

  @override
  void onSignalNotified(Signal source) {
    print('Signal notified: ${source.value}');
  }

  @override
  void onSignalDisposed(Signal source) {
    print('Signal disposed: ${source.value}');
    _signals.removeWhere((e) => e.target == source);
  }

  @override
  void onWatcherCreated(Watcher source) {
    print('Watcher created: ${source.runtimeType}');
    _watchers.add(WeakReference(source));
  }

  @override
  void onWatcherTriggered(Watcher source) {
    print('Watcher triggered: ${source.runtimeType}');
  }

  @override
  void onWatcherDisposed(Watcher source) {
    print('Watcher disposed: ${source.runtimeType}');
    _watchers.removeWhere((e) => e.target == source);
  }
}
