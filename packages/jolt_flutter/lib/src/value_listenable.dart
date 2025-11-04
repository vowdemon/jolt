part of 'value_notifier.dart';

extension JoltValueListenableExtension<T> on jolt.JReadonlyValue<T> {
  /// Converts this Jolt value to a Flutter ValueListenable.
  ///
  /// Returns a cached instance that stays synchronized with this Jolt value.
  /// Multiple calls return the same instance.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(42);
  /// final listenable = signal.listenable;
  ///
  /// // Use with ValueListenableBuilder
  /// ValueListenableBuilder<int>(
  ///   valueListenable: listenable,
  ///   builder: (context, value, child) => Text('$value'),
  /// )
  /// ```
  JoltValueListenable<T> get listenable {
    JoltValueListenable<T>? notifier =
        _notifiers[this] as JoltValueListenable<T>?;
    if (notifier == null) {
      _notifiers[this] = notifier = JoltValueListenable(this);
    }
    return notifier;
  }
}

class JoltValueListenable<T> extends _JoltValueNotifierBase<T>
    implements ValueListenable<T> {
  JoltValueListenable(super.joltValue);
}

extension JoltFlutterListenableExtension<T> on ValueListenable<T> {
  /// Converts this ValueListenable to a read-only Signal.
  ///
  /// Creates a unidirectional bridge from Flutter's ValueListenable to Jolt.
  /// Changes to the original ValueListenable will be synchronized to the Signal,
  /// but the Signal cannot be modified.
  ///
  /// Parameters:
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final notifier = ValueNotifier(0);
  /// final signal = notifier.toListenableSignal();
  ///
  /// // Only notifier changes sync to signal
  /// notifier.value = 1; // signal.value becomes 1
  /// // signal.value = 2; // This would throw an error
  /// ```
  jolt.ReadonlySignal<T> toListenableSignal({JoltDebugFn? onDebug}) {
    return _ValueListenableSignal(this, onDebug: onDebug);
  }
}

class _ValueListenableSignal<T> extends jolt.Signal<T> {
  _ValueListenableSignal(ValueListenable<T> listenable, {super.onDebug})
      : super(listenable.value) {
    _listener = () {
      final newValue = listenable.value;
      if (newValue != peek) {
        super.set(newValue);
      }
    };

    listenable.addListener(_listener);

    JFinalizer.attachToJoltAttachments(this, () {
      listenable.removeListener(_listener);
    });
  }

  late VoidCallback _listener;

  @override
  void set(T value) {
    throw UnimplementedError();
  }
}
