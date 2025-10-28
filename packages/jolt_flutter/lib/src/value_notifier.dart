import 'package:flutter/foundation.dart';
import 'package:free_disposer/free_disposer.dart';
import 'package:jolt/jolt.dart' as jolt;
import 'package:jolt_flutter/jolt_flutter.dart';

part 'value_listenable.dart';

final _notifiers = Expando<_JoltValueNotifierBase<Object?>>();

/// Extension to convert Jolt values to Flutter ValueNotifiers
extension JoltValueNotifierExtension<T> on jolt.JReadonlyValue<T> {
  /// Converts this Jolt value to a Flutter ValueNotifier.
  ///
  /// Returns a cached ValueNotifier instance that stays synchronized
  /// with this Jolt value. Multiple calls return the same instance.
  ///
  /// Example:
  /// ```dart
  /// final signal = Signal(42);
  /// final notifier = signal.notifier;
  /// ```
  JoltValueNotifier<T> get notifier {
    JoltValueNotifier<T>? notifier = _notifiers[this] as JoltValueNotifier<T>?;
    if (notifier == null) {
      _notifiers[this] = notifier = JoltValueNotifier(this);
    }
    return notifier;
  }
}

/// A ValueNotifier that bridges Jolt signals with Flutter's ValueNotifier
class JoltValueNotifier<T> extends _JoltValueNotifierBase<T>
    implements ValueNotifier<T> {
  JoltValueNotifier(super.joltValue);
}

class _JoltValueNotifierBase<T> {
  /// Creates a ValueNotifier that wraps a Jolt signal.
  ///
  /// The ValueNotifier will automatically sync with changes to the Jolt signal
  /// and notify Flutter listeners when the value changes.
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

  /// The underlying Jolt value being wrapped

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
  /// Creates a bridge between Flutter's ValueNotifier and Jolt signals,
  /// allowing seamless interoperability. Changes to either the original
  /// ValueNotifier or the returned Signal will be synchronized.
  ///
  /// Returns a [Signal] that stays synchronized with this ValueNotifier.
  ///
  /// Example:
  /// ```dart
  /// final textController = TextEditingController();
  /// final textSignal = textController.toNotifierSignal();
  ///
  /// // Changes to textController update textSignal
  /// textController.text = 'Hello';
  /// print(textSignal.value); // 'Hello'
  ///
  /// // Changes to textSignal update textController
  /// textSignal.value = 'World';
  /// print(textController.text); // 'World'
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
