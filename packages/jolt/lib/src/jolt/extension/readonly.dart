import "dart:async";

import "package:jolt/jolt.dart";
import "package:jolt/src/jolt/shared.dart";

/// Extension methods for readonly reactive values.
extension JoltReadonlyExtension<T> on ReadonlyNode<T> {
  /// Converts this reactive value to a broadcast stream.
  ///
  /// The stream emits the current value whenever the reactive value changes.
  /// Multiple listeners can subscribe to the same stream. The stream is
  /// automatically managed and cleaned up when the reactive value is disposed.
  ///
  /// Returns: A broadcast stream that emits values when this reactive value changes
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final stream = counter.stream;
  ///
  /// stream.listen((value) => print('Counter: $value'));
  /// // Prints: "Counter: 0"
  /// counter.value = 1; // Prints: "Counter: 1"
  /// counter.value = 2; // Prints: "Counter: 2"
  /// ```
  Stream<T> get stream {
    assert(!isDisposed, "$runtimeType is disposed");
    var s = streamHolders[this] as StreamHolder<T>?;
    if (s == null) {
      streamHolders[this] = s = StreamHolder<T>(
        onListen: () {
          s!.setWatcher(untracked(() => Watcher(
                () => value,
                (newValue, __) {
                  s!.sink.add(newValue);
                },
                when: this is IMutableCollection ? (_, __) => true : null,
              )));
        },
        onCancel: () {
          s?.clearWatcher();
        },
      );

      JFinalizer.attachToJoltAttachments(this, s.dispose);
    }

    return s.stream;
  }

  /// Creates a stream subscription that listens to changes in this reactive value.
  ///
  /// Parameters:
  /// - [onData]: Function called with each new value
  /// - [onError]: Optional function called when an error occurs
  /// - [onDone]: Optional function called when the stream is closed
  /// - [cancelOnError]: Whether to cancel the subscription on error
  /// - [immediately]: Whether to call [onData] immediately with the current value
  ///
  /// Returns: A StreamSubscription that can be used to cancel the listener
  ///
  /// This is a convenience method that combines getting the stream and listening to it.
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  ///
  /// final subscription = counter.listen(
  ///   (value) => print('Counter: $value'),
  ///   immediately: true, // Prints current value immediately
  /// );
  ///
  /// counter.value = 1; // Prints: "Counter: 1"
  ///
  /// subscription.cancel(); // Stop listening
  /// ```
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    bool immediately = false,
  }) {
    assert(!isDisposed, "$runtimeType is disposed");
    if (immediately) onData?.call(value);
    return stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  /// Waits until the reactive value satisfies a predicate condition.
  ///
  /// This method creates an effect that monitors the reactive value and
  /// completes the returned future when the predicate returns `true` for
  /// the current value. The effect is automatically disposed when the
  /// future completes or is cancelled.
  ///
  /// **Behavior:**
  /// - The effect runs immediately and whenever the value changes
  /// - The future completes with the value that satisfied the predicate
  /// - The effect is automatically cleaned up when the future completes
  ///
  /// Parameters:
  /// - [predicate]: A function that returns `true` when the condition is met
  ///
  /// Returns: A Future that completes with the value when the predicate is satisfied
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  ///
  /// // Wait until count reaches 5
  /// final future = count.until((value) => value >= 5);
  ///
  /// count.value = 1; // Still waiting
  /// count.value = 3; // Still waiting
  /// count.value = 5; // Future completes with value 5
  ///
  /// final result = await future; // result is 5
  /// ```
  ///
  /// Example with async/await:
  /// ```dart
  /// final isLoading = Signal(true);
  ///
  /// // Wait until loading completes
  /// final data = await isLoading.until((value) => !value);
  /// print('Loading finished');
  /// ```
  Future<T> until(bool Function(T value) predicate) {
    final completer = Completer<T>();

    final effect = Effect(() {
      if (predicate(value)) {
        completer.complete(value);
      }
    });

    completer.future.whenComplete(effect.dispose);

    return completer.future;
  }
}
