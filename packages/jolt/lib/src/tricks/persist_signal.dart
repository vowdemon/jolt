import "dart:async";

import "package:jolt/jolt.dart";
import "package:jolt/src/jolt/signal.dart";

/// Mixin providing write queue and throttling for persistent signals.
///
/// Uses a 2-element queue to ensure writes are never lost and supports
/// throttling to debounce rapid writes.
mixin _PersistWriteMixin<T> on SignalImpl<T> {
  /// Function to write the value to storage.
  FutureOr<void> Function(T value) get write;

  /// Throttle delay before writing (null = no throttling).
  Duration? get throttle;

  // ===== Write Queue (2-element) =====

  /// Currently writing value (slot 1).
  _WriteTask<T>? _writing;

  /// Pending write value (slot 2).
  _WriteTask<T>? _pending;

  /// Timer for throttled writes.
  Timer? _writeTimer;

  /// Completer to track when throttle timer completes.
  Completer<void>? _timerCompleter;

  /// Value to write when throttle timer expires (for trailing write).
  T? _throttledValue;

  /// Schedules a write with throttling (trailing edge).
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

  /// Enqueues a write in the 2-element queue.
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

  /// Executes a write task asynchronously.
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

  /// Handles write completion and processes next pending write.
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

  /// Waits for all pending writes to complete.
  ///
  /// Includes: currently executing write, pending write in queue,
  /// and throttled write waiting for timer.
  ///
  /// Example:
  /// ```dart
  /// signal.value = 'new value';
  /// await signal.ensureWrite(); // Wait for write
  /// ```
  Future<void> ensureWrite() async {
    while (true) {
      // Wait for currently writing task
      if (_writing != null) {
        await _writing!.completer.future;
        // After _writing completes, _pending may have been moved to _writing
        // Continue loop to check again
        continue;
      }

      // coverage:ignore-start
      // Wait for pending write task
      if (_pending != null) {
        await _pending!.completer.future;
        // After _pending completes, it may have been moved to _writing
        // Continue loop to check again
        continue;
      }
      // coverage:ignore-end

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

/// A write task in the queue.
class _WriteTask<T> {
  _WriteTask(this.value) : completer = Completer<void>();

  /// Value to write.
  final T value;

  /// Completer for task completion.
  final Completer<void> completer;
}

/// Synchronous persistent signal implementation.
///
/// Reads values synchronously and initializes immediately (unless lazy).
/// Uses a 2-element write queue for efficient writes.
///
/// **Note:** Write operations require initialization. Lazy signals
/// auto-initialize on first access.
class SyncPersistSignalImpl<T> extends SignalImpl<T>
    with _PersistWriteMixin<T>
    implements PersistSignal<T> {
  /// Creates a synchronous persistent signal.
  ///
  /// Parameters:
  /// - [read]: Synchronous function to read from storage
  /// - [write]: Function to write to storage
  /// - [lazy]: Defer loading until first access (default: false)
  /// - [throttle]: Delay before writing (null = no throttling)
  /// - [onDebug]: Optional debug callback
  ///
  /// Example:
  /// ```dart
  /// final theme = PersistSignal.sync(
  ///   read: () => prefs.getString('theme') ?? 'light',
  ///   write: (value) => prefs.setString('theme', value),
  /// );
  /// ```
  SyncPersistSignalImpl({
    required this.read,
    required this.write,
    bool lazy = false,
    this.throttle,
    super.onDebug,
  }) : super(null) {
    if (!lazy) {
      _loadSync();
    }
  }

  SyncPersistSignalImpl.lazy({
    required this.read,
    required this.write,
    this.throttle,
    super.onDebug,
  }) : super(null);

  /// Synchronous read function.
  final T Function() read;

  /// Write function (sync or async).
  @override
  final FutureOr<void> Function(T value) write;

  /// Throttle delay (null = no throttling).
  @override
  final Duration? throttle;

  // ===== Initialization State =====

  /// Version counter for tracking state changes.
  int _version = 0;

  /// Whether initialized from storage.
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  // ===== Initialization =====

  /// Loads value from storage synchronously.
  void _loadSync() {
    final loadVersion = _version;
    final result = read();
    if (_version == loadVersion) {
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
    _version++;

    _scheduleWrite(newValue);
  }

  @override
  Future<void> ensure([FutureOr<void> Function(T value)? fn]) async {
    // Sync version is always initialized
    await fn?.call(super.value);
  }
}

/// Asynchronous persistent signal implementation.
///
/// Reads values asynchronously and supports optional initialValue during loading.
/// Uses a 2-element write queue for efficient writes.
///
/// **Note:** Write operations require initialization. Use [ensure] or
/// [getEnsured] before writing, or check [isInitialized].
class AsyncPersistSignalImpl<T> extends SignalImpl<T>
    with _PersistWriteMixin<T>
    implements PersistSignal<T> {
  /// Creates an asynchronous persistent signal.
  ///
  /// Parameters:
  /// - [read]: Async function to read from storage
  /// - [write]: Function to write to storage
  /// - [initialValue]: Optional temporary value during loading (null if omitted)
  /// - [lazy]: Defer loading until first access (default: false)
  /// - [throttle]: Delay before writing (null = no throttling)
  /// - [onDebug]: Optional debug callback
  ///
  /// Example:
  /// ```dart
  /// final theme = PersistSignal.async(
  ///   read: () async => await prefs.getString('theme') ?? 'light',
  ///   write: (value) => prefs.setString('theme', value),
  ///   initialValue: () => 'light',  // Show while loading
  /// );
  /// ```
  AsyncPersistSignalImpl({
    required this.read,
    required this.write,
    this.initialValue,
    bool lazy = false,
    this.throttle,
    super.onDebug,
  }) : super(null) {
    if (!lazy) {
      _load();
    }
  }

  AsyncPersistSignalImpl.lazy({
    required this.read,
    required this.write,
    this.initialValue,
    this.throttle,
    super.onDebug,
  }) : super(null);

  /// Optional temporary value during async loading (for display).
  final T Function()? initialValue;

  /// Async read function.
  final Future<T> Function() read;

  /// Write function (sync or async).
  @override
  final FutureOr<void> Function(T value) write;

  /// Throttle delay (null = no throttling).
  @override
  final Duration? throttle;

  // ===== Initialization State =====

  /// Version counter for tracking state changes.
  int _version = 0;

  /// Whether initialized from storage.
  bool _isInitialized = false;

  /// Completer for initialization operation.
  Completer<void>? _initCompleter;

  @override
  bool get isInitialized => _isInitialized;

  // ===== Initialization =====

  /// Loads value from storage asynchronously.
  Future<void> _load() {
    // Return existing init future if already loading
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    final loadVersion = _version;
    final result = read();

    batch(() {
      if (initialValue != null) {
        super.value = initialValue!();
      }

      // Async read
      result.then((loadedValue) {
        // Only apply loaded value if version hasn't changed
        if (_version == loadVersion) {
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
    _version++;

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

/// Signal that persists its value to external storage.
///
/// Automatically saves value changes to storage. Supports sync/async reads,
/// lazy loading, and write throttling. Uses a 2-element write queue.
///
/// **Initialization:**
/// - Sync signals: initialized immediately (or on first access if lazy)
/// - Async signals: must call [ensure] or [getEnsured] before writing
///
/// Example (sync):
/// ```dart
/// final theme = PersistSignal.sync(
///   read: () => prefs.getString('theme') ?? 'light',
///   write: (value) => prefs.setString('theme', value),
/// );
/// theme.value = 'dark'; // Auto-saved
/// ```
///
/// Example (async):
/// ```dart
/// final theme = PersistSignal.async(
///   read: () async => await prefs.getString('theme') ?? 'light',
///   write: (value) => prefs.setString('theme', value),
///   initialValue: () => 'light',
/// );
/// await theme.ensure(); // Wait for init
/// theme.value = 'dark'; // Auto-saved
/// ```
abstract interface class PersistSignal<T> implements Signal<T> {
  /// Creates a synchronous persistent signal.
  ///
  /// Parameters:
  /// - [read]: Sync function to read from storage
  /// - [write]: Function to write to storage
  /// - [lazy]: Defer loading until first access (default: false)
  /// - [throttle]: Delay before writing (null = no throttling)
  /// - [onDebug]: Optional debug callback
  ///
  /// Example:
  /// ```dart
  /// final theme = PersistSignal.sync(
  ///   read: () => prefs.getString('theme') ?? 'light',
  ///   write: (value) => prefs.setString('theme', value),
  /// );
  /// ```
  factory PersistSignal.sync({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    bool lazy,
    Duration? throttle,
    JoltDebugFn? onDebug,
  }) = SyncPersistSignalImpl<T>;

  /// Creates a lazy synchronous persistent signal.
  ///
  /// Parameters:
  /// - [read]: Sync function to read from storage
  /// - [write]: Function to write to storage
  /// - [throttle]: Delay before writing (null = no throttling)
  /// - [onDebug]: Optional debug callback
  ///
  /// Example:
  /// ```dart
  /// final settings = PersistSignal.lazySync(
  ///   read: () => loadSettings(),
  ///   write: (value) => saveSettings(value),
  /// );
  /// ```
  factory PersistSignal.lazySync({
    required T Function() read,
    required FutureOr<void> Function(T value) write,
    Duration? throttle,
    JoltDebugFn? onDebug,
  }) = SyncPersistSignalImpl<T>.lazy;

  /// Creates an asynchronous persistent signal.
  ///
  /// Parameters:
  /// - [read]: Async function to read from storage
  /// - [write]: Function to write to storage
  /// - [initialValue]: Optional temporary value during loading (null if omitted)
  /// - [lazy]: Defer loading until first access (default: false)
  /// - [throttle]: Delay before writing (null = no throttling)
  /// - [onDebug]: Optional debug callback
  ///
  /// Example:
  /// ```dart
  /// final counter = PersistSignal.async(
  ///   read: () async => await prefs.getInt('counter') ?? 0,
  ///   write: (value) => prefs.setInt('counter', value),
  ///   initialValue: () => 0,  // Show while loading
  /// );
  /// ```
  factory PersistSignal.async({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    T Function()? initialValue,
    bool lazy,
    Duration? throttle,
    JoltDebugFn? onDebug,
  }) = AsyncPersistSignalImpl<T>;

  /// Creates a lazy asynchronous persistent signal.
  ///
  /// Parameters:
  /// - [read]: Async function to read from storage
  /// - [write]: Function to write to storage
  /// - [initialValue]: Optional temporary value during loading (null if omitted)
  /// - [throttle]: Delay before writing (null = no throttling)
  /// - [onDebug]: Optional debug callback
  ///
  /// Example:
  /// ```dart
  /// final settings = PersistSignal.lazyAsync(
  ///   read: () async => await loadSettings(),
  ///   write: (value) async => await saveSettings(value),
  ///   initialValue: () => defaultSettings,
  /// );
  /// ```
  factory PersistSignal.lazyAsync({
    required Future<T> Function() read,
    required FutureOr<void> Function(T value) write,
    T Function()? initialValue,
    Duration? throttle,
    JoltDebugFn? onDebug,
  }) = AsyncPersistSignalImpl<T>.lazy;

  /// Whether initialized from storage.
  bool get isInitialized;

  /// Gets value, ensuring initialization is complete.
  ///
  /// Waits for storage to load if needed.
  ///
  /// Returns: The loaded value
  Future<T> getEnsured();

  /// Ensures initialization, optionally running a function.
  ///
  /// Parameters:
  /// - [fn]: Optional function to run after initialization
  ///
  /// Example:
  /// ```dart
  /// await counter.ensure(() {
  ///   counter.value++; // Safe to write
  /// });
  /// ```
  Future<void> ensure([FutureOr<void> Function(T value)? fn]);

  /// Waits for all pending writes to complete.
  ///
  /// Includes: currently executing write, pending write in queue,
  /// and throttled write waiting for timer.
  ///
  /// Example:
  /// ```dart
  /// signal.value = 'new value';
  /// await signal.ensureWrite(); // Wait for write
  /// ```
  Future<void> ensureWrite();
}
