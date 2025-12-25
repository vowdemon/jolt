part of 'listenable.dart';

final _notifiers = Expando<JoltValueNotifier<Object?>>();

/// Extension for converting Jolt Writable values to Flutter ValueNotifier.
extension JoltValueNotifierExtension<T> on Writable<T> {
  /// Converts this Jolt value to a Flutter ValueNotifier.
  ///
  /// Returns a cached instance synchronized with this value.
  /// Multiple calls return the same instance. Supports bidirectional sync.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final notifier = counter.notifier;
  ///
  /// ValueListenableBuilder<int>(
  ///   valueListenable: notifier,
  ///   builder: (context, value, child) => Text('$value'),
  /// )
  /// ```
  JoltValueNotifier<T> get notifier {
    var notifier = _notifiers[this] as JoltValueNotifier<T>?;

    if (notifier == null) {
      _notifiers[this] = notifier = JoltValueNotifier(this);
    }

    return notifier;
  }
}

/// A ValueNotifier that wraps a Jolt Writable value.
///
/// Provides Flutter's ValueNotifier interface with bidirectional sync.
/// Changes to either the Jolt value or ValueNotifier are synchronized.
///
/// Example:
/// ```dart
/// final signal = Signal(42);
/// final notifier = signal.notifier;
///
/// AnimatedBuilder(
///   animation: notifier,
///   builder: (context, child) => Text('${notifier.value}'),
/// )
/// ```
class JoltValueNotifier<T>
    with _ValueNotifierMixin<T>
    implements ValueNotifier<T>, Disposable {
  /// Creates a ValueNotifier from a Jolt Writable.
  ///
  /// Parameters:
  /// - [node]: The Jolt Writable value to wrap
  JoltValueNotifier(this.node) {
    final watcher = Watcher(() => node.value, (value, __) {
      notifyListeners();
    }, when: IMutableCollection.skipNode(node));

    final finalizerDisposer = JFinalizer.attachToJoltAttachments(node, dispose);
    _disposer = () {
      watcher.dispose();
      finalizerDisposer();
    };
  }

  /// The wrapped Jolt Writable value.
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
