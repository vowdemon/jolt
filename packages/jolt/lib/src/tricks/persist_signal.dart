import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";

Future<void>? _invokeWrite<T>(
  FutureOr<void> Function(T value) write,
  T value,
) {
  try {
    final result = write(value);
    if (result is Future) {
      return result.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
    }
  } catch (_) {
    // Persistence stays optimistic and write failures remain non-reporting.
  }
  return null;
}

final class _SyncPersistSignalImpl<T> extends SignalImpl<T>
    implements PersistSignal<T> {
  _SyncPersistSignalImpl({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    JoltDebugOption? debug,
  })  : _write = write,
        super(read(), debug: debug);

  final FutureOr<void> Function(T value) _write;
  Future<void>? _lastWrite;

  @override
  set value(T newValue) {
    super.value = newValue;
    if (!isDisposed) {
      _lastWrite = _invokeWrite(_write, newValue);
    }
  }

  @override
  Future<void> ensureWrite() => _lastWrite ?? Future<void>.value();
}

final class _AsyncPersistSignalImpl<T> extends SignalImpl<AsyncState<T>>
    implements AsyncPersistSignal<T> {
  _AsyncPersistSignalImpl({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    JoltDebugOption? debug,
  })  : _write = write,
        super(AsyncLoading<T>(), debug: debug) {
    final operationToken = Object();
    _operationToken = operationToken;
    unawaited(_observeRead(Future<T>.sync(read), operationToken));
  }

  final FutureOr<void> Function(T value) _write;
  Future<void>? _lastWrite;
  Object? _operationToken;
  _AsyncPersistAssignment? _assignment;

  @override
  set value(AsyncState<T> newValue) {
    _operationToken = null;
    final previous = _assignment;
    _assignment = null;

    super.value = newValue;
    if (!isDisposed && newValue is AsyncSuccess<T>) {
      _lastWrite = _invokeWrite(_write, newValue.value);
    }

    previous?.complete();
  }

  Future<void> _observeRead(Future<T> future, Object operationToken) async {
    try {
      final result = await future;
      if (_isCurrent(operationToken)) {
        super.value = AsyncSuccess<T>(result);
      }
    } catch (error, stackTrace) {
      if (_isCurrent(operationToken)) {
        super.value = AsyncError<T>(error, stackTrace);
      }
    }
  }

  Future<void> _observeAssignment(
    Future<T> future,
    _AsyncPersistAssignment assignment,
  ) async {
    try {
      final result = await future;
      if (_isCurrent(assignment)) {
        super.value = AsyncSuccess<T>(result);
        _lastWrite = _invokeWrite(_write, result);
      }
    } catch (error, stackTrace) {
      if (_isCurrent(assignment)) {
        super.value = AsyncError<T>(error, stackTrace);
      }
    } finally {
      assignment.complete();
    }
  }

  bool _isCurrent(Object operationToken) =>
      !isDisposed && identical(_operationToken, operationToken);

  @override
  void set(T value) {
    this.value = AsyncSuccess<T>(value);
  }

  @override
  void setFuture(Future<T> value) {
    final assignment = _AsyncPersistAssignment();
    final previous = _assignment;
    _operationToken = assignment;
    _assignment = assignment;

    super.value = AsyncLoading<T>();
    previous?.complete();

    if (isDisposed) {
      assignment.complete();
      return;
    }

    unawaited(_observeAssignment(value, assignment));
  }

  @override
  Future<void> ensureWrite() async {
    while (true) {
      final assignment = _assignment;
      if (assignment != null) {
        await assignment.completed.future;
      }

      if (identical(_assignment, assignment)) {
        break;
      }
    }

    await (_lastWrite ?? Future<void>.value());
  }

  @override
  void dispose() {
    _operationToken = null;
    final assignment = _assignment;
    _assignment = null;
    assignment?.complete();
    super.dispose();
  }
}

final class _AsyncPersistAssignment {
  final Completer<void> completed = Completer<void>();

  void complete() {
    if (!completed.isCompleted) {
      completed.complete();
    }
  }
}

/// Keyed storage used by [PersistSignal] and [AsyncPersistSignal].
///
/// A storage implementation decides whether [initial] is needed, allowing it
/// to distinguish a missing key from a stored nullable value. Reads and writes
/// may complete synchronously or asynchronously.
///
/// [PersistSignalStorageX] provides `sync<T>` and `async<T>` convenience
/// methods when the storage instance is the natural construction receiver.
/// {@category Advanced Techniques}
abstract interface class PersistSignalStorage<K> {
  /// Reads [key], optionally invoking [initial] when storage considers it
  /// missing. When [initial] is omitted, the storage owns missing-value
  /// behavior.
  FutureOr<T> read<T>(K key, [T Function()? initial]);

  /// Writes [value] at [key].
  FutureOr<void> write<T>(K key, T value);
}

