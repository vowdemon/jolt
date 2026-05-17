import 'dart:async';

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
