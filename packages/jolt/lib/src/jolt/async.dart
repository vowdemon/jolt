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

/// State inspection and mapping for any readable [AsyncState].
///
/// The helpers read [Readable.value], so they participate in reactive tracking
/// exactly like a direct value read. They are available on async signals,
/// computed async states, readonly views, and compatible readable adapters.
/// {@category Advanced Techniques}
extension AsyncStateReadableX<T> on Readable<AsyncState<T>> {
  /// The successful data, or `null` while loading or after an error.
  T? get data => value.data;

  /// Whether the current state is [AsyncLoading].
  bool get isLoading => value.isLoading;

  /// Whether the current state is [AsyncSuccess].
  bool get isSuccess => value.isSuccess;

  /// Whether the current state is [AsyncError].
  bool get isError => value.isError;

  /// The current error, or `null` outside [AsyncError].
  Object? get error => value.error;

  /// The current error stack trace, or `null` outside [AsyncError].
  StackTrace? get stackTrace => value.stackTrace;

  /// Maps the current state through its matching optional callback.
  ///
  /// Returns `null` when the callback for the current state is omitted.
  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @pragma("dart2js:prefer-inline")
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
}

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

  /// Replaces the current source and subscribes to [source].
  ///
  /// Any earlier source is disposed, and late emissions from replaced sources
  /// are ignored. This signal keeps its current state until the new source
  /// emits a replacement state.
  Future<void> fetch(AsyncSource<T> source);
}
