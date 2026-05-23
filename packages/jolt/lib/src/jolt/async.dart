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

/// A reactive signal that exposes the state of an asynchronous source.
///
/// [AsyncSignal] usually starts in [AsyncLoading], then publishes
/// [AsyncSuccess] or [AsyncError] as its current source emits results.
/// {@category Advanced Techniques}
abstract interface class AsyncSignal<T> implements Signal<AsyncState<T>> {
  /// Creates an async signal and optionally starts an initial source.
  ///
  /// The optional [source] starts immediately. The optional [initialValue]
  /// controls the state exposed before that source emits and defaults to
  /// [AsyncLoading].
  factory AsyncSignal({
    AsyncSource<T>? source,
    AsyncState<T>? initialValue,
    JoltDebugOption? debug,
  }) = AsyncSignalImpl<T>;

  /// Creates an async signal backed by a [Future].
  ///
  /// The [future] drives this signal from [AsyncLoading] to either
  /// [AsyncSuccess] or [AsyncError].
  factory AsyncSignal.fromFuture(Future<T> future, {JoltDebugOption? debug}) =>
      AsyncSignalImpl(source: FutureSource(future), debug: debug);

  /// Creates an async signal backed by a [Stream].
  ///
  /// The [stream] drives this signal from [AsyncLoading] to later
  /// [AsyncSuccess] or [AsyncError] states.
  factory AsyncSignal.fromStream(Stream<T> stream, {JoltDebugOption? debug}) =>
      AsyncSignalImpl(source: StreamSource(stream), debug: debug);

  /// Gets the data from the current async state.
  ///
  /// This is the successful value for [AsyncSuccess] and `null` while loading
  /// or after an error.
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

  /// Maps the current async state to a value with optional handlers.
  ///
  /// The [loading], [success], and [error] callbacks handle the corresponding
  /// state variants. Returns `null` when the callback for this state's variant
  /// is omitted.
  R? map<R>({
    R Function()? loading,
    R Function(T)? success,
    R Function(Object?, StackTrace?)? error,
  });

  /// Replaces the current source and subscribes to [source].
  ///
  /// Any earlier source is disposed, and late emissions from replaced sources
  /// are ignored. This signal keeps its current state until the new source
  /// emits a replacement state.
  Future<void> fetch(AsyncSource<T> source);
}
