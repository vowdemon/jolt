import 'package:flutter/foundation.dart';
import 'package:free_disposer/free_disposer.dart';
import 'package:jolt/jolt.dart' as jolt;

/// A mixin that provides Flutter ValueNotifier integration for Jolt signals.
///
/// [JoltValueNotifier] allows Jolt signals to be used as Flutter ValueNotifiers,
/// enabling seamless integration with Flutter's existing reactive widgets like
/// ValueListenableBuilder, AnimatedBuilder, and others.
///
/// This mixin automatically manages listener subscriptions and ensures that
/// Flutter widgets are notified when the underlying Jolt signal changes.
///
/// ## Example
///
/// ```dart
/// final signal = Signal(42);
///
/// // Can be used as ValueNotifier
/// ValueListenableBuilder<int>(
///   valueListenable: signal,
///   builder: (context, value, child) => Text('$value'),
/// )
///
/// // Or with AnimatedBuilder
/// AnimatedBuilder(
///   animation: signal,
///   builder: (context, child) => Text('${signal.value}'),
/// )
/// ```
mixin JoltValueNotifier<T> on jolt.JReadonlyValue<T>
    implements ValueNotifier<T> {
  final List<VoidCallback> _listeners = [];

  bool _initializedValueNotifier = false;
  Disposer? _valueNotifierDisposer;

  /// Adds a listener that will be called when the signal's value changes.
  ///
  /// The first listener added will set up the subscription to the underlying
  /// Jolt signal. Subsequent listeners are added to the internal list.
  ///
  /// ## Parameters
  ///
  /// - [listener]: Callback to be invoked when the value changes
  ///
  /// ## Example
  ///
  /// ```dart
  /// final counter = Signal(0);
  ///
  /// counter.addListener(() {
  ///   print('Counter changed to: ${counter.value}');
  /// });
  ///
  /// counter.value = 5; // Prints: "Counter changed to: 5"
  /// ```
  @override
  void addListener(VoidCallback listener) {
    if (!_initializedValueNotifier) {
      _initializedValueNotifier = true;
      _listeners.add(listener);

      _valueNotifierDisposer = subscribe((_, __) {
        notifyListeners();
      },
          when: this is jolt.IMutableCollection
              ? (newValue, oldValue) => true
              : null);
    } else {
      _listeners.add(listener);
    }
  }

  /// Returns whether this signal has any registered listeners.
  ///
  /// ## Returns
  ///
  /// `true` if there are listeners, `false` otherwise
  ///
  /// ## Example
  ///
  /// ```dart
  /// final signal = Signal(0);
  /// print(signal.hasListeners); // false
  ///
  /// signal.addListener(() {});
  /// print(signal.hasListeners); // true
  /// ```
  @override
  bool get hasListeners => _listeners.isNotEmpty;

  /// Notifies all registered listeners that the value has changed.
  ///
  /// This method is called automatically when the underlying Jolt signal changes.
  /// You typically don't need to call this manually.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // This is called automatically when signal changes
  /// signal.value = newValue; // notifyListeners() called internally
  /// ```
  @override
  void notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Removes a previously registered listener.
  ///
  /// If the listener was registered multiple times, only the first occurrence
  /// is removed.
  ///
  /// ## Parameters
  ///
  /// - [listener]: The listener callback to remove
  ///
  /// ## Example
  ///
  /// ```dart
  /// final signal = Signal(0);
  ///
  /// void onChanged() {
  ///   print('Changed!');
  /// }
  ///
  /// signal.addListener(onChanged);
  /// signal.removeListener(onChanged); // No longer listens
  /// ```
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _valueNotifierDisposer?.call();
      _valueNotifierDisposer = null;
      _initializedValueNotifier = false;
    }
  }

  /// Disposes of the ValueNotifier integration and cleans up resources.
  ///
  /// This method clears all listeners and calls the parent dispose method.
  /// It's automatically called when the signal is disposed.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final signal = Signal(0);
  /// // ... use signal ...
  /// signal.dispose(); // Cleanup automatically handled
  /// ```
  @override
  void onDispose() {
    _listeners.clear();
    _listeners.length = 0;
    _valueNotifierDisposer?.call();
    super.onDispose();
  }
}
