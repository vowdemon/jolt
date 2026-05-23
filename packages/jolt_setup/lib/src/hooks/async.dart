import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jolt/core.dart';
import 'package:jolt_flutter/jolt_flutter.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

import '../setup/framework.dart';
import 'annotation.dart';

/// Tracks a [Future] as an [AsyncSnapshot] for the current setup scope.
///
/// Use `useFuture(future)` to mirror a specific future, or
/// `useFuture.watch(readableFuture)` when the future itself is reactive and can
/// be replaced over time. A non-null [initialData] produces an initial
/// `ConnectionState.none` snapshot with that data.
///
/// ```dart
/// setup(context, props) {
///   final snapshot = useFuture(loadUser());
///
///   return () => switch (snapshot.connectionState) {
///     ConnectionState.done => Text('${snapshot.data}'),
///     _ => const CircularProgressIndicator(),
///   };
/// }
/// ```
@defineHook
final useFuture = JoltSetupHookFutureCreator._();

/// Future snapshot hook factory methods.
final class JoltSetupHookFutureCreator {
  const JoltSetupHookFutureCreator._();

  /// Creates an [AsyncSnapshotFutureSignal] that tracks [future].
  @defineHook
  AsyncSnapshotFutureSignal<T> call<T>(FutureOr<T>? future, {T? initialData}) {
    return useHook(_UseFutureHook(future, initialData: initialData));
  }

  /// Creates an [AsyncSnapshotFutureSignal] that tracks [future.value].
  @defineHook
  AsyncSnapshotFutureSignal<T> watch<T>(Readable<FutureOr<T>?> future,
      {T? initialData}) {
    final result =
        useHook(_UseFutureWatchHook(future, initialData: initialData));

    return result;
  }

  static _AsyncSnapshotFutureSignalImpl<T> _create<T>(FutureOr<T>? future,
      {T? initialData}) {
    return switch (future) {
      null => _AsyncSnapshotFutureSignalImpl(null, initialData: initialData),
      Future() =>
        _AsyncSnapshotFutureSignalImpl(future, initialData: initialData),
      T() => _AsyncSnapshotFutureSignalImpl(SynchronousFuture(future),
          initialData: initialData),
    };
  }
}

class _UseFutureWatchHook<T>
    extends SetupHook<_AsyncSnapshotFutureSignalImpl<T>> {
  _UseFutureWatchHook(this.future, {this.initialData});
  final Readable<FutureOr<T>?> future;
  final T? initialData;

  @override
  _AsyncSnapshotFutureSignalImpl<T> build() {
    _future = future.value;
    return JoltSetupHookFutureCreator._create(future.value,
        initialData: initialData);
  }

  Object? _future;
  Disposer? _disposer;

  @override
  void mount() {
    _disposer = Effect(
      () {
        if (identical(_future, future.value)) {
          return;
        }
        _future = future.value;
        state.setFuture(future.value);
      },
    ).dispose;
  }

  @override
  void unmount() {
    _disposer?.call();
    _disposer = null;
    _future = null;
    state.dispose();
  }
}

class _UseFutureHook<T> extends SetupHook<_AsyncSnapshotFutureSignalImpl<T>> {
  _UseFutureHook(this.future, {this.initialData});
  final FutureOr<T>? future;
  final T? initialData;

  @override
  _AsyncSnapshotFutureSignalImpl<T> build() {
    return JoltSetupHookFutureCreator._create(future, initialData: initialData);
  }

  @override
  void unmount() {
    state.dispose();
  }
}

