part of 'listenable.dart';

final _delegatedValueNotifierSignals =
    Expando<DelegatedRefCountHelper<SignalImpl<Object?>>>();

/// Extension for converting ValueNotifier to Jolt Signal.
extension JoltValueNotifierSignalExtension<T> on ValueNotifier<T> {
  /// Converts this ValueNotifier to a Signal with bidirectional sync.
  ///
  /// Changes to either ValueNotifier or Signal are synchronized.
  ///
  /// Parameters:
  /// - [onDebug]: Optional debug callback
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
  Signal<T> toNotifierSignal({JoltDebugFn? onDebug}) {
    return ValueNotifierSignal.from(this, onDebug: onDebug);
  }
}

/// A writable Signal wrapping a ValueNotifier with bidirectional sync.
///
/// Multiple instances share the same DelegatedSignal via reference counting.
/// When all instances are disposed, the shared signal is also disposed.
class ValueNotifierSignal<T> extends DelegatedSignal<T> {
  /// Creates from a DelegatedRefCountHelper and ValueNotifier.
  ValueNotifierSignal.delegated(super.delegated, this.notifier);

  /// The wrapped ValueNotifier.
  final ValueNotifier<T> notifier;

  /// Creates a Signal from a ValueNotifier.
  ///
  /// Parameters:
  /// - [notifier]: The ValueNotifier to wrap
  /// - [onDebug]: Optional debug callback
  ///
  /// Returns: A Signal synchronized with the ValueNotifier
  static Signal<T> from<T>(ValueNotifier<T> notifier, {JoltDebugFn? onDebug}) {
    if (notifier is JoltValueNotifier<T>) {
      final node = notifier.node;
      if (node is Signal<T>) {
        return node;
      }
    }

    final delegated = _getOrCreateDelegated(notifier, onDebug: onDebug);
    return ValueNotifierSignal.delegated(delegated, notifier);
  }

  static DelegatedRefCountHelper<SignalImpl<T>> _getOrCreateDelegated<T>(
    ValueNotifier<T> notifier, {
    JoltDebugFn? onDebug,
  }) {
    var delegated = _delegatedValueNotifierSignals[notifier]
        as DelegatedRefCountHelper<SignalImpl<T>>?;

    if (delegated == null) {
      _delegatedValueNotifierSignals[notifier] =
          delegated = _createDelegatedSignalImpl<T>(
        notifier,
        expando: _delegatedValueNotifierSignals,
        onDebug: onDebug,
      );
    }

    return delegated;
  }

  @override
  set value(T value) {
    assert(!isDisposed, "ValueNotifierSignal is disposed");

    notifier.value = value;
  }
}
