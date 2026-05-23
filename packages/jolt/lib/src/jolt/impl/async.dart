import 'dart:async';

import 'package:jolt/core.dart';
import 'package:jolt/jolt.dart';
import 'package:meta/meta.dart';
import 'package:shared_interfaces/shared_interfaces.dart';

/// Represents the current state of an asynchronous operation.
///
/// Use [AsyncLoading], [AsyncSuccess], and [AsyncError] to branch on loading,
/// data, and failure outcomes in a single value.
///
/// Example:
/// ```dart
/// AsyncState<String> state = AsyncLoading<String>();
///
/// if (state.isLoading) {
///   print('Loading...');
/// } else if (state.isSuccess) {
///   print('Data: ${state.data}');
/// } else if (state.isError) {
///   print('Error: ${state.error}');
/// }
/// ```
sealed class AsyncState<T> {
  const AsyncState();

  /// Whether this state represents a loading operation.
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether this state represents a successful operation with data.
  bool get isSuccess => this is AsyncSuccess<T>;

  /// Whether this state represents an error.
  bool get isError => this is AsyncError<T>;

  /// The data from the async operation, if available.
  ///
  /// Returns the data for [AsyncSuccess] state,
  /// null for [AsyncLoading] and [AsyncError] states.
  T? get data =>
      this is AsyncSuccess<T> ? (this as AsyncSuccess<T>).value : null;

  /// The error from the async operation, if any.
  ///
  /// Returns the error for [AsyncError] state,
  /// null for [AsyncLoading] and [AsyncSuccess] states.
  Object? get error =>
      this is AsyncError<T> ? (this as AsyncError<T>).error : null;

  /// The stack trace from the async operation error, if any.
  ///
  /// Returns the stack trace for [AsyncError] state,
  /// null for other states.
  StackTrace? get stackTrace =>
      this is AsyncError<T> ? (this as AsyncError<T>).stackTrace : null;

  /// Maps this state to a value with optional handlers.
  ///
  /// The [loading], [success], and [error] callbacks handle the corresponding
  /// state variants. Returns `null` when the callback for this state's variant
  /// is omitted.
  ///
  /// Example:
  /// ```dart
  /// final message = state.map(
  ///   loading: () => 'Loading...',
  ///   success: (data) => 'Success: $data',
  ///   error: (error, stackTrace) => 'Error: $error',
  /// );
  /// ```
  R? map<R>({
    R Function()? loading,
    R Function(T)? success,
    R Function(Object?, StackTrace?)? error,
  }) =>
      switch (this) {
        AsyncLoading<T>() => loading?.call(),
        AsyncError<T>() => error?.call(this.error, stackTrace),
        AsyncSuccess<T>() => success?.call(data as T),
      };
}

/// Represents the loading state of an async operation.
///
/// This state indicates that an async operation is in progress
/// and no data is available yet.
///
/// Example:
/// ```dart
/// final state = AsyncLoading<String>();
/// print(state.isLoading); // true
/// ```
final class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

/// Represents the success state of an async operation with data.
///
/// This state indicates that an async operation completed successfully
/// and contains the resulting data.
///
/// Example:
/// ```dart
/// final state = AsyncSuccess('Hello World');
/// print(state.isSuccess); // true
/// print(state.data); // 'Hello World'
/// ```
final class AsyncSuccess<T> extends AsyncState<T> {
  /// Creates a success state that carries [value].
  const AsyncSuccess(this.value);

  /// The successful result data.
  final T value;
}

/// Represents the error state of an async operation.
///
/// This state indicates that an async operation failed with an error.
///
/// Example:
/// ```dart
/// final state = AsyncError('Something went wrong', stackTrace);
/// print(state.isError); // true
/// print(state.error); // 'Something went wrong'
/// ```
final class AsyncError<T> extends AsyncState<T> {
  /// Creates an error state with an error and optional stack trace.
  ///
  /// The [error] argument stores the failure. The optional [stackTrace]
  /// captures where that failure came from.
  const AsyncError(this.error, [this.stackTrace]);

  @override
  final Object? error;

  @override
  final StackTrace? stackTrace;
}

