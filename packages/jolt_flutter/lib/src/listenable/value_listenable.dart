part of 'listenable.dart';

final _listenables = Expando<JoltValueListenable<Object?>>();

extension JoltValueListenableExtension<T> on Readonly<T> {
  /// Converts this Jolt value to a Flutter ValueListenable.
  ///
  /// Returns a cached instance that stays synchronized with this Jolt value.
  /// Multiple calls return the same instance.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(42);
  /// final listenable = signal.listenable;
  ///
  /// // Use with ValueListenableBuilder
  /// ValueListenableBuilder<int>(
  ///   valueListenable: listenable,
  ///   builder: (context, value, child) => Text('$value'),
  /// )
  /// ```
  JoltValueListenable<T> get listenable {
    var listenable = _listenables[this] as JoltValueListenable<T>?;

    if (listenable == null) {
      _listenables[this] = listenable = JoltValueListenable(this);
    }

    return listenable;
  }
}

class JoltValueListenable<T>
    with _ValueNotifierMixin<T>
    implements ValueListenable<T>, Disposable {
  JoltValueListenable(this.node) {
    final watcher = Watcher(node.get, (value, __) {
      notifyListeners();
    }, when: IMutableCollection.skipNode(node));

    final finalizerDisposer = JFinalizer.attachToJoltAttachments(node, dispose);
    _disposer = () {
      watcher.dispose();
      finalizerDisposer();
    };
  }

  final Readonly<T> node;

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

extension JoltFlutterListenableExtension<T> on ValueListenable<T> {
  /// Converts this ValueListenable to a read-only Signal.
  ///
  /// Creates a unidirectional bridge from Flutter's ValueListenable to Jolt.
  /// Changes to the original ValueListenable will be synchronized to the Signal,
  /// but the Signal cannot be modified.
  ///
  /// Parameters:
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final notifier = ValueNotifier(0);
  /// final signal = notifier.toListenableSignal();
  ///
  /// // Only notifier changes sync to signal
  /// notifier.value = 1; // signal.value becomes 1
  /// // signal.value = 2; // This would throw an error
  /// ```
  ReadonlySignal<T> toListenableSignal({JoltDebugFn? onDebug}) {
    if (this is JoltValueListenable<T>) {
      final node = (this as JoltValueListenable<T>).node;
      if (node is ReadonlySignal<T>) {
        return node;
      }
    }
    return ValueListenableSignal(this, onDebug: onDebug);
  }
}

class ValueListenableSignal<T> extends ReadonlySignalImpl<T>
    implements SignalReactiveNode<T> {
  ValueListenableSignal(ValueListenable<T> listenable, {super.onDebug})
      : super(listenable.value) {
    void listener() {
      setSignal(this, listenable.value);
    }

    listenable.addListener(listener);

    JFinalizer.attachToJoltAttachments(this, () {
      listenable.removeListener(listener);
    });
  }
}
