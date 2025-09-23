import 'dart:async';

import 'package:free_disposer/free_disposer.dart';

import '../base.dart';
import 'watcher.dart';

class _Stream<T> {
  _Stream() {
    count = 0;
    sc = StreamController<T>.broadcast(
        onListen: () => count++,
        onCancel: () {
          count--;
          if (count == 0) {
            dispose();
          }
        });
  }
  late StreamController<T>? sc;
  late Disposer? disposer;
  int count = 0;

  void dispose() {
    sc?.close();
    sc = null;
    disposer?.call();
    disposer = null;
  }
}

final _streams = Expando<_Stream<Object?>>();

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
    _Stream<T>? s = _streams[this] as _Stream<T>?;
    if (s == null) {
      _streams[this] = s = _Stream<T>();

      final watcherHandler = subscribe(
        (value, _) {
          if (s!.count == 0) return;
          s.sc!.add(value);
        },
        when: this is IMutableCollection ? (newValue, oldValue) => true : null,
      );

      s.disposer = () {
        watcherHandler();
      };

      disposeWith(() {
        s?.dispose();
        _streams[this] = null;
      });
    }

    return s.sc?.stream ?? Stream.empty();
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
