import 'dart:async';

import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

extension JoltUtilsStreamExtension<T> on Readable<T> {
  /// Converts this reactive value to a broadcast stream.
  ///
  /// Emits values whenever the reactive value changes. Multiple listeners
  /// can subscribe. Automatically cleaned up when disposed.
  ///
  /// Returns: A broadcast stream of value changes
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// counter.stream.listen((value) => print('Counter: $value'));
  /// counter.value = 1; // Prints: "Counter: 1"
  /// ```
  Stream<T> get stream => JoltStreamHelper.getStream(this);

  /// Listens to changes in this reactive value.
  ///
  /// Parameters:
  /// - [onData]: Callback for each new value
  /// - [onError]: Optional error callback
  /// - [onDone]: Optional completion callback
  /// - [cancelOnError]: Whether to cancel on error
  /// - [immediately]: Whether to call [onData] with current value immediately
  ///
  /// Returns: A StreamSubscription for cancellation
  ///
  /// Example:
  /// ```dart
  /// final counter = Signal(0);
  /// final sub = counter.listen(
  ///   (value) => print('Counter: $value'),
  ///   immediately: true,
  /// );
  /// sub.cancel();
  /// ```
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    bool immediately = false,
  }) {
    assert(() {
      if (this is ReadableNode) {
        return !(this as ReadableNode).isDisposed;
      }
      return true;
    }(), "$runtimeType is disposed");

    final controller = JoltStreamHelper.getOrCreateStreamController(this);

    if (immediately) {
      Future.microtask(() => onData?.call(value));
    }
    return controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

abstract final class JoltStreamHelper {
  static final _readableStreams = Expando<StreamController>();

  static StreamController<T>? getStreamController<T>(Readable<T> obj) =>
      _readableStreams[obj] as StreamController<T>?;

  static StreamController<T> getOrCreateStreamController<T>(
      Readable<T> readable) {
    assert(() {
      if (readable is ReadableNode) {
        return !(readable as ReadableNode).isDisposed;
      }
      return true;
    }(), "${readable.runtimeType} is disposed");

    StreamController<T>? controller =
        _readableStreams[readable] as StreamController<T>?;

    if (controller == null) {
      final newController = createWatchedStreamController(readable);
      _readableStreams[readable] = newController;
      controller = newController;
    }

    return controller;
  }

  static Stream<T> getStream<T>(Readable<T> readable) {
    return getOrCreateStreamController(readable).stream;
  }

  static StreamController<T> createWatchedStreamController<T>(
      Readable<T> readable,
      {bool sync = false}) {
    Watcher? watcher;
    late final StreamController<T> controller;

    void disposer() {
      watcher?.dispose();
      watcher = null;
    }

    controller = StreamController<T>.broadcast(
      sync: sync,
      onListen: () {
        watcher = Watcher(
          () => readable.value,
          (newValue, __) {
            controller.add(newValue);
          },
          when: IMutableCollection.skipNode(readable),
        );
      },
      onCancel: disposer,
    );

    JFinalizer.attachToJoltAttachments(readable, disposer);

    return controller;
  }
}
