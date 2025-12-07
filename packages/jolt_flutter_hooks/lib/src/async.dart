import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jolt_flutter/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:jolt_flutter/setup.dart';

/// Creates a reactive signal that tracks the state of a Future.
///
/// This hook provides an [AsyncSnapshot] that updates automatically as the
/// Future progresses through its lifecycle. The behavior matches [FutureBuilder].
///
/// Parameters:
/// - [future]: The Future to track, can be null
/// - [initialData]: Optional initial data to use before the Future completes
///
/// Example:
/// ```dart
/// final future = Future.delayed(Duration(seconds: 1), () => 42);
/// final snapshot = useFuture(future);
///
/// if (snapshot.connectionState == ConnectionState.waiting) {
///   return CircularProgressIndicator();
/// } else if (snapshot.hasError) {
///   return Text('Error: ${snapshot.error}');
/// } else {
///   return Text('Data: ${snapshot.data}');
/// }
/// ```
AsyncSnapshotFutureSignal<T> useFuture<T>(Future<T>? future, {T? initialData}) {
  return useAutoDispose<_AsyncSnapshotFutureSignalImpl<T>>(() {
    final signal = _AsyncSnapshotFutureSignalImpl<T>(
      future,
      initialData: initialData,
    );
    return signal;
  });
}

// ignore: must_be_immutable
class _AsyncSnapshotFutureSignalImpl<T> extends SignalImpl<AsyncSnapshot<T>>
    with _AsyncSnapshotSignalMixin<T>
    implements AsyncSnapshotFutureSignal<T> {
  _AsyncSnapshotFutureSignalImpl(this.future, {T? initialData})
      : super(initialData == null
            ? AsyncSnapshot<T>.nothing()
            : AsyncSnapshot<T>.withData(ConnectionState.none, initialData)) {
    batch(_subscribe);
  }

  Future<T>? future;

  /// An object that identifies the currently active callbacks. Used to avoid
  /// calling setState from stale callbacks, e.g. after disposal of this state,
  /// or after widget reconfiguration to a new Future.
  Object? _activeCallbackIdentity;

  @override
  void setFuture(Future<T>? future) {
    batch(() {
      if (this.future == future) {
        return;
      }
      if (_activeCallbackIdentity != null) {
        _unsubscribe();
        inState(ConnectionState.none);
      }
      this.future = future;
      _subscribe();
    });
  }

  void _subscribe() {
    if (future == null) {
      return;
    }
    final Object callbackIdentity = Object();
    _activeCallbackIdentity = callbackIdentity;

    future!.then<void>(
      (T data) {
        if (_activeCallbackIdentity == callbackIdentity) {
          value = AsyncSnapshot<T>.withData(ConnectionState.done, data);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_activeCallbackIdentity == callbackIdentity) {
          value = AsyncSnapshot<T>.withError(
              ConnectionState.done, error, stackTrace);
        }
      },
    );
    // An implementation like `SynchronousFuture` may have already called the
    // .then closure. Do not overwrite it in that case.
    if (peek.connectionState != ConnectionState.done) {
      inState(ConnectionState.waiting);
    }
  }

  void _unsubscribe() {
    _activeCallbackIdentity = null;
  }

  @override
  void onDispose() {
    _unsubscribe();
    super.onDispose();
  }
}

/// Interface for a signal that tracks a Future's state.
///
/// Provides methods to update the Future being tracked.
abstract interface class AsyncSnapshotFutureSignal<T>
    implements AsyncSnapshot<T> {
  /// Updates the Future being tracked.
  ///
  /// Parameters:
  /// - [future]: The new Future to track, can be null
  void setFuture(Future<T>? future);
}

/// Creates a reactive signal that tracks the state of a Stream.
///
/// This hook provides an [AsyncSnapshot] that updates automatically as the
/// Stream emits data, errors, or completes. The behavior matches [StreamBuilder].
///
/// Parameters:
/// - [stream]: The Stream to track, can be null
/// - [initialData]: Optional initial data to use before the Stream emits
///
/// Example:
/// ```dart
/// final controller = StreamController<int>();
/// final snapshot = useStream(controller.stream);
///
/// if (snapshot.connectionState == ConnectionState.waiting) {
///   return CircularProgressIndicator();
/// } else if (snapshot.hasError) {
///   return Text('Error: ${snapshot.error}');
/// } else {
///   return Text('Data: ${snapshot.data}');
/// }
///
/// // Later, emit data
/// controller.add(42);
/// ```
AsyncSnapshotStreamSignal<T> useStream<T>(Stream<T>? stream, {T? initialData}) {
  return useAutoDispose<_AsyncSnapshotStreamSignalImpl<T>>(() {
    final signal = _AsyncSnapshotStreamSignalImpl<T>(
      stream,
      initialData: initialData,
    );
    return signal;
  });
}

