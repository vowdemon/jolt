import 'package:free_disposer/free_disposer.dart';

import '../base.dart';
import '../effect.dart';

final _watchers = Expando<Set<Watcher>>();

/// Extension methods for subscribing to reactive value changes.
///
/// This extension provides convenient methods for watching reactive values
/// and executing callbacks when they change, with support for custom
/// trigger conditions and immediate execution.
extension JoltWatcherValueExtension<T> on JReadonlyValue<T> {
  /// Subscribes to changes in this reactive value with a callback function.
  ///
  /// Creates a watcher that monitors this reactive value and executes the
  /// provided callback function whenever the value changes. The watcher
  /// is automatically managed and disposed when the reactive value is disposed.
  ///
  /// Parameters:
  /// - [fn]: Callback function executed when the value changes
  /// - [when]: Optional condition function to control when the callback triggers
  /// - [immediately]: Whether to execute the callback immediately with current value
  ///
  /// Returns: A disposer function that can be called to unsubscribe
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  ///
  /// // Basic subscription
  /// final disposer = counter.subscribe((newValue, oldValue) {
  ///   print('Counter changed from $oldValue to $newValue');
  /// });
  ///
  /// // Subscription with condition
  /// final conditionalDisposer = counter.subscribe(
  ///   (newValue, oldValue) => print('Counter increased to $newValue'),
  ///   when: (newValue, oldValue) => newValue > oldValue,
  /// );
  ///
  /// // Subscription with immediate execution
  /// final immediateDisposer = counter.subscribe(
  ///   (newValue, oldValue) => print('Current value: $newValue'),
  ///   immediately: true, // Executes immediately with current value
  /// );
  ///
  /// counter.value = 1; // Triggers all applicable subscriptions
  /// counter.value = 0; // Only triggers basic subscription (not conditional)
  ///
  /// // Clean up subscriptions
  /// disposer();
  /// conditionalDisposer();
  /// immediateDisposer();
  /// ```
  Disposer subscribe(WatcherFn<T> fn,
      {WhenFn<T>? when, bool immediately = false}) {
    final watcher = Watcher(
      () => value,
      fn,
      when: when,
      immediately: immediately,
    );
    Set<Watcher>? subs = _watchers[this];
    if (subs == null) {
      _watchers[this] = subs = {};
      disposeWith(() {
        for (var watcher in subs!) {
          watcher.dispose();
        }
        subs.clear();
      });
    }
    subs.add(watcher);
    return watcher.dispose;
  }
}
