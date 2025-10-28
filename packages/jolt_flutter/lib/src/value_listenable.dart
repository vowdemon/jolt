part of 'value_notifier.dart';

extension JoltValueListenableExtension<T> on jolt.JReadonlyValue<T> {
  /// Converts this Jolt value to a Flutter ValueNotifier.
  ///
  /// Returns a cached ValueNotifier instance that stays synchronized
  /// with this Jolt value. Multiple calls return the same instance.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(42);
  /// final notifier = signal.notifier;
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
  jolt.ReadonlySignal<T> toListenableSignal() {
    return _ValueListenableSignal(this);
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

    _disposer = () {
      listenable.removeListener(_listener);
    };
    disposeWith(_disposer);
  }

  late VoidCallback _listener;

  Disposer? _disposer;

  @override
  void set(T value) {
    throw UnimplementedError();
  }

  @override
  void onDispose() {
    super.onDispose();
    _disposer?.call();
    _disposer = null;
  }
}
