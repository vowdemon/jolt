part of 'listenable.dart';

final _valueListenableSignals = Expando<ValueListenableSignal<Object?>>();

/// Converts Flutter [ValueListenable] to Jolt [Readable].
extension JoltValueListenableSignalExtension<T> on ValueListenable<T> {
  /// A read-only Jolt view of this listenable.
  ///
  /// Changes on the listenable update the returned readable; the readable cannot
  /// push values back. If this is a [JoltValueListenable] or [JoltValueNotifier],
  /// the original Jolt node is returned. Otherwise a cached
  /// [ValueListenableSignal] is shared until [ValueListenableSignal.dispose].
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

/// A read-only Jolt bridge from a [ValueListenable].
///
/// One cached instance exists per source listenable until [dispose]. After
/// disposal, both [peek] and tracked [value] reads keep returning the last
/// value seen before disposal.
class ValueListenableSignal<T> implements Readonly<T>, Disposable {
  /// The Flutter listenable mirrored by this bridge.
  final ValueListenable<T> listenable;

  /// The Jolt node that tracks the current listenable value.
  final SignalNode<T> raw;

  /// Creates a read-only bridge for [listenable].
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

  /// Whether this bridge has been disposed.
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
