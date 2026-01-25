import 'package:flutter/foundation.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/core.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

part 'value_listenable.dart';
part 'value_listenable_signal.dart';
part 'value_notifier.dart';
part 'value_notifier_signal.dart';

/// Mixin providing ValueNotifier-like listener management.
///
/// Manages a list of listeners and provides methods to add, remove,
/// and notify them. Used internally by JoltValueListenable and JoltValueNotifier.
mixin _ValueNotifierMixin<T> {
  final _listeners = <VoidCallback>[];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  bool get hasListeners => _listeners.isNotEmpty;

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

/// Creates a delegated signal helper from a ValueListenable.
///
/// Parameters:
/// - [notifier]: The ValueListenable to wrap
/// - [debug]: Optional debug options
/// - [expando]: Expando for caching the helper
///
/// Returns: A DelegatedRefCountHelper managing the signal
DelegatedRefCountHelper<SignalImpl<T>> _createDelegatedSignalImpl<T>(
    ValueListenable<T> notifier,
    {JoltDebugOption? debug,
    required Expando<dynamic> expando}) {
  final source = SignalImpl<T>(notifier.value, debug: debug);
  Disposer? watcherDisposer;

  return DelegatedRefCountHelper(source, onCreate: (source) {
    void listener() {
      source.value = notifier.value;
    }

    notifier.addListener(listener);

    watcherDisposer = () {
      notifier.removeListener(listener);
    };
  }, onDispose: (source) {
    watcherDisposer?.call();
    watcherDisposer = null;
    expando[notifier] = null;
  }, autoDispose: true);
}
