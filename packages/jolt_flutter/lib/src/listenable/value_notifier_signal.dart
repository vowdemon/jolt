part of 'listenable.dart';

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
    return ValueNotifierSignal(this, debug: debug);
  }
}

/// A writable Signal wrapping a ValueNotifier with bidirectional sync.
///
/// Multiple instances share the same DelegatedSignal via reference counting.
/// When all instances are disposed, the shared signal is also disposed.
class ValueNotifierSignal<T> implements Signal<T> {
  final SignalNode<T> raw;
  final ValueNotifier<T> notifier;

  /// Creates from a DelegatedRefCountHelper and ValueNotifier.
  ValueNotifierSignal(this.notifier, {JoltDebugOption? debug})
      : raw = SignalNode(notifier.value) {
    notifier.addListener(_listener);
  }

  @override
  T get value {
    if (isDisposed) return notifier.value;
    return raw.get();
  }

  @override
  set value(T value) {
    notifier.value = value;
  }

  @override
  void dispose() {
    notifier.removeListener(_listener);
    raw.dispose();
  }

  @override
  bool get isDisposed => raw.isDisposed;

  @override
  void notify([bool force = true]) => raw.notify();

  @override
  T get peek => notifier.value;

  void _listener() {
    raw.value = notifier.value;
  }
}
