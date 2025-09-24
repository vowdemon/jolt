import 'package:jolt/core.dart' show globalReactiveSystem;
import 'package:jolt/jolt.dart';
import 'package:free_disposer/free_disposer.dart';

class MapEntrySignal<T extends V, K, V> extends WritableComputed<T> {
  MapEntrySignal(
    MapSignalMixin<K, V> map,
    K key, {
    T Function()? defaultValue,
    bool createIfAbsent = false,
    super.autoDispose,
    bool connect = false,
  }) : super(() {
          if (createIfAbsent) {
            return map.putIfAbsent(
              key,
              defaultValue as V Function()? ?? () => null as V,
            ) as T;
          } else {
            return (map[key] ?? defaultValue?.call() ?? null as V) as T;
          }
        }, (value) => map[key] = value as V) {
    map.disposeWith(dispose);
    if (connect) {
      _watcherDisposer = map.subscribe(
        (_, __) {
          globalReactiveSystem.computedNotify(this);
        },
      );
    }
  }

  Disposer? _watcherDisposer;

  @override
  void onDispose() {
    _watcherDisposer?.call();
    super.onDispose();
  }
}
