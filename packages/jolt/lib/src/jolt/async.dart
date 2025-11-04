import 'dart:async';

import 'package:shared_interfaces/shared_interfaces.dart';

import 'signal.dart';
import 'shared.dart';

/// Represents the state of an asynchronous operation.
///
/// AsyncState is a sealed class that represents different states of async operations:
/// - [AsyncLoading]: Initial loading state
/// - [AsyncData]: Success state with data
/// - [AsyncError]: Error state with error information
/// - [AsyncRefreshing]: Refreshing state while maintaining previous data
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

  /// Whether this state represents a refreshing operation.
  bool get isRefreshing => this is AsyncRefreshing<T>;

  /// Whether this state represents a successful operation with data.
  bool get isSuccess => this is AsyncData<T>;

  /// Whether this state represents an error.
  bool get isError => this is AsyncError<T>;

  /// The data from the async operation, if available.
  ///
  /// Returns the data for [AsyncData] and [AsyncRefreshing] states,
  /// null for [AsyncLoading] and [AsyncError] states.
  T? get data => switch (this) {
        AsyncData<T>(:final value) => value,
        AsyncRefreshing<T>(:final value) => value,
        _ => null,
      };

  /// The error from the async operation, if any.
  ///
  /// Returns the error for [AsyncError] and [AsyncRefreshing] states,
  /// null for [AsyncLoading] and [AsyncData] states.
  Object? get error => switch (this) {
        AsyncError<T>(:final error) => error,
        AsyncRefreshing<T>(:final error) => error,
        _ => null,
      };

  /// The stack trace from the async operation error, if any.
  ///
  /// Returns the stack trace for [AsyncError] and [AsyncRefreshing] states,
  /// null for other states.
  StackTrace? get stackTrace => switch (this) {
        AsyncError<T>(:final stackTrace) => stackTrace,
        AsyncRefreshing<T>(:final stackTrace) => stackTrace,
        _ => null,
      };

  /// Maps the async state to a value based on its current state.
  ///
  /// Parameters:
  /// - [loading]: Function called for loading state
  /// - [refreshing]: Function called for refreshing state
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
  ///   refreshing: (data, error, stackTrace) => 'Refreshing: $data',
  /// );
  /// ```
  R? map<R>({
    R Function()? loading,
    R Function(T?, Object?, StackTrace?)? refreshing,
    R Function(T)? success,
    R Function(Object?, StackTrace?)? error,
  }) =>
      switch (this) {
        AsyncLoading<T>() => loading?.call(),
        AsyncRefreshing<T>() => refreshing?.call(data, this.error, stackTrace),
        AsyncError<T>() => error?.call(this.error, stackTrace),
        AsyncData<T>() => success?.call(data as T),
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
class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

/// Represents the refreshing state of an async operation.
///
/// This state indicates that an async operation is refreshing
/// while maintaining access to previous data and potential error information.
///
/// Example:
/// ```dart
/// final state = AsyncRefreshing('old data', someError, stackTrace);
/// print(state.isRefreshing); // true
/// print(state.data); // 'old data'
/// ```
class AsyncRefreshing<T> extends AsyncState<T> {
  /// Creates a refreshing state with optional previous value and error.
  ///
  /// Parameters:
  /// - [value]: The previous value to maintain during refresh
  /// - [error]: Optional error from previous operation
  /// - [stackTrace]: Optional stack trace from previous error
  const AsyncRefreshing(this.value, [this.error, this.stackTrace]);

  /// The previous value maintained during refresh.
  final T? value;

  @override
  final Object? error;

  @override
  final StackTrace? stackTrace;
}

/// Represents the success state of an async operation with data.
///
/// This state indicates that an async operation completed successfully
/// and contains the resulting data.
///
/// Example:
/// ```dart
/// final state = AsyncData('Hello World');
/// print(state.isSuccess); // true
/// print(state.data); // 'Hello World'
/// ```
class AsyncData<T> extends AsyncState<T> {
  /// Creates a success state with the given value.
  ///
  /// Parameters:
  /// - [value]: The successful result data
  const AsyncData(this.value);

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
class AsyncError<T> extends AsyncState<T> {
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
/// that emits values to an AsyncSignal.
abstract interface class AsyncSource<T> implements Disposable {
  /// Starts the async operation and connects it to the given signal.
  ///
  /// Parameters:
  /// - [emit]: The AsyncSignal to emit states to
  ///
  /// This method should set up the async operation and emit appropriate
  /// AsyncState values as the operation progresses.
  void start(AsyncSignal<T> emit);

  @override
  FutureOr<void> dispose();
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
class FutureSource<T> implements AsyncSource<T> {
  /// Creates a future source with the given future.
  ///
  /// Parameters:
  /// - [_future]: The future to wrap
  FutureSource(this._future);

  final Future<T> _future;

  /// Starts the future and emits appropriate states.
  ///
  /// Emits [AsyncLoading] initially, then either [AsyncData] on success
  /// or [AsyncError] on failure.
  @override
  void start(AsyncSignal<T> signal) {
    signal.set(AsyncLoading<T>());
    _future
        .then(
          (value) => signal.set(AsyncData(value)),
          onError: (err, st) => signal.set(AsyncError(err, st)),
        )
        .ignore();
  }

  @override
  FutureOr<void> dispose() {}
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
class StreamSource<T> implements AsyncSource<T> {
  /// Creates a stream source with the given stream.
  ///
  /// Parameters:
  /// - [_stream]: The stream to wrap
  StreamSource(this._stream);

  final Stream<T> _stream;
  StreamSubscription<T>? _sub;

  /// Starts listening to the stream and emits appropriate states.
  ///
  /// Emits [AsyncLoading] initially, then [AsyncData] for each stream value
  /// or [AsyncError] for stream errors.
  @override
  void start(AsyncSignal<T> signal) {
    signal.set(AsyncLoading<T>());
    _sub = _stream.listen(
      (value) => signal.set(AsyncData(value)),
      onError: (err, st) => signal.set(AsyncError(err, st)),
    );
  }

  @override
  FutureOr<void> dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// A reactive signal that manages async state transitions.
///
/// AsyncSignal wraps an AsyncSource and provides a reactive interface
/// to async operations, automatically managing state transitions and
/// providing convenient access to the current async state.
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
class AsyncSignal<T> extends Signal<AsyncState<T>> {
  /// Creates an async signal with the given source.
  ///
  /// Parameters:
  /// - [source]: The async source to manage
  /// - [initialValue]: Optional initial async state
  AsyncSignal(AsyncSource<T> source,
      {AsyncState<T>? initialValue, super.onDebug})
      : _source = source,
        super(initialValue ?? AsyncLoading<T>()) {
    _source.start(this);
    JFinalizer.attachToJoltAttachments(this, _source.dispose);
  }

  final AsyncSource<T> _source;

  /// The async source being managed by this signal.
  AsyncSource<T> get source => _source;

  /// Convenient access to the data from the current async state.
  ///
  /// Returns the data if available, null otherwise.
  ///
  /// Example:
  /// ```dart
  /// final signal = AsyncSignal.fromFuture(someFuture);
  /// print(signal.data); // null initially, then the future result
  /// ```
  T? get data => value.data;

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
  factory AsyncSignal.fromFuture(Future<T> future) {
    return AsyncSignal(FutureSource(future));
  }

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
  factory AsyncSignal.fromStream(Stream<T> stream) {
    return AsyncSignal(StreamSource(stream));
  }
}

/// A specialized async signal for Future-based operations.
///
/// FutureSignal is a convenience class for working with Future-based
/// async operations, providing the same functionality as AsyncSignal
/// with a more specific constructor.
///
/// Example:
/// ```dart
/// final signal = FutureSignal(
///   Future.delayed(Duration(seconds: 1), () => 'Hello')
/// );
/// ```
class FutureSignal<T> extends AsyncSignal<T> {
  /// Creates a future signal with the given future.
  ///
  /// Parameters:
  /// - [future]: The future to manage
  FutureSignal(Future<T> future) : super(FutureSource(future));
}

/// A specialized async signal for Stream-based operations.
///
/// StreamSignal is a convenience class for working with Stream-based
/// async operations, providing the same functionality as AsyncSignal
/// with a more specific constructor.
///
/// Example:
/// ```dart
/// final signal = StreamSignal(
///   Stream.periodic(Duration(seconds: 1), (i) => i)
/// );
/// ```
class StreamSignal<T> extends AsyncSignal<T> {
  /// Creates a stream signal with the given stream.
  ///
  /// Parameters:
  /// - [stream]: The stream to manage
  StreamSignal(Stream<T> stream) : super(StreamSource(stream));
}