// ignore: must_be_immutable
class _AsyncSnapshotFutureSignalImpl<T> extends SignalImpl<AsyncSnapshot<T>>
    with _AsyncSnapshotSignalMixin<T>
    implements AsyncSnapshotFutureSignal<T> {
  _AsyncSnapshotFutureSignalImpl(this.future,
      {T? initialData, JoltDebugOption? debug})
      : super(
          initialData == null
              ? AsyncSnapshot<T>.nothing()
              : AsyncSnapshot<T>.withData(ConnectionState.none, initialData),
          debug: debug,
        ) {
    batch(_subscribe);
  }

  Future<T>? future;

  /// An object that identifies the currently active callbacks. Used to avoid
  /// calling setState from stale callbacks, e.g. after disposal of this state,
  /// or after widget reconfiguration to a new Future.
  Object? _activeCallbackIdentity;

  @override
  void setFuture(FutureOr<T>? future) {
    batch(() {
      if (this.future == future) {
        return;
      }
      if (_activeCallbackIdentity != null) {
        _unsubscribe();
        inState(ConnectionState.none);
      }
      switch (future) {
        case null:
          this.future = null;
        case Future():
          this.future = future;
        case T():
          this.future = SynchronousFuture(future);
      }
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
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

/// Interface for a signal that tracks a Future's state.
///
/// The signal exposes the current [AsyncSnapshot] fields and can be pointed at
/// another future with [setFuture].
abstract interface class AsyncSnapshotFutureSignal<T>
    implements AsyncSnapshot<T> {
  /// Starts tracking [future].
  ///
  /// Passing `null` clears the active future without producing a new waiting
  /// snapshot. Passing a synchronous value treats that value as a completed
  /// future.
  void setFuture(FutureOr<T>? future);
}

/// Tracks a [Stream] as an [AsyncSnapshot] for the current setup scope.
///
/// Use `useStream(stream)` to mirror a specific stream, or
/// `useStream.watch(readableStream)` when the stream itself is reactive and can
/// be replaced over time. The subscription is cancelled when the setup scope
/// unmounts.
///
/// ```dart
/// setup(context, props) {
///   final snapshot = useStream(messages);
///
///   return () => Text(snapshot.data ?? 'No messages yet');
/// }
/// ```
@defineHook
final useStream = JoltSetupHookStreamCreator._();

/// Stream snapshot hook factory methods.
final class JoltSetupHookStreamCreator {
  const JoltSetupHookStreamCreator._();

  /// Creates an [AsyncSnapshotStreamSignal] that tracks [stream].
  @defineHook
  AsyncSnapshotStreamSignal<T> call<T>(Stream<T>? stream, {T? initialData}) {
    return useAutoDispose<_AsyncSnapshotStreamSignalImpl<T>>(() {
      return _create(stream, initialData: initialData);
    });
  }

  /// Creates an [AsyncSnapshotStreamSignal] that tracks [source.value].
  @defineHook
  AsyncSnapshotStreamSignal<T> watch<T>(
    Readable<Stream<T>?> source, {
    T? initialData,
  }) {
    return useHook(_UseStreamWatchHook(source, initialData: initialData));
  }

  static _AsyncSnapshotStreamSignalImpl<T> _create<T>(
    Stream<T>? stream, {
    T? initialData,
  }) {
    return _AsyncSnapshotStreamSignalImpl<T>(
      stream,
      initialData: initialData,
    );
  }
}

class _UseStreamWatchHook<T>
    extends SetupHook<_AsyncSnapshotStreamSignalImpl<T>> {
  _UseStreamWatchHook(this.source, {this.initialData});

  final Readable<Stream<T>?> source;
  final T? initialData;

  Stream<T>? _stream;
  Disposer? _disposer;

  @override
  _AsyncSnapshotStreamSignalImpl<T> build() {
    _stream = source.value;
    return JoltSetupHookStreamCreator._create(
      _stream,
      initialData: initialData,
    );
  }

  @override
  void mount() {
    _disposer = Effect(() {
      if (identical(_stream, source.value)) {
        return;
      }
      _stream = source.value;
      state.setStream(_stream);
    }).dispose;
  }

  @override
  void unmount() {
    _disposer?.call();
    _disposer = null;
    _stream = null;
    state.dispose();
  }
}

// ignore: must_be_immutable
class _AsyncSnapshotStreamSignalImpl<T> extends SignalImpl<AsyncSnapshot<T>>
    with _AsyncSnapshotSignalMixin<T>
    implements AsyncSnapshotStreamSignal<T> {
  _AsyncSnapshotStreamSignalImpl(this.stream,
      {T? initialData, JoltDebugOption? debug})
      : super(
          initialData == null
              ? AsyncSnapshot<T>.nothing()
              : AsyncSnapshot<T>.withData(ConnectionState.none, initialData),
          debug: debug,
        ) {
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
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

/// Interface for a signal that tracks a Stream's state.
///
/// The signal exposes the current [AsyncSnapshot] fields and can be pointed at
/// another stream with [setStream].
abstract interface class AsyncSnapshotStreamSignal<T>
    implements AsyncSnapshot<T> {
  /// Starts tracking [stream].
  ///
  /// Passing `null` clears the active stream without creating a new
  /// subscription.
  void setStream(Stream<T>? stream);
}

// ignore: unused_element
mixin _AsyncSnapshotSignalMixin<T> on Signal<AsyncSnapshot<T>>
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

/// Stream-controller hook factory methods.
final class JoltSetupHookStreamControllerCreator {
  const JoltSetupHookStreamControllerCreator._();

  /// Creates a single-subscription [StreamController].
  @defineHook
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

  /// Creates a broadcast [StreamController].
  @defineHook
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

/// Creates a [StreamController] for the current setup scope.
///
/// The controller is created once and closed when the setup scope unmounts.
/// Use [JoltSetupHookStreamControllerCreator.broadcast] for a broadcast
/// controller.
///
/// ```dart
/// setup(context, props) {
///   final controller = useStreamController<int>();
///   final snapshot = useStream(controller.stream);
///
///   return () => Text('${snapshot.data ?? 0}');
/// }
/// ```
@defineHook
const useStreamController = JoltSetupHookStreamControllerCreator._();
