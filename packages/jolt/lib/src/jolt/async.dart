import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/src/jolt/signal.dart";
import "package:shared_interfaces/shared_interfaces.dart";

/// Represents the state of an asynchronous operation.
///
/// AsyncState is a sealed class that represents different states of async operations:
/// - [AsyncLoading]: Initial loading state
/// - [AsyncSuccess]: Success state with data
/// - [AsyncError]: Error state with error information
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

  /// Maps the async state to a value based on its current state.
  ///
  /// Parameters:
  /// - [loading]: Function called for loading state
  /// - [success]: Function called for success state with data
  /// - [error]: Function called for error state
  ///
  /// Returns: The result of the appropriate function, or null if no function provided
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
  /// Creates a success state with the given value.
  ///
  /// Parameters:
  /// - [value]: The successful result data
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
  /// Creates an error state with the given error and optional stack trace.
  ///
  /// Parameters:
  /// - [error]: The error that occurred
  /// - [stackTrace]: Optional stack trace of the error
  const AsyncError(this.error, [this.stackTrace]);

  @override
  final Object? error;

  @override
  final StackTrace? stackTrace;
}

/// Abstract interface for async data sources.
///
/// AsyncSource defines how to start and manage an asynchronous operation
/// that emits values to an AsyncSignal. Implement this interface to create
/// custom async sources for AsyncSignal.
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
  /// Subscribes to the async source and emits states.
  ///
  /// Parameters:
  /// - [emit]: Function to call with async states (loading, success, error)
  ///
  /// This method should emit [AsyncLoading] initially, then either
  /// [AsyncSuccess] on success or [AsyncError] on failure.
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
  /// Creates a future source with the given future.
  ///
  /// Parameters:
  /// - [_future]: The future to wrap
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
  /// Creates a stream source with the given stream.
  ///
  /// Parameters:
  /// - [_stream]: The stream to wrap
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

/// Implementation of [AsyncSignal] that manages async state transitions.
///
/// This is the concrete implementation of the [AsyncSignal] interface. AsyncSignal
/// wraps an AsyncSource and provides a reactive interface to async operations,
/// automatically managing state transitions and providing convenient access to
/// the current async state.
///
/// See [AsyncSignal] for the public interface and usage examples.
///
/// Example:
/// ```dart
/// final future = Future.delayed(Duration(seconds: 1), () => 'Hello');
/// final signal = AsyncSignal.fromFuture(future);
///
/// // React to state changes
/// Effect(() {
///   final state = signal.value;
///   if (state.isLoading) print('Loading...');
///   if (state.isSuccess) print('Data: ${state.data}');
///   if (state.isError) print('Error: ${state.error}');
/// });
/// ```
class AsyncSignalImpl<T> extends SignalImpl<AsyncState<T>>
    implements AsyncSignal<T> {
  /// Creates an async signal with the given source.
  ///
  /// Parameters:
  /// - [source]: The async source to manage
  /// - [initialValue]: Optional initial async state
  AsyncSignalImpl({
    AsyncSource<T>? source,
    AsyncState<T>? initialValue,
    super.onDebug,
  }) : super(initialValue ?? AsyncLoading<T>()) {
    if (source != null) {
      unawaited(fetch(source));
    }
  }

  @override
  T? get data => value.data;

  Disposer? _sourceDisposer;

  Future<void> fetch(AsyncSource<T> source) async {
    _sourceDisposer?.call();
    _sourceDisposer = null;

    void emit(AsyncState<T> state) {
      if (!isDisposed) set(state);
    }

    final future = source.subscribe(emit);
    _sourceDisposer = source.dispose;
    final currentDisposer = source.dispose;

    try {
      await future;
    } finally {
      if (_sourceDisposer == currentDisposer) {
        _sourceDisposer = null;
        currentDisposer();
      }
    }
  }
}

/// Interface for reactive signals that manage async state transitions.
///
/// AsyncSignal wraps an AsyncSource and provides a reactive interface
/// to async operations, automatically managing state transitions and
/// providing convenient access to the current async state.
///
/// Example:
/// ```dart
/// AsyncSignal<String> signal = AsyncSignal.fromFuture(
///   Future.delayed(Duration(seconds: 1), () => 'Hello')
/// );
///
/// Effect(() {
///   if (signal.value.isSuccess) {
///     print('Data: ${signal.data}');
///   }
/// });
/// ```
abstract interface class AsyncSignal<T> implements Signal<AsyncState<T>> {
  /// Creates an async signal with the given source.
  ///
  /// Parameters:
  /// - [source]: The async source to manage
  /// - [initialValue]: Optional initial async state
  /// - [onDebug]: Optional debug callback for reactive system debugging
  ///
  /// Example:
  /// ```dart
  /// final signal = AsyncSignal(
  ///   source: FutureSource(future),
  ///   initialValue: AsyncLoading(),
  /// );
  /// ```
  factory AsyncSignal({
    AsyncSource<T>? source,
    AsyncState<T>? initialValue,
    JoltDebugFn? onDebug,
  }) = AsyncSignalImpl<T>;

  /// Creates an async signal from a Future.
  ///
  /// Parameters:
  /// - [future]: The future to wrap
  ///
  /// Returns: An AsyncSignal that manages the future's lifecycle
  ///
  /// Example:
  /// ```dart
  /// final signal = AsyncSignal.fromFuture(
  ///   Future.delayed(Duration(seconds: 1), () => 'Hello')
  /// );
  /// ```
  factory AsyncSignal.fromFuture(Future<T> future, {JoltDebugFn? onDebug}) =>
      AsyncSignalImpl(source: FutureSource(future), onDebug: onDebug);

  /// Creates an async signal from a Stream.
  ///
  /// Parameters:
  /// - [stream]: The stream to wrap
  ///
  /// Returns: An AsyncSignal that manages the stream's lifecycle
  ///
  /// Example:
  /// ```dart
  /// final signal = AsyncSignal.fromStream(
  ///   Stream.periodic(Duration(seconds: 1), (i) => i)
  /// );
  /// ```
  factory AsyncSignal.fromStream(Stream<T> stream, {JoltDebugFn? onDebug}) =>
      AsyncSignalImpl(source: StreamSource(stream), onDebug: onDebug);

  /// Gets the data from the current async state.
  ///
  /// Returns the data for [AsyncSuccess] state, null for [AsyncLoading]
  /// and [AsyncError] states.
  ///
  /// Example:
  /// ```dart
  /// final data = signal.data; // null if loading or error
  /// ```
  T? get data;
}
