import "dart:async";

import "package:jolt/jolt.dart";

/// Extension methods for reactive values.
extension JoltUtilsUntilExtension<T> on ReadableNode<T> {
  /// Waits until the value satisfies a condition.
  ///
  /// Creates an effect that monitors the value and completes when the
  /// predicate returns `true`. The effect is automatically disposed.
  ///
  /// Parameters:
  /// - [predicate]: Function that returns `true` when condition is met
  ///
  /// Returns: A Future that completes with the value when condition is satisfied
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final result = await count.until((value) => value >= 5);
  /// // result is 5
  /// ```
  Future<T> until(bool Function(T value) predicate) {
    if (predicate(value)) {
      return Future.value(value);
    }

    final completer = Completer<T>();

    final effect = Effect.lazy(() {
      if (completer.isCompleted) {
        return;
      }

      if (predicate(value)) {
        completer.complete(value);
      }
    });

    trackWithEffect(() => value, effect);

    completer.future.whenComplete(effect.dispose);

    return completer.future;
  }

  /// Waits until the reactive value equals a specific value.
  ///
  /// Parameters:
  /// - [predicate]: The value to wait for
  ///
  /// Returns: A Future that completes when the value equals [predicate]
  ///
  /// Example:
  /// ```dart
  /// final status = Signal('loading');
  /// await status.untilWhen('ready'); // Waits until status is 'ready'
  /// ```
  Future<T> untilWhen<U>(U predicate) => until((value) => value == predicate);
}
