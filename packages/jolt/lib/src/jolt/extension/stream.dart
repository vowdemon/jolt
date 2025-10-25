import 'dart:async';

import 'package:jolt/src/jolt/utils.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import '../base.dart';
import '../effect.dart';

final _streams = Expando<_StreamHolder<Object?>>();

class _StreamHolder<T> implements Disposable {
  _StreamHolder({
    void Function()? onListen,
    void Function()? onCancel,
  }) : sc = StreamController<T>.broadcast(
          onListen: onListen,
          onCancel: onCancel,
        );
  final StreamController<T> sc;
  Watcher? watcher;

  Stream<T> get stream => sc.stream;
  StreamSink<T> get sink => sc.sink;

  void setWatcher(Watcher watcher) {
    this.watcher = watcher;
  }

  void clearWatcher() {
    watcher?.dispose();
    watcher = null;
  }

  @override
  void dispose() {
    clearWatcher();
    sc.close();
  }
}

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
  /// // Prints: "Counter: 0"
  /// counter.value = 1; // Prints: "Counter: 1"
  /// counter.value = 2; // Prints: "Counter: 2"
  /// ```
  Stream<T> get stream {
    assert(!isDisposed);
    var s = _streams[this] as _StreamHolder<T>?;
    if (s == null) {
      _streams[this] = s = _StreamHolder<T>(
        onListen: () {
          s!.setWatcher(Watcher(
            () => value,
            (newValue, __) {
              s!.sink.add(newValue);
            },
            when: this is IMutableCollection ? (_, __) => true : null,
          ));
        },
        onCancel: () {
          s?.clearWatcher();
        },
      );

      attachToJoltAttachments(this, s.dispose);
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

@internal
@visibleForTesting
_StreamHolder<T>? getStreamHolder<T>(JReadonlyValue<T> value) {
  return _streams[value] as _StreamHolder<T>?;
}
