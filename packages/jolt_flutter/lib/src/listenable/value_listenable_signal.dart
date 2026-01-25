part of 'listenable.dart';

final _delegatedValueListenableSignals =
    Expando<DelegatedRefCountHelper<SignalImpl<Object?>>>();

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
  ReadonlySignal<T> toListenableSignal({JoltDebugOption? debug}) {
    return ValueListenableSignal.from(this, debug: debug);
  }
}

/// A read-only Signal wrapping a ValueListenable.
///
/// Multiple instances share the same DelegatedSignal via reference counting.
/// When all instances are disposed, the shared signal is also disposed.
class ValueListenableSignal<T> extends DelegatedReadonlySignal<T> {
  /// Creates from a DelegatedRefCountHelper.
  ValueListenableSignal.delegated(super.delegated);

  /// Creates a ReadonlySignal from a ValueListenable.
  ///
  /// Parameters:
  /// - [listenable]: The ValueListenable to wrap
  /// - [debug]: Optional debug options
  ///
  /// Returns: A ReadonlySignal synchronized with the ValueListenable
  static ReadonlySignal<T> from<T>(ValueListenable<T> listenable,
      {JoltDebugOption? debug}) {
    if (listenable is JoltValueListenable<T>) {
      final node = listenable.node;
      if (node is ReadonlySignal<T>) {
        return node;
      }
    }
    final delegated = _getOrCreateDelegated(listenable, debug: debug);
    return ValueListenableSignal.delegated(delegated);
  }

  static DelegatedRefCountHelper<SignalImpl<T>> _getOrCreateDelegated<T>(
    ValueListenable<T> listenable, {
    JoltDebugOption? debug,
  }) {
    var delegated = _delegatedValueListenableSignals[listenable]
        as DelegatedRefCountHelper<SignalImpl<T>>?;

    if (delegated == null) {
      _delegatedValueListenableSignals[listenable] =
          delegated = _createDelegatedSignalImpl<T>(
        listenable,
        expando: _delegatedValueListenableSignals,
        debug: debug,
      );
    }

    return delegated;
  }
}
