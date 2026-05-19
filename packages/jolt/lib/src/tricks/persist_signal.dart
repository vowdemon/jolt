import "dart:async";

import "package:jolt/core.dart";
import "package:jolt/jolt.dart";
import "package:meta/meta.dart";

mixin _PersistWriteMixin<T> on SignalImpl<T> {
  FutureOr<void> Function(T value) get write;

  Duration? get throttle;

  // ===== Write Queue (2-element) =====

  _WriteTask<T>? _writing;

  _WriteTask<T>? _pending;

  Timer? _writeTimer;

  Completer<void>? _timerCompleter;

  T? _throttledValue;

  void _scheduleWrite(T value) {
    if (throttle != null) {
      // Update throttled value (always keep the latest)
      _throttledValue = value;

      // If timer is not running, start it
      if (_writeTimer == null) {
        _timerCompleter = Completer<void>();
        _writeTimer = Timer(throttle!, () {
          // Execute trailing write with the latest value
          final valueToWrite = _throttledValue as T;
          _throttledValue = null;
          _writeTimer = null;
          _timerCompleter?.complete();
          _timerCompleter = null;
          _enqueueWrite(valueToWrite);
        });
      }
      // If timer is already running, just update the value (don't cancel)
    } else {
      // No throttle, enqueue immediately
      _enqueueWrite(value);
    }
  }

  void _enqueueWrite(T value) {
    final task = _WriteTask<T>(value);

    if (_writing == null) {
      // ✅ Slot 1 empty: start writing immediately
      _writing = task;
      _executeWrite(task);
    } else {
      // ✅ Slot 1 busy: put in slot 2 (overwrites any existing pending)
      _pending = task;
    }
  }

  Future<void> _executeWrite(_WriteTask<T> task) async {
    try {
      final result = write(task.value);
      if (result is Future) {
        await result;
      }
    } catch (_) {
      // Silently ignore write errors (optimistic update already applied)
    } finally {
      task.completer.complete();
      _onWriteComplete();
    }
  }

  void _onWriteComplete() {
    // Clear slot 1
    _writing = null;

    // If slot 2 has a pending write, move it to slot 1 and execute
    if (_pending != null) {
      _writing = _pending;
      _pending = null;
      _executeWrite(_writing!);
    }
  }

  Future<void> ensureWrite() async {
    while (true) {
      // Wait for currently writing task
      if (_writing != null) {
        await _writing!.completer.future;
        // After _writing completes, _pending may have been moved to _writing
        // Continue loop to check again
        continue;
      }

      // Wait for throttled write timer and its resulting write
      if (_writeTimer != null && _timerCompleter != null) {
        // Wait for timer to complete
        await _timerCompleter!.future;
        // After timer completes, it may have triggered a write
        // Continue loop to check for any writes that may have been enqueued
        continue;
      }

      // No more pending writes, exit loop
      break;
    }
  }
}

class _WriteTask<T> {
  _WriteTask(this.value) : completer = Completer<void>();

  final T value;

  final Completer<void> completer;
}

class _SyncPersistSignalImpl<T> extends SignalImpl<T>
    with _PersistWriteMixin<T>
    implements PersistSignal<T> {
  _SyncPersistSignalImpl({
    required this.read,
    required this.write,
    bool lazy = false,
    this.throttle,
    super.debug,
  }) : super(null) {
    if (!lazy) {
      _loadSync();
    }
  }

  _SyncPersistSignalImpl.lazy({
    required this.read,
    required this.write,
    this.throttle,
    super.debug,
  }) : super(null);

  final T Function() read;

  @override
  final FutureOr<void> Function(T value) write;

  @override
  final Duration? throttle;

  // ===== Initialization State =====

  @override
  @visibleForTesting
  int version = 0;

  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  // ===== Initialization =====

  void _loadSync() {
    final loadVersion = version;
    final result = read();
    if (version == loadVersion) {
      super.value = result;
    }
    _isInitialized = true;
  }

  // ===== Value Access =====

  @override
  T get value {
    // Trigger lazy initialization
    if (!_isInitialized) {
      _loadSync();
    }
    return super.value;
  }

  @override
  Future<T> getEnsured() async {
    // Sync version is always initialized when accessed
    return super.value;
  }

  // ===== Value Mutation =====

  @override
  set value(T newValue) {
    if (!_isInitialized) {
      _loadSync();
    }

    super.value = newValue;
    version++;

    _scheduleWrite(newValue);
  }

  @override
  Future<void> ensure([FutureOr<void> Function(T value)? fn]) async {
    // Sync version is always initialized
    await fn?.call(super.value);
  }
}

