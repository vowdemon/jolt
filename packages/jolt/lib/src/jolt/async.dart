import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

export "impl/async.dart"
    show
        AsyncState,
        AsyncSuccess,
        AsyncError,
        AsyncLoading,
        AsyncSource,
        StreamSource,
        FutureSource;

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
  /// - [debug]: Optional debug options
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
    JoltDebugOption? debug,
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
  factory AsyncSignal.fromFuture(Future<T> future, {JoltDebugOption? debug}) =>
      AsyncSignalImpl(source: FutureSource(future), debug: debug);

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
  factory AsyncSignal.fromStream(Stream<T> stream, {JoltDebugOption? debug}) =>
      AsyncSignalImpl(source: StreamSource(stream), debug: debug);

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

  /// Whether the current state represents a loading operation.
  bool get isLoading;

  /// Whether the current state represents a successful operation with data.
  bool get isSuccess;

  /// Whether the current state represents an error.
  bool get isError;

  /// The error from the current async state, if any.
  Object? get error;

  /// The stack trace from the current async error state, if any.
  StackTrace? get stackTrace;

  /// Maps the current async state to a value based on its state variant.
  R? map<R>({
    R Function()? loading,
    R Function(T)? success,
    R Function(Object?, StackTrace?)? error,
  });

  /// Replaces the current async source and subscribes to the new one.
  ///
  /// This can be used to reload or switch the underlying async operation
  /// while keeping the same signal instance.
  ///
  /// Example:
  /// ```dart
  /// await signal.fetch(FutureSource(fetchData()));
  /// ```
  Future<void> fetch(AsyncSource<T> source);
}
