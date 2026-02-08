import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

/// A cancellable future that completes when a reactive value satisfies a condition.
///
/// [Until] implements [Future] so it can be awaited directly. It also provides
/// [cancel] to stop waiting and dispose the underlying effect.
///
/// The condition is checked reactively: when [source] changes, the predicate
/// is re-evaluated. When it returns `true`, the future completes with the
/// current value.
///
/// **Important:** After calling [cancel], the future remains pending forever.
/// Do not await a cancelled [Until]—it will never complete.
///
/// Example:
/// ```dart
/// final until = Until(signal, (value) => value >= 5);
/// final result = await until; // Completes when condition is met
///
/// // If you need to stop waiting:
/// until.cancel(); // Disposes effect; do not await after this
/// ```
abstract interface class Until<T> implements Future<T> {
  /// Creates an [Until] that waits for [source] to satisfy [predicate].
  ///
  /// The future completes with the value of [source] when [predicate] returns
  /// `true` for that value. If the condition is already satisfied at creation
  /// time, the future completes immediately.
  ///
  /// Parameters:
  /// - [source]: The reactive value to observe
  /// - [predicate]: Returns `true` when the condition is met
  /// - [detach]: If true, the underlying effect is not bound to the current
  ///   scope and will not be disposed when the scope is disposed
  factory Until(ReadableNode<T> source, bool Function(T value) predicate,
      {bool? detach}) = UntilImpl<T>;

  /// Creates an [Until] that waits for [source] to equal [value].
  ///
  /// Convenience factory for the common case of waiting for an exact value.
  /// Equivalent to `Until(source, (v) => v == value, detach: detach)`.
  ///
  /// Example:
  /// ```dart
  /// final status = Signal('loading');
  /// await Until.when(status, 'ready'); // Waits until status is 'ready'
  /// ```
  factory Until.when(ReadableNode<T> source, T value, {bool? detach}) =>
      Until<T>(source, (v) => v == value, detach: detach);

  /// Creates an [Until] that waits for [source] to change from its current value.
  ///
  /// Captures the value at creation time and completes when [source] holds a
  /// different value (using `!=` for comparison). Useful for waiting for
  /// the next transition.
  ///
  /// Example:
  /// ```dart
  /// final status = Signal('idle');
  /// status.value = 'loading';
  /// final next = await Until.changed(status); // Waits for status != 'loading'
  /// ```
  factory Until.changed(ReadableNode<T> source, {bool? detach}) {
    final current = source.value;
    return Until<T>(source, (v) => v != current, detach: detach);
  }

  /// Cancels the wait and disposes the underlying effect.
  ///
  /// Does not complete the future. The future remains pending indefinitely.
  /// **Do not await after calling [cancel]**—the await will not resolve.
  ///
  /// Has no effect if the condition was already met or [cancel] was already
  /// called. Use [isCancelled] to check whether [cancel] was invoked.
  void cancel();

  /// Whether this [Until] has completed (with a value or error).
  ///
  /// True when the condition was satisfied or when the future was completed
  /// through some other means. False when still waiting or when [cancel] was
  /// called (the future stays pending in that case).
  bool get isCompleted;

  /// Whether [cancel] was called on this [Until].
  ///
  /// Once true, the effect is disposed and the future will never complete.
  bool get isCancelled;
}

/// Implementation of [Until] that monitors a reactive value until a condition is met.
class UntilImpl<T> implements Until<T> {
  late final Completer<T> _completer;
  Effect? _effect;
  bool _cancelled = false;

  UntilImpl(ReadableNode<T> source, bool Function(T value) predicate,
      {bool? detach}) {
    if (predicate(source.value)) {
      _completer = Completer<T>()..complete(source.value);
    } else {
      _completer = Completer<T>();
      _effect = Effect.lazy(() {
        if (_completer.isCompleted) return;
        if (predicate(source.value)) _completer.complete(source.value);
      }, detach: detach ?? true, debug: JoltDebugOption.type('Until<$T>'));
      trackWithEffect(() => source.value, _effect!);
      _completer.future.whenComplete(_effect!.dispose);
    }
  }

  Future<T> get _future => _completer.future;

  @override
  void cancel() {
    if (!_completer.isCompleted) {
      _cancelled = true;
      _effect?.dispose();
      _effect = null;
    }
  }

  @override
  bool get isCompleted => _completer.isCompleted;

  @override
  bool get isCancelled => _cancelled;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
          {Function? onError}) =>
      _future.then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _future.asStream();
}

/// Extension methods for reactive values.
extension JoltUtilsUntilExtension<T> on ReadableNode<T> {
  /// Waits until the value satisfies a condition.
  ///
  /// Returns an [Until] that implements [Future] and can be awaited. The
  /// returned value also has a [Until.cancel] method to stop waiting and
  /// dispose the effect when the predicate will never be satisfied.
  ///
  /// Parameters:
  /// - [predicate]: Function that returns `true` when condition is met
  /// - [detach]: If true, the effect will not be bound to the current scope
  ///
  /// Returns: An [Until] that completes with the value when condition is satisfied
  ///
  /// Example:
  /// ```dart
  /// final count = Signal(0);
  /// final until = count.until((value) => value >= 5);
  /// // await until; // wait for condition
  /// // until.cancel(); // or cancel to stop waiting
  /// ```
  Until<T> until(bool Function(T value) predicate, {bool? detach}) =>
      Until<T>(this, predicate, detach: detach);

  /// Waits until the reactive value equals [value].
  ///
  /// Equivalent to `until((v) => v == value)`.
  ///
  /// Example:
  /// ```dart
  /// final status = Signal('loading');
  /// await status.untilWhen('ready');
  /// ```
  Until<T> untilWhen<U>(U value, {bool? detach}) =>
      Until<T>.when(this, value as T, detach: detach);

  /// Waits until the value changes from its current value.
  ///
  /// Completes with the new value when it changes. Uses `!=` for comparison.
  ///
  /// Example:
  /// ```dart
  /// final status = Signal('idle');
  /// status.value = 'loading';
  /// final next = await status.untilChanged(); // Waits for status != 'loading'
  /// ```
  Until<T> untilChanged({bool? detach}) =>
      Until<T>.changed(this, detach: detach);
}
