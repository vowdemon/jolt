part of 'listenable.dart';

final _notifiers = Expando<JoltValueNotifier<Object?>>();

/// Extension to convert Jolt values to Flutter ValueNotifiers.
extension JoltValueNotifierExtension<T> on Writable<T> {
  /// Converts this Jolt value to a Flutter ValueNotifier.
  ///
  /// Returns a cached instance that stays synchronized with this Jolt value.
  /// Multiple calls return the same instance.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final notifier = counter.notifier;
  ///
  /// // Use with Flutter widgets
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

/// A ValueNotifier that bridges Jolt signals with Flutter's ValueNotifier.
///
/// This class wraps a Jolt reactive value and provides Flutter's ValueNotifier
/// interface, allowing seamless integration with Flutter widgets and state
/// management.
///
/// Example:
/// ```dart
/// final signal = Signal(42);
/// final notifier = JoltValueNotifier(signal);
///
/// // Use with AnimatedBuilder
/// AnimatedBuilder(
///   animation: notifier,
///   builder: (context, child) => Text('${notifier.value}'),
/// )
/// ```
class JoltValueNotifier<T>
    with _ValueNotifierMixin<T>
    implements ValueNotifier<T>, Disposable {
  /// Creates a ValueNotifier that wraps a Jolt signal.
  ///
  /// Parameters:
  /// - [joltValue]: The Jolt reactive value to wrap
  JoltValueNotifier(this.node) {
    final watcher = Watcher(node.get, (value, __) {
      notifyListeners();
    }, when: IMutableCollection.skipNode(node));

    final finalizerDisposer = JFinalizer.attachToJoltAttachments(node, dispose);
    _disposer = () {
      watcher.dispose();
      finalizerDisposer();
    };
  }

  final Writable<T> node;

  @override
  T get value => node.peek;

  @override
  set value(T newValue) {
    node.set(newValue);
  }

  Disposer? _disposer;

  @override
  void dispose() {
    _disposer?.call();
    _disposer = null;
    _notifiers[node] = null;
  }
}

/// Extension methods for integrating Flutter ValueNotifier with Jolt signals.
extension JoltFlutterValueNotifierExtension<T> on ValueNotifier<T> {
  /// Converts this ValueNotifier to a reactive Signal with bidirectional sync.
  ///
  /// Creates a bridge between Flutter's ValueNotifier and Jolt signals.
  /// Changes to either the original ValueNotifier or the returned Signal
  /// will be synchronized.
  ///
  /// Parameters:
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final notifier = ValueNotifier(0);
  /// final signal = notifier.toNotifierSignal();
  ///
  /// // Changes sync bidirectionally
  /// notifier.value = 1; // signal.value becomes 1
  /// signal.value = 2;   // notifier.value becomes 2
  /// ```
  Signal<T> toNotifierSignal({JoltDebugFn? onDebug}) {
    if (this is JoltValueNotifier<T>) {
      final node = (this as JoltValueNotifier<T>).node;
      if (node is Signal<T>) {
        return node;
      }
    }
    return NotifierSignal(this, onDebug: onDebug);
  }
}

class NotifierSignal<T> extends SignalImpl<T> {
  NotifierSignal(this._notifier, {super.onDebug}) : super(_notifier.value) {
    void listener() {
      final newValue = _notifier.value;
      if (newValue != peek) {
        super.set(newValue);
      }
    }

    _notifier.addListener(listener);

    JFinalizer.attachToJoltAttachments(this, () {
      _notifier.removeListener(listener);
    });
  }

  final ValueNotifier<T> _notifier;

  @override
  T set(T value) {
    if (isDisposed) return value;
    _notifier.value = value;
    return value;
  }
}