// ignore: must_be_immutable
class _AsyncSnapshotStreamSignalImpl<T> extends SignalImpl<AsyncSnapshot<T>>
    with _AsyncSnapshotSignalMixin<T>
    implements AsyncSnapshotStreamSignal<T> {
  _AsyncSnapshotStreamSignalImpl(this.stream, {T? initialData})
      : super(initialData == null
            ? AsyncSnapshot<T>.nothing()
            : AsyncSnapshot<T>.withData(ConnectionState.none, initialData)) {
    batch(_subscribe);
  }

  Stream<T>? stream;
  StreamSubscription<T>? _subscription;

  @override
  void setStream(Stream<T>? stream) {
    batch(() {
      if (this.stream == stream) {
        return;
      }
      if (_subscription != null) {
        _unsubscribe();
        inState(ConnectionState.none);
      }
      this.stream = stream;
      _subscribe();
    });
  }

  void _subscribe() {
    if (stream == null) {
      return;
    }
    _subscription = stream!.listen(
      (T data) {
        value = AsyncSnapshot<T>.withData(ConnectionState.active, data);
      },
      onError: (Object error, StackTrace stackTrace) {
        value = AsyncSnapshot<T>.withError(
            ConnectionState.active, error, stackTrace);
      },
      onDone: () {
        inState(ConnectionState.done);
      },
    );
    // Set to waiting state after connecting
    if (peek.connectionState != ConnectionState.active &&
        peek.connectionState != ConnectionState.done) {
      inState(ConnectionState.waiting);
    }
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void onDispose() {
    _unsubscribe();
    super.onDispose();
  }
}

/// Interface for a signal that tracks a Stream's state.
///
/// Provides methods to update the Stream being tracked.
abstract interface class AsyncSnapshotStreamSignal<T>
    implements AsyncSnapshot<T> {
  /// Updates the Stream being tracked.
  ///
  /// Parameters:
  /// - [stream]: The new Stream to track, can be null
  void setStream(Stream<T>? stream);
}

// ignore: unused_element
mixin _AsyncSnapshotSignalMixin<T> on SignalImpl<AsyncSnapshot<T>>
    implements AsyncSnapshot<T> {
  @override
  ConnectionState get connectionState => value.connectionState;

  @override
  T? get data => value.data;

  @override
  Object? get error => value.error;

  @override
  bool get hasData => value.hasData;

  @override
  bool get hasError => value.hasError;

  @override
  AsyncSnapshot<T> inState(ConnectionState state) {
    value = peek.inState(state);
    return this;
  }

  @override
  T get requireData => value.requireData;

  @override
  StackTrace? get stackTrace => value.stackTrace;
}

final class _StreamControllerCreator {
  const _StreamControllerCreator._();

  /// Creates a StreamController that is automatically closed when the widget is unmounted.
  ///
  /// Parameters:
  /// - [onListen]: Optional callback called when the stream is listened to
  /// - [onPause]: Optional callback called when the stream subscription is paused
  /// - [onResume]: Optional callback called when the stream subscription is resumed
  /// - [onCancel]: Optional callback called when the stream subscription is cancelled
  /// - [sync]: Whether the stream controller is synchronous (default: false)
  ///
  /// Example:
  /// ```dart
  /// final controller = useStreamController<int>();
  /// controller.stream.listen((value) {
  ///   print('Received: $value');
  /// });
  /// controller.add(42);
  /// ```
  StreamController<T> call<T>(
      {void Function()? onListen,
      void Function()? onPause,
      void Function()? onResume,
      FutureOr<void> Function()? onCancel,
      bool sync = false}) {
    return useMemoized<StreamController<T>>(() {
      return StreamController<T>(
        onListen: onListen,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
        sync: sync,
      );
    }, (controller) => controller.close());
  }

  /// Creates a broadcast StreamController that is automatically closed when the widget is unmounted.
  ///
  /// Parameters:
  /// - [onListen]: Optional callback called when the stream is listened to
  /// - [onCancel]: Optional callback called when the stream subscription is cancelled
  /// - [sync]: Whether the stream controller is synchronous (default: false)
  ///
  /// Example:
  /// ```dart
  /// final controller = useStreamController.broadcast<int>();
  /// controller.stream.listen((value) {
  ///   print('Listener 1: $value');
  /// });
  /// controller.stream.listen((value) {
  ///   print('Listener 2: $value');
  /// });
  /// controller.add(42); // Both listeners receive the value
  /// ```
  StreamController<T> broadcast<T>(
      {void Function()? onListen,
      FutureOr<void> Function()? onCancel,
      bool sync = false}) {
    return useMemoized<StreamController<T>>(() {
      return StreamController<T>.broadcast(
        onListen: onListen,
        onCancel: onCancel,
        sync: sync,
      );
    }, (controller) => controller.close());
  }
}

/// Creates a StreamController that is automatically closed when the widget is unmounted.
///
/// Use [useStreamController] to create a single-subscription controller,
/// or [useStreamController.broadcast] to create a broadcast controller.
///
/// Example:
/// ```dart
/// final controller = useStreamController<int>();
/// controller.stream.listen((value) => print(value));
/// controller.add(42);
/// ```
const useStreamController = _StreamControllerCreator._();

/// Subscribes to a Stream and automatically cancels the subscription when the widget is unmounted.
///
/// Parameters:
/// - [stream]: The Stream to subscribe to
/// - [onData]: Optional callback called when data is emitted
/// - [onError]: Optional callback called when an error occurs
/// - [onDone]: Optional callback called when the stream completes
/// - [cancelOnError]: Whether to cancel the subscription on error (default: false)
///
/// Example:
/// ```dart
/// final controller = StreamController<int>();
/// useStreamSubscription(
///   controller.stream,
///   onData: (value) {
///     print('Received: $value');
///   },
///   onError: (error, stackTrace) {
///     print('Error: $error');
///   },
///   onDone: () {
///     print('Stream completed');
///   },
/// );
/// controller.add(42);
/// ```
void useStreamSubscription<T>(
  Stream<T> stream,
  void Function(T event)? onData, {
  Function? onError,
  void Function()? onDone,
  bool? cancelOnError,
}) {
  useMemoized(() {
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }, (subscription) => subscription.cancel());
}
