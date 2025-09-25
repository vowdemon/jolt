import 'package:flutter/foundation.dart';
import 'package:free_disposer/free_disposer.dart';
import 'package:jolt/jolt.dart' as jolt;

final _notifiers = Expando<JoltValueNotifier<Object?>>();

class JoltValueNotifier<T> implements ValueNotifier<T> {
  JoltValueNotifier(this.joltValue) {
    _value = joltValue.value;
    _disposer = joltValue.subscribe((value, __) {
      _value = value;
      notifyListeners();
    },
        when: joltValue is jolt.IMutableCollection
            ? (newValue, oldValue) => true
            : null);
    _disposerJolt = joltValue.disposeWith(dispose);
  }

  final jolt.JReadonlyValue<T> joltValue;

  Disposer? _disposer;
  Disposer? _disposerJolt;

  late T _value;

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    assert(joltValue is jolt.JWritableValue<T>);

    (joltValue as jolt.JWritableValue<T>).set(newValue);
  }

  @override
  void dispose() {
    _disposer?.call();
    _disposer = null;
    _disposerJolt?.call();
    _disposerJolt = null;
    _notifiers[joltValue] = null;
  }

  final _listeners = <VoidCallback>[];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

extension JoltValueNotifierExtension<T> on jolt.JReadonlyValue<T> {
  JoltValueNotifier<T> get notifier {
    JoltValueNotifier<T>? notifier = _notifiers[this] as JoltValueNotifier<T>?;
    if (notifier == null) {
      _notifiers[this] = notifier = JoltValueNotifier(this);
    }
    return notifier;
  }
}

/// Extension methods for integrating Flutter ValueNotifier with Jolt signals.
extension JoltFlutterValueNotifierExtension<T> on ValueNotifier<T> {
  /// Converts this ValueNotifier to a reactive Signal with bidirectional sync.
  ///
  /// This extension method creates a bridge between Flutter's ValueNotifier and
  /// Jolt signals, allowing seamless interoperability. Changes to either the
  /// original ValueNotifier or the returned Signal will be synchronized.
  ///
  /// ## Returns
  ///
  /// A [Signal] that stays synchronized with this ValueNotifier
  ///
  /// ## Example
  ///
  /// ```dart
  /// final textController = TextEditingController();
  /// final textSignal = textController.toSignal();
  ///
  /// // Changes to textController update textSignal
  /// textController.text = 'Hello';
  /// print(textSignal.value); // 'Hello'
  ///
  /// // Changes to textSignal update textController
  /// textSignal.value = 'World';
  /// print(textController.text); // 'World'
  ///
  /// JoltBuilder(
  ///   builder: (context) => TextField(
  ///     controller: textController,
  ///     // Signal automatically updates when text changes
  ///   ),
  /// )
  /// ```
  jolt.Signal<T> toSignal() {
    final signal =
        jolt.WritableComputed(() => value, (value) => this.value = value);
    void listener() {
      if (value != signal.peek) {
        signal.set(value);
      }
    }

    addListener(listener);
    signal.disposeWith(() {
      removeListener(listener);
    });
    return signal;
  }
}
