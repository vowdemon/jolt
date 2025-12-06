import 'package:flutter/foundation.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt_flutter/core.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

part 'value_listenable.dart';
part 'value_notifier.dart';

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