class _AsyncPersistSignalImpl<T> extends SignalImpl<T>
    with _PersistWriteMixin<T>
    implements PersistSignal<T> {
  _AsyncPersistSignalImpl({
    required this.read,
    required this.write,
    this.initialValue,
    bool lazy = false,
    this.throttle,
    super.debug,
  }) : super(null) {
    if (!lazy) {
      _load();
    }
  }

  _AsyncPersistSignalImpl.lazy({
    required this.read,
    required this.write,
    this.initialValue,
    this.throttle,
    super.debug,
  }) : super(null);

  final T Function()? initialValue;

  final Future<T> Function() read;

  @override
  final FutureOr<void> Function(T value) write;

  @override
  final Duration? throttle;

  // ===== Initialization State =====

  @override
  @visibleForTesting
  int version = 0;

  bool _isInitialized = false;

  Completer<void>? _initCompleter;

  @override
  bool get isInitialized => _isInitialized;

  // ===== Initialization =====

  Future<void> _load() {
    // Return existing init future if already loading
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    final loadVersion = version;
    final result = read();

    batch(() {
      if (initialValue != null) {
        super.value = initialValue!();
      }

      // Async read
      result.then((loadedValue) {
        // Only apply loaded value if version hasn't changed
        if (version == loadVersion) {
          super.value = loadedValue;
        }
        _isInitialized = true;
        _initCompleter!.complete();
      }).catchError((error, stackTrace) {
        // On error, mark as initialized (keeps initialValue if provided)
        _isInitialized = true;
        _initCompleter!.completeError(error, stackTrace);
      });
    });

    return _initCompleter!.future;
  }

  // ===== Value Access =====

  @override
  T get value {
    // Trigger lazy initialization
    if (!_isInitialized && _initCompleter == null) {
      unawaited(_load());
    }
    return super.value;
  }

  @override
  Future<T> getEnsured() async {
    if (!_isInitialized) {
      await _load();
    }
    return super.value;
  }

  // ===== Value Mutation =====

  @override
  set value(T newValue) {
    // Enforce initialization
    if (!_isInitialized) {
      throw StateError(
        'Cannot write to PersistSignal before initialization completes.  '
        'Use await signal.getEnsured() or await signal.ensure() first.',
      );
    }

    // Update value immediately (optimistic)
    super.value = newValue;
    version++;

    // Schedule write
    _scheduleWrite(newValue);
  }

  @override
  Future<void> ensure([FutureOr<void> Function(T value)? fn]) {
    if (!_isInitialized) {
      final loadFuture = _load();
      if (fn == null) {
        return loadFuture;
      }
      return loadFuture.then((_) => fn(super.value));
    }
    if (fn == null) {
      return Future.value();
    }
    final result = fn(super.value);
    if (result is Future) {
      return result;
    }
    return Future.value();
  }
}

