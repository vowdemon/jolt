import 'dart:async';
import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    show IList;
import 'package:jolt/jolt.dart' show untracked;

import '../foundation/query_cancellation.dart';
import '../foundation/query_value.dart';
import '../query/recipe.dart';

/// Controls visibility and accumulation when a stream-backed query refetches.
enum StreamRefetchMode {
  /// Restore the query's reset state, then publish each reduced chunk.
  ///
  /// A never-fetched initial-data seed remains visible on the first attempt.
  /// Once fetched, every retry attempt restores configured initial data or
  /// absence before accepting new chunks.
  reset,

  /// Reduce from the logical-operation baseline and publish each chunk.
  append,

  /// Accumulate privately and replace visible data only after normal close.
  replace,
}

/// Creates an attempt-aware stream-backed ordinary query function.
///
/// [initial] runs once per retry attempt. [reduce] is synchronous and receives
/// chunks serially. Retry remains typed to the final [Data] because this helper
/// returns one final value only after the stream closes normally.
QueryFunction<Data> streamedQuery<Chunk, Data>({
  required Stream<Chunk> Function(QueryContext context) stream,
  required Data Function() initial,
  required Data Function(Data current, Chunk chunk) reduce,
  StreamRefetchMode mode = StreamRefetchMode.reset,
}) {
  return (context) async {
    final controller = context.streamDataInternal;
    final baseline = controller?.beginAttempt(_internalMode(mode)) ??
        const QueryValue<Object?>.absent();
    final seed = untracked(initial);
    context.ensureOperationCurrentInternal();
    var accumulator = switch ((mode, baseline)) {
      (
        StreamRefetchMode.append || StreamRefetchMode.reset,
        QueryPresent<Object?>(value: final value),
      ) =>
        value as Data,
      _ => seed,
    };

    final source = untracked(() => stream(context));
    context.ensureOperationCurrentInternal();
    final cursor = _GuardedStreamCursor<Chunk>(source);
    var wasCancelled = false;
    Object? cancellationReason;
    final removeCancellationListener = context.cancellationToken.addListener(
      (reason) {
        wasCancelled = true;
        cancellationReason = reason;
        unawaited(cursor.cancel());
      },
    );

    try {
      streamEvents:
      while (true) {
        final event = await cursor.next();
        if (wasCancelled) {
          throw QueryCancelledException(cancellationReason);
        }
        switch (event) {
          case _GuardedStreamData<Chunk>(:final value):
            final next = untracked(
              () => reduce(accumulator, value),
            );
            accumulator = next;
            if (mode != StreamRefetchMode.replace) {
              controller?.commitPartial(next);
            }
          case _GuardedStreamError<Chunk>(:final error, :final stackTrace):
            Error.throwWithStackTrace(error, stackTrace);
          case _GuardedStreamDone<Chunk>():
            break streamEvents;
        }
      }
      if (wasCancelled) {
        throw QueryCancelledException(cancellationReason);
      }
      return accumulator;
    } finally {
      removeCancellationListener();
      await cursor.cancel();
    }
  };
}

/// Creates a stream-backed query that accumulates chunks into a typed list.
///
/// This is the common-case counterpart to [streamedQuery]. Each emitted chunk
/// is appended to a new list while refetch visibility follows [mode].
QueryFunction<IList<Chunk>> streamedListQuery<Chunk>({
  required Stream<Chunk> Function(QueryContext context) stream,
  StreamRefetchMode mode = StreamRefetchMode.reset,
}) {
  return streamedQuery<Chunk, IList<Chunk>>(
    stream: stream,
    initial: IList<Chunk>.new,
    reduce: (current, chunk) => current.add(chunk),
    mode: mode,
  );
}

QueryStreamAttemptModeInternal _internalMode(StreamRefetchMode mode) {
  return switch (mode) {
    StreamRefetchMode.reset => QueryStreamAttemptModeInternal.reset,
    StreamRefetchMode.append => QueryStreamAttemptModeInternal.append,
    StreamRefetchMode.replace => QueryStreamAttemptModeInternal.replace,
  };
}

final class _GuardedStreamCursor<T> {
  _GuardedStreamCursor(Stream<T> source) {
    _subscription = source.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  final Queue<_GuardedStreamEvent<T>> _events = Queue<_GuardedStreamEvent<T>>();
  // This cursor owns and cancels the source subscription in [cancel].
  // ignore: cancel_subscriptions
  StreamSubscription<T>? _subscription;
  Completer<_GuardedStreamEvent<T>>? _waiting;
  Future<void>? _cancellation;
  bool _isTerminal = false;
  bool _isCancellationRequested = false;

  Future<_GuardedStreamEvent<T>> next() async {
    if (_isCancellationRequested) {
      await cancel();
      return _GuardedStreamDone<T>();
    }
    if (_events.isNotEmpty) return _events.removeFirst();
    if (_isTerminal) return _GuardedStreamDone<T>();
    final waiting = Completer<_GuardedStreamEvent<T>>();
    _waiting = waiting;
    return waiting.future;
  }

  Future<void> cancel() {
    final existing = _cancellation;
    if (existing != null) return existing;
    _isCancellationRequested = true;
    final subscription = _subscription;
    _subscription = null;
    final cancellation = Future<void>.sync(() async {
      await subscription?.cancel();
    }).whenComplete(() {
      _events.clear();
      final waiting = _waiting;
      _waiting = null;
      if (waiting != null && !waiting.isCompleted) {
        waiting.complete(_GuardedStreamDone<T>());
      }
    });
    _cancellation = cancellation;
    return cancellation;
  }

  void _onData(T value) {
    if (_isTerminal || _isCancellationRequested) return;
    _emit(_GuardedStreamData<T>(value));
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (_isTerminal || _isCancellationRequested) return;
    _isTerminal = true;
    _emit(_GuardedStreamError<T>(error, stackTrace));
  }

  void _onDone() {
    if (_isTerminal || _isCancellationRequested) return;
    _isTerminal = true;
    _emit(_GuardedStreamDone<T>());
  }

  void _emit(_GuardedStreamEvent<T> event) {
    final waiting = _waiting;
    if (waiting == null) {
      _events.add(event);
      return;
    }
    _waiting = null;
    waiting.complete(event);
  }
}

sealed class _GuardedStreamEvent<T> {
  const _GuardedStreamEvent();
}

final class _GuardedStreamData<T> extends _GuardedStreamEvent<T> {
  const _GuardedStreamData(this.value);

  final T value;
}

final class _GuardedStreamError<T> extends _GuardedStreamEvent<T> {
  const _GuardedStreamError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class _GuardedStreamDone<T> extends _GuardedStreamEvent<T> {
  const _GuardedStreamDone();
}