/// A source of [AsyncState] updates for [AsyncSignal].
///
/// Implement [AsyncSource] when you need custom logic for starting an
/// asynchronous operation and emitting its loading, success, and error states.
///
/// Example:
/// ```dart
/// class MyAsyncSource<T> extends AsyncSource<T> {
///   @override
///   FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) async {
///     emit(AsyncLoading());
///     try {
///       final data = await fetchData();
///       emit(AsyncSuccess(data));
///     } catch (e, st) {
///       emit(AsyncError(e, st));
///     }
///   }
/// }
/// ```
abstract class AsyncSource<T> implements Disposable {
  /// Starts the async source and emits state updates.
  ///
  /// The [emit] callback publishes loading, success, and error states. This
  /// method should emit [AsyncLoading] first, then later emit either
  /// [AsyncSuccess] or [AsyncError].
  ///
  /// Example:
  /// ```dart
  /// @override
  /// FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) async {
  ///   emit(AsyncLoading());
  ///   final data = await fetchData();
  ///   emit(AsyncSuccess(data));
  /// }
  /// ```
  FutureOr<void> subscribe(void Function(AsyncState<T> state) emit);

  /// Disposes this async source and cleans up resources.
  ///
  /// Override this method to provide custom cleanup logic, such as
  /// canceling ongoing operations or closing connections.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   _subscription?.cancel();
  /// }
  /// ```
  @override
  FutureOr<void> dispose() {}
}

/// An async source that wraps a Future.
///
/// FutureSource handles Future-based async operations, automatically
/// managing the loading, success, and error states.
///
/// Example:
/// ```dart
/// final future = Future.delayed(Duration(seconds: 1), () => 'Hello');
/// final source = FutureSource(future);
/// final signal = AsyncSignal(source);
/// ```
class FutureSource<T> extends AsyncSource<T> {
  /// Creates a source backed by a [Future].
  ///
  /// The future is observed and translated into async states.
  FutureSource(this._future);

  final Future<T> _future;

  /// Starts the future and emits appropriate states.
  ///
  /// Emits [AsyncLoading] initially, then either [AsyncSuccess] on success
  /// or [AsyncError] on failure.
  @override
  FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) async {
    await _future
        .then((data) => emit(AsyncSuccess(data)))
        .catchError((e, st) => emit(AsyncError(e, st)));
  }
}

/// An async source that wraps a Stream.
///
/// StreamSource handles Stream-based async operations, automatically
/// managing the loading, data, and error states for each stream event.
///
/// Example:
/// ```dart
/// final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
/// final source = StreamSource(stream);
/// final signal = AsyncSignal(source);
/// ```
class StreamSource<T> extends AsyncSource<T> {
  /// Creates a source backed by a [Stream].
  ///
  /// The stream is observed and translated into async states.
  StreamSource(this._stream);

  final Stream<T> _stream;
  StreamSubscription<T>? _sub;

  /// Starts listening to the stream and emits appropriate states.
  ///
  /// Emits [AsyncLoading] initially, then [AsyncSuccess] for each stream value
  /// or [AsyncError] for stream errors.
  @override
  FutureOr<void> subscribe(void Function(AsyncState<T> state) emit) async {
    final completer = Completer<void>();
    _sub = _stream.listen(
      (data) => emit(AsyncSuccess(data)),
      onError: (e, st) => emit(AsyncError(e, st)),
      onDone: completer.complete,
    );
    await completer.future;
  }

  @override
  void dispose() {
    _sub?.cancel().ignore();
    _sub = null;
  }
}

class AsyncSignalImpl<T> extends SignalImpl<AsyncState<T>>
    implements AsyncSignal<T> {
  AsyncSignalImpl({
    AsyncSource<T>? source,
    AsyncState<T>? initialValue,
    JoltDebugOption? debug,
  }) : super(initialValue ?? AsyncLoading<T>()) {
    if (source != null) {
      unawaited(fetch(source));
    }
  }

  @override
  T? get data => value.data;

  @override
  bool get isLoading => value.isLoading;

  @override
  bool get isSuccess => value.isSuccess;

  @override
  bool get isError => value.isError;

  @override
  Object? get error => value.error;

  @override
  StackTrace? get stackTrace => value.stackTrace;

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
  @override
  R? map<R>({
    R Function()? loading,
    R Function(T)? success,
    R Function(Object?, StackTrace?)? error,
  }) =>
      value.map(
        loading: loading,
        success: success,
        error: error,
      );

  Disposer? _sourceDisposer;
  Object? _objId;

  @override
  Future<void> fetch(AsyncSource<T> source) async {
    if (isDisposed) return;
    final objId = Object();
    _objId = objId;

    _sourceDisposer?.call();
    _sourceDisposer = source.dispose;

    void emit(AsyncState<T> state) {
      if (_objId == objId) {
        value = state;
      }
    }

    try {
      await source.subscribe(emit);
    } finally {
      if (_objId == objId) {
        _objId = null;
        final disposer = _sourceDisposer;
        _sourceDisposer = null;
        disposer?.call();
      }
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    super.dispose();
    _objId = null;
    _sourceDisposer?.call();
    _sourceDisposer = null;
  }
}
