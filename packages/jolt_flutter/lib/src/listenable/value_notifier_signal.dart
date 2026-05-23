part of 'listenable.dart';

final _valueNotifierSignals = Expando<ValueNotifierSignal<Object?>>();

/// Converts Flutter [ValueNotifier] to Jolt [Signal].
extension JoltValueNotifierSignalExtension<T> on ValueNotifier<T> {
  /// A writable Jolt view of this notifier with bidirectional sync.
  ///
  /// If this is a [JoltValueNotifier] backed by a [Signal], that signal is
  /// returned. Otherwise a cached [ValueNotifierSignal] is shared until
  /// [ValueNotifierSignal.dispose].
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

/// A writable Jolt bridge from a [ValueNotifier].
///
/// Assignments to [value] update the notifier, and notifier changes update the
/// signal. One cached instance exists per source notifier until [dispose].
/// After disposal, [peek] and [value] keep returning the last value seen before
/// disposal, and assignments to [value] are ignored.
class ValueNotifierSignal<T> implements Signal<T> {
  /// The Jolt node that tracks the current notifier value.
  final SignalNode<T> raw;

  /// The Flutter notifier mirrored by this bridge.
  final ValueNotifier<T> notifier;

  /// Creates a writable bridge for [notifier].
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
  void notify() {
    if (_isDisposed) return;
    raw.notify();
  }

  @override
  T get peek => _isDisposed ? _disposedValue : notifier.value;

  void _listener() {
    raw.set(notifier.value);
  }
}
