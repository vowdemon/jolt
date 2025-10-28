import 'package:flutter/foundation.dart';
import 'package:free_disposer/free_disposer.dart';
import 'package:jolt/jolt.dart' as jolt;
import 'package:jolt_flutter/jolt_flutter.dart';

part 'value_listenable.dart';

final _notifiers = Expando<_JoltValueNotifierBase<Object?>>();

/// Extension to convert Jolt values to Flutter ValueNotifiers.
extension JoltValueNotifierExtension<T> on jolt.JReadonlyValue<T> {
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
    JoltValueNotifier<T>? notifier = _notifiers[this] as JoltValueNotifier<T>?;
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
class JoltValueNotifier<T> extends _JoltValueNotifierBase<T>
    implements ValueNotifier<T> {
  /// Creates a ValueNotifier that wraps a Jolt signal.
  ///
  /// Parameters:
  /// - [joltValue]: The Jolt reactive value to wrap
  JoltValueNotifier(super.joltValue);
}

class _JoltValueNotifierBase<T> {
  /// Creates a ValueNotifier that wraps a Jolt signal.
  ///
  /// Parameters:
  /// - [joltValue]: The Jolt reactive value to wrap
  ///
  /// Automatically syncs with Jolt signal changes and notifies Flutter listeners.
  _JoltValueNotifierBase(this.joltValue) {
    _value = joltValue.value;
    _disposer = jolt.Watcher(joltValue.get, (value, __) {
      _value = value;
      notifyListeners();
    },
            when: joltValue is jolt.IMutableCollection
                ? (newValue, oldValue) => true
                : null)
        .dispose;
    _disposerJolt = joltValue.disposeWith(dispose);
  }

  /// The underlying Jolt value being wrapped.
  final jolt.JReadonlyValue<T> joltValue;

  Disposer? _disposer;
  Disposer? _disposerJolt;

  late T _value;

  T get value => _value;

  set value(T newValue) {
    assert(joltValue is jolt.JWritableValue<T>);

    (joltValue as jolt.JWritableValue<T>).set(newValue);
  }

  void dispose() {
    _disposer?.call();
    _disposer = null;
    _disposerJolt?.call();
    _disposerJolt = null;
    _notifiers[joltValue] = null;
  }

  final _listeners = <VoidCallback>[];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  bool get hasListeners => _listeners.isNotEmpty;

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
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
  jolt.Signal<T> toNotifierSignal({JoltDebugFn? onDebug}) {
    return _NotifierSignal(this, onDebug: onDebug);
  }
}

class _NotifierSignal<T> extends jolt.Signal<T> {
  _NotifierSignal(this._notifier, {super.onDebug}) : super(_notifier!.value) {
    _listener = () {
      final newValue = _notifier!.value;
      if (newValue != peek) {
        super.set(newValue);
      }
    };

    _notifier!.addListener(_listener!);

    _disposer = () {
      _notifier!.removeListener(_listener!);
      _notifier = null;
    };

    disposeWith(_disposer);
  }

  VoidCallback? _listener;
  ValueNotifier<T>? _notifier;
  Disposer? _disposer;

  @override
  void set(T value) {
    if (isDisposed) return;
    _notifier?.value = value;
  }

  @override
  void onDispose() {
    super.onDispose();
    _disposer?.call();
    _disposer = null;
  }
}
