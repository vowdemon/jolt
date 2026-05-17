part of 'listenable.dart';

final _valueListenableSignals = Expando<ValueListenableSignal<Object?>>();

/// Extension for converting ValueListenable to Jolt Signal.
extension JoltValueListenableSignalExtension<T> on ValueListenable<T> {
  /// Converts this ValueListenable to a read-only Signal.
  ///
  /// Creates a unidirectional bridge: ValueListenable changes sync to Signal,
  /// but Signal cannot be modified.
  ///
  /// Parameters:
  /// - [debug]: Optional debug options
  ///
  /// Returns: A ReadonlySignal synchronized with this ValueListenable
  ///
  /// Example:
  /// ```dart
  /// final notifier = ValueNotifier(0);
  /// final signal = notifier.toListenableSignal();
  /// notifier.value = 1; // signal.value becomes 1
  /// ```
  Readable<T> toListenableSignal({JoltDebugOption? debug}) {
    final source = this;
    if (source is JoltValueListenable<T>) {
      return source.node;
    }
    if (source is JoltValueNotifier<T>) {
      return source.node;
    }

    var signal = _valueListenableSignals[this] as ValueListenableSignal<T>?;
    if (signal == null) {
      _valueListenableSignals[this] =
          signal = ValueListenableSignal(this, debug: debug);
    }
    return signal;
  }
}

/// A read-only Signal wrapping a ValueListenable.
///
/// A shared bridge is cached per source listenable until disposed.
class ValueListenableSignal<T> implements Readonly<T>, Disposable {
  final ValueListenable<T> listenable;
  final SignalNode<T> raw;

  ValueListenableSignal(this.listenable, {JoltDebugOption? debug})
      : raw = SignalNode(listenable.value) {
    listenable.addListener(_listener);
  }

  late final T _disposedValue;
  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _disposedValue = peek;
    _isDisposed = true;
    _valueListenableSignals[listenable] = null;
    listenable.removeListener(_listener);
    raw.dispose();
  }

  bool get isDisposed => _isDisposed;

  @override
  T get peek => _isDisposed ? _disposedValue : listenable.value;

  @override
  T get value {
    if (_isDisposed) return _disposedValue;
    return raw.get();
  }

  void _listener() {
    raw.set(listenable.value);
  }
}
