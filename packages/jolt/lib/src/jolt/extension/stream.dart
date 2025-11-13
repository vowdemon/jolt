import 'dart:async';

import '../base.dart';
import '../effect.dart';
import '../shared.dart';
import '../track.dart';

/// Extension methods for converting reactive values to streams.
extension JoltStreamValueExtension<T> on ReadonlyNode<T> {
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
    assert(!isDisposed);
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
    assert(!isDisposed);
    if (immediately) onData?.call(value);
    return stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
