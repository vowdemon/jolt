import 'package:jolt/tricks.dart' as jt;

import '../mixins/value_notifier.dart';
import 'signal.dart';

class ConvertComputed<T, U> extends jt.ConvertComputed<T, U>
    with JoltValueNotifier<T>
    implements Signal<T> {
  ConvertComputed(super.source, {required super.decode, required super.encode});
}

class MapEntrySignal<T extends V, K, V> extends jt.MapEntrySignal<T, K, V>
    with JoltValueNotifier<T>
    implements Signal<T> {
  MapEntrySignal(super.map, super.key,
      {super.defaultValue,
      super.createIfAbsent,
      super.autoDispose,
      super.connect});
}

class PersistSignal<T> extends jt.PersistSignal<T>
    with JoltValueNotifier<T>
    implements Signal<T> {
  PersistSignal(
      {super.initialValue,
      required super.read,
      required super.write,
      super.lazy,
      super.writeDelay,
      super.autoDispose});
}
