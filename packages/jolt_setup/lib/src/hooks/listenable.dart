import 'package:flutter/foundation.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_setup/hooks.dart';
import 'package:jolt_setup/jolt_setup.dart';

/// Creates a ValueNotifier that is automatically disposed when the widget is unmounted.
///
/// Parameters:
/// - [initialValue]: The initial value for the ValueNotifier
///
/// Example:
/// ```dart
/// final notifier = useValueNotifier(0);
/// notifier.value = 10; // Update value
/// ```
@defineHook
ValueNotifier<T> useValueNotifier<T>(T initialValue) {
  return useChangeNotifier(
    () => ValueNotifier(initialValue),
  );
}

/// Subscribes to a ValueListenable and calls the listener when the value changes.
///
/// Parameters:
/// - [listenable]: The ValueListenable to subscribe to
/// - [listener]: Function called when the value changes, receives the new value
///
/// Example:
/// ```dart
/// final notifier = ValueNotifier(0);
/// useValueListenable(notifier, (value) {
///   print('Value changed to: $value');
/// });
/// ```
@defineHook
void useValueListenable<T>(
    ValueListenable<T> listenable, void Function(T value) listener) {
  useMemoized(() {
    void internalListener() {
      listener(listenable.value);
    }

    listenable.addListener(internalListener);
    return internalListener;
  }, (listener) => listenable.removeListener(listener));
}

/// Subscribes to a Listenable and calls the listener when it notifies.
///
/// Parameters:
/// - [listenable]: The Listenable to subscribe to
/// - [listener]: Callback function called when the listenable notifies
///
/// Example:
/// ```dart
/// final notifier = ChangeNotifier();
/// useListenable(notifier, () {
///   print('Notifier changed');
/// });
/// ```
@defineHook
void useListenable<T>(Listenable listenable, VoidCallback listener) {
  useMemoized(() {
    listenable.addListener(listener);
    return listener;
  }, (listener) => listenable.removeListener(listener));
}

/// Subscribes to a Listenable and syncs it with a Writable node, optionally bidirectional.
///
/// Parameters:
/// - [node]: The Writable node to sync with
/// - [listenable]: The Listenable to subscribe to
/// - [getter]: Function to get the value from the listenable
/// - [setter]: Optional function to set the value to the listenable (enables bidirectional sync)
///
/// Example:
/// ```dart
/// final signal = useSignal(0);
/// final notifier = ValueNotifier(0);
/// useListenableSync(
///   signal,
///   notifier,
///   getter: (n) => n.value,
///   setter: (value) => notifier.value = value, // Bidirectional sync
/// );
/// ```
@defineHook
void useListenableSync<T, C extends Listenable>(Writable<T> node, C listenable,
    {required T Function(C listenable) getter,
    void Function(T value)? setter}) {
  useMemoized(() {
    late final VoidCallback listener;
    late final VoidCallback disposer;

    if (setter != null) {
      bool skip = false;
      final watcher = Watcher(() => node.value, (value, __) {
        if (skip) {
          skip = false;
          return;
        }
        setter(value);
      }, when: IMutableCollection.skipNode(node));

      listener = () {
        skip = true;
        try {
          node.value = getter(listenable);
        } catch (_) {
          skip = false;
          rethrow;
        }
      };
      disposer = () {
        watcher.dispose();
        listenable.removeListener(listener);
      };
    } else {
      listener = () {
        node.value = getter(listenable);
      };
      disposer = () {
        listenable.removeListener(listener);
      };
    }

    listenable.addListener(listener);

    return disposer;
  }, (disposer) => disposer());
}

class _ChangeNotifierHook<T extends ChangeNotifier> extends SetupHook<T> {
  _ChangeNotifierHook(this.creator);

  final T Function() creator;
  @override
  T build() => creator();

  @override
  void unmount() {
    state.dispose();
  }
}

@pragma('vm:prefer-inline')
@pragma('wasm:prefer-inline')
@pragma('dart2js:prefer-inline')
@defineHook
T useChangeNotifier<T extends ChangeNotifier>(T Function() creator) {
  return useHook(_ChangeNotifierHook(creator));
}
