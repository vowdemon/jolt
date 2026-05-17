part of 'listenable.dart';

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
  ValueListenableSignal<T> toListenableSignal({JoltDebugOption? debug}) {
    return ValueListenableSignal(this, debug: debug);
  }
}

/// A read-only Signal wrapping a ValueListenable.
///
/// Multiple instances share the same DelegatedSignal via reference counting.
/// When all instances are disposed, the shared signal is also disposed.
class ValueListenableSignal<T> implements Readonly<T>, Disposable {
  final ValueListenable<T> listenable;
  final SignalNode<T> raw;

  ValueListenableSignal(this.listenable, {JoltDebugOption? debug})
      : raw = SignalNode(listenable.value) {
    listenable.addListener(_listener);
  }

  @override
  FutureOr<void> dispose() {
    listenable.removeListener(_listener);
    raw.dispose();
  }

  bool get isDisposed => raw.isDisposed;

  @override
  T get peek => listenable.value;

  @override
  T get value {
    if (isDisposed) return listenable.value;
    return raw.get();
  }

  void _listener() {
    raw.value = listenable.value;
  }
}
