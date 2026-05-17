part of 'listenable.dart';

final _valueNotifierSignals = Expando<ValueNotifierSignal<Object?>>();

/// Extension for converting ValueNotifier to Jolt Signal.
extension JoltValueNotifierSignalExtension<T> on ValueNotifier<T> {
  /// Converts this ValueNotifier to a Signal with bidirectional sync.
  ///
  /// Changes to either ValueNotifier or Signal are synchronized.
  ///
  /// Parameters:
  /// - [debug]: Optional debug options
  ///
  /// Returns: A Signal synchronized with this ValueNotifier
  ///
  /// Example:
  /// ```dart
  /// final notifier = ValueNotifier(0);
  /// final signal = notifier.toNotifierSignal();
  /// notifier.value = 1; // signal.value becomes 1
  /// signal.value = 2;   // notifier.value becomes 2
  /// ```
  Signal<T> toNotifierSignal({JoltDebugOption? debug}) {
    final source = this;
    if (source is JoltValueNotifier<T>) {
      final node = source.node;
      if (node is Signal<T>) {
        return node;
      }
    }

    var signal = _valueNotifierSignals[this] as ValueNotifierSignal<T>?;
    if (signal == null) {
      _valueNotifierSignals[this] =
          signal = ValueNotifierSignal(this, debug: debug);
    }
    return signal;
  }
}

/// A writable Signal wrapping a ValueNotifier with bidirectional sync.
///
/// A shared bridge is cached per source notifier until disposed.
class ValueNotifierSignal<T> implements Signal<T> {
  final SignalNode<T> raw;
  final ValueNotifier<T> notifier;

  ValueNotifierSignal(this.notifier, {JoltDebugOption? debug})
      : raw = SignalNode(notifier.value) {
    notifier.addListener(_listener);
  }

  late final T _disposedValue;
  bool _isDisposed = false;

  @override
  T get value {
    if (_isDisposed) return _disposedValue;
    return raw.get();
  }

  @override
  set value(T value) {
    if (_isDisposed) return;
    notifier.value = value;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _disposedValue = peek;
    _isDisposed = true;
    _valueNotifierSignals[notifier] = null;
    notifier.removeListener(_listener);
    raw.dispose();
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void notify([bool force = true]) {
    if (_isDisposed) return;
    raw.notify();
  }

  @override
  T get peek => _isDisposed ? _disposedValue : notifier.value;

  void _listener() {
    raw.set(notifier.value);
  }
}
