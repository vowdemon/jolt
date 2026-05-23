import 'dart:async';

import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';

/// Stream interop for [Readable] values.
/// {@category Advanced Techniques}
extension JoltUtilsStreamExtension<T> on Readable<T> {
  /// A broadcast stream of later visible changes to this readable.
  ///
  /// This stream does not emit the current value when a listener subscribes.
  /// Use [listen] with `immediately: true` when a snapshot should be delivered
  /// before later change events.
  ///
  /// ```dart
  /// final counter = Signal(0);
  /// final values = <int>[];
  ///
  /// counter.stream.listen(values.add);
  /// counter.value = 1;
  /// await Future<void>.delayed(Duration.zero);
  ///
  /// print(values); // [1]
  /// ```
  Stream<T> get stream => _getOrCreateStream(this);

  /// Subscribes to later visible changes to this readable.
  ///
  /// When [immediately] is `true`, Jolt first schedules one microtask that
  /// calls [onData] with this readable's current value, then continues with
  /// later stream events.
  ///
  /// ```dart
  /// final counter = Signal(1);
  /// counter.listen(print, immediately: true); // prints 1, then later changes
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
