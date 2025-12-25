part of 'listenable.dart';

final _listenables = Expando<JoltValueListenable<Object?>>();

/// Extension for converting Jolt values to Flutter ValueListenable.
extension JoltValueListenableExtension<T> on Readable<T> {
  /// Converts this Jolt value to a Flutter ValueListenable.
  ///
  /// Returns a cached instance synchronized with this value.
  /// Multiple calls return the same instance.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(42);
  /// final listenable = signal.listenable;
  ///
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

/// A ValueListenable that wraps a Jolt Readable value.
///
/// Provides Flutter's ValueListenable interface for Jolt reactive values.
/// Automatically synchronizes with the underlying Jolt value.
///
/// Example:
/// ```dart
/// final signal = Signal(42);
/// final listenable = signal.listenable;
/// listenable.addListener(() => print('Changed'));
/// ```
class JoltValueListenable<T>
    with _ValueNotifierMixin<T>
    implements ValueListenable<T>, Disposable {
  /// Creates a ValueListenable from a Jolt Readable.
  ///
  /// Parameters:
  /// - [node]: The Jolt Readable value to wrap
  JoltValueListenable(this.node) {
    final watcher = Watcher(() => node.value, (value, __) {
      notifyListeners();
    }, when: IMutableCollection.skipNode(node));

    final finalizerDisposer = JFinalizer.attachToJoltAttachments(node, dispose);
    _disposer = () {
      watcher.dispose();
      finalizerDisposer();
    };
  }

  /// The wrapped Jolt Readable value.
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
