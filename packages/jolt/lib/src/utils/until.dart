import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

/// A cancellable future that completes when a reactive value satisfies a condition.
///
/// [Until] can be awaited like any other [Future]. Calling [cancel] stops
/// waiting, disposes the underlying reactive effect, and leaves this future
/// pending forever.
///
/// ```dart
/// final status = Signal('idle');
/// final ready = Until(status, (value) => value == 'ready');
///
/// status.value = 'ready';
/// print(await ready); // ready
/// ```
abstract interface class Until<T> implements Future<T> {
  /// Creates an [Until] that waits for [source] to satisfy [predicate].
  ///
  /// The future completes with the value of [source] when [predicate] returns
  /// `true` for that value. If the condition is already satisfied, this future
  /// completes immediately. When [detach] is omitted or `true`, the underlying
  /// effect is not tied to the current [EffectScope]. Set [detach] to `false`
  /// to let scope disposal stop the wait.
  factory Until(Readable<T> source, bool Function(T value) predicate,
      {bool? detach}) = _UntilImpl<T>;

  /// Creates an [Until] that waits for [source] to equal [value].
  ///
  /// This is shorthand for `Until(source, (v) => v == value, detach: detach)`.
  factory Until.when(Readable<T> source, T value, {bool? detach}) =>
      Until<T>(source, (v) => v == value, detach: detach);

  /// Creates an [Until] that waits for [source] to change from its current value.
  ///
  /// Captures the value at creation time and completes when [source] holds a
  /// different value using `!=` for comparison.
  factory Until.changed(Readable<T> source, {bool? detach}) {
    final current = source.value;
    return Until<T>(source, (v) => v != current, detach: detach);
  }

  /// Cancels the wait and disposes the underlying effect.
  ///
  /// Calling [cancel] does not complete this future. It stays pending forever,
  /// so code should not await a cancelled [Until].
  void cancel();

  /// Whether this wait has already completed.
  bool get isCompleted;

  /// Whether [cancel] was called on this wait.
  bool get isCancelled;
}

class _UntilImpl<T> implements Until<T> {
  late final Completer<T> _completer;
  Effect? _effect;
  bool _cancelled = false;

  _UntilImpl(Readable<T> source, bool Function(T value) predicate,
      {bool? detach}) {
    if (predicate(source.value)) {
      _completer = Completer<T>()..complete(source.value);
    } else {
      _completer = Completer<T>();
      _effect = Effect.lazy(() {
        if (_completer.isCompleted) return;
        if (predicate(source.value)) _completer.complete(source.value);
      }, detach: detach ?? true, debug: JoltDebugOption.type('Until<$T>'));
      (_effect as EffectImpl).track(() => source.value);

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

/// Extension methods for waiting on reactive values.
extension JoltUtilsUntilExtension<T> on Readable<T> {
  /// Waits until the value satisfies a condition.
  ///
  /// This is shorthand for [Until.new]. When [detach] is omitted or `true`,
  /// the wait survives disposal of the current [EffectScope].
  ///
  /// ```dart
  /// final count = Signal(0);
  /// final ready = count.until((value) => value >= 5);
  ///
  /// count.value = 5;
  /// print(await ready); // 5
  /// ```
  Until<T> until(bool Function(T value) predicate, {bool? detach}) =>
      Until<T>(this, predicate, detach: detach);

  /// Waits until the reactive value equals [value].
  ///
  /// The [value] argument must be assignable to [T]. This is shorthand for
  /// `until((v) => v == value)`.
  Until<T> untilWhen<U>(U value, {bool? detach}) =>
      Until<T>.when(this, value as T, detach: detach);

  /// Waits until the value changes from its current value.
  ///
  /// This snapshots the current value when called and completes with the first
  /// later value that differs by `!=`.
  Until<T> untilChanged({bool? detach}) =>
      Until<T>.changed(this, detach: detach);
}
