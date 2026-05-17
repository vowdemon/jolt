import 'dart:async';

import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:jolt/src/core/utils.dart';

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
  Stream<T> get stream => _getOrCreateStream(this);

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
    final stream = _getOrCreateStream(this);

    if (immediately) {
      Future.microtask(() => onData?.call(value));
    }
    return stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

final _nodeStreams = Expando<_StreamAttachment>();
final _readableStreams = Expando<_StreamAttachment>();

Stream<T> _getOrCreateStream<T>(Readable<T> readable) {
  final readableAttachment =
      _readableStreams[readable] as _StreamAttachment<T>?;
  if (readableAttachment != null) {
    return readableAttachment.stream;
  }

  final node = captureReactiveNode(readable);
  if (node == null) {
    final newAttachment = _StreamAttachment<T>(readable);
    _readableStreams[readable] = newAttachment;
    return newAttachment.stream;
  }

  final attachment = _nodeStreams[node] as _StreamAttachment<T>?;
  if (attachment == null) {
    final newAttachment = _StreamAttachment<T>(readable);
    _nodeStreams[node] = newAttachment;
    _readableStreams[readable] = newAttachment;
    return newAttachment.stream;
  }

  _readableStreams[readable] = attachment;
  return attachment.stream;
}

final class _StreamAttachment<T> {
  _StreamAttachment(Readable<T> readable, {bool sync = false}) {
    controller = StreamController<T>.broadcast(
      sync: sync,
      onListen: () => _listen(readable),
      onCancel: _cancel,
    );
    stream = controller.stream;
  }

  late final StreamController<T> controller;
  late final Stream<T> stream;
  Effect? _effect;

  void _listen(Readable<T> readable) {
    if (_effect != null) return;

    var isInitialRun = true;
    _effect = Effect.lazy(
      () {
        final value = readable.value;
        if (isInitialRun) {
          isInitialRun = false;
          return;
        }
        controller.add(value);
      },
      detach: true,
      debug: const JoltDebugOption.type('Effect<ReadableStream>'),
    )..run();
  }

  void _cancel() {
    _effect?.dispose();
    _effect = null;
  }
}
