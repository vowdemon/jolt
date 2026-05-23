part of 'listenable.dart';

final _notifiers = Expando<JoltValueNotifier<Object?>>();

/// Converts [Writable] values to Flutter [ValueNotifier].
extension JoltValueNotifierExtension<T> on Writable<T> {
  /// A cached [JoltValueNotifier] synchronized with this writable.
  ///
  /// Assigning to [JoltValueNotifier.value] updates the underlying writable and
  /// vice versa. Repeated access returns the same instance until
  /// [JoltValueNotifier.dispose] clears the cache entry.
  JoltValueNotifier<T> get notifier {
    var notifier = _notifiers[this] as JoltValueNotifier<T>?;

    if (notifier == null) {
      _notifiers[this] = notifier = JoltValueNotifier(this);
    }

    return notifier;
  }
}

/// A [ValueNotifier] backed by a Jolt [Writable].
///
/// [value] reads via [Writable.peek] and writes propagate to [node]. Listeners
/// are notified when the writable changes from any source.
class JoltValueNotifier<T>
    with _ValueNotifierMixin<T>
    implements ValueNotifier<T>, Disposable {
  /// Wraps [node] and keeps it in sync with this notifier.
  JoltValueNotifier(this.node) {
    final effect = Effect(() {
      node.value;
      notifyListeners();
    }, detach: true, debug: const JoltDebugOption.type('JoltValueNotifier'));

    _disposer = effect.dispose;
  }

  /// The Jolt writable this notifier mirrors.
  final Writable<T> node;

  @override
  T get value => node.peek;

  @override
  set value(T newValue) {
    node.value = newValue;
  }

  Disposer? _disposer;

  @override
  void dispose() {
    _disposer?.call();
    _disposer = null;
    _notifiers[node] = null;
  }
}
