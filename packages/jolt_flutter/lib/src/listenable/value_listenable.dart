part of 'listenable.dart';

final _listenables = Expando<JoltValueListenable<Object?>>();

/// Converts [Readable] values to Flutter [ValueListenable].
extension JoltValueListenableExtension<T> on Readable<T> {
  /// A cached [JoltValueListenable] synchronized with this readable.
  ///
  /// Repeated access returns the same instance until [JoltValueListenable.dispose]
  /// clears the cache entry.
  JoltValueListenable<T> get listenable {
    var listenable = _listenables[this] as JoltValueListenable<T>?;

    if (listenable == null) {
      _listenables[this] = listenable = JoltValueListenable(this);
    }

    return listenable;
  }
}

/// A [ValueListenable] backed by a Jolt [Readable].
///
/// [value] reflects the readable via [Readable.peek]. Listeners are notified
/// when the underlying readable changes. [dispose] stops synchronization and
/// removes this wrapper from the cache for [node].
class JoltValueListenable<T>
    with _ValueNotifierMixin<T>
    implements ValueListenable<T>, Disposable {
  /// Wraps [node] and subscribes to its updates.
  JoltValueListenable(this.node) {
    final effect = Effect(() {
      node.value;
      notifyListeners();
    }, detach: true, debug: const JoltDebugOption.type('JoltValueListenable'));

    _disposer = effect.dispose;
  }

  /// The Jolt readable this listenable mirrors.
  final Readable<T> node;

  Disposer? _disposer;

  @override
  T get value => node.peek;

  @override
  void dispose() {
    _disposer?.call();
    _disposer = null;
    _listenables[node] = null;
  }
}