@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:prefer-inline")
T _readStorageSync<K, T>(
  PersistSignalStorage<K> storage,
  K key,
  T Function()? initial,
) {
  final value = storage.read<T>(key, initial);
  if (value is Future<T>) {
    throw StateError(
      "PersistSignal.storage requires storage.read to complete synchronously. "
      "Use AsyncPersistSignal.storage for asynchronous storage reads.",
    );
  }
  return value;
}

/// A signal that reads its initial value synchronously and persists later
/// assignments through keyed storage or caller-provided callbacks.
///
/// Use [AsyncPersistSignal] when the initial read returns a [Future].
/// {@category Advanced Techniques}
abstract interface class PersistSignal<T> implements Signal<T> {
  /// Creates a persistent signal backed by direct callbacks.
  ///
  /// [read] runs during construction. Later assignments update the signal
  /// immediately and are passed to [write].
  factory PersistSignal({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    JoltDebugOption? debug,
  }) = _SyncPersistSignalImpl<T>;

  /// Creates a synchronous persistent signal backed by keyed [storage].
  ///
  /// The storage decides whether to return a stored value, invoke [initial],
  /// or apply its own missing-value behavior when [initial] is omitted.
  /// Its read must complete synchronously; use [AsyncPersistSignal.storage]
  /// when it returns a Future.
  static PersistSignal<T> storage<K, T>({
    required K key,
    T Function()? initial,
    required PersistSignalStorage<K> storage,
    JoltDebugOption? debug,
  }) =>
      PersistSignal<T>(
        read: () => _readStorageSync(storage, key, initial),
        write: (value) => storage.write<T>(key, value),
        debug: debug,
      );

  /// Waits for the most recent Future returned by [write] to finish.
  ///
  /// Write callbacks are invoked immediately and may run concurrently. Any
  /// throttling, ordering, or coalescing policy belongs inside `write`.
  Future<void> ensureWrite();
}

/// A signal that exposes asynchronous persistence as [AsyncState].
///
/// The signal starts in [AsyncLoading]. The initial read becomes
/// [AsyncSuccess] or [AsyncError] without being written back. Explicit success
/// values are persisted, while loading and error assignments only replace
/// reactive state.
/// {@category Advanced Techniques}
abstract interface class AsyncPersistSignal<T>
    implements Signal<AsyncState<T>> {
  /// Creates an async-state persistent signal backed by keyed [storage].
  ///
  /// The storage decides whether to return a stored value, invoke [initial],
  /// or apply its own missing-value behavior when [initial] is omitted.
  /// Synchronous values, Future values, synchronous throws, and asynchronous
  /// failures are normalized into loading, success, and error states.
  static AsyncPersistSignal<T> storage<K, T>({
    required K key,
    T Function()? initial,
    required PersistSignalStorage<K> storage,
    JoltDebugOption? debug,
  }) =>
      AsyncPersistSignal<T>(
        read: () => Future<T>.sync(
          () => storage.read<T>(key, initial),
        ),
        write: (value) => storage.write<T>(key, value),
        debug: debug,
      );

  /// Creates an asynchronous persistent signal from direct callbacks.
  ///
  /// [read] starts during construction. Its result updates the initial
  /// [AsyncLoading] state but is not written back automatically.
  factory AsyncPersistSignal({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    JoltDebugOption? debug,
  }) = _AsyncPersistSignalImpl<T>;

  /// Publishes [value] as [AsyncSuccess] and persists it immediately.
  void set(T value);

  /// Publishes [AsyncLoading] and observes [value] as an explicit assignment.
  ///
  /// A successful result is published and persisted only while this assignment
  /// remains current. A current failure is published as [AsyncError] and is not
  /// written. Any later explicit assignment supersedes this Future.
  void setFuture(Future<T> value);

  /// Waits for the current assignment to settle and the latest write callback
  /// Future to finish.
  ///
  /// The initial read is not part of this barrier. A superseded unresolved
  /// assignment does not keep it pending, and earlier overlapping write
  /// callback Futures are not drained.
  Future<void> ensureWrite();
}

/// Convenience persistent-signal factories on a [PersistSignalStorage].
///
/// These methods are equivalent to [PersistSignal.storage] and
/// [AsyncPersistSignal.storage], while inferring the key type from the storage
/// receiver.
/// {@category Advanced Techniques}
extension PersistSignalStorageX<K> on PersistSignalStorage<K> {
  /// Creates a synchronously read persistent signal for [key].
  ///
  /// The storage receives [initial] unchanged and owns missing-value behavior.
  /// Its read must complete synchronously; use [async] otherwise.
  PersistSignal<T> sync<T>({
    required K key,
    T Function()? initial,
    JoltDebugOption? debug,
  }) =>
      PersistSignal.storage(
        key: key,
        initial: initial,
        storage: this,
        debug: debug,
      );

  /// Creates an async-state persistent signal for [key].
  ///
  /// The storage receives [initial] unchanged and may complete its read either
  /// synchronously or asynchronously.
  AsyncPersistSignal<T> async<T>({
    required K key,
    T Function()? initial,
    JoltDebugOption? debug,
  }) =>
      AsyncPersistSignal.storage(
        key: key,
        initial: initial,
        storage: this,
        debug: debug,
      );
}
