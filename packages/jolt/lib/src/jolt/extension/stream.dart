import 'dart:async';

import 'package:free_disposer/free_disposer.dart';

import '../base.dart';
import 'watcher.dart';

final _streams = Expando<StreamController<Object?>>();

/// Extension methods for converting reactive values to streams.
extension JoltStreamValueExtension<T> on JReadonlyValue<T> {
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
  ///
  /// counter.value = 1; // Prints: "Counter: 1"
  /// counter.value = 2; // Prints: "Counter: 2"
  /// ```
  Stream<T> get stream {
    assert(!isDisposed);
    var s = _streams[this] as StreamController<T>?;
    if (s == null) {
      Disposer? watcherDisposer;

      _streams[this] = s = StreamController<T>.broadcast(onListen: () {
        if (watcherDisposer != null) return;
        watcherDisposer = subscribe(
          (value, _) {
            if (!(s?.isClosed ?? false)) s!.add(value);
          },
          when:
              this is IMutableCollection ? (newValue, oldValue) => true : null,
        );
      }, onCancel: () {
        watcherDisposer?.call();
        watcherDisposer = null;
      });

      disposeWith(() {
        s?.close();
        _streams[this] = null;
      });
    }

    return s.stream;
  }

  /// Creates a stream subscription that listens to changes in this reactive value.
  ///
  /// Parameters:
  /// - [listener]: Function called with each new value
  /// - [immediately]: Whether to call the listener immediately with the current value
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
    void Function(T value) listener, {
    bool immediately = false,
  }) {
    assert(!isDisposed);
    if (immediately) listener(value);
    return stream.listen(listener);
  }
}