/// A signal that persists its value to external storage.
///
/// [PersistSignal] keeps an in-memory reactive value and writes later
/// assignments through the provided storage callback. Use the synchronous
/// factories when storage reads are immediate, and the asynchronous factories
/// when loading requires a [Future].
abstract interface class PersistSignal<T> implements Signal<T> {
  /// Creates a persistent signal backed by synchronous storage reads.
  ///
  /// The [read] callback loads the stored value. The [write] callback persists
  /// later assignments. When [lazy] is `false`, this signal reads storage
  /// during construction. When [lazy] is `true`, it reads on the first access
  /// or write. Set [throttle] to delay persistence and collapse writes that
  /// arrive during the throttle window to the latest value.
  ///
  /// ```dart
  /// final theme = PersistSignal.sync(
  ///   read: () => prefs.getString('theme') ?? 'light',
  ///   write: (value) => prefs.setString('theme', value),
  /// );
  ///
  /// theme.value = 'dark';
  /// await theme.ensureWrite();
  /// ```
  factory PersistSignal.sync({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    bool lazy,
    Duration? throttle,
    JoltDebugOption? debug,
  }) = _SyncPersistSignalImpl<T>;

  /// Creates a lazily initialized persistent signal with synchronous storage reads.
  ///
  /// This is equivalent to [PersistSignal.sync] with `lazy: true`.
  factory PersistSignal.lazySync({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    Duration? throttle,
    JoltDebugOption? debug,
  }) = _SyncPersistSignalImpl<T>.lazy;

  /// Creates a persistent signal backed by asynchronous storage reads.
  ///
  /// The [read] callback loads the stored value. The [write] callback persists
  /// later assignments. When [lazy] is `false`, loading starts during
  /// construction. When [lazy] is `true`, loading starts on the first access or
  /// call to [ensure] or [getEnsured]. The optional [initialValue] supplies a
  /// temporary in-memory value while loading is in progress. Assigning
  /// [PersistSignal.value] before initialization completes throws [StateError].
  /// Set [throttle] to delay persistence and collapse writes that arrive during
  /// the throttle window to the latest value.
  ///
  /// ```dart
  /// final profile = PersistSignal.async(
  ///   read: () async => api.loadName(),
  ///   write: (value) => api.saveName(value),
  ///   initialValue: () => 'Loading...',
  /// );
  ///
  /// await profile.ensure();
  /// print(profile.value);
  /// ```
  factory PersistSignal.async({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    T Function()? initialValue,
    bool lazy,
    Duration? throttle,
    JoltDebugOption? debug,
  }) = _AsyncPersistSignalImpl<T>;

  /// Creates a lazily initialized persistent signal with asynchronous storage reads.
  ///
  /// This is equivalent to [PersistSignal.async] with `lazy: true`.
  factory PersistSignal.lazyAsync({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    T Function()? initialValue,
    Duration? throttle,
    JoltDebugOption? debug,
  }) = _AsyncPersistSignalImpl<T>.lazy;

  /// Whether this signal has finished its initial storage load.
  ///
  /// Synchronous eager signals become initialized during construction.
  /// Asynchronous signals become initialized after [ensure] or [getEnsured]
  /// finishes, or after a lazy load triggered by a read completes.
  bool get isInitialized;

  /// A testing hook for the load-versus-write version counter.
  ///
  /// Jolt uses [version] to ignore stale storage reads that complete after a
  /// newer in-memory value was written.
  @visibleForTesting
  int get version;

  @visibleForTesting
  set version(int value);

  /// The current value after ensuring initialization completed.
  ///
  /// Synchronous signals return immediately. Asynchronous signals wait for the
  /// initial storage load when needed.
  Future<T> getEnsured();

  /// Ensures initialization and optionally runs [fn] with the loaded value.
  ///
  /// When [fn] is provided, it runs only after initialization completes, and
  /// the returned future waits for [fn] if it returns a [Future].
  Future<void> ensure([FutureOr<void> Function(T value)? fn]);

  /// Waits for all pending persistence work to complete.
  ///
  /// This includes the in-flight write, the queued trailing write, and any
  /// write delayed by [throttle].
  ///
  /// ```dart
  /// signal.value = 'dark';
  /// await signal.ensureWrite();
  /// ```
  Future<void> ensureWrite();
}
